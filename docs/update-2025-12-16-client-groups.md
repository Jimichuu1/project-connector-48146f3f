# Update: Client Groups & Database Structure Consistency

**Date:** 2025-12-16

---

## Overview

This update introduces the **Client Groups** feature for organizing clients into groups (similar to Lead Groups), along with database structure consistency improvements and new UI features.

---

## New Features

### 1. Client Groups

Clients can now be organized into groups, similar to how leads can be organized.

#### System Groups (Auto-Created Per Tenant)
- **Converted** - Automatically populated with clients converted from leads
- **Live** - For manually created clients marked as live

#### Database Tables

```sql
-- Client groups table
CREATE TABLE public.client_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_system BOOLEAN DEFAULT false,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client group members table
CREATE TABLE public.client_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.client_groups(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  added_by UUID REFERENCES public.profiles(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id, client_id)
);
```

#### Key Functions

```sql
-- Get or create system groups for a tenant
CREATE OR REPLACE FUNCTION get_or_create_client_system_groups(
  p_admin_id uuid, 
  p_user_id uuid
)
RETURNS TABLE(converted_group_id uuid, live_group_id uuid);

-- Trigger to auto-add converted clients to "Converted" group
CREATE TRIGGER auto_add_client_to_converted_group
AFTER INSERT ON public.clients
FOR EACH ROW
EXECUTE FUNCTION auto_add_client_to_converted_group();
```

#### UI Components

- `ClientGroupDisplay` - Shows client's group with colored badges
  - **Converted**: Purple badge
  - **Live**: Red badge
- `AssignClientGroupDialog` - Dialog to assign clients to groups
- Client Groups column added to Clients table

---

### 2. Country Detection from Phone Number

The country column in the Clients table now derives the country from the phone number's international calling code instead of using stored (potentially incorrect) data.

#### Implementation

```typescript
import { getCountryFromPhone, getCountryCode } from "@/lib/phoneCountryCode";

// In ClientsTableView.tsx
<TableCell>
  {getCountryCode(getCountryFromPhone(client.home_phone)) || "-"}
</TableCell>
```

This shows short country codes (USA, UK, DE, etc.) derived from the phone number prefix.

---

## Database Structure Improvements

### Consistency Between lead_groups and client_groups

Applied NOT NULL constraints to align `client_groups` with `lead_groups` structure:

```sql
-- Fix client_groups timestamps
ALTER TABLE public.client_groups ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE public.client_groups ALTER COLUMN updated_at SET NOT NULL;

-- Fix client_group_members timestamps
ALTER TABLE public.client_group_members ALTER COLUMN added_at SET NOT NULL;

-- Add missing index to lead_groups
CREATE INDEX IF NOT EXISTS idx_lead_groups_admin_id ON public.lead_groups(admin_id);
```

### Column Comparison

| Column | lead_groups | client_groups |
|--------|-------------|---------------|
| `created_at` | NOT NULL | NOT NULL ✅ |
| `updated_at` | NOT NULL | NOT NULL ✅ |
| `created_by` | NOT NULL | NULL (allows system creation) |
| `added_at` (members) | NOT NULL | NOT NULL ✅ |
| `added_by` (members) | NOT NULL | NULL (allows trigger creation) |

**Note:** `created_by` and `added_by` remain nullable in client_groups to support:
- System group auto-creation via `get_or_create_client_system_groups()`
- Auto-assignment via `auto_add_client_to_converted_group()` trigger

---

## RLS Policies for Client Groups

```sql
-- View client groups in tenant
CREATE POLICY "Users can view client groups in tenant" ON client_groups
FOR SELECT USING (can_access_tenant(admin_id));

-- Create client groups (SUPER_ADMIN, TENANT_OWNER, MANAGER only)
CREATE POLICY "Authorized users can create client groups" ON client_groups
FOR INSERT WITH CHECK (
  (auth.uid() = created_by) AND 
  (has_role(auth.uid(), 'SUPER_ADMIN') OR 
   has_role(auth.uid(), 'TENANT_OWNER') OR 
   has_role(auth.uid(), 'MANAGER'))
);

-- Update client groups
CREATE POLICY "Authorized users can update client groups" ON client_groups
FOR UPDATE USING (
  has_role(auth.uid(), 'SUPER_ADMIN') OR 
  ((has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER')) AND 
   (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id)))
);

-- Delete non-system client groups
CREATE POLICY "Authorized users can delete non-system client groups" ON client_groups
FOR DELETE USING (
  (is_system = false) AND 
  (has_role(auth.uid(), 'SUPER_ADMIN') OR 
   ((has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER')) AND 
    (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id))))
);
```

---

## UI Changes

### Clients Table

1. **New "Client Group" column** - Shows group badge (Converted/Live)
2. **Country column** - Now derives from phone code, shows short codes
3. **Column reordering** - Client Group moved before Balance column

### Badge Colors

| Group | Border | Background | Text |
|-------|--------|------------|------|
| Converted | purple-500 | purple-500/10 | purple-500 |
| Live | red-500 | red-500/10 | red-500 |

---

## Files Modified

### Components
- `src/components/clients/ClientGroupDisplay.tsx` - New component
- `src/components/clients/AssignClientGroupDialog.tsx` - Updated to ensure system groups exist
- `src/components/clients/ClientsTableView.tsx` - Added Client Group column, country from phone

### Hooks
- `src/hooks/useClientGroups.ts` - Added `getSystemGroupIds()` function

### Libraries
- `src/lib/phoneCountryCode.ts` - Used for country detection from phone codes

---

## Migration Summary

```sql
-- Run in order:

-- 1. Create client_groups table (if not exists)
-- 2. Create client_group_members table (if not exists)
-- 3. Apply NOT NULL constraints
ALTER TABLE public.client_groups ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE public.client_groups ALTER COLUMN updated_at SET NOT NULL;
ALTER TABLE public.client_group_members ALTER COLUMN added_at SET NOT NULL;

-- 4. Add performance index
CREATE INDEX IF NOT EXISTS idx_lead_groups_admin_id ON public.lead_groups(admin_id);
```

# Row-Level Security (RLS) AI Context Prompt

## Project Overview

This is a **multi-tenant Forex CRM** using Supabase PostgreSQL with comprehensive Row-Level Security. RLS enforces data isolation between tenants and role-based access control at the database level.

---

## RLS Fundamentals

### What is RLS?

Row-Level Security restricts which rows users can SELECT, INSERT, UPDATE, or DELETE based on policies. Policies are SQL expressions evaluated for each row.

```sql
-- Enable RLS on a table (REQUIRED)
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners too (optional but recommended)
ALTER TABLE my_table FORCE ROW LEVEL SECURITY;
```

### Policy Types

| Command | Description |
|---------|-------------|
| `SELECT` | Controls which rows can be read |
| `INSERT` | Controls which rows can be inserted |
| `UPDATE` | Controls which rows can be modified |
| `DELETE` | Controls which rows can be removed |
| `ALL` | Applies to all operations |

### Policy Clauses

- **USING**: Filters existing rows (SELECT, UPDATE, DELETE)
- **WITH CHECK**: Validates new/modified rows (INSERT, UPDATE)

```sql
CREATE POLICY "policy_name" ON table_name
FOR SELECT                    -- Command type
TO authenticated             -- Role (optional, defaults to PUBLIC)
USING (condition)            -- Filter existing rows
WITH CHECK (condition);      -- Validate new rows
```

---

## Critical Security Rules

### 1. NEVER Query the Same Table in RLS Policy

This causes infinite recursion:

```sql
-- ❌ WRONG - Causes infinite recursion
CREATE POLICY "Admins can view all" ON profiles
FOR SELECT USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'ADMIN'
);
```

### 2. ALWAYS Use Security Definer Functions

```sql
-- ✅ CORRECT - Use security definer function
CREATE FUNCTION has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE POLICY "Admins can view all" ON profiles
FOR SELECT USING (has_role(auth.uid(), 'ADMIN'));
```

### 3. User ID Columns Must NOT Be Nullable

If RLS uses `user_id` for filtering, it must be NOT NULL:

```sql
-- ✅ CORRECT
user_id uuid NOT NULL REFERENCES auth.users(id)

-- ❌ WRONG - Nullable user_id breaks RLS
user_id uuid REFERENCES auth.users(id)
```

### 4. Always Set user_id on Insert

Frontend must include user_id in inserts:

```typescript
// ✅ CORRECT
await supabase.from('table').insert({
  user_id: user.id,  // REQUIRED
  ...data
});

// ❌ WRONG - Missing user_id
await supabase.from('table').insert({ ...data });
```

---

## Security Definer Functions

These functions bypass RLS and run with owner privileges. Essential for avoiding recursion.

### Role Check Functions

```sql
-- Check if user has specific role
CREATE OR REPLACE FUNCTION has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Check if user has specific permission
CREATE OR REPLACE FUNCTION has_permission(_user_id uuid, _permission app_permission)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_permissions
    WHERE user_id = _user_id AND permission = _permission
  )
$$;

-- Get user's role as text
CREATE OR REPLACE FUNCTION get_user_role_direct(check_user_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::text FROM user_roles WHERE user_id = check_user_id LIMIT 1
$$;

-- Check if user is super admin
CREATE OR REPLACE FUNCTION is_super_admin(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = _user_id AND role = 'SUPER_ADMIN'
  )
$$;

-- Check if user is admin or tenant owner
CREATE OR REPLACE FUNCTION is_admin_or_tenant_owner(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = _user_id
    AND role IN ('SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER')
  )
$$;
```

### Tenant Access Functions

```sql
-- Get tenant owner ID for a user
CREATE OR REPLACE FUNCTION get_user_admin_id(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid;
  v_created_by uuid;
  v_role text;
  v_max_depth int := 10;
  v_depth int := 0;
BEGIN
  v_current_user := p_user_id;
  
  WHILE v_depth < v_max_depth LOOP
    -- Check if current user is a TENANT_OWNER
    SELECT role INTO v_role
    FROM user_roles
    WHERE user_id = v_current_user
    LIMIT 1;
    
    IF v_role = 'TENANT_OWNER' THEN
      RETURN v_current_user;
    END IF;
    
    -- Get who created this user
    SELECT created_by INTO v_created_by
    FROM profiles
    WHERE id = v_current_user;
    
    -- If no creator found or self-referencing, break
    IF v_created_by IS NULL OR v_created_by = v_current_user THEN
      RETURN NULL;
    END IF;
    
    v_current_user := v_created_by;
    v_depth := v_depth + 1;
  END LOOP;
  
  RETURN NULL;
END;
$$;

-- Check if user can access a tenant's data
CREATE OR REPLACE FUNCTION can_access_tenant(_admin_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_admin_id uuid;
  v_profile_admin_id uuid;
BEGIN
  -- SUPER_ADMIN can access everything
  IF has_role(auth.uid(), 'SUPER_ADMIN') THEN
    RETURN true;
  END IF;
  
  -- Get current user's admin_id from profile
  SELECT p.admin_id INTO v_profile_admin_id
  FROM profiles p
  WHERE p.id = auth.uid();
  
  -- TENANT_OWNER checking their own data
  IF has_role(auth.uid(), 'TENANT_OWNER') AND (_admin_id = auth.uid() OR _admin_id IS NULL) THEN
    RETURN true;
  END IF;
  
  -- If record has no admin_id, only SUPER_ADMIN can see
  IF _admin_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Use profile's admin_id for faster lookup
  IF v_profile_admin_id IS NOT NULL THEN
    RETURN v_profile_admin_id = _admin_id;
  END IF;
  
  -- Fallback to chain traversal
  v_user_admin_id := get_user_admin_id(auth.uid());
  
  IF v_user_admin_id IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN v_user_admin_id = _admin_id;
END;
$$;

-- Get all user IDs in same tenant
CREATE OR REPLACE FUNCTION get_tenant_user_ids(_user_id uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p2.id
  FROM profiles p1
  JOIN profiles p2 ON (
    p1.admin_id = p2.admin_id 
    OR p1.id = p2.admin_id 
    OR p2.id = p1.admin_id
    OR p1.admin_id IS NULL AND p2.admin_id IS NULL
  )
  WHERE p1.id = _user_id
$$;
```

### Group Chat Functions

```sql
-- Check if user is member of a group
CREATE OR REPLACE FUNCTION is_group_member(p_group_chat_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_chat_members
    WHERE group_chat_id = p_group_chat_id
    AND user_id = p_user_id
  )
$$;

-- Check if group is static (auto-managed)
CREATE OR REPLACE FUNCTION is_static_group(p_group_chat_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_chats
    WHERE id = p_group_chat_id
    AND is_static = true
  )
$$;
```

### Privacy Functions

```sql
-- Check if current user can view phone numbers
CREATE OR REPLACE FUNCTION can_view_phone()
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  show_to_agents boolean;
  show_to_super_agents boolean;
BEGIN
  -- Admins and Managers always see
  IF has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER') THEN
    RETURN true;
  END IF;
  
  -- Get visibility settings
  SELECT gs.show_phone_to_agents, gs.show_phone_to_super_agents
  INTO show_to_agents, show_to_super_agents
  FROM general_settings gs
  LIMIT 1;
  
  IF has_role(auth.uid(), 'AGENT') THEN
    RETURN COALESCE(show_to_agents, false);
  END IF;
  
  IF has_role(auth.uid(), 'SUPER_AGENT') THEN
    RETURN COALESCE(show_to_super_agents, true);
  END IF;
  
  RETURN false;
END;
$$;

-- Similar function for email visibility
CREATE OR REPLACE FUNCTION can_view_email()
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  show_to_agents boolean;
  show_to_super_agents boolean;
BEGIN
  IF has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER') THEN
    RETURN true;
  END IF;
  
  SELECT gs.show_email_to_agents, gs.show_email_to_super_agents
  INTO show_to_agents, show_to_super_agents
  FROM general_settings gs
  LIMIT 1;
  
  IF has_role(auth.uid(), 'AGENT') THEN
    RETURN COALESCE(show_to_agents, false);
  END IF;
  
  IF has_role(auth.uid(), 'SUPER_AGENT') THEN
    RETURN COALESCE(show_to_super_agents, true);
  END IF;
  
  RETURN false;
END;
$$;
```

### User Deletion Check

```sql
-- Check if user can delete another user
CREATE OR REPLACE FUNCTION can_delete_user(_target_user_id uuid, _current_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If target is SUPER_ADMIN, only another SUPER_ADMIN can delete
  IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = _target_user_id AND role = 'SUPER_ADMIN') THEN
    RETURN EXISTS (SELECT 1 FROM user_roles WHERE user_id = _current_user_id AND role = 'SUPER_ADMIN');
  END IF;
  
  -- For non-super-admin users, ADMIN and SUPER_ADMIN can delete
  RETURN EXISTS (
    SELECT 1 FROM user_roles 
    WHERE user_id = _current_user_id 
    AND role IN ('ADMIN', 'SUPER_ADMIN')
  );
END;
$$;
```

---

## Role Hierarchy

```
SUPER_ADMIN     → Full system access, manages all tenants
TENANT_OWNER    → Owns a tenant, manages their organization
ADMIN           → Full access within tenant (legacy, same as MANAGER)
MANAGER         → Full access within tenant
SUPER_AGENT     → Handles clients, limited lead access
AGENT           → Handles leads only, most restricted
```

### Role-Based Access Patterns

```sql
-- Super admin only
has_role(auth.uid(), 'SUPER_ADMIN')

-- Admin level (tenant full access)
has_role(auth.uid(), 'SUPER_ADMIN') OR 
has_role(auth.uid(), 'TENANT_OWNER') OR 
has_role(auth.uid(), 'ADMIN') OR 
has_role(auth.uid(), 'MANAGER')

-- Using text comparison for multiple roles
get_user_role_direct(auth.uid()) = ANY (
  ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER']::text[]
)

-- Combined check with is_admin_or_tenant_owner
is_admin_or_tenant_owner(auth.uid())
```

---

## Complete RLS Policies by Table

### profiles

```sql
-- Users can view profiles in their tenant
CREATE POLICY "Users can view profiles in tenant" ON profiles
FOR SELECT USING (
  can_access_tenant(admin_id) OR id = auth.uid()
);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
FOR UPDATE USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Admins can manage all profiles in tenant
CREATE POLICY "Admins manage profiles in tenant" ON profiles
FOR ALL USING (
  can_access_tenant(admin_id) AND 
  is_admin_or_tenant_owner(auth.uid())
)
WITH CHECK (is_admin_or_tenant_owner(auth.uid()));
```

### user_roles

```sql
-- Users can view roles in their tenant
CREATE POLICY "Users can view roles" ON user_roles
FOR SELECT USING (
  user_id = auth.uid() OR
  has_role(auth.uid(), 'SUPER_ADMIN') OR
  has_role(auth.uid(), 'ADMIN') OR
  has_role(auth.uid(), 'MANAGER')
);

-- Only admins can manage roles
CREATE POLICY "Admins can manage roles" ON user_roles
FOR ALL USING (
  has_role(auth.uid(), 'SUPER_ADMIN') OR
  has_role(auth.uid(), 'ADMIN')
)
WITH CHECK (
  has_role(auth.uid(), 'SUPER_ADMIN') OR
  has_role(auth.uid(), 'ADMIN')
);
```

### leads

```sql
-- Admins manage all leads in tenant
CREATE POLICY "Admins manage all leads" ON leads
FOR ALL USING (
  can_access_tenant(admin_id) AND
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER']::text[]
  )
)
WITH CHECK (
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER']::text[]
  )
);

-- Users can view leads assigned to them or created by them
CREATE POLICY "Users can view assigned leads" ON leads
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    transferred_by = auth.uid()
  )
);

-- Users can create leads
CREATE POLICY "Users can create leads" ON leads
FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Users can update assigned leads
CREATE POLICY "Users can update assigned leads" ON leads
FOR UPDATE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);

-- Only users with permission can delete leads
CREATE POLICY "Users with permission can delete leads" ON leads
FOR DELETE USING (
  has_permission(auth.uid(), 'CAN_DELETE_LEADS')
);
```

### clients

```sql
-- Admins manage all clients
CREATE POLICY "Admins manage all clients" ON clients
FOR ALL USING (
  can_access_tenant(admin_id) AND
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER']::text[]
  )
)
WITH CHECK (
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER']::text[]
  )
);

-- Users can view clients in their tenant
CREATE POLICY "Users can view clients in tenant" ON clients
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);

-- Super agents with CAN_ASSIGN_ALL can view all clients
CREATE POLICY "Super agents with assign permission" ON clients
FOR SELECT USING (
  can_access_tenant(admin_id) AND
  has_role(auth.uid(), 'SUPER_AGENT') AND
  has_permission(auth.uid(), 'CAN_ASSIGN_ALL')
);

-- Users can create clients
CREATE POLICY "Users can create clients" ON clients
FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Users can update accessible clients
CREATE POLICY "Users can update clients" ON clients
FOR UPDATE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);

-- Only users with delete permission
CREATE POLICY "Users with delete permission" ON clients
FOR DELETE USING (
  has_permission(auth.uid(), 'CAN_DELETE_LEADS')
);
```

### client_groups

```sql
-- Users can view client groups in tenant
CREATE POLICY "Users can view client groups in tenant" ON client_groups
FOR SELECT USING (can_access_tenant(admin_id));

-- Authorized users can create client groups
CREATE POLICY "Authorized users can create client groups" ON client_groups
FOR INSERT WITH CHECK (
  (auth.uid() = created_by) AND 
  (has_role(auth.uid(), 'SUPER_ADMIN') OR 
   has_role(auth.uid(), 'TENANT_OWNER') OR 
   has_role(auth.uid(), 'MANAGER'))
);

-- Authorized users can update client groups
CREATE POLICY "Authorized users can update client groups" ON client_groups
FOR UPDATE USING (
  has_role(auth.uid(), 'SUPER_ADMIN') OR 
  ((has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER')) AND 
   (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id)))
);

-- Authorized users can delete non-system client groups
CREATE POLICY "Authorized users can delete non-system client groups" ON client_groups
FOR DELETE USING (
  (is_system = false) AND 
  (has_role(auth.uid(), 'SUPER_ADMIN') OR 
   ((has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER')) AND 
    (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id))))
);
```

### client_group_members

```sql
-- Users can view memberships in tenant
CREATE POLICY "Users can view client group members" ON client_group_members
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM client_groups g 
    WHERE g.id = group_id AND can_access_tenant(g.admin_id)
  )
);

-- Authorized users can manage memberships
CREATE POLICY "Authorized users can manage client group members" ON client_group_members
FOR ALL USING (
  has_role(auth.uid(), 'SUPER_ADMIN') OR 
  has_role(auth.uid(), 'TENANT_OWNER') OR 
  has_role(auth.uid(), 'MANAGER')
)
WITH CHECK (
  has_role(auth.uid(), 'SUPER_ADMIN') OR 
  has_role(auth.uid(), 'TENANT_OWNER') OR 
  has_role(auth.uid(), 'MANAGER')
);
```

### deposits

```sql
-- Users can view deposits in their tenant
CREATE POLICY "Users can view deposits" ON deposits
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    agent_id = auth.uid() OR
    super_agent_id = auth.uid()
  )
);

-- Only certain roles can create deposits
CREATE POLICY "Users can create deposits" ON deposits
FOR INSERT WITH CHECK (
  auth.uid() = created_by AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    has_role(auth.uid(), 'SUPER_AGENT')
  )
);

-- Only admins can update deposits
CREATE POLICY "Admins can update deposits" ON deposits
FOR UPDATE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER')
  )
);
```

### documents

```sql
-- Users can view documents for accessible leads/clients
CREATE POLICY "Users can view documents" ON documents
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    (lead_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM leads
      WHERE leads.id = documents.lead_id
      AND can_access_tenant(leads.admin_id)
      AND (
        leads.assigned_to = auth.uid() OR
        leads.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    )) OR
    (client_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM clients
      WHERE clients.id = documents.client_id
      AND can_access_tenant(clients.admin_id)
      AND (
        clients.assigned_to = auth.uid() OR
        clients.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    ))
  )
);

-- Users can upload documents for accessible entities
CREATE POLICY "Users can upload documents" ON documents
FOR INSERT WITH CHECK (
  auth.uid() = uploaded_by AND (
    (lead_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM leads
      WHERE leads.id = documents.lead_id
      AND (
        leads.assigned_to = auth.uid() OR
        leads.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    )) OR
    (client_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM clients
      WHERE clients.id = documents.client_id
      AND (
        clients.assigned_to = auth.uid() OR
        clients.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    ))
  )
);

-- Users can delete their own documents
CREATE POLICY "Users can delete own documents" ON documents
FOR DELETE USING (uploaded_by = auth.uid());

-- Admins can delete documents in tenant
CREATE POLICY "Admins can delete documents" ON documents
FOR DELETE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'TENANT_OWNER') OR
    has_role(auth.uid(), 'MANAGER')
  )
);
```

### kyc_records

```sql
-- Similar pattern to documents - access based on lead/client access
CREATE POLICY "Users can view KYC records" ON kyc_records
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    (lead_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM leads
      WHERE leads.id = kyc_records.lead_id
      AND can_access_tenant(leads.admin_id)
      AND (
        leads.assigned_to = auth.uid() OR
        leads.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    )) OR
    (client_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM clients
      WHERE clients.id = kyc_records.client_id
      AND can_access_tenant(clients.admin_id)
      AND (
        clients.assigned_to = auth.uid() OR
        clients.created_by = auth.uid() OR
        has_role(auth.uid(), 'SUPER_ADMIN') OR
        has_role(auth.uid(), 'TENANT_OWNER') OR
        has_role(auth.uid(), 'MANAGER')
      )
    ))
  )
);

CREATE POLICY "Users can create KYC records" ON kyc_records
FOR INSERT WITH CHECK (
  auth.uid() = created_by AND (
    (lead_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM leads WHERE leads.id = kyc_records.lead_id
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() OR
           has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR
           has_role(auth.uid(), 'MANAGER'))
    )) OR
    (client_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM clients WHERE clients.id = kyc_records.client_id
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid() OR
           has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR
           has_role(auth.uid(), 'MANAGER'))
    ))
  )
);

-- Admins can delete KYC records
CREATE POLICY "Admins can delete KYC records" ON kyc_records
FOR DELETE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'TENANT_OWNER') OR
    has_role(auth.uid(), 'MANAGER')
  )
);
```

### notifications

Notifications support archiving - notifications older than 1 month are archived (not deleted).
The `archived_at` column determines if a notification is archived (NULL = recent, NOT NULL = archived).

```sql
-- Users can view their own notifications (both recent and archived)
CREATE POLICY "Users can view own notifications" ON notifications
FOR SELECT USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
FOR UPDATE USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- System can create notifications for anyone
CREATE POLICY "System can create notifications" ON notifications
FOR INSERT WITH CHECK (true);

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications" ON notifications
FOR DELETE USING (user_id = auth.uid());
```

**Archiving Function:**
```sql
-- Archive notifications older than 1 month
CREATE OR REPLACE FUNCTION public.archive_old_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications
  SET archived_at = now()
  WHERE archived_at IS NULL
    AND created_at < now() - INTERVAL '1 month';
END;
$$;

GRANT EXECUTE ON FUNCTION public.archive_old_notifications() TO authenticated;
```

**Query Patterns:**
```sql
-- Fetch recent notifications (last 1 month)
SELECT * FROM notifications
WHERE user_id = auth.uid()
  AND archived_at IS NULL
  AND created_at >= now() - INTERVAL '1 month'
ORDER BY created_at DESC;

-- Fetch archived notifications
SELECT * FROM notifications
WHERE user_id = auth.uid()
  AND archived_at IS NOT NULL
ORDER BY created_at DESC
LIMIT 200;
```

### attendance

```sql
-- Users can view their own attendance
CREATE POLICY "Users view own attendance" ON attendance
FOR SELECT USING (user_id = auth.uid());

-- Admins can view all attendance in tenant
CREATE POLICY "Admins view all attendance" ON attendance
FOR SELECT USING (
  can_access_tenant(admin_id) AND
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER']::text[]
  )
);

-- Users can insert their own attendance
CREATE POLICY "Users insert own attendance" ON attendance
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own attendance
CREATE POLICY "Users update own attendance" ON attendance
FOR UPDATE USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Admins can manage all attendance
CREATE POLICY "Admins manage attendance" ON attendance
FOR ALL USING (
  can_access_tenant(admin_id) AND
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER']::text[]
  )
)
WITH CHECK (
  get_user_role_direct(auth.uid()) = ANY (
    ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER']::text[]
  )
);
```

### call_history

```sql
-- Users can view their own call history
CREATE POLICY "Users view own call history" ON call_history
FOR SELECT USING (user_id = auth.uid());

-- Users can view call history in tenant (admins)
CREATE POLICY "Users view call history in tenant" ON call_history
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    user_id = auth.uid()
  )
);

-- Users can create their own call history
CREATE POLICY "Users create own call history" ON call_history
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own call history
CREATE POLICY "Users update own call history" ON call_history
FOR UPDATE USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Service role can update any call history (webhooks)
CREATE POLICY "Service role update call history" ON call_history
FOR UPDATE USING (true)
WITH CHECK (true);
```

### conversations & messages

```sql
-- Users can view their own conversations
CREATE POLICY "Users view own conversations" ON conversations
FOR SELECT USING (
  auth.uid() = user1_id OR auth.uid() = user2_id
);

-- Admins can view all conversations
CREATE POLICY "Admins view all conversations" ON conversations
FOR SELECT USING (has_role(auth.uid(), 'ADMIN'));

-- Users can create conversations they're part of
CREATE POLICY "Users create conversations" ON conversations
FOR INSERT WITH CHECK (
  auth.uid() = user1_id OR auth.uid() = user2_id
);

-- Users can update their conversations
CREATE POLICY "Users update conversations" ON conversations
FOR UPDATE USING (
  auth.uid() = user1_id OR auth.uid() = user2_id
);

-- Messages: Users can view messages in their conversations
CREATE POLICY "Users view messages" ON messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversations
    WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
  )
);

-- Users can send messages in their conversations
CREATE POLICY "Users send messages" ON messages
FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM conversations
    WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
  )
);
```

### group_chats & group_chat_messages

```sql
-- Users can view static groups or groups they're members of
CREATE POLICY "Users view groups" ON group_chats
FOR SELECT USING (
  is_static = true OR
  EXISTS (
    SELECT 1 FROM group_chat_members
    WHERE group_chat_members.group_chat_id = group_chats.id
    AND group_chat_members.user_id = auth.uid()
  )
);

-- Users can view members of their groups
CREATE POLICY "Users view group members" ON group_chat_members
FOR SELECT USING (
  is_static_group(group_chat_id) OR
  user_id = auth.uid() OR
  is_group_member(group_chat_id, auth.uid())
);

-- Users can view messages in their groups
CREATE POLICY "Users view group messages" ON group_chat_messages
FOR SELECT USING (
  is_static_group(group_chat_id) OR
  is_group_member(group_chat_id, auth.uid())
);

-- Users can send messages to their groups
CREATE POLICY "Users send group messages" ON group_chat_messages
FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (
    is_static_group(group_chat_id) OR
    is_group_member(group_chat_id, auth.uid())
  )
);
```

### admin_settings & general_settings

```sql
-- Users can view their tenant settings
CREATE POLICY "Users view tenant settings" ON admin_settings
FOR SELECT USING (can_access_tenant(admin_id));

-- Admins can manage their own settings
CREATE POLICY "Admins manage own settings" ON admin_settings
FOR ALL USING (
  admin_id = auth.uid() OR has_role(auth.uid(), 'SUPER_ADMIN')
)
WITH CHECK (
  admin_id = auth.uid() OR has_role(auth.uid(), 'SUPER_ADMIN')
);

-- Super admins can view all admin settings
CREATE POLICY "Super admins view all settings" ON admin_settings
FOR SELECT USING (has_role(auth.uid(), 'SUPER_ADMIN'));

-- General settings: Super admins manage all
CREATE POLICY "Super admins manage general settings" ON general_settings
FOR ALL USING (has_role(auth.uid(), 'SUPER_ADMIN'))
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'));

-- Tenant owners manage their settings
CREATE POLICY "Tenant owners manage settings" ON general_settings
FOR ALL USING (
  admin_id = auth.uid() AND has_role(auth.uid(), 'TENANT_OWNER')
)
WITH CHECK (
  admin_id = auth.uid() AND has_role(auth.uid(), 'TENANT_OWNER')
);

-- Users can view their tenant settings
CREATE POLICY "Users view general settings" ON general_settings
FOR SELECT USING (can_access_tenant(admin_id));
```

### audit_logs

```sql
-- Users can view their own audit logs
CREATE POLICY "Users view own audit logs" ON audit_logs
FOR SELECT USING (auth.uid() = user_id);

-- Admins can view all audit logs
CREATE POLICY "Admins view all audit logs" ON audit_logs
FOR SELECT USING (
  has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER')
);

-- System can insert audit logs
CREATE POLICY "System insert audit logs" ON audit_logs
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- No updates or deletes allowed
```

### auth_attempts

```sql
-- Admins can view all auth attempts
CREATE POLICY "Admins view auth attempts" ON auth_attempts
FOR SELECT USING (has_role(auth.uid(), 'ADMIN'));

-- System can insert auth attempts
CREATE POLICY "System insert auth attempts" ON auth_attempts
FOR INSERT WITH CHECK (true);

-- No updates or deletes allowed
```

### ip_whitelist

```sql
-- Users can view their own IP whitelist
CREATE POLICY "Users view own whitelist" ON ip_whitelist
FOR SELECT USING (auth.uid() = user_id);

-- Admins can view all whitelists
CREATE POLICY "Admins view all whitelists" ON ip_whitelist
FOR SELECT USING (has_role(auth.uid(), 'ADMIN'));

-- Admins can manage whitelists
CREATE POLICY "Admins insert whitelist" ON ip_whitelist
FOR INSERT WITH CHECK (
  has_role(auth.uid(), 'ADMIN') AND auth.uid() = created_by
);

CREATE POLICY "Admins update whitelist" ON ip_whitelist
FOR UPDATE USING (has_role(auth.uid(), 'ADMIN'));

CREATE POLICY "Admins delete whitelist" ON ip_whitelist
FOR DELETE USING (has_role(auth.uid(), 'ADMIN'));
```

---

## Common RLS Patterns

### Pattern 1: Simple Owner-Based Access

```sql
CREATE POLICY "Users manage own records" ON my_table
FOR ALL USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

### Pattern 2: Tenant-Scoped Access

```sql
CREATE POLICY "Users access tenant records" ON my_table
FOR SELECT USING (can_access_tenant(admin_id));

CREATE POLICY "Users create in tenant" ON my_table
FOR INSERT WITH CHECK (auth.uid() = created_by);
```

### Pattern 3: Role-Based Access

```sql
CREATE POLICY "Admins full access" ON my_table
FOR ALL USING (
  has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER')
);

CREATE POLICY "Users limited access" ON my_table
FOR SELECT USING (
  assigned_to = auth.uid() OR created_by = auth.uid()
);
```

### Pattern 4: Permission-Based Access

```sql
CREATE POLICY "Users with permission can delete" ON my_table
FOR DELETE USING (
  has_permission(auth.uid(), 'CAN_DELETE_LEADS')
);
```

### Pattern 5: Hierarchical Access (Parent-Child)

```sql
-- Access based on parent record access
CREATE POLICY "Access child via parent" ON child_table
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM parent_table
    WHERE parent_table.id = child_table.parent_id
    AND (
      parent_table.assigned_to = auth.uid() OR
      has_role(auth.uid(), 'ADMIN')
    )
  )
);
```

### Pattern 6: Combined Tenant + Role Access

```sql
CREATE POLICY "Complex access control" ON my_table
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);
```

---

## Common Errors & Solutions

### Error: "new row violates row-level security policy"

**Causes:**
1. Missing `user_id` in INSERT
2. User doesn't have permission
3. Missing `created_by` field

**Solution:**
```typescript
// Always include user_id/created_by
await supabase.from('leads').insert({
  created_by: user.id,  // REQUIRED
  admin_id: userAdminId, // Often required
  ...data
});
```

### Error: "infinite recursion detected in policy"

**Cause:** Policy queries the same table it's defined on.

**Solution:** Use security definer function:
```sql
-- Bad
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin')

-- Good
USING (has_role(auth.uid(), 'ADMIN'))
```

### Error: "permission denied for table"

**Causes:**
1. RLS not enabled
2. No matching policy
3. User not authenticated

**Solution:**
```sql
-- Verify RLS is enabled
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

-- Add default SELECT policy for authenticated users
CREATE POLICY "Authenticated can view" ON my_table
FOR SELECT TO authenticated
USING (true);
```

### Error: Empty results when data exists

**Cause:** RLS filtering out rows.

**Debug:**
```sql
-- Temporarily disable RLS (admin only)
ALTER TABLE my_table DISABLE ROW LEVEL SECURITY;

-- Check policies
SELECT * FROM pg_policies WHERE tablename = 'my_table';
```

---

## Testing RLS Policies

### 1. Test with Different Roles

```sql
-- Set role context for testing
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "user-uuid-here"}';

-- Run query
SELECT * FROM leads;

-- Reset
RESET ROLE;
```

### 2. Use Supabase Client with Different Users

```typescript
// Test as specific user
const { data: userData } = await supabase.auth.signInWithPassword({
  email: 'agent@test.com',
  password: 'password'
});

// Should only see assigned leads
const { data: leads } = await supabase.from('leads').select('*');
console.log('Agent sees:', leads.length, 'leads');
```

### 3. Check Policy Coverage

```sql
-- List all policies for a table
SELECT 
  policyname,
  cmd,
  permissive,
  qual::text as using_clause,
  with_check::text as with_check_clause
FROM pg_policies 
WHERE tablename = 'leads';
```

---

## Best Practices

1. **Always use SECURITY DEFINER** for helper functions
2. **Set search_path = public** in all functions
3. **Use STABLE** for read-only functions (performance)
4. **Test with each role** before deploying
5. **Avoid complex subqueries** in policies (use functions instead)
6. **Add indexes** on columns used in RLS policies
7. **Document each policy** with clear comments
8. **Use consistent patterns** across tables
9. **Never trust client-side role checks** - always enforce at DB level
10. **Log security-critical actions** to audit_logs table

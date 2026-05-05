# Database & Schema AI Context Prompt

## Project Overview

This is a **multi-tenant Forex CRM application** using Supabase PostgreSQL. The database supports complete lead-to-client lifecycle management, sales pipeline tracking, deposits, KYC verification, call center integration, and role-based access control.

---

## Technology Stack

- **Database**: PostgreSQL (via Supabase)
- **Security**: Row-Level Security (RLS) with security definer functions
- **Authentication**: Supabase Auth
- **Multi-tenancy**: Isolated via `admin_id` column

---

## Core Concepts

### Multi-Tenancy Model

Every tenant is identified by an `admin_id` (UUID of TENANT_OWNER user). Data isolation enforced via:

```sql
-- Helper function to check tenant access
CREATE OR REPLACE FUNCTION can_access_tenant(_admin_id uuid)
RETURNS boolean AS $$
BEGIN
  -- SUPER_ADMIN can access everything
  IF has_role(auth.uid(), 'SUPER_ADMIN') THEN RETURN true; END IF;
  
  -- TENANT_OWNER checking own data
  IF has_role(auth.uid(), 'TENANT_OWNER') AND (_admin_id = auth.uid() OR _admin_id IS NULL) THEN
    RETURN true;
  END IF;
  
  -- Users within same tenant
  RETURN get_user_admin_id(auth.uid()) = _admin_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

### Role Hierarchy

```sql
CREATE TYPE app_role AS ENUM (
  'SUPER_ADMIN',    -- Full system access, manages all tenants
  'TENANT_OWNER',   -- Tenant administrator, owns organization
  'ADMIN',          -- Deprecated but kept for backwards compatibility
  'MANAGER',        -- Full tenant access (same as ADMIN)
  'SUPER_AGENT',    -- Handles converted clients
  'AGENT'           -- Handles leads only
);
```

### Permission System

```sql
CREATE TYPE app_permission AS ENUM (
  'CAN_VIEW_REPORTS',
  'CAN_VIEW_SETTINGS',
  'CAN_MANAGE_USERS',
  'CAN_DELETE_LEADS',
  'CAN_ASSIGN_ALL',
  'CAN_TRANSFER_LEADS'
);
```

---

## Database Tables

### User Management Tables

#### `profiles`
User profile information linked to Supabase Auth.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key, references auth.users |
| `email` | text | User email (internal: username@crm.internal) |
| `username` | text | Login username |
| `full_name` | text | Display name |
| `last_name` | text | Last name |
| `avatar_url` | text | Profile picture URL |
| `admin_id` | uuid | Tenant owner ID (for tenant isolation) |
| `created_by` | uuid | User who created this profile |
| `ccc_phone_number` | text | Comma-separated call center phone numbers |
| `ccc_username` | text | Call center agent identifier |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Key relationships:**
- `admin_id` → profiles.id (tenant owner)
- `created_by` → profiles.id (creator)

#### `user_roles`
Role assignments for users.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | References profiles.id |
| `role` | app_role | User's role |

**Constraint:** Unique (user_id, role)

#### `user_permissions`
Additional permissions beyond role.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | References profiles.id |
| `permission` | app_permission | Granted permission |

---

### Lead Management Tables

#### `leads`
Potential customers being prospected.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Lead name |
| `email` | text | Contact email |
| `phone` | text | Contact phone |
| `country` | text | Country code |
| `company` | text | Company name |
| `job_title` | text | Job title |
| `source` | lead_source | How lead was acquired |
| `status` | lead_status | Current lead status |
| `assigned_to` | uuid | Assigned agent |
| `created_by` | uuid | Creator user |
| `admin_id` | uuid | Tenant owner |
| `conversion_probability` | integer | 0-100 probability |
| `balance` | numeric | Account balance |
| `equity` | numeric | Account equity |
| `pending_conversion` | boolean | In conversion queue |
| `is_transferred` | boolean | Was transferred |
| `transferred_by` | uuid | Previous agent |
| `position` | integer | Sort order |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update |

**Enums:**
```sql
CREATE TYPE lead_source AS ENUM (
  'WEBSITE', 'REFERRAL', 'COLD_CALL', 'SOCIAL_MEDIA', 
  'EMAIL_CAMPAIGN', 'TRADE_SHOW', 'PARTNER', 'OTHER'
);

CREATE TYPE lead_status AS ENUM (
  'NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 
  'NEGOTIATION', 'WON', 'LOST', 'NURTURING'
);
```

#### `lead_statuses`
Configurable lead status definitions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Status name |
| `color` | text | Hex color code |
| `position` | integer | Display order |
| `is_default` | boolean | Default status |
| `is_active` | boolean | Status enabled |

#### `lead_groups`
Groups for organizing leads.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Group name |
| `description` | text | Group description |
| `admin_id` | uuid | Tenant owner |
| `created_by` | uuid | Creator |

#### `lead_group_members`
Lead-to-group assignments.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Lead reference |
| `group_id` | uuid | Group reference |
| `added_by` | uuid | Who added |
| `added_at` | timestamptz | When added |

#### `lead_activities`
Activity log for leads.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Lead reference |
| `user_id` | uuid | Acting user |
| `activity_type` | text | Type of activity |
| `description` | text | Activity details |
| `created_at` | timestamptz | When occurred |

#### `lead_comments`
Comments on leads.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Lead reference |
| `user_id` | uuid | Comment author |
| `comment` | text | Comment content |
| `created_at` | timestamptz | When posted |

#### `lead_tasks`
Tasks related to leads.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Lead reference |
| `assigned_to` | uuid | Task assignee |
| `title` | text | Task title |
| `description` | text | Task details |
| `due_date` | timestamptz | Due date |
| `completed` | boolean | Completion status |

---

### Client Management Tables

#### `clients`
Converted leads who became customers.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Client name |
| `email` | text | Contact email |
| `home_phone` | text | Phone number |
| `country` | text | Country code |
| `source` | lead_source | Acquisition source |
| `status` | client_status | Current status |
| `pipeline_status` | pipeline_status | Pipeline stage |
| `kyc_status` | kyc_status | KYC verification |
| `assigned_to` | uuid | Assigned super agent |
| `created_by` | uuid | Creator |
| `admin_id` | uuid | Tenant owner |
| `converted_from_lead_id` | uuid | Original lead |
| `transferred_by` | uuid | Originating agent |
| `balance` | numeric | Account balance |
| `equity` | numeric | Account equity |
| `deposits` | numeric | Total deposits |
| `margin_level` | numeric | Margin level |
| `open_trades` | integer | Active trades count |
| `potential_value` | numeric | Potential revenue |
| `actual_value` | numeric | Realized revenue |
| `satisfaction_score` | integer | Client satisfaction |
| `join_date` | timestamptz | Conversion date |

**Enums:**
```sql
CREATE TYPE client_status AS ENUM (
  'ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED'
);

CREATE TYPE pipeline_status AS ENUM (
  'PROSPECT', 'UPCOMING_SALE', 'STUCK', 'FLIPPED', 'DEPOSIT'
);

CREATE TYPE kyc_status AS ENUM (
  'PENDING', 'VERIFIED', 'REJECTED'
);
```

#### `client_statuses`
Configurable client status definitions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Status name |
| `color` | text | Hex color code |
| `position` | integer | Display order |
| `is_default` | boolean | Default status |
| `is_active` | boolean | Status enabled |

#### `client_activities`, `client_comments`, `client_tasks`
Similar structure to lead equivalents.

#### `client_withdrawals`
Withdrawal requests from clients.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `client_id` | uuid | Client reference |
| `amount` | numeric | Withdrawal amount |
| `status` | withdrawal_status | Request status |
| `approved_by` | uuid | Approving admin |
| `approved_at` | timestamptz | Approval time |
| `rejection_reason` | text | If rejected |
| `notes` | text | Additional notes |

```sql
CREATE TYPE withdrawal_status AS ENUM (
  'PENDING', 'APPROVED', 'REJECTED'
);
```

#### `client_groups`
Groups for organizing clients (similar to lead_groups).

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Group name (NOT NULL) |
| `description` | text | Group description |
| `is_system` | boolean | System-managed group (default false) |
| `admin_id` | uuid | Tenant owner |
| `created_by` | uuid | Creator (nullable for system groups) |
| `created_at` | timestamptz | Creation timestamp (NOT NULL) |
| `updated_at` | timestamptz | Last update timestamp (NOT NULL) |

**System Groups:**
- `Converted` - Auto-populated with clients converted from leads
- `Live` - Manually created clients marked as live

**Key Features:**
- System groups (`is_system = true`) cannot be deleted
- Automatically created per tenant via `get_or_create_client_system_groups()` function
- Clients converted from leads are auto-added via trigger

#### `client_group_members`
Client-to-group assignments.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `group_id` | uuid | Group reference |
| `client_id` | uuid | Client reference |
| `added_by` | uuid | Who added (nullable for auto-assignments) |
| `added_at` | timestamptz | When added (NOT NULL) |

**Constraint:** Unique (group_id, client_id)

---

### Financial Tables

#### `deposits`
Deposit transactions with revenue split.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `client_id` | uuid | Client reference |
| `lead_id` | uuid | Original lead (if any) |
| `amount` | numeric | Deposit amount |
| `agent_id` | uuid | Transferring agent |
| `super_agent_id` | uuid | Working super agent |
| `agent_percentage` | integer | Agent split % |
| `super_agent_percentage` | integer | Super agent split % |
| `agent_amount` | numeric | Agent earnings |
| `super_agent_amount` | numeric | Super agent earnings |
| `sale_branch_id` | uuid | Sale branch reference |
| `exchanges` | text[] | Exchange platforms |
| `status` | text | pending/approved/rejected |
| `approved_by` | uuid | Approving user |
| `approved_at` | timestamptz | Approval time |
| `rejection_reason` | text | If rejected |
| `admin_id` | uuid | Tenant owner |
| `created_by` | uuid | Creator |
| `created_at` | timestamptz | Creation time |

#### `sale_branches`
Revenue split configuration by branch.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Branch name |
| `agent_percentage` | integer | Default agent % |
| `super_agent_percentage` | integer | Default super agent % |
| `admin_id` | uuid | Tenant owner |

---

### KYC & Documents Tables

#### `kyc_records`
Know Your Customer verification records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Lead reference (optional) |
| `client_id` | uuid | Client reference (optional) |
| `bank_name` | text | Bank/institution name |
| `notes` | text | KYC notes |
| `status` | kyc_status | Verification status |
| `verified_by` | uuid | Verifying user |
| `verified_date` | timestamptz | Verification date |
| `admin_id` | uuid | Tenant owner |
| `created_by` | uuid | Creator |

#### `documents`
Uploaded files for leads/clients/KYC.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | File name |
| `file_path` | text | Storage path |
| `size` | bigint | File size in bytes |
| `type` | document_type | Document category |
| `lead_id` | uuid | Lead reference (optional) |
| `client_id` | uuid | Client reference (optional) |
| `kyc_record_id` | uuid | KYC record (optional) |
| `uploaded_by` | uuid | Uploader |
| `admin_id` | uuid | Tenant owner |

```sql
CREATE TYPE document_type AS ENUM (
  'ID_DOCUMENT', 'PROOF_OF_ADDRESS', 'BANK_STATEMENT',
  'CONTRACT', 'OTHER'
);
```

---

### Communication Tables

#### `call_history`
Outbound call records via CCC integration.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Calling agent |
| `lead_id` | uuid | Lead called (optional) |
| `client_id` | uuid | Client called (optional) |
| `phone_number` | text | Dialed number |
| `agent_email` | text | Agent identifier |
| `call_id` | text | CCC API call ID |
| `status` | text | Call status |
| `duration` | integer | Call duration (seconds) |
| `error_message` | text | If failed |
| `admin_id` | uuid | Tenant owner |
| `created_at` | timestamptz | Call time |

**Call statuses:** `initiating`, `initiated`, `ringing`, `answered`, `busy`, `failed`, `completed`

#### `conversations`
Direct message conversations between users.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user1_id` | uuid | First participant |
| `user2_id` | uuid | Second participant |
| `created_at` | timestamptz | Creation time |
| `updated_at` | timestamptz | Last activity |

#### `messages`
Messages within conversations.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `conversation_id` | uuid | Conversation reference |
| `sender_id` | uuid | Message sender |
| `content` | text | Message content |
| `is_read` | boolean | Read status |
| `created_at` | timestamptz | Send time |

#### `group_chats`
Group chat rooms.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Chat name |
| `description` | text | Chat description |
| `is_static` | boolean | Auto-managed by role |
| `created_by` | uuid | Creator |

**Static groups:** `Info` (all users), `Ret` (super agents + managers), `Con` (agents + managers)

#### `group_chat_members`
Group membership.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `group_chat_id` | uuid | Group reference |
| `user_id` | uuid | Member user |
| `joined_at` | timestamptz | Join time |

#### `group_chat_messages`
Messages in group chats.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `group_chat_id` | uuid | Group reference |
| `sender_id` | uuid | Message sender |
| `content` | text | Message content |
| `created_at` | timestamptz | Send time |

---

### Email Tables

#### `email_credentials`
User email configuration for sending.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | User reference |
| `email_address` | text | Email address |
| `email_password` | text | Email password |
| `email_address_encrypted` | text | Encrypted email |
| `email_password_encrypted` | text | Encrypted password |
| `admin_id` | uuid | Tenant owner |

#### `email_templates`
Reusable email templates.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Creator |
| `name` | text | Template name |
| `subject` | text | Email subject |
| `header_html` | text | Header HTML |
| `body_html` | text | Body HTML |
| `footer_html` | text | Footer HTML |
| `is_shared` | boolean | Visible to team |
| `admin_id` | uuid | Tenant owner |

#### `email_signatures`
User email signatures.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | User reference |
| `signature_html` | text | Signature HTML |
| `is_active` | boolean | Active signature |
| `admin_id` | uuid | Tenant owner |

#### `received_emails`
Fetched emails via IMAP.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Email owner |
| `message_id` | text | Email message ID |
| `sender_email` | text | From address |
| `sender_name` | text | From name |
| `recipient_email` | text | To address |
| `subject` | text | Email subject |
| `body_html` | text | HTML content |
| `body_text` | text | Plain text content |
| `is_read` | boolean | Read status |
| `received_at` | timestamptz | Receive time |
| `in_reply_to` | text | Reply reference |
| `email_references` | text | Thread references |
| `admin_id` | uuid | Tenant owner |

---

### Notification Tables

#### `notifications`
User notifications with archiving support.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Recipient |
| `type` | notification_type | Notification category |
| `message` | text | Notification text |
| `is_read` | boolean | Read status |
| `related_entity_type` | text | Entity type |
| `related_entity_id` | uuid | Entity ID |
| `related_profile_id` | uuid | Related user |
| `admin_id` | uuid | Tenant owner (for multi-tenant visibility) |
| `archived_at` | timestamptz | Archive timestamp (NULL = recent, NOT NULL = archived) |
| `created_at` | timestamptz | Creation time |

**Archiving System:**
- Notifications older than 1 month are archived (not deleted)
- Archived notifications have `archived_at` set to the archive timestamp
- Recent notifications (last 1 month) have `archived_at = NULL`
- Use `archive_old_notifications()` function to archive old notifications

**Indexes:**
- `idx_notifications_archived` - For archived notifications queries
- `idx_notifications_recent` - For recent notifications queries (user_id, created_at DESC)

```sql
CREATE TYPE notification_type AS ENUM (
  'NEW_LEAD', 'WITHDRAWAL_REQUEST', 'LEAD_ASSIGNED',
  'CLIENT_CONVERTED', 'TASK_DUE', 'TICKET_CREATED',
  'CONVERSION_APPROVED', 'CONVERSION_REJECTED',
  'DEPOSIT_APPROVED', 'DEPOSIT_REJECTED', 'DEPOSIT_SPLIT_RECEIVED',
  'CLIENT_ASSIGNED'
);
```

**Frontend Pages:**
- `/notifications` - Notification History page with tabs for Recent, Unread, and Archived notifications
- Accessible via "See all Notifications" link in notification bell popover

#### `reminders`
Scheduled reminders.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Owner |
| `title` | text | Reminder title |
| `description` | text | Details |
| `due_date` | timestamptz | Due date/time |
| `is_completed` | boolean | Completion status |
| `lead_id` | uuid | Related lead (optional) |
| `client_id` | uuid | Related client (optional) |
| `admin_id` | uuid | Tenant owner |

---

### Security Tables

#### `auth_attempts`
Login attempt tracking.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `ip_address` | text | Client IP |
| `user_email` | text | Attempted email |
| `attempt_type` | text | login/password_reset |
| `success` | boolean | Attempt result |
| `failure_reason` | text | If failed |
| `blocked_until` | timestamptz | IP block expiry |
| `user_agent` | text | Browser info |
| `created_at` | timestamptz | Attempt time |

#### `audit_logs`
Security and action audit trail.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Acting user |
| `action_type` | text | Action performed |
| `entity_type` | text | Affected entity type |
| `entity_id` | uuid | Affected entity ID |
| `details` | jsonb | Action details |
| `ip_address` | text | Client IP |
| `user_agent` | text | Browser info |
| `created_at` | timestamptz | Action time |

#### `user_sessions`
Active session tracking.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Session owner |
| `refresh_token_hash` | text | Token hash |
| `ip_address` | text | Client IP |
| `user_agent` | text | Browser info |
| `is_active` | boolean | Session active |
| `refresh_count` | integer | Token refresh count |
| `last_activity` | timestamptz | Last activity |
| `last_refresh_at` | timestamptz | Last token refresh |
| `expires_at` | timestamptz | Session expiry |
| `created_at` | timestamptz | Session start |

#### `ip_whitelist`
IP-based access control.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Restricted user |
| `ip_address` | text | Allowed IP |
| `description` | text | IP description |
| `is_active` | boolean | Rule active |
| `created_by` | uuid | Creator |

---

### Settings Tables

#### `admin_settings`
Tenant-specific configuration.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `admin_id` | uuid | Tenant owner |
| `work_start_time` | time | Work hours start |
| `work_end_time` | time | Work hours end |
| `late_start_fee` | numeric | Late fee |
| `excessive_break_fee` | numeric | Break fee |
| `max_break_minutes` | integer | Max break time |
| `day_off_fee` | numeric | Day off fee |
| `show_phone_to_agents` | boolean | Phone visibility |
| `show_email_to_agents` | boolean | Email visibility |
| `show_phone_to_super_agents` | boolean | Phone visibility |
| `show_email_to_super_agents` | boolean | Email visibility |
| `ccc_api_key` | text | CCC API key (primary) |
| `ccc_api_key_new` | text | CCC API key (rotation) |
| `ccc_initiate_endpoint` | text | CCC initiate URL |
| `ccc_end_endpoint` | text | CCC hangup URL |
| `ccc_control_endpoint` | text | CCC control URL |
| `ccc_integration_enabled` | boolean | CCC enabled |
| `call_integration_access_granted` | boolean | CCC access |
| `email_integration_access_granted` | boolean | Email access |
| `email_integration_active` | boolean | Email enabled |
| `integration_providers` | jsonb | Provider config |
| `celebration_video_url` | text | Celebration video |
| `celebration_sound_url` | text | Celebration sound |
| `password_protection_config` | jsonb | Password rules |

#### `general_settings`
System-wide defaults (fallback).

Same structure as `admin_settings` but for global defaults.

---

### Attendance Tables

#### `attendance`
Employee attendance tracking.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | Employee |
| `date` | date | Work date |
| `clock_in` | timestamptz | Clock in time |
| `clock_out` | timestamptz | Clock out time |
| `is_late` | boolean | Was late |
| `late_start_fee` | numeric | Late penalty |
| `break_minutes` | integer | Total break time |
| `break_time_fee` | numeric | Break penalty |
| `total_fees` | numeric | Total penalties |
| `working_started_at` | timestamptz | Last work start |
| `working_periods` | jsonb | Work/break periods |
| `notes` | text | Daily notes |
| `admin_id` | uuid | Tenant owner |

---

## Key Database Functions

### Role & Permission Checks

```sql
-- Check if user has specific role
CREATE FUNCTION has_role(_user_id uuid, _role app_role)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Check if user has specific permission
CREATE FUNCTION has_permission(_user_id uuid, _permission app_permission)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_permissions
    WHERE user_id = _user_id AND permission = _permission
  )
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Get user's role directly
CREATE FUNCTION get_user_role_direct(check_user_id uuid)
RETURNS text AS $$
  SELECT role::text FROM user_roles WHERE user_id = check_user_id LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### Tenant Resolution

```sql
-- Get tenant owner for a user (traverse creation chain)
CREATE FUNCTION get_user_admin_id(p_user_id uuid)
RETURNS uuid AS $$
DECLARE
  v_current_user uuid;
  v_created_by uuid;
  v_role text;
  v_max_depth int := 10;
  v_depth int := 0;
BEGIN
  v_current_user := p_user_id;
  
  WHILE v_depth < v_max_depth LOOP
    SELECT role INTO v_role FROM user_roles WHERE user_id = v_current_user LIMIT 1;
    IF v_role = 'TENANT_OWNER' THEN RETURN v_current_user; END IF;
    
    SELECT created_by INTO v_created_by FROM profiles WHERE id = v_current_user;
    IF v_created_by IS NULL OR v_created_by = v_current_user THEN RETURN NULL; END IF;
    
    v_current_user := v_created_by;
    v_depth := v_depth + 1;
  END LOOP;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

### Phone/Email Visibility

```sql
-- Check if current user can view phone numbers
CREATE FUNCTION can_view_phone()
RETURNS boolean AS $$
DECLARE
  show_to_agents boolean;
  show_to_super_agents boolean;
BEGIN
  IF has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER') THEN
    RETURN true;
  END IF;
  
  SELECT gs.show_phone_to_agents, gs.show_phone_to_super_agents
  INTO show_to_agents, show_to_super_agents
  FROM general_settings gs LIMIT 1;
  
  IF has_role(auth.uid(), 'AGENT') THEN RETURN COALESCE(show_to_agents, false); END IF;
  IF has_role(auth.uid(), 'SUPER_AGENT') THEN RETURN COALESCE(show_to_super_agents, true); END IF;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

### Encryption Functions

```sql
-- Encrypt sensitive data
CREATE FUNCTION encrypt_sensitive(p_data text)
RETURNS text AS $$
DECLARE
  v_key bytea;
  v_iv bytea;
  v_encrypted bytea;
BEGIN
  IF p_data IS NULL OR p_data = '' THEN RETURN NULL; END IF;
  
  v_key := get_encryption_key();
  v_iv := extensions.gen_random_bytes(16);
  v_encrypted := extensions.encrypt_iv(convert_to(p_data, 'UTF8'), v_key, v_iv, 'aes-cbc');
  
  RETURN encode(v_iv || v_encrypted, 'base64');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Decrypt sensitive data
CREATE FUNCTION decrypt_sensitive(p_encrypted text)
RETURNS text AS $$
DECLARE
  v_key bytea;
  v_data bytea;
  v_iv bytea;
  v_encrypted bytea;
BEGIN
  IF p_encrypted IS NULL OR p_encrypted = '' THEN RETURN NULL; END IF;
  
  v_key := get_encryption_key();
  v_data := decode(p_encrypted, 'base64');
  v_iv := substring(v_data from 1 for 16);
  v_encrypted := substring(v_data from 17);
  
  RETURN convert_from(extensions.decrypt_iv(v_encrypted, v_key, v_iv, 'aes-cbc'), 'UTF8');
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Row-Level Security Patterns

### Standard Tenant-Scoped Table

```sql
-- Enable RLS
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

-- Users can view records in their tenant
CREATE POLICY "Users can view in tenant" ON my_table
FOR SELECT USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);

-- Users can create in their tenant
CREATE POLICY "Users can create" ON my_table
FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Users can update records they have access to
CREATE POLICY "Users can update" ON my_table
FOR UPDATE USING (
  can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR
    has_role(auth.uid(), 'ADMIN') OR
    has_role(auth.uid(), 'MANAGER') OR
    assigned_to = auth.uid() OR
    created_by = auth.uid()
  )
);

-- Only admins can delete
CREATE POLICY "Admins can delete" ON my_table
FOR DELETE USING (
  has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER')
);
```

### Auto-Set admin_id Trigger

```sql
CREATE FUNCTION set_admin_id_from_user()
RETURNS trigger AS $$
BEGIN
  IF NEW.admin_id IS NULL THEN
    NEW.admin_id := get_user_admin_id(auth.uid());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER set_admin_id_trigger
BEFORE INSERT ON my_table
FOR EACH ROW EXECUTE FUNCTION set_admin_id_from_user();
```

---

## Storage Buckets

| Bucket | Public | Purpose |
|--------|--------|---------|
| `documents` | No | Lead/client documents |
| `celebration-sounds` | Yes | Celebration audio |
| `celebration-videos` | Yes | Celebration video |
| `email-images` | Yes | Email embedded images |

---

## Realtime Subscriptions

Tables with realtime enabled:
- `messages`
- `group_chat_messages`
- `notifications`
- `call_history`
- `deposits`
- `clients` (pipeline updates)

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
```

---

## Common Query Patterns

### Get leads for current user's tenant
```sql
SELECT * FROM leads
WHERE can_access_tenant(admin_id)
  AND (assigned_to = auth.uid() OR has_role(auth.uid(), 'ADMIN'))
ORDER BY created_at DESC;
```

### Get clients with deposit totals
```sql
SELECT c.*, 
  COALESCE(SUM(d.amount), 0) as total_deposits
FROM clients c
LEFT JOIN deposits d ON d.client_id = c.id AND d.status = 'approved'
WHERE can_access_tenant(c.admin_id)
GROUP BY c.id;
```

### Get tenant users
```sql
SELECT p.*, ur.role
FROM profiles p
JOIN user_roles ur ON ur.user_id = p.id
WHERE p.admin_id = get_user_admin_id(auth.uid())
   OR p.id = get_user_admin_id(auth.uid());
```

---

## Migration Best Practices

1. **Always use SECURITY DEFINER** for helper functions to avoid RLS recursion
2. **Set search_path** in functions: `SET search_path = public`
3. **Use admin_id consistently** for tenant isolation
4. **Enable RLS immediately** after table creation
5. **Test policies** with different role contexts
6. **Add indexes** for frequently filtered columns (admin_id, assigned_to, status)
7. **Use ON DELETE CASCADE/SET NULL** appropriately for foreign keys

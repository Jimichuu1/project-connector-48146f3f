# Kybalion CRM - Complete Application Documentation

> **Last Updated:** December 2024  
> **Version:** 1.0.0  
> **Technology Stack:** React 18, TypeScript, Vite, Tailwind CSS, Supabase (Lovable Cloud)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Role Hierarchy & Access Control](#role-hierarchy--access-control)
3. [Database Schema Overview](#database-schema-overview)
4. [RLS Policy Summary](#rls-policy-summary)
5. [Page Documentation](#page-documentation)
   - [Index (Login)](#1-index-login-page)
   - [Dashboard](#2-dashboard)
   - [Leads](#3-leads)
   - [Lead Detail](#4-lead-detail)
   - [Clients](#5-clients)
   - [Client Detail](#6-client-detail)
   - [Pipeline](#7-pipeline)
   - [Convert Queue](#8-convert-queue)
   - [Attendance](#9-attendance)
   - [Email](#10-email)
   - [Reports](#11-reports)
   - [Salary](#12-salary)
   - [Call History](#13-call-history)
   - [User Management](#14-user-management)
   - [Tenant Management](#15-tenant-management)
   - [Team Management](#16-team-management)
   - [General Settings](#17-general-settings)
   - [Integrations](#18-integrations)
   - [Security Monitoring](#19-security-monitoring)
   - [Profile](#20-profile)
   - [Notification History](#21-notification-history)
6. [Key Database Functions](#key-database-functions)
7. [Edge Functions](#edge-functions)
8. [Security Considerations](#security-considerations)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (React)                          │
├─────────────────────────────────────────────────────────────────┤
│  Pages (21)  │  Components (150+)  │  Hooks (40+)  │  Contexts  │
└──────────────┴─────────────────────┴───────────────┴────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SUPABASE (Lovable Cloud)                     │
├──────────────┬─────────────────────┬───────────────┬────────────┤
│  PostgreSQL  │   Auth (GoTrue)     │  Edge Funcs   │  Storage   │
│  38+ Tables  │   JWT + Sessions    │  15+ Funcs    │  Documents │
│  RLS Enabled │   Role-based        │  TypeScript   │  Avatars   │
└──────────────┴─────────────────────┴───────────────┴────────────┘
```

### Multi-Tenant Architecture

The application uses a **multi-tenant architecture** where:
- Each tenant is identified by an `admin_id` (the TENANT_OWNER's user ID)
- All data tables include an `admin_id` column for tenant isolation
- RLS policies ensure users can only access data within their tenant
- SUPER_ADMIN can access all tenants

```
SUPER_ADMIN (Global)
    │
    ├── TENANT_OWNER (Tenant A - admin_id: uuid-a)
    │       ├── MANAGER
    │       │     ├── SUPER_AGENT
    │       │     │     └── AGENT
    │       │     └── AGENT
    │       └── AGENT
    │
    └── TENANT_OWNER (Tenant B - admin_id: uuid-b)
            ├── MANAGER
            └── AGENT
```

---

## Role Hierarchy & Access Control

### Role Definitions

| Role | Level | Description | Key Permissions |
|------|-------|-------------|-----------------|
| `SUPER_ADMIN` | 1 | System Administrator | Full access to all tenants, system settings |
| `TENANT_OWNER` | 2 | Tenant Administrator | Full access within their tenant |
| `MANAGER` | 3 | Team Manager | Manages team members, approves deposits |
| `SUPER_AGENT` | 4 | Senior Sales Agent | Can create deposits, manage assigned leads/clients |
| `AGENT` | 5 | Sales Agent | Basic lead/client management for assigned records |

### Permission Matrix

| Feature | SUPER_ADMIN | TENANT_OWNER | MANAGER | SUPER_AGENT | AGENT |
|---------|:-----------:|:------------:|:-------:|:-----------:|:-----:|
| View All Tenants | ✅ | ❌ | ❌ | ❌ | ❌ |
| Create Tenants | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage Users | ✅ | ✅ | ✅ | ❌ | ❌ |
| View All Leads | ✅ | ✅ | ✅ | ❌ | ❌ |
| View Assigned Leads | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create Leads | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delete Leads | ✅ | ✅ | ✅ | ❌ | ❌ |
| View All Clients | ✅ | ✅ | ✅ | ❌ | ❌ |
| Create Deposits | ✅ | ✅ | ✅ | ✅ | ❌ |
| Approve Deposits | ✅ | ✅ | ✅ | ❌ | ❌ |
| View Reports | ✅ | ✅ | ✅ | Own | Own |
| Manage Settings | ✅ | ✅ | ❌ | ❌ | ❌ |
| View Security Logs | ✅ | ✅ | ✅ | ❌ | ❌ |

---

## Database Schema Overview

### Core Tables

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    profiles     │────▶│     leads       │────▶│    clients      │
│  (User data)    │     │ (Sales leads)   │     │ (Converted)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       ▼                       ▼
        │               ┌─────────────────┐     ┌─────────────────┐
        │               │   deposits      │     │ client_groups   │
        │               │ (Transactions)  │     │ (Grouping)      │
        │               └─────────────────┘     └─────────────────┘
        │
        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   user_roles    │     │   attendance    │     │   reminders     │
│ (Role mapping)  │     │ (Time tracking) │     │ (Task reminders)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Table Count by Category

| Category | Tables | Description |
|----------|--------|-------------|
| User Management | 4 | profiles, user_roles, user_preferences, ip_whitelist |
| Lead Management | 5 | leads, lead_groups, lead_group_memberships, lead_activities, lead_statuses |
| Client Management | 8 | clients, client_groups, client_group_members, client_activities, client_comments, client_tasks, client_statuses, client_withdrawals |
| Financial | 4 | deposits, sale_branches, commission_tier_settings, manager_commission_settings |
| Communication | 7 | email_templates, email_signatures, email_credentials, sent_emails, received_emails, conversations, messages |
| Documents | 2 | documents, kyc_records |
| Attendance | 1 | attendance |
| Notifications | 2 | notifications, reminders |
| Security | 3 | auth_attempts, audit_logs, login_sessions |
| Settings | 2 | general_settings, admin_settings |

---

## RLS Policy Summary

### Key RLS Functions

```sql
-- Check if user can access a tenant
can_access_tenant(admin_id uuid) RETURNS boolean

-- Check if user has a specific role
has_role(user_id uuid, role app_role) RETURNS boolean

-- Get user's role directly
get_user_role_direct(user_id uuid) RETURNS text

-- Get user's admin_id
get_user_admin_id(user_id uuid) RETURNS uuid
```

### Common RLS Patterns

1. **Tenant Isolation**
```sql
can_access_tenant(admin_id)
```

2. **Role-Based Access**
```sql
has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR 
has_role(auth.uid(), 'TENANT_OWNER'::app_role)
```

3. **Owner Access**
```sql
assigned_to = auth.uid() OR created_by = auth.uid()
```

4. **Hierarchical Access**
```sql
-- Managers see their team's data
EXISTS (
  SELECT 1 FROM profiles 
  WHERE profiles.manager_id = auth.uid() 
  AND profiles.id = table.user_id
)
```

---

## Page Documentation

---

### 1. Index (Login Page)

**Route:** `/`  
**File:** `src/pages/Index.tsx`  
**Access:** Public (unauthenticated)

#### Purpose
Authentication entry point with username/email login, CAPTCHA protection, and brute-force prevention.

#### Features
- Username or email-based login
- "Remember me" functionality
- Progressive CAPTCHA after failed attempts
- IP-based blocking after excessive failures
- Animated background with glassmorphism UI

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `auth.users` | READ | Validate credentials |
| `profiles` | READ | Fetch user profile on login |
| `auth_attempts` | INSERT | Log login attempts |
| `login_sessions` | INSERT | Create session record |

#### RLS Policies
- `auth_attempts`: Anyone can INSERT (for logging)
- `profiles`: Users can read their own profile

#### Key Functions
```typescript
signIn(username, password, rememberMe, captchaToken)
// Returns: { error?, needsCaptcha?, isBlocked?, attemptsRemaining? }
```

#### Security Features
- Rate limiting: 5 attempts before CAPTCHA
- IP blocking: 15 minutes after 10 failed attempts
- Session token rotation
- Secure cookie handling

---

### 2. Dashboard

**Route:** `/dashboard`  
**File:** `src/pages/Dashboard.tsx`  
**Access:** All authenticated users

#### Purpose
Main KPI dashboard showing tenant-wide performance metrics, top performers, and quick stats.

#### Features
- Real-time statistics cards (Leads, Clients, Deposits, Conversion Rate)
- Top agents leaderboard by deposits
- Monthly deposit trends chart
- Role-based data visibility

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `leads` | READ | Count and stats |
| `clients` | READ | Count and balance totals |
| `deposits` | READ | Sum amounts, count |
| `profiles` | READ | Agent names for leaderboard |

#### RLS Policies
- **SUPER_ADMIN**: All tenant data
- **TENANT_OWNER/MANAGER**: Own tenant data
- **AGENT/SUPER_AGENT**: Aggregate stats only

#### Data Flow
```
Dashboard Component
    │
    ├── useQuery('dashboard-stats')
    │       └── SELECT COUNT(*) FROM leads/clients/deposits
    │
    ├── useQuery('top-agents')
    │       └── SELECT profiles.*, SUM(deposits.amount) 
    │           GROUP BY agent_id ORDER BY total DESC
    │
    └── useQuery('monthly-trends')
            └── SELECT DATE_TRUNC('month', created_at), SUM(amount)
                FROM deposits GROUP BY month
```

---

### 3. Leads

**Route:** `/leads`  
**File:** `src/pages/Leads.tsx`  
**Access:** All authenticated users (filtered by role)

#### Purpose
Comprehensive lead management with table, board (Kanban), and group views.

#### Features
- Multi-view: Table, Board (Kanban), Groups
- Advanced filtering (status, country, assigned agent, date range)
- Bulk actions (assign, delete, move to group)
- Import/Export CSV
- Real-time status updates
- Shuffle assignment (random distribution with pagination support for large groups 1000+ leads)

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `leads` | CRUD | Core lead data |
| `lead_groups` | READ | Group filtering |
| `lead_group_memberships` | CRUD | Lead-group associations |
| `lead_statuses` | READ | Status options |
| `lead_activities` | INSERT | Activity logging |
| `profiles` | READ | Agent names |

#### RLS Policies
```sql
-- SELECT: Role-based visibility
leads_select_policy:
  SUPER_ADMIN: All leads
  TENANT_OWNER/MANAGER: Tenant leads (admin_id match)
  AGENT/SUPER_AGENT: assigned_to = auth.uid() OR created_by = auth.uid()

-- INSERT: All authenticated users
leads_insert_policy: true

-- UPDATE: Admins + assigned/created by
leads_update_policy: Role check OR ownership

-- DELETE: Admins only
leads_delete_policy: SUPER_ADMIN/TENANT_OWNER/MANAGER/ADMIN
```

#### Key Hooks
```typescript
useLeadsPaginated({
  page, pageSize, search, filters, sortColumn, sortDirection
})
// Returns: { leads, totalCount, isLoading }

useLeadActions()
// Returns: { updateStatus, assignLead, deleteLead, bulkAssign }

useLeadGroups()
// Returns: { groups, createGroup, deleteGroup }
```

---

### 4. Lead Detail

**Route:** `/leads/:id`  
**File:** `src/pages/LeadDetail.tsx`  
**Access:** Users with access to the lead

#### Purpose
Detailed view of individual lead with full information, KYC data, and activity history.

#### Features
- Lead header with status badge
- Contact information (phone, email with visibility controls)
- Financial summary (balance, equity)
- KYC banks and notes management
- Document upload/download
- Activity timeline
- Quick actions (call, email, edit)

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `leads` | READ/UPDATE | Lead data |
| `kyc_records` | CRUD | KYC information |
| `documents` | CRUD | File attachments |
| `lead_activities` | READ/INSERT | Activity log |
| `call_history` | INSERT | Call logging |

#### RLS Policies
- Same as leads table for base access
- `kyc_records`: Linked to lead access
- `documents`: Upload by owner, view by lead accessor

#### Visibility Controls
```typescript
const shouldShowPhone = isSuperAdmin || isTenantOwner || isManager || 
  (isSuperAgent && settings?.show_phone_to_super_agents) ||
  (isAgent && settings?.show_phone_to_agents);

const shouldShowEmail = isSuperAdmin || isTenantOwner || isManager ||
  (isSuperAgent && settings?.show_email_to_super_agents) ||
  (isAgent && settings?.show_email_to_agents);
```

---

### 5. Clients

**Route:** `/clients`  
**File:** `src/pages/Clients.tsx`  
**Access:** All authenticated users (filtered by role)

#### Purpose
Client management interface mirroring leads functionality for converted customers.

#### Features
- Table and Board views
- Default sort by last modified (updated_at descending)
- Summary statistics (Total Clients, Total Balance, Total Initial Amount)
- Status management with custom statuses
- Group assignment
- Bulk operations
- Export functionality

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `clients` | CRUD | Core client data |
| `client_groups` | READ | Grouping |
| `client_group_members` | CRUD | Group memberships |
| `client_statuses` | READ | Status options |
| `client_activities` | INSERT | Activity log |
| `deposits` | READ | Financial data |

#### RLS Policies
```sql
-- Similar pattern to leads
clients_select_policy:
  Admins: Full tenant access
  Agents: assigned_to = auth.uid() OR created_by = auth.uid()

clients_secure VIEW:
  Masks email/phone based on role and settings
```

#### Key Statistics
```typescript
const stats = {
  totalClients: clients.length,
  totalBalance: clients.reduce((sum, c) => sum + (c.balance || 0), 0),
  totalInitialAmt: clients.reduce((sum, c) => sum + (c.deposits || 0), 0)
};
```

---

### 6. Client Detail

**Route:** `/clients/:id`  
**File:** `src/pages/ClientDetail.tsx`  
**Access:** Users with access to the client

#### Purpose
Comprehensive client profile with financial data, KYC, documents, and deposit history.

#### Features
- Client header with pipeline status
- Financial metrics (Balance, Equity, Open Trades, Margin Level)
- Deposit history with approval status
- KYC management (banks, notes)
- Document management
- Activity timeline
- Pipeline stage visualization

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `clients` | READ/UPDATE | Client data |
| `deposits` | READ | Deposit history |
| `kyc_records` | CRUD | KYC data |
| `documents` | CRUD | Files |
| `client_activities` | READ/INSERT | Activity log |

#### Pipeline Stages
```typescript
enum PipelineStatus {
  NEW = 'new',
  CONTACTED = 'contacted', 
  INTERESTED = 'interested',
  DEPOSITED = 'deposited',
  FLIPPED = 'flipped'
}
```

---

### 7. Pipeline

**Route:** `/pipeline`  
**File:** `src/pages/Pipeline.tsx`  
**Access:** All authenticated users

#### Purpose
Visual sales pipeline (Kanban board) for tracking client progression through sales stages.

#### Features
- Drag-and-drop stage management
- Stage columns: New → Contacted → Interested → Deposited → Flipped
- Deposit creation dialog
- Deposit approval workflow
- Celebration animation on deposits
- Filtering by agent, date range

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `clients` | READ/UPDATE | Pipeline status |
| `deposits` | CRUD | Deposit management |
| `sale_branches` | READ | Sale branch options |
| `profiles` | READ | Agent assignments |

#### RLS Policies
```sql
-- Deposits
deposits_insert_policy:
  SUPER_ADMIN, TENANT_OWNER, ADMIN, MANAGER, SUPER_AGENT can create

deposits_update_policy:
  SUPER_ADMIN, TENANT_OWNER, ADMIN, MANAGER can approve/reject

deposits_delete_policy:
  SUPER_ADMIN, TENANT_OWNER, SUPER_AGENT can delete
```

#### Drag-and-Drop Flow
```
User drags client card
    │
    ├── onDragEnd() triggered
    │       │
    │       ├── If moving to 'deposited' → Open DepositDialog
    │       │
    │       └── Otherwise → Update pipeline_status
    │
    └── Optimistic UI update + Database sync
```

---

### 8. Convert Queue

**Route:** `/convert`  
**File:** `src/pages/ConvertQueue.tsx`  
**Access:** MANAGER, TENANT_OWNER, SUPER_ADMIN

#### Purpose
Workflow for converting leads to clients with pending request management.

#### Features
- Pending conversions tab (leads with pending_conversion = true)
- Converted clients tab
- Conversion dialog with agent assignment
- Cancel conversion request
- Filtering and search

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `leads` | READ/UPDATE | Pending leads |
| `clients` | READ/INSERT | Converted clients |
| `profiles` | READ | Agent options |

#### Conversion Flow
```
Lead (pending_conversion = true)
    │
    ├── Manager reviews
    │       │
    │       ├── Approve → Create client, Update lead.pending_conversion = false
    │       │
    │       └── Cancel → Update lead.pending_conversion = false
    │
    └── Client created with converted_from_lead_id reference
```

#### Key Hook
```typescript
useConvertQueue()
// Returns: {
//   leads: Lead[],           // Pending conversion
//   convertedClients: Client[],
//   handleConvert: (leadId, agentId) => Promise,
//   handleCancel: (leadId) => Promise
// }
```

---

### 9. Attendance

**Route:** `/attendance`  
**File:** `src/pages/Attendance.tsx`  
**Access:** All authenticated users

#### Purpose
Time tracking system with clock in/out, break management, and fee calculations.

#### Features
- Clock in/out with timestamp
- Break time tracking
- Late start detection
- Fee calculations (late fee, excessive break fee)
- Working hours configuration
- Monthly summary by agent (for managers)

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `attendance` | CRUD | Time records |
| `general_settings` | READ | Working hours config |
| `profiles` | READ | User info |

#### RLS Policies
```sql
-- Users manage their own attendance
attendance_policy:
  INSERT: auth.uid() = user_id
  UPDATE: auth.uid() = user_id OR is_admin
  SELECT: auth.uid() = user_id OR can_access_tenant(admin_id)
```

#### Fee Calculation
```typescript
interface AttendanceRecord {
  clock_in: string;
  clock_out?: string;
  break_minutes: number;
  is_late: boolean;
  late_start_fee: number;      // From settings
  break_time_fee: number;      // Calculated from excess break
  total_fees: number;          // Sum of all fees
}
```

---

### 10. Email

**Route:** `/email`  
**File:** `src/pages/Email.tsx`  
**Access:** All authenticated users

#### Purpose
Email management system with templates, signatures, and sent email history.

#### Features
- Email template management (create, edit, share)
- Email signature editor
- Sent emails history
- Template variables support
- Admin view of all sent emails

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `email_templates` | CRUD | Email templates |
| `email_signatures` | CRUD | User signatures |
| `sent_emails` | READ | Email history |
| `email_credentials` | READ | Sender config |

#### RLS Policies
```sql
-- Templates
email_templates_select:
  user_id = auth.uid() OR is_shared = true

email_templates_insert:
  auth.uid() = user_id

-- Signatures
email_signatures: user_id = auth.uid()

-- Sent emails
sent_emails: user_id = auth.uid() OR is_admin
```

#### Template Variables
```
{{name}} - Recipient name
{{email}} - Recipient email
{{company}} - Company name
{{date}} - Current date
```

---

### 11. Reports

**Route:** `/reports`  
**File:** `src/pages/Reports.tsx`  
**Access:** All authenticated users (role-filtered views)

#### Purpose
Analytics and reporting dashboard with multiple report types.

#### Features
- Daily summary cards
- Sales report (by agent, by period)
- Pipeline report (stage distribution)
- Conversion report (lead to client rates)
- Deposits report (amounts, approval rates)
- Export to CSV/Excel
- Date range filtering

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `leads` | READ | Lead statistics |
| `clients` | READ | Client statistics |
| `deposits` | READ | Financial data |
| `profiles` | READ | Agent data |

#### RLS Policies
- All data is tenant-isolated
- Agents see only their own stats
- Managers see team stats
- Admins see all tenant stats

#### Report Types
```typescript
enum ReportType {
  SALES = 'sales',
  PIPELINE = 'pipeline', 
  CONVERSION = 'conversion',
  DEPOSITS = 'deposits'
}
```

#### Role-Based Views
| Role | Available Reports |
|------|-------------------|
| AGENT | Own performance only (AgentReportView) |
| SUPER_AGENT | Own performance (SuperAgentReportView) |
| MANAGER | Team performance + all reports |
| TENANT_OWNER/SUPER_ADMIN | All reports + daily summary |

---

### 12. Salary

**Route:** `/salary`  
**File:** `src/pages/Salary.tsx`  
**Access:** MANAGER, TENANT_OWNER, SUPER_ADMIN

#### Purpose
Commission and salary calculator based on tiered structures.

#### Features
- Monthly salary breakdown
- Commission tier configuration
- Base salary tiers
- Fee deductions from attendance
- Per-user salary details
- Role-specific commission rates

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `commission_tier_settings` | CRUD | Commission tiers |
| `manager_commission_settings` | CRUD | Manager-specific |
| `deposits` | READ | Commission base |
| `attendance` | READ | Fee deductions |
| `profiles` | READ | User data |

#### RLS Policies
```sql
commission_tier_settings:
  SELECT: can_access_tenant(admin_id)
  INSERT/UPDATE/DELETE: SUPER_ADMIN OR (TENANT_OWNER AND admin_id = auth.uid())
```

#### Commission Calculation
```typescript
interface CommissionTier {
  threshold: number;  // Deposit amount threshold
  rate: number;       // Commission percentage
}

// Example tiers
const agentTiers = [
  { threshold: 0, rate: 5 },
  { threshold: 10000, rate: 6 },
  { threshold: 20000, rate: 7 }
];
```

#### Salary Formula
```
Net Salary = Base Salary + Commission - Attendance Fees
Commission = Total Approved Deposits × Commission Rate
```

---

### 13. Call History

**Route:** `/call-history`  
**File:** `src/pages/CallHistory.tsx`  
**Access:** All authenticated users

#### Purpose
Log of all initiated calls with status tracking.

#### Features
- Call log table
- Status tracking (initiated, answered, failed)
- Duration tracking
- Filter by date, agent, status
- Link to lead/client

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `call_history` | READ | Call records |
| `leads` | READ | Linked leads |
| `clients` | READ | Linked clients |
| `profiles` | READ | Agent names |

#### RLS Policies
```sql
call_history:
  SELECT: can_access_tenant(admin_id)
  INSERT: auth.uid() = user_id
```

#### Call Record Structure
```typescript
interface CallHistory {
  id: string;
  user_id: string;
  agent_email: string;
  phone_number: string;
  lead_id?: string;
  client_id?: string;
  status: 'initiated' | 'answered' | 'failed' | 'no_answer';
  duration?: number;
  error_message?: string;
  created_at: string;
}
```

---

### 14. User Management

**Route:** `/users`  
**File:** `src/pages/UserManagement.tsx`  
**Access:** MANAGER, TENANT_OWNER, SUPER_ADMIN

#### Purpose
User CRUD operations with role assignment and IP whitelisting.

#### Features
- User list with search/filter
- Create new users
- Edit user details
- Reset passwords
- Delete users
- IP whitelist management
- Role assignment

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `profiles` | CRUD | User profiles |
| `user_roles` | CRUD | Role assignments |
| `ip_whitelist` | CRUD | IP restrictions |
| `auth.users` | Edge Function | Auth user creation |

#### RLS Policies
```sql
profiles:
  SELECT: can_access_tenant(admin_id) OR id = auth.uid()
  UPDATE: is_admin OR id = auth.uid()

user_roles:
  ALL: is_admin
```

#### Edge Functions Used
```typescript
// Create user
supabase.functions.invoke('create-user', {
  body: { email, password, role, firstName, lastName }
})

// Reset password  
supabase.functions.invoke('manage-user-password', {
  body: { userId, newPassword }
})
```

---

### 15. Tenant Management

**Route:** `/tenants`  
**File:** `src/pages/TenantManagement.tsx`  
**Access:** SUPER_ADMIN only

#### Purpose
Multi-tenant administration for creating and managing tenant workspaces.

#### Features
- Tenant list with statistics
- Create new tenant (creates TENANT_OWNER user)
- Edit tenant details
- Reset tenant owner password
- IP whitelist per tenant
- Aggregate stats per tenant

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `profiles` | CRUD | Tenant owner profiles |
| `user_roles` | READ | Role verification |
| `leads` | READ | Tenant stats |
| `clients` | READ | Tenant stats |
| `deposits` | READ | Tenant stats |
| `ip_whitelist` | CRUD | Tenant IP rules |

#### RLS Policies
```sql
-- All operations require SUPER_ADMIN role
profiles (for tenant owners):
  SELECT: has_role(auth.uid(), 'SUPER_ADMIN')
```

#### Tenant Creation Flow
```
1. Create auth.users entry via Edge Function
2. Create profiles entry with role = 'TENANT_OWNER'
3. Create user_roles entry
4. Initialize general_settings for tenant
5. Create default commission_tier_settings
```

---

### 16. Team Management

**Route:** `/team`  
**File:** `src/pages/TeamManagement.tsx`  
**Access:** TENANT_OWNER, SUPER_ADMIN

#### Purpose
Visual team hierarchy management with drag-and-drop assignment.

#### Features
- Visual hierarchy display
- Drag-and-drop agent assignment to managers
- Unassigned pool
- Role badges
- Team statistics

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `profiles` | READ/UPDATE | Team structure |
| `user_roles` | READ | Role verification |

#### RLS Policies
```sql
profiles:
  UPDATE (manager_id): TENANT_OWNER or SUPER_ADMIN
```

#### Team Hierarchy Structure
```typescript
interface TeamHierarchy {
  managers: TeamMember[];      // Users with MANAGER role
  superAgents: TeamMember[];   // Users with SUPER_AGENT role
  agents: TeamMember[];        // Users with AGENT role
  tenantOwners: TeamMember[];  // Users with TENANT_OWNER role
}

interface TeamMember {
  id: string;
  full_name: string;
  role: string;
  manager_id?: string;
  avatar_url?: string;
}
```

---

### 17. General Settings

**Route:** `/settings`  
**File:** `src/pages/GeneralSettings.tsx`  
**Access:** TENANT_OWNER, SUPER_ADMIN

#### Purpose
Tenant-wide configuration for privacy, security, and operational settings.

#### Features
- Phone/Email visibility controls
- Password protection rules
- Working hours configuration
- Celebration sounds upload
- Status management (lead/client statuses)
- Attendance fee settings

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `general_settings` | CRUD | Settings data |
| `admin_settings` | CRUD | Admin-specific |
| `lead_statuses` | CRUD | Status options |
| `client_statuses` | CRUD | Status options |

#### RLS Policies
```sql
general_settings:
  SELECT: can_access_tenant(admin_id)
  ALL: SUPER_ADMIN OR (TENANT_OWNER AND admin_id = auth.uid())
```

#### Settings Structure
```typescript
interface GeneralSettings {
  // Privacy
  show_phone_to_agents: boolean;
  show_phone_to_super_agents: boolean;
  show_email_to_agents: boolean;
  show_email_to_super_agents: boolean;
  
  // Working Hours
  work_start_time: string;  // "09:00"
  work_end_time: string;    // "18:00"
  max_break_minutes: number;
  
  // Fees
  late_start_fee: number;
  excessive_break_fee: number;
  day_off_fee: number;
  
  // Media
  celebration_sound_url?: string;
  celebration_video_url?: string;
  
  // Password Policy
  password_protection_config: {
    min_password_length: number;
    require_uppercase: boolean;
    require_lowercase: boolean;
    require_numbers: boolean;
    require_special_chars: boolean;
    enable_leaked_password_check: boolean;
  };
}
```

---

### 18. Integrations

**Route:** `/integrations`  
**File:** `src/pages/Integrations.tsx`  
**Access:** TENANT_OWNER, SUPER_ADMIN

#### Purpose
Third-party integration management for calling and email services.

#### Features
- CCC (Call Control Center) integration
- Email provider configuration
- API key management
- Connection testing
- Provider status display

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `general_settings` | READ/UPDATE | Integration config |
| `admin_settings` | READ/UPDATE | API keys |

#### RLS Policies
```sql
admin_settings:
  ALL: admin_id = auth.uid() (TENANT_OWNER only)
  SELECT: SUPER_ADMIN
```

#### Integration Providers
```typescript
interface IntegrationProvider {
  id: string;
  name: string;
  type: 'calling' | 'email';
  isEnabled: boolean;
  config: {
    apiKey?: string;
    endpoint?: string;
    webhookUrl?: string;
  };
}
```

---

### 19. Security Monitoring

**Route:** `/security`  
**File:** `src/pages/SecurityMonitoring.tsx`  
**Access:** MANAGER, TENANT_OWNER, SUPER_ADMIN

#### Purpose
Security dashboard for monitoring authentication, sessions, and suspicious activity.

#### Features
- Failed login attempts summary
- Active sessions display
- File upload monitoring
- Login history
- IP-based threat detection
- Per-tenant security view (for SUPER_ADMIN)

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `auth_attempts` | READ | Login attempts |
| `login_sessions` | READ | Active sessions |
| `documents` | READ | File uploads |
| `audit_logs` | READ | Activity logs |

#### RLS Policies
```sql
auth_attempts:
  SELECT: is_admin OR user_email = current_user_email

login_sessions:
  SELECT: can_access_tenant(admin_id)

audit_logs:
  SELECT: is_admin OR user_id = auth.uid()
```

#### Security Metrics
```typescript
interface SecurityMetrics {
  failedLogins24h: number;
  activeSessions: number;
  suspiciousUploads: number;
  highRiskIPs: string[];
}
```

---

### 20. Profile

**Route:** `/profile`  
**File:** `src/pages/Profile.tsx`  
**Access:** All authenticated users

#### Purpose
User profile management with avatar, password change, and session management.

#### Features
- Avatar upload
- Profile information update
- Password change
- Active sessions list
- Session termination

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `profiles` | READ/UPDATE | User profile |
| `login_sessions` | READ/DELETE | Sessions |
| `storage.avatars` | CRUD | Avatar images |

#### RLS Policies
```sql
profiles:
  SELECT: id = auth.uid() OR can_access_tenant(admin_id)
  UPDATE: id = auth.uid()

storage.avatars:
  INSERT: auth.uid()::text = (storage.foldername(name))[1]
  SELECT: public bucket
```

---

### 21. Notification History

**Route:** `/notifications`  
**File:** `src/pages/NotificationHistory.tsx`  
**Access:** All authenticated users

#### Purpose
View and manage notification history with read/archive functionality.

#### Features
- Recent notifications tab
- Unread notifications tab
- Archived notifications tab
- Mark as read (individual/all)
- Notification type icons

#### Database Tables

| Table | Operation | Purpose |
|-------|-----------|---------|
| `notifications` | READ/UPDATE | Notification records |

#### RLS Policies
```sql
notifications:
  SELECT: user_id = auth.uid()
  UPDATE: user_id = auth.uid()  -- Mark as read
```

#### Notification Types
```typescript
enum NotificationType {
  LEAD_ASSIGNED = 'lead_assigned',
  CLIENT_ASSIGNED = 'client_assigned',
  DEPOSIT_APPROVED = 'deposit_approved',
  DEPOSIT_REJECTED = 'deposit_rejected',
  REMINDER_DUE = 'reminder_due',
  SYSTEM = 'system'
}
```

---

## Key Database Functions

### Security Functions (SECURITY DEFINER)

| Function | Purpose | Used By |
|----------|---------|---------|
| `can_access_tenant(admin_id)` | Check tenant access | All RLS policies |
| `has_role(user_id, role)` | Check user role | RLS policies |
| `get_user_role_direct(user_id)` | Get role as text | RLS policies |
| `get_user_admin_id(user_id)` | Get user's tenant | Data filtering |
| `is_manager_of(user_id)` | Check manager relationship | Team access |

### Utility Functions

| Function | Purpose |
|----------|---------|
| `update_updated_at_column()` | Auto-update timestamps |
| `log_activity(entity, action, details)` | Create audit log |
| `calculate_commission(amount, tiers)` | Commission calculation |

---

## Edge Functions

| Function | Purpose | Auth Required |
|----------|---------|---------------|
| `create-user` | Create new user with role | TENANT_OWNER+ |
| `manage-user-password` | Reset user password | TENANT_OWNER+ |
| `initiate-call` | Start CCC call | Authenticated |
| `hangup-call` | End CCC call | Authenticated |
| `send-email` | Send email via provider | Authenticated |
| `mark-email-read` | Update email read status | Authenticated |
| `bulk-assign-leads` | Bulk lead assignment | MANAGER+ |
| `bulk-assign-clients` | Bulk client assignment | MANAGER+ |
| `bulk-delete-leads` | Bulk lead deletion | MANAGER+ |
| `bulk-delete-clients` | Bulk client deletion | MANAGER+ |
| `bulk-update-lead-status` | Bulk status update | MANAGER+ |
| `bulk-update-client-status` | Bulk status update | MANAGER+ |
| `security-monitor` | Security check endpoint | MANAGER+ |
| `health-check` | System health check | Public |
| `test-ccc-connection` | Test CCC integration | TENANT_OWNER+ |
| `test-email-provider` | Test email config | TENANT_OWNER+ |

---

## Security Considerations

### Authentication
- JWT-based authentication via Supabase Auth
- Session token rotation every 24 hours
- IP-based rate limiting
- CAPTCHA after failed attempts
- IP whitelisting per user/tenant

### Data Protection
- Row Level Security on all tables
- Tenant isolation via `admin_id`
- Role-based access control
- Secure views for PII masking
- Encrypted storage for sensitive data

### Audit Trail
- All mutations logged to `audit_logs`
- Login attempts tracked
- Session history maintained
- File upload monitoring

### Best Practices Implemented
- No direct auth.users access
- SECURITY DEFINER functions for elevated operations
- Input validation on all forms
- XSS protection via DOMPurify
- CSRF protection via SameSite cookies

---

## Appendix: Quick Reference

### Route → Page Mapping
```
/                    → Index (Login)
/dashboard           → Dashboard
/leads               → Leads
/leads/:id           → LeadDetail
/clients             → Clients
/clients/:id         → ClientDetail
/pipeline            → Pipeline
/convert             → ConvertQueue
/attendance          → Attendance
/email               → Email
/reports             → Reports
/salary              → Salary
/call-history        → CallHistory
/users               → UserManagement
/tenants             → TenantManagement
/team                → TeamManagement
/settings            → GeneralSettings
/integrations        → Integrations
/security            → SecurityMonitoring
/profile             → Profile
/notifications       → NotificationHistory
```

### Role → Accessible Pages
```
SUPER_ADMIN:    All pages
TENANT_OWNER:   All except /tenants
MANAGER:        All except /tenants, /settings (limited)
SUPER_AGENT:    Dashboard, Leads, Clients, Pipeline, Attendance, Email, Reports (own), Profile
AGENT:          Dashboard, Leads (assigned), Clients (assigned), Attendance, Email, Reports (own), Profile
```

---

*This documentation is auto-generated and should be updated when significant changes are made to the application structure.*

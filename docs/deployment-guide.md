# Complete Forex CRM Deployment Guide

This guide provides step-by-step instructions for deploying the Forex CRM application to your own infrastructure.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Supabase Project Setup](#supabase-project-setup)
3. [Database Setup](#database-setup)
4. [Edge Functions Deployment](#edge-functions-deployment)
5. [Secrets Configuration](#secrets-configuration)
6. [Frontend Build](#frontend-build)
7. [Web Hosting Deployment](#web-hosting-deployment)
8. [Post-Deployment Configuration](#post-deployment-configuration)
9. [Verification Checklist](#verification-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- [ ] A Supabase account (https://supabase.com)
- [ ] Node.js 18+ installed locally (for building)
- [ ] Git installed
- [ ] Access to your web hosting (e.g., Orangewebsite, Netlify, Vercel)
- [ ] The project source code

### Required Credentials You'll Need

| Credential | Where to Find |
|------------|---------------|
| Supabase Project URL | Supabase Dashboard → Settings → API |
| Supabase Anon Key | Supabase Dashboard → Settings → API |
| Supabase Service Role Key | Supabase Dashboard → Settings → API |
| CCC API Key | Your Call Center Connect provider |

---

## Supabase Project Setup

### Step 1: Create a New Supabase Project

1. Go to https://supabase.com/dashboard
2. Click **"New Project"**
3. Fill in:
   - **Organization**: Select or create one
   - **Project Name**: `forex-crm` (or your preferred name)
   - **Database Password**: Generate a strong password (SAVE THIS!)
   - **Region**: Choose closest to your users
4. Click **"Create new project"**
5. Wait 2-3 minutes for project initialization

### Step 2: Get Your API Credentials

1. Once project is ready, go to **Settings** → **API**
2. Copy and save these values:

```
Project URL: https://[your-project-id].supabase.co
Anon/Public Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Service Role Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (keep secret!)
```

### Step 3: Configure Authentication

1. Go to **Authentication** → **Providers**
2. Ensure **Email** provider is enabled
3. Go to **Authentication** → **Settings**
4. Under **Auth Settings**:
   - Set **Site URL**: `https://your-domain.com`
   - Set **Redirect URLs**: `https://your-domain.com/*`
5. Under **Email Settings**:
   - **Enable email confirmations**: OFF (for auto-confirm)
   - Or configure your SMTP for production emails

---

## Database Setup

### Overview

The database setup involves running **127 migration files** in chronological order. Each migration builds on the previous one, so order is critical.

> ⚠️ **Important**: Do NOT skip migrations or run them out of order. Each migration depends on the previous ones.

---

### Step 1: Open SQL Editor

1. In Supabase Dashboard, click **SQL Editor** in the left sidebar
2. Click **"New query"** button (top right)
3. You'll see a blank query editor

![SQL Editor Location](https://supabase.com/docs/img/guides/database/sql-editor.png)

---

### Step 2: Understand Migration Files

Migration files are located in `supabase/migrations/` folder. Each file is named with a timestamp:

```
Format: YYYYMMDDHHMMSS_uuid.sql
Example: 20251125091827_5cb6fe6a-7780-4b21-bc68-88b37cfe1407.sql
         ↑              ↑
         Date/Time      Unique ID
```

**Total migrations to run: 127 files**

The migrations are ordered chronologically:
- Start with: `20251125091827_...` (November 25, 2025)
- End with: `20251206171021_...` (December 6, 2025)

---

### Step 3: Run Migrations (Detailed Process)

#### Method A: Run Each File Individually (Recommended for First Time)

**For each migration file, follow these steps:**

1. **Open the file** in your code editor (VS Code, etc.)
   ```
   Location: supabase/migrations/20251125091827_5cb6fe6a-7780-4b21-bc68-88b37cfe1407.sql
   ```

2. **Select ALL content** in the file (Ctrl+A / Cmd+A)

3. **Copy** the content (Ctrl+C / Cmd+C)

4. **Go to Supabase SQL Editor**

5. **Clear any existing text** in the query window

6. **Paste** the migration SQL (Ctrl+V / Cmd+V)

7. **Click "Run"** button (or press Ctrl+Enter / Cmd+Enter)

8. **Check the result:**
   - ✅ **Success**: Green message "Success. No rows returned" or similar
   - ❌ **Error**: Red error message - STOP and troubleshoot

9. **Clear the query window** and repeat for the next migration file

#### Method B: Combine Multiple Migrations (Advanced)

You can combine multiple small migrations into one query:

```sql
-- Migration 1 content here
-- ...

-- Migration 2 content here  
-- ...

-- Migration 3 content here
-- ...
```

> ⚠️ **Warning**: If ANY part fails, you may need to manually clean up. Method A is safer.

---

### Step 4: Complete Migration File List

Run these files **in this exact order**:

```
supabase/migrations/
├── 01. 20251125091827_5cb6fe6a-7780-4b21-bc68-88b37cfe1407.sql
├── 02. 20251125091838_bdb20be0-ab05-4ca2-bf3c-ac1d1fc97063.sql
├── 03. 20251125092325_47ba2c08-2974-4495-8fe1-0bcbb20807f9.sql
├── 04. 20251125102618_dc4f4c31-ee10-4b1b-bf63-c7b59fc9fcdb.sql
├── 05. 20251125103021_bfe652c7-e88b-4ebd-ab7b-d8bb00ead5d3.sql
├── 06. 20251125103609_ce37d0d7-7fa8-4f8c-987b-ae6bedc542c4.sql
├── 07. 20251125111733_3d6d2df0-2731-4184-a019-27d15f9e69a3.sql
├── 08. 20251125115800_c98b8e84-4efd-422d-9758-c6e7cdcc8695.sql
├── 09. 20251126045206_b7f95f4e-babb-4534-bc71-9af02f7b1bc0.sql
├── 10. 20251126100741_b2f481ff-cc03-4376-be4b-c6884523655b.sql
├── ... (continue through all 127 files)
├── 125. 20251206164143_d1988d2e-12ac-4d83-9f89-56a9312db2c7.sql
├── 126. 20251206171021_9dae0b9c-1f6e-404f-9a4e-74645df17900.sql
└── 127. (latest migration file)
```

**Pro Tip**: Sort files by name in your file explorer - they're already in chronological order!

---

### Step 5: Verify Database Setup

After running ALL migrations, verify the setup:

#### 5.1 Check Tables Were Created

Run this query:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected tables (35+ tables):**

| Core Tables | User Tables | Feature Tables |
|-------------|-------------|----------------|
| `profiles` | `user_roles` | `leads` |
| `clients` | `user_permissions` | `deposits` |
| `admin_settings` | `user_sessions` | `documents` |
| `general_settings` | `user_preferences` | `kyc_records` |
| `attendance` | `conversations` | `reminders` |
| `audit_logs` | `messages` | `notifications` |
| `auth_attempts` | `group_chats` | `call_history` |
| `email_templates` | `group_chat_members` | `email_credentials` |

#### 5.2 Check Enums Were Created

```sql
SELECT typname FROM pg_type 
WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND typtype = 'e';
```

**Expected enums:**
- `app_role` (SUPER_ADMIN, TENANT_OWNER, ADMIN, MANAGER, SUPER_AGENT, AGENT)
- `app_permission`
- `lead_status`
- `client_status`
- `pipeline_status`
- `kyc_status`
- `notification_type`
- And more...

#### 5.3 Check Functions Were Created

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_type = 'FUNCTION'
ORDER BY routine_name;
```

**Expected functions (20+):**
- `has_role`
- `has_permission`
- `can_access_tenant`
- `get_user_admin_id`
- `encrypt_sensitive`
- `decrypt_sensitive`
- And more...

#### 5.4 Check RLS Policies Are Enabled

```sql
SELECT tablename, policyname, cmd
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

You should see multiple policies for each table (SELECT, INSERT, UPDATE, DELETE).

---

### Step 6: Create Initial Super Admin User

#### 6.1 Create Auth User via Dashboard

1. Go to **Authentication** → **Users** in Supabase Dashboard
2. Click **"Add user"** button
3. Fill in:
   - **Email**: `superadmin@crm.internal` (or your preferred email)
   - **Password**: A strong password (save this!)
   - **Auto Confirm User**: ✅ Check this box
4. Click **"Create user"**
5. **Copy the User UID** (UUID shown in the user row)

#### 6.2 Create Profile and Assign Role

Run this SQL in SQL Editor (replace `YOUR_USER_UUID_HERE` with the copied UUID):

```sql
-- Step 1: Create the profile
INSERT INTO public.profiles (id, email, full_name, username, created_at, updated_at)
VALUES (
  'YOUR_USER_UUID_HERE',                    -- Replace with actual UUID
  'superadmin@crm.internal',                -- Same email used above
  'Super Admin',                            -- Display name
  'superadmin',                             -- Login username
  now(),
  now()
);

-- Step 2: Assign SUPER_ADMIN role
INSERT INTO public.user_roles (user_id, role, created_at)
VALUES (
  'YOUR_USER_UUID_HERE',                    -- Same UUID
  'SUPER_ADMIN',
  now()
);

-- Step 3: Verify the user was created correctly
SELECT 
  p.id,
  p.email,
  p.username,
  p.full_name,
  ur.role
FROM profiles p
JOIN user_roles ur ON ur.user_id = p.id
WHERE p.username = 'superadmin';
```

**Expected result:**

| id | email | username | full_name | role |
|----|-------|----------|-----------|------|
| (uuid) | superadmin@crm.internal | superadmin | Super Admin | SUPER_ADMIN |

---

### Step 7: Troubleshooting Database Setup

#### Error: "relation already exists"

The table was already created. This is usually safe to ignore if running migrations again.

```sql
-- Check if table exists
SELECT * FROM information_schema.tables WHERE table_name = 'table_name';
```

#### Error: "duplicate key value violates unique constraint"

The data already exists. Skip this migration or run:

```sql
-- Delete existing data first (BE CAREFUL!)
TRUNCATE table_name CASCADE;
```

#### Error: "permission denied for schema public"

You need proper permissions:

```sql
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
```

#### Error: "type 'app_role' does not exist"

Migrations ran out of order. Start from the beginning:

1. Go to **Database** → **Tables**
2. Delete all tables (or reset the database)
3. Run migrations from file #1

#### How to Reset Database Completely

If needed, you can reset and start fresh:

1. Go to **Database** → **Database Settings**
2. Click **"Reset database"** (this deletes ALL data)
3. Wait for reset to complete
4. Run all migrations again from the start

---

### Step 8: Enable Required Extensions

Some migrations require PostgreSQL extensions. Verify they're enabled:

```sql
-- Check enabled extensions
SELECT * FROM pg_extension;

-- Enable if missing (usually auto-enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

---

### Step 9: Configure Storage Buckets

After migrations, verify storage buckets exist:

1. Go to **Storage** in Supabase Dashboard
2. Verify these buckets exist:
   - `documents` (private)
   - `celebration-sounds` (public)
   - `celebration-videos` (public)
   - `email-images` (public)

If missing, create them:

```sql
-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('documents', 'documents', false),
  ('celebration-sounds', 'celebration-sounds', true),
  ('celebration-videos', 'celebration-videos', true),
  ('email-images', 'email-images', true)
ON CONFLICT (id) DO NOTHING;
```

---

### Database Setup Checklist

Before proceeding, verify:

- [ ] All 127 migrations ran successfully
- [ ] 35+ tables exist in public schema
- [ ] Enums created (app_role, lead_status, etc.)
- [ ] Functions created (has_role, can_access_tenant, etc.)
- [ ] RLS policies enabled on all tables
- [ ] Super Admin user created and can log in
- [ ] Storage buckets exist
- [ ] Extensions enabled (uuid-ossp, pgcrypto)

---

## Edge Functions Deployment

### Step 1: Access Functions Section

1. In Supabase Dashboard, go to **Edge Functions**
2. Click **"Create a new function"**

### Step 2: Deploy Each Function

For each function, you need to:
1. Click **"Create a new function"**
2. Enter the function name (exact name from list below)
3. Paste the code from the corresponding file
4. Configure JWT verification
5. Click **"Deploy"**

### Functions to Deploy:

| Function Name | File Location | JWT Required |
|---------------|---------------|--------------|
| `health-check` | `supabase/functions/health-check/index.ts` | NO |
| `create-user` | `supabase/functions/create-user/index.ts` | YES |
| `create-sample-users` | `supabase/functions/create-sample-users/index.ts` | YES |
| `manage-user-password` | `supabase/functions/manage-user-password/index.ts` | YES |
| `initiate-call` | `supabase/functions/initiate-call/index.ts` | YES |
| `hangup-call` | `supabase/functions/hangup-call/index.ts` | YES |
| `call-control` | `supabase/functions/call-control/index.ts` | YES |
| `call-webhook` | `supabase/functions/call-webhook/index.ts` | NO |
| `test-ccc-connection` | `supabase/functions/test-ccc-connection/index.ts` | YES |
| `update-ccc-api-key` | `supabase/functions/update-ccc-api-key/index.ts` | YES |
| `security-monitor` | `supabase/functions/security-monitor/index.ts` | NO |
| `send-email` | `supabase/functions/send-email/index.ts` | YES |
| `fetch-emails` | `supabase/functions/fetch-emails/index.ts` | YES |
| `test-email-provider` | `supabase/functions/test-email-provider/index.ts` | YES |
| `mark-email-read` | `supabase/functions/mark-email-read/index.ts` | YES |

### Step 3: Configure JWT Verification (Critical Security Step)

JWT (JSON Web Token) verification controls who can call your Edge Functions:

- **JWT Required = YES**: Only authenticated users with valid tokens can call the function
- **JWT Required = NO**: Anyone on the internet can call the function (public endpoint)

---

#### Understanding Which Functions Need Public Access

| Function | JWT Required | Why? |
|----------|--------------|------|
| `health-check` | **NO** | Health monitoring systems need unauthenticated access |
| `call-webhook` | **NO** | External CCC API sends callbacks without your JWT |
| `security-monitor` | **NO** | Scheduled jobs/cron call this without user context |
| All others | **YES** | User actions that need authentication |

---

#### How to Disable JWT Verification (for Public Functions)

**For each function marked "JWT Required: NO", follow these steps:**

##### Step 3.1: Navigate to the Function

1. In Supabase Dashboard, click **Edge Functions** in the left sidebar
2. You'll see a list of your deployed functions
3. Click on the function name (e.g., `health-check`)

##### Step 3.2: Open Function Settings

1. You're now on the function's detail page
2. Look for tabs at the top: **Details**, **Logs**, **Settings**
3. Click the **Settings** tab

##### Step 3.3: Disable JWT Verification

1. Find the section labeled **"JWT Verification"** or **"Verify JWT"**
2. You'll see a toggle switch (currently ON by default)
3. Click the toggle to turn it **OFF**
4. The toggle should now show as disabled/grey

##### Step 3.4: Save Changes

1. Click the **"Save"** button
2. Wait for confirmation message
3. The function is now publicly accessible

---

#### Visual Guide: JWT Settings Location

```
Supabase Dashboard
└── Edge Functions (left sidebar)
    └── [Click function name, e.g., "health-check"]
        └── Settings (top tab)
            └── JWT Verification
                └── Toggle: ON/OFF ← Click to disable
                └── [Save] button
```

---

#### Repeat for All Public Functions

You must configure JWT settings for these 3 functions:

| # | Function Name | Action Required |
|---|---------------|-----------------|
| 1 | `health-check` | Disable JWT verification |
| 2 | `call-webhook` | Disable JWT verification |
| 3 | `security-monitor` | Disable JWT verification |

**All other functions should keep JWT verification ENABLED (default).**

---

#### Verify JWT Configuration

After configuring, test each public function:

**Test health-check (no auth required):**
```bash
curl https://[your-project-id].supabase.co/functions/v1/health-check
```

Expected response:
```json
{"status":"healthy","timestamp":"2025-12-07T12:00:00.000Z"}
```

**Test a protected function without auth (should fail):**
```bash
curl https://[your-project-id].supabase.co/functions/v1/create-user
```

Expected response (401 Unauthorized):
```json
{"error":"Invalid JWT"}
```

This confirms JWT protection is working!

---

#### ⚠️ Security Warning

**Never disable JWT verification on functions that:**
- Create, update, or delete user data
- Access sensitive information (emails, passwords, API keys)
- Perform financial operations (deposits, transfers)
- Modify user roles or permissions

**Public functions should only be used for:**
- Health checks and monitoring
- Webhooks from trusted external services (with their own signature verification)
- Scheduled background jobs

---

#### Alternative: Configure via config.toml (Advanced)

If you're deploying via CLI (not dashboard), you can configure JWT in `supabase/config.toml`:

```toml
# supabase/config.toml

[functions.health-check]
verify_jwt = false

[functions.call-webhook]
verify_jwt = false

[functions.security-monitor]
verify_jwt = false

# All other functions default to verify_jwt = true
```

This is automatically applied when deploying via `supabase functions deploy`.

---

### Step 4: Verify All Functions Are Deployed

After deploying all functions, verify they're active:

1. Go to **Edge Functions** in dashboard
2. Check each function shows **"Active"** status
3. Green indicator means deployed and running

#### Quick Test: Health Check

```bash
curl https://[your-project-id].supabase.co/functions/v1/health-check
```

Expected response:
```json
{"status":"healthy","timestamp":"..."}
```

#### Test Protected Function (with auth):

```bash
curl -X POST https://[your-project-id].supabase.co/functions/v1/test-ccc-connection \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json"
```

---

## Secrets Configuration

### Step 1: Access Secrets

1. Go to **Settings** → **Edge Functions**
2. Or go to **Settings** → **Vault**

### Step 2: Add Required Secrets

Click **"Add secret"** for each:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `CALL_CENTER_API_KEY` | Your CCC API key | Required for call integration |

### Step 3: Verify Secrets

Your secrets should appear in the list. They're encrypted and won't show the actual values.

---

## Frontend Build

### Step 1: Clone and Install

```bash
# Clone the repository (if not already done)
git clone [your-repo-url]
cd forex-crm

# Install dependencies
npm install
```

### Step 2: Create Environment File

Create a `.env` file in the project root:

```env
VITE_SUPABASE_URL=https://[your-project-id].supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_SUPABASE_PROJECT_ID=[your-project-id]
```

**Important**: Use your Anon Key for `VITE_SUPABASE_PUBLISHABLE_KEY`, NOT the Service Role Key!

### Step 3: Build for Production

```bash
npm run build
```

This creates a `dist/` folder with all production files.

### Step 4: Verify Build

Check the `dist/` folder contains:
- `index.html`
- `assets/` folder with JS and CSS files

---

## Web Hosting Deployment

### Option A: Orangewebsite (cPanel/FTP)

#### Using cPanel File Manager:

1. Log into your cPanel
2. Open **File Manager**
3. Navigate to `public_html` (or your domain folder)
4. Delete existing files (if any)
5. Click **Upload**
6. Upload all contents of `dist/` folder
7. Ensure `index.html` is in the root

#### Using FTP:

1. Connect to your hosting via FTP (FileZilla, etc.)
2. Navigate to `public_html`
3. Upload all contents of `dist/` folder
4. Verify files are uploaded

#### Configure .htaccess for SPA Routing:

Create a `.htaccess` file in `public_html`:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  RewriteRule ^index\.html$ - [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.html [L]
</IfModule>

# Security headers
<IfModule mod_headers.c>
  Header set X-Frame-Options "DENY"
  Header set X-Content-Type-Options "nosniff"
  Header set X-XSS-Protection "1; mode=block"
  Header set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType text/css "access plus 1 year"
  ExpiresByType application/javascript "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/svg+xml "access plus 1 year"
</IfModule>
```

### Option B: Netlify

1. Go to https://netlify.com
2. Drag and drop the `dist/` folder
3. Or connect your GitHub repo and set:
   - Build command: `npm run build`
   - Publish directory: `dist`
4. Add environment variables in Site Settings → Environment Variables

Create `netlify.toml` in project root:

```toml
[build]
  command = "npm run build"
  publish = "dist"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### Option C: Vercel

1. Install Vercel CLI: `npm i -g vercel`
2. Run: `vercel`
3. Follow prompts
4. Add environment variables in Vercel Dashboard

Create `vercel.json` in project root:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

---

## Post-Deployment Configuration

### Step 1: Update Supabase Settings

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Update:
   - **Site URL**: `https://your-actual-domain.com`
   - **Redirect URLs**: Add `https://your-actual-domain.com/*`

### Step 2: Configure CORS (if needed)

1. Go to **Settings** → **API**
2. Under **CORS**, add your domain to allowed origins

### Step 3: Test Login

1. Visit your deployed site
2. Log in with your super admin credentials
3. Verify you can access the dashboard

### Step 4: Configure CCC Integration

1. Log in as super admin
2. Go to **Settings** → **Integrations**
3. Enter your CCC API endpoints and credentials
4. Test the connection

### Step 5: Create Your First Tenant (if multi-tenant)

1. Go to **Tenant Management**
2. Create a new tenant
3. Assign users to the tenant

---

## Verification Checklist

After deployment, verify each feature:

### Authentication
- [ ] Can log in with super admin
- [ ] Can create new users
- [ ] Password reset works
- [ ] Session management works

### Core Features
- [ ] Dashboard loads with data
- [ ] Leads page works (view, create, edit, delete)
- [ ] Clients page works
- [ ] Pipeline board functions
- [ ] Convert Queue works

### Integrations
- [ ] CCC connection test passes (if configured)
- [ ] Calls can be initiated
- [ ] Email sending works (if configured)

### Security
- [ ] RLS policies are active
- [ ] Role-based access works
- [ ] Audit logs are recording

---

## Troubleshooting

### Common Issues

#### "Failed to fetch" errors
- Check your Supabase URL in `.env` is correct
- Verify CORS is configured in Supabase
- Check browser console for specific errors

#### "Invalid JWT" errors
- Verify you're using the Anon Key, not Service Role Key
- Check the key is correctly copied (no extra spaces)

#### Blank page after deployment
- Check `.htaccess` is properly configured
- Verify all files from `dist/` were uploaded
- Check browser console for errors

#### Database errors
- Verify all migrations ran successfully
- Check RLS policies aren't blocking access
- Verify user roles are properly assigned

#### Edge functions not working
- Check function is deployed and active
- Verify JWT settings are correct
- Check Supabase logs for function errors

### Getting Help

1. Check Supabase logs: **Dashboard** → **Logs**
2. Check Edge Function logs: **Edge Functions** → [Function Name] → **Logs**
3. Check browser console for frontend errors
4. Verify network requests in browser DevTools

---

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_SUPABASE_URL` | Your Supabase project URL | `https://abc123.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Supabase Anon Key | `eyJhbGciOi...` |
| `VITE_SUPABASE_PROJECT_ID` | Project ID | `abc123` |

---

## Security Reminders

1. **Never expose Service Role Key** in frontend code
2. **Always use HTTPS** in production
3. **Enable RLS** on all tables with user data
4. **Rotate API keys** periodically
5. **Monitor audit logs** for suspicious activity
6. **Backup database** regularly

---

## Support

For issues specific to:
- **Supabase**: https://supabase.com/docs
- **React/Vite**: https://vitejs.dev/guide/
- **Hosting**: Contact your hosting provider

---

*Last updated: December 2024*

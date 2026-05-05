# Edge Functions AI Context Prompt

## Project Overview

This is a **Forex CRM application** built with React frontend and Supabase backend. Edge functions are Deno-based serverless functions that handle backend logic including API integrations, user management, email operations, and call center connectivity.

---

## Technology Stack

- **Runtime**: Deno (TypeScript)
- **Database**: Supabase PostgreSQL
- **Authentication**: Supabase Auth with JWT tokens
- **Hosting**: Supabase Edge Functions

---

## Project Structure

```
supabase/
├── config.toml                    # Function configuration (JWT settings)
└── functions/
    ├── _shared/                   # Shared utilities
    │   ├── cors.ts                # CORS headers and response helpers
    │   ├── logger.ts              # Structured logging
    │   └── rate-limiter.ts        # Rate limiting utilities
    ├── call-control/index.ts      # Call control operations (mute, hold, etc.)
    ├── call-webhook/index.ts      # Webhook for call status updates (NO JWT)
    ├── create-sample-users/index.ts # Create sample users for testing
    ├── create-user/index.ts       # Create new user accounts
    ├── fetch-emails/index.ts      # Fetch emails via IMAP
    ├── hangup-call/index.ts       # End active calls
    ├── health-check/index.ts      # System health check (NO JWT)
    ├── initiate-call/index.ts     # Start outbound calls via CCC API
    ├── manage-user-password/index.ts # Reset/delete user passwords
    ├── mark-email-read/index.ts   # Mark emails as read/unread via IMAP
    ├── security-monitor/index.ts  # Security threat monitoring (NO JWT)
    ├── send-email/index.ts        # Send emails via SMTP
    ├── setup-test-admin/index.ts  # Create test super admin (NO JWT)
    ├── test-ccc-connection/index.ts # Test CCC API connectivity
    ├── test-email-provider/index.ts # Test email provider configuration
    └── update-ccc-api-key/index.ts # Manage CCC API key rotation
```

---

## Edge Function Template

Every edge function follows this pattern:

```typescript
// @ts-ignore deno import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers - REQUIRED for browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Handle CORS preflight - ALWAYS include this
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 1. Initialize Supabase client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 2. For authenticated endpoints: Get user from JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(
      authHeader.replace("Bearer ", "")
    );

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Parse request body
    const body = await req.json();

    // 4. Your business logic here
    // ...

    // 5. Return success response
    return new Response(
      JSON.stringify({ success: true, data: {} }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("Function error:", message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
```

---

## Configuration (supabase/config.toml)

The `config.toml` file controls JWT verification for each function:

```toml
project_id = "lahchwagkhwypecmjojj"

[functions.health-check]
verify_jwt = false  # Public endpoint

[functions.call-webhook]
verify_jwt = false  # Webhook endpoint (external calls)

[functions.security-monitor]
verify_jwt = false  # Scheduled/internal endpoint

[functions.setup-test-admin]
verify_jwt = false  # One-time setup endpoint

# All other functions default to verify_jwt = true (require authentication)
```

**Rules:**
- `verify_jwt = false` → Public endpoint, no auth required
- `verify_jwt = true` (default) → Requires valid JWT in Authorization header

---

## Environment Variables

Available in all edge functions via `Deno.env.get()`:

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin service role key (full access) |
| `CALL_CENTER_API_KEY` | CCC API authentication key |

---

## Database Access Patterns

### Using Service Role (Admin Access)
```typescript
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// Full database access, bypasses RLS
const { data, error } = await supabaseAdmin
  .from("profiles")
  .select("*");
```

### Using User Context (Respects RLS)
```typescript
const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  {
    global: {
      headers: { Authorization: authHeader },
    },
  }
);

// Respects Row Level Security policies
const { data, error } = await supabaseClient
  .from("leads")
  .select("*");
```

---

## Key Database Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles (id, email, username, full_name, admin_id, ccc_phone_number, ccc_username) |
| `user_roles` | Role assignments (user_id, role: SUPER_ADMIN/TENANT_OWNER/ADMIN/MANAGER/SUPER_AGENT/AGENT) |
| `admin_settings` | Tenant-specific settings (CCC config, email settings, integration flags) |
| `general_settings` | Global settings fallback |
| `leads` | Lead records |
| `clients` | Client records (converted leads) |
| `deposits` | Deposit transactions |
| `call_history` | Call records |
| `email_credentials` | User email configurations |
| `received_emails` | Fetched email storage |

---

## Role Hierarchy

```
SUPER_ADMIN     → Full system access, can manage all tenants
TENANT_OWNER    → Tenant admin, owns a tenant organization
ADMIN           → Full tenant access
MANAGER         → Same as ADMIN
SUPER_AGENT     → Handles converted clients
AGENT           → Handles leads only
```

---

## CCC (Call Center Connect) Integration

The CCC API handles outbound calling. Configuration stored in `admin_settings`:

```typescript
// Fetch CCC configuration
const { data: settings } = await supabaseAdmin
  .from("admin_settings")
  .select("ccc_api_key, ccc_api_key_new, ccc_initiate_endpoint, ccc_end_endpoint, ccc_control_endpoint")
  .eq("admin_id", adminId)
  .single();

// Zero-downtime key rotation: try new key first, fallback to primary
const apiKey = settings.ccc_api_key_new || settings.ccc_api_key;

// Make CCC API call
const response = await fetch(settings.ccc_initiate_endpoint, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ /* call params */ }),
});
```

---

## Shared Utilities

### CORS Helper (supabase/functions/_shared/cors.ts)

```typescript
import { getCorsHeaders, createSuccessResponse, createErrorResponse } from "../_shared/cors.ts";

const origin = req.headers.get("origin");
const corsHeaders = getCorsHeaders(origin, true);

// Success response
return createSuccessResponse({ data: result }, corsHeaders);

// Error response
return createErrorResponse("Something went wrong", 500, corsHeaders);
```

---

## Common Patterns

### Check User Role
```typescript
const { data: roleData } = await supabaseAdmin
  .from("user_roles")
  .select("role")
  .eq("user_id", user.id)
  .single();

if (!["ADMIN", "SUPER_ADMIN", "MANAGER"].includes(roleData?.role)) {
  return new Response(
    JSON.stringify({ error: "Insufficient permissions" }),
    { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}
```

### Get User's Tenant (admin_id)
```typescript
const { data: profile } = await supabaseAdmin
  .from("profiles")
  .select("admin_id")
  .eq("id", user.id)
  .single();

const adminId = profile?.admin_id || user.id; // TENANT_OWNER uses own ID
```

### Rate Limiting
```typescript
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 100;

function checkRateLimit(ip: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const record = rateLimitStore.get(ip);
  
  if (!record || now > record.resetAt) {
    rateLimitStore.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW });
    return { allowed: true, remaining: RATE_LIMIT_MAX - 1 };
  }
  
  if (record.count >= RATE_LIMIT_MAX) {
    return { allowed: false, remaining: 0 };
  }
  
  record.count++;
  return { allowed: true, remaining: RATE_LIMIT_MAX - record.count };
}

---

## Creating Notifications (Multi-Tenant)

When creating notifications from edge functions, always include `admin_id` for proper tenant scoping:

```typescript
// Get user's tenant ID
const { data: profile } = await supabaseAdmin
  .from("profiles")
  .select("admin_id")
  .eq("id", user.id)
  .single();

const tenantId = profile?.admin_id || user.id;

// Create notification with tenant scope
await supabaseAdmin.from('notifications').insert({
  user_id: targetUserId,
  type: 'LEAD_ASSIGNED',  // notification_type enum
  message: 'A new lead has been assigned to you',
  admin_id: tenantId,     // REQUIRED for multi-tenant visibility
  related_entity_type: 'lead',
  related_entity_id: leadId,
  related_profile_id: assignedByUserId,  // Optional: who triggered the notification
});
```

**Notification Types:**
| Type | When to Use |
|------|-------------|
| `NEW_LEAD` | New lead created |
| `LEAD_ASSIGNED` | Lead assigned to agent |
| `CLIENT_CONVERTED` | Lead converted to client |
| `CLIENT_ASSIGNED` | Client assigned to agent |
| `WITHDRAWAL_REQUEST` | Client withdrawal request |
| `TASK_DUE` | Task reminder |
| `TICKET_CREATED` | Support ticket created |
| `CONVERSION_APPROVED` | Conversion approved |
| `CONVERSION_REJECTED` | Conversion rejected |
| `DEPOSIT_APPROVED` | Deposit approved |
| `DEPOSIT_REJECTED` | Deposit rejected |
| `DEPOSIT_SPLIT_RECEIVED` | Deposit split received |

**Archiving:**
- Notifications older than 1 month are automatically archived
- Archived notifications have `archived_at` timestamp set
- Never delete notifications - archive them instead
```

---

## Testing Edge Functions

### Via Supabase Dashboard
1. Go to Edge Functions in Supabase Dashboard
2. Select function → Logs tab
3. Use the "Invoke" button to test

### Via curl
```bash
# Public endpoint
curl -X POST https://lahchwagkhwypecmjojj.supabase.co/functions/v1/health-check

# Authenticated endpoint
curl -X POST https://lahchwagkhwypecmjojj.supabase.co/functions/v1/create-user \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "Test123!", "role": "AGENT"}'
```

---

## Deployment

Edge functions are automatically deployed when code changes are pushed. For manual deployment:

1. Update function code in `supabase/functions/[function-name]/index.ts`
2. Update `supabase/config.toml` if JWT settings change
3. Functions deploy automatically on build

---

## Security Considerations

1. **Always validate input** - Never trust user input
2. **Check permissions** - Verify user role before sensitive operations
3. **Use service role carefully** - Only when bypassing RLS is required
4. **Log security events** - Use audit_logs table for tracking
5. **Handle errors gracefully** - Don't expose internal details in error messages
6. **Rate limit public endpoints** - Prevent abuse

---

## Multi-Tenancy

This is a multi-tenant application. Key rules:

1. **Data isolation**: All data is scoped by `admin_id` (tenant ID)
2. **User-tenant mapping**: Users belong to tenants via `profiles.admin_id`
3. **Settings per tenant**: Each tenant has own `admin_settings` record
4. **SUPER_ADMIN exception**: Can see/manage all tenants

```typescript
// Filter data by tenant
const { data } = await supabaseAdmin
  .from("leads")
  .select("*")
  .eq("admin_id", userAdminId);
```

---

## Existing Functions Reference

| Function | JWT | Purpose |
|----------|-----|---------|
| `call-control` | ✅ | Mute/hold/transfer calls |
| `call-webhook` | ❌ | Receive call status updates from CCC |
| `create-sample-users` | ✅ | Generate test users |
| `create-user` | ✅ | Create new user accounts |
| `fetch-emails` | ✅ | Fetch emails via IMAP |
| `hangup-call` | ✅ | End active calls |
| `health-check` | ❌ | System health status |
| `initiate-call` | ✅ | Start outbound calls |
| `manage-user-password` | ✅ | Reset/delete passwords |
| `mark-email-read` | ✅ | Mark emails read/unread |
| `security-monitor` | ❌ | Scan for security threats |
| `send-email` | ✅ | Send emails via SMTP |
| `setup-test-admin` | ❌ | Create test super admin |
| `test-ccc-connection` | ✅ | Test CCC API connectivity |
| `test-email-provider` | ✅ | Test email provider config |
| `update-ccc-api-key` | ✅ | Manage CCC API key rotation |

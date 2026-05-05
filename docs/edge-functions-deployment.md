# Edge Functions Deployment Guide

## Deployment via Supabase Dashboard

Since you cannot install Supabase CLI, deploy each function manually:

1. Go to your Supabase project → **Edge Functions**
2. Click **"New Function"**
3. Name it exactly as shown below
4. Paste the corresponding code
5. Click **Deploy**

---

## Required Secrets

Before deploying, add these secrets in **Supabase Dashboard → Settings → Vault**:
- `CALL_CENTER_API_KEY` - Your CCC API key (optional, for call integration)

---

## Function 1: `health-check`

**JWT Required:** No (set `verify_jwt = false`)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

const startTime = Date.now();
const VERSION = '1.0.0';

async function checkDatabase() {
  const start = Date.now();
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );
    const { error } = await supabase.from('profiles').select('id').limit(1);
    const latency = Date.now() - start;
    if (error) return { status: 'fail', latency_ms: latency, message: error.message };
    return { status: 'pass', latency_ms: latency };
  } catch (error) {
    return { status: 'fail', latency_ms: Date.now() - start, message: error instanceof Error ? error.message : 'Unknown error' };
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.split('/').pop();

  if (path === 'live' || req.method === 'HEAD') {
    return new Response('OK', { status: 200, headers: { ...corsHeaders, 'Content-Type': 'text/plain' } });
  }

  if (path === 'ready') {
    const dbCheck = await checkDatabase();
    const isReady = dbCheck.status === 'pass';
    return new Response(
      JSON.stringify({ ready: isReady, checks: { database: dbCheck } }),
      { status: isReady ? 200 : 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const dbCheck = await checkDatabase();
  return new Response(
    JSON.stringify({
      status: dbCheck.status === 'pass' ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      version: VERSION,
      uptime: Math.floor((Date.now() - startTime) / 1000),
      checks: { database: dbCheck },
    }),
    { status: dbCheck.status === 'pass' ? 200 : 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
```

---

## Function 2: `create-user`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('No authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) throw new Error('Unauthorized');

    const { data: roleData } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .single();

    const hasPermission = ['SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER'].includes(roleData?.role || '');
    if (!hasPermission) throw new Error('Insufficient permissions');

    const { username, password, fullName, role, whitelistedIps } = await req.json();
    if (!username || !password || !fullName || !role) throw new Error('Missing required fields');

    // Role creation validation
    const creatorRole = roleData?.role;
    if (role === 'SUPER_ADMIN') throw new Error('SUPER_ADMIN role cannot be created');
    if (role === 'TENANT_OWNER' && creatorRole !== 'SUPER_ADMIN') throw new Error('Only SUPER_ADMIN can create TENANT_OWNER');
    if (role === 'ADMIN' && creatorRole !== 'SUPER_ADMIN') throw new Error('Only SUPER_ADMIN can create ADMIN');

    const tempEmail = `${username}@crm.internal`;

    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: tempEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, username },
    });

    if (authError) throw authError;
    if (!authData.user) throw new Error('User creation failed');

    await supabaseAdmin.from('profiles').update({ username, full_name: fullName, created_by: user.id }).eq('id', authData.user.id);
    await supabaseAdmin.from('user_roles').delete().eq('user_id', authData.user.id);
    await supabaseAdmin.from('user_roles').insert({ user_id: authData.user.id, role });

    if (whitelistedIps?.trim()) {
      const ips = whitelistedIps.split(',').map((ip: string) => ip.trim()).filter((ip: string) => ip);
      if (ips.length > 0) {
        await supabaseAdmin.from('ip_whitelist').insert(ips.map((ip: string) => ({ user_id: authData.user.id, ip_address: ip, created_by: user.id })));
      }
    }

    await supabaseAdmin.from('audit_logs').insert({
      user_id: user.id,
      action_type: 'user_created',
      entity_type: 'user',
      entity_id: authData.user.id,
      details: { username, full_name: fullName, role },
    });

    return new Response(
      JSON.stringify({ success: true, user: { id: authData.user.id, email: tempEmail, username, fullName, role } }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
```

---

## Function 3: `manage-user-password`

**JWT Required:** Yes

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) throw new Error('Unauthorized');

    const { data: roles } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .in('role', ['SUPER_ADMIN', 'ADMIN', 'MANAGER']);

    if (!roles || roles.length === 0) throw new Error('Unauthorized: ADMIN role required');

    const { action, userId, newPassword, force } = await req.json();

    if (action === 'delete-user') {
      if (!userId) throw new Error('Missing userId');

      const { count: clientsCount } = await supabaseAdmin.from('clients').select('id', { count: 'exact', head: true }).eq('assigned_to', userId);
      const { count: leadsCount } = await supabaseAdmin.from('leads').select('id', { count: 'exact', head: true }).eq('assigned_to', userId);
      const totalAssignments = (clientsCount ?? 0) + (leadsCount ?? 0);

      if (totalAssignments > 0 && !force) {
        return new Response(JSON.stringify({ needsConfirmation: true, assignedClientsCount: clientsCount ?? 0, assignedLeadsCount: leadsCount ?? 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      if (force && totalAssignments > 0) {
        await supabaseAdmin.from('clients').update({ assigned_to: null }).eq('assigned_to', userId);
        await supabaseAdmin.from('leads').update({ assigned_to: null }).eq('assigned_to', userId);
      }

      await supabaseAdmin.auth.admin.deleteUser(userId);
      await supabaseAdmin.from('user_roles').delete().eq('user_id', userId);
      await supabaseAdmin.from('user_permissions').delete().eq('user_id', userId);
      await supabaseAdmin.from('ip_whitelist').delete().eq('user_id', userId);
      await supabaseAdmin.from('profiles').delete().eq('id', userId);

      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (action === 'update-password') {
      if (!userId || !newPassword) throw new Error('Missing userId or newPassword');
      await supabaseAdmin.auth.admin.updateUserById(userId, { password: newPassword });
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    throw new Error('Invalid action');
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
  }
});
```

---

## Function 4: `initiate-call`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.84.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { phone, leadId, clientId, userId } = await req.json();
    if (!phone || !userId) {
      return new Response(JSON.stringify({ error: 'Phone and userId required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: userProfile } = await supabase.from('profiles').select('admin_id').eq('id', userId).single();
    const tenantId = userProfile?.admin_id || userId;

    const { data: settings } = await supabase.from('admin_settings').select('ccc_api_key, ccc_initiate_endpoint').eq('admin_id', tenantId).single();
    if (!settings?.ccc_api_key) {
      return new Response(JSON.stringify({ error: 'CCC API key not configured' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: profile } = await supabase.from('profiles').select('ccc_username, email').eq('id', userId).single();
    if (!profile?.ccc_username) {
      return new Response(JSON.stringify({ error: 'CCC username not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const cleanPhone = phone.replace(/[^\d]/g, '');
    const cccUrl = settings.ccc_initiate_endpoint || 'https://ccc.mmdsmart.com/api/call/';

    const { data: callRecord } = await supabase.from('call_history').insert({
      user_id: userId, lead_id: leadId || null, client_id: clientId || null,
      phone_number: cleanPhone, agent_email: profile.email, status: 'initiating',
    }).select().single();

    const response = await fetch(cccUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${settings.ccc_api_key}` },
      body: JSON.stringify({ phone: cleanPhone, agent_id: profile.ccc_username }),
    });

    const responseText = await response.text();
    let callId = responseText.trim();

    if (!response.ok) {
      if (callRecord) await supabase.from('call_history').update({ status: 'failed', error_message: responseText }).eq('id', callRecord.id);
      return new Response(JSON.stringify({ error: 'Failed to initiate call', details: responseText }), { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (callRecord) await supabase.from('call_history').update({ status: 'initiated', call_id: callId }).eq('id', callRecord.id);

    return new Response(JSON.stringify({ success: true, callId, message: 'Call initiated successfully' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 5: `hangup-call`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { call_id } = await req.json();
    if (!call_id) {
      return new Response(JSON.stringify({ error: 'call_id is required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: callRecord } = await supabase.from('call_history').select('admin_id').eq('call_id', call_id).single();
    const tenantId = callRecord?.admin_id;

    let settings;
    if (tenantId) {
      const { data } = await supabase.from('admin_settings').select('ccc_api_key, ccc_end_endpoint').eq('admin_id', tenantId).single();
      settings = data;
    }
    if (!settings) {
      const { data } = await supabase.from('admin_settings').select('ccc_api_key, ccc_end_endpoint').limit(1).single();
      settings = data;
    }

    if (!settings?.ccc_api_key) {
      return new Response(JSON.stringify({ error: 'CCC API key not configured' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const controlUrl = settings.ccc_end_endpoint || 'https://ccc.mmdsmart.com/api/ctc/end';

    const hangupResponse = await fetch(controlUrl, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${settings.ccc_api_key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ call_id }),
    });

    await supabase.from('call_history').update({ status: 'completed' }).eq('call_id', call_id);

    return new Response(JSON.stringify({ success: true, message: 'Call ended successfully' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 6: `call-webhook`

**JWT Required:** No (set `verify_jwt = false`)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.84.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const callId = payload.call_id || payload.id;
    const callStatus = payload.status || payload.call_status;
    const duration = payload.duration || null;

    if (!callId) {
      return new Response(JSON.stringify({ error: 'Missing call_id' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: existingCall, error: findError } = await supabase.from('call_history').select('*').eq('call_id', callId).single();
    if (findError || !existingCall) {
      return new Response(JSON.stringify({ error: 'Call record not found' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    let mappedStatus = callStatus;
    if (callStatus) {
      const sl = callStatus.toLowerCase();
      if (sl.includes('answer')) mappedStatus = 'answered';
      else if (sl.includes('busy')) mappedStatus = 'busy';
      else if (sl.includes('fail')) mappedStatus = 'failed';
      else if (sl.includes('end') || sl.includes('complete')) mappedStatus = 'completed';
      else if (sl.includes('ring')) mappedStatus = 'ringing';
    }

    await supabase.from('call_history').update({ status: mappedStatus, duration: duration ? parseInt(duration, 10) : null }).eq('id', existingCall.id);

    return new Response(JSON.stringify({ success: true, call_id: callId, new_status: mappedStatus }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 7: `security-monitor`

**JWT Required:** No (set `verify_jwt = false`, scheduled via cron)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    const now = new Date();
    const fifteenMinutesAgo = new Date(now.getTime() - 15 * 60 * 1000);

    // Check for failed login attempts
    const { data: failedLogins } = await supabase
      .from('auth_attempts')
      .select('ip_address, user_email')
      .eq('success', false)
      .gte('created_at', fifteenMinutesAgo.toISOString());

    if (failedLogins) {
      const ipCounts = new Map();
      for (const attempt of failedLogins) {
        if (!ipCounts.has(attempt.ip_address)) {
          ipCounts.set(attempt.ip_address, { count: 0, emails: new Set() });
        }
        const entry = ipCounts.get(attempt.ip_address);
        entry.count++;
        if (attempt.user_email) entry.emails.add(attempt.user_email);
      }

      for (const [ip, data] of ipCounts) {
        if (data.count >= 5) {
          const { data: adminRoles } = await supabase.from('user_roles').select('user_id').eq('role', 'ADMIN');
          if (adminRoles) {
            for (const admin of adminRoles) {
              await supabase.from('notifications').insert({
                user_id: admin.user_id,
                type: 'TICKET_CREATED',
                message: `Security Alert: ${data.count} failed login attempts from IP ${ip}`,
                related_entity_type: 'security_alert',
              });
            }
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 8: `test-ccc-connection`

**JWT Required:** Yes

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.84.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: roles } = await supabase.from('user_roles').select('role').eq('user_id', user.id);
    if (!roles?.some(r => r.role === 'ADMIN')) {
      return new Response(JSON.stringify({ success: false, error: 'Admin required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: profile } = await supabase.from('profiles').select('admin_id').eq('id', user.id).single();
    const tenantId = profile?.admin_id || user.id;

    const serviceClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    const { data: settings } = await serviceClient.from('admin_settings').select('ccc_api_key, ccc_initiate_endpoint').eq('admin_id', tenantId).single();

    if (!settings?.ccc_api_key) {
      return new Response(JSON.stringify({ success: false, error: 'API key not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const endpoint = settings.ccc_initiate_endpoint || 'https://ccc.mmdsmart.com/api/call/';
    const testResponse = await fetch(endpoint, { method: 'OPTIONS', headers: { 'Authorization': `Bearer ${settings.ccc_api_key}` } });

    return new Response(JSON.stringify({ success: true, message: 'Connection successful', statusCode: testResponse.status }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 9: `update-ccc-api-key`

**JWT Required:** Yes

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.84.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const anonClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await anonClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: roles } = await supabase.from('user_roles').select('role').eq('user_id', user.id);
    const hasAccess = roles?.some(r => ['SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER'].includes(r.role));
    if (!hasAccess) {
      return new Response(JSON.stringify({ success: false, error: 'Admin required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { apiKey, tenantId, action } = await req.json();
    const targetTenantId = tenantId || user.id;

    if (action === 'set') {
      await supabase.from('admin_settings').update({ ccc_api_key: apiKey, updated_at: new Date().toISOString() }).eq('admin_id', targetTenantId);
      return new Response(JSON.stringify({ success: true, message: 'API key updated' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (action === 'check_status') {
      const { data: settings } = await supabase.from('admin_settings').select('ccc_api_key, ccc_api_key_new').eq('admin_id', targetTenantId).single();
      return new Response(JSON.stringify({ success: true, hasApiKey: !!settings?.ccc_api_key, rotationPending: !!settings?.ccc_api_key_new }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ success: false, error: 'Invalid action' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 10: `create-sample-users`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Missing authorization header' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const token = authHeader.replace('Bearer ', '');
    const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: roles } = await supabaseAdmin.from('user_roles').select('role').eq('user_id', user.id).eq('role', 'ADMIN');
    if (!roles || roles.length === 0) {
      return new Response(JSON.stringify({ success: false, error: 'ADMIN role required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const sampleUsers = [
      { email: 'agent1@forexcrm.com', password: 'Agent123!@#', full_name: 'John Smith', role: 'AGENT' },
      { email: 'agent2@forexcrm.com', password: 'Agent123!@#', full_name: 'Sarah Johnson', role: 'AGENT' },
      { email: 'agent3@forexcrm.com', password: 'Agent123!@#', full_name: 'Michael Chen', role: 'AGENT' },
      { email: 'superagent1@forexcrm.com', password: 'SuperAgent123!@#', full_name: 'Emily Williams', role: 'SUPER_AGENT' },
      { email: 'superagent2@forexcrm.com', password: 'SuperAgent123!@#', full_name: 'David Martinez', role: 'SUPER_AGENT' },
    ];

    const createdUsers = [];
    for (const userData of sampleUsers) {
      const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
      if (existingUsers?.users.some(u => u.email === userData.email)) continue;

      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: userData.email, password: userData.password, email_confirm: true,
        user_metadata: { full_name: userData.full_name },
      });

      if (authError || !authData.user) continue;

      await supabaseAdmin.from('user_roles').insert({ user_id: authData.user.id, role: userData.role });
      createdUsers.push({ email: userData.email, full_name: userData.full_name, role: userData.role });
    }

    return new Response(JSON.stringify({ success: true, message: `Created ${createdUsers.length} users`, users: createdUsers }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 11: `send-email`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', { auth: { persistSession: false } });

    const authHeader = req.headers.get('Authorization');
    const token = authHeader?.replace('Bearer ', '').trim();
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { to, subject, text, html, cc, bcc, isManualRecipient } = await req.json();

    if (!to || !subject || (!text && !html)) {
      return new Response(JSON.stringify({ error: 'Missing required fields: to, subject, and text or html' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: settings } = await supabaseClient.from('general_settings').select('integration_providers, email_integration_active').single();
    if (!settings?.email_integration_active) {
      return new Response(JSON.stringify({ error: 'Email integration is not active' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: emailCreds } = await supabaseClient.from('email_credentials').select('email_address, email_password').eq('user_id', user.id).single();
    if (!emailCreds?.email_address || !emailCreds?.email_password) {
      return new Response(JSON.stringify({ error: 'Email credentials not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: profile } = await supabaseClient.from('profiles').select('full_name').eq('id', user.id).single();

    const providers = settings.integration_providers as any;
    const emailProviders = providers?.email || {};
    const activeProviderEntry = Object.entries(emailProviders).find(([, config]: [string, any]) => config?.active);

    if (!activeProviderEntry) {
      return new Response(JSON.stringify({ error: 'No active email provider configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const [providerId, providerConfig] = activeProviderEntry;
    const userCredentials = { email: emailCreds.email_address, password: emailCreds.email_password, name: profile?.full_name || 'User' };

    let messageId = 'email-' + Date.now();

    if (providerId === 'smtp') {
      const { SMTPClient } = await import('https://deno.land/x/denomailer@1.6.0/mod.ts');
      const client = new SMTPClient({
        connection: {
          hostname: (providerConfig as any).host,
          port: parseInt((providerConfig as any).port) || 465,
          tls: (providerConfig as any).tls !== false,
          auth: { username: userCredentials.email, password: userCredentials.password },
        },
      });
      await client.send({
        from: `${userCredentials.name} <${userCredentials.email}>`,
        to: Array.isArray(to) ? to.join(', ') : to,
        cc: cc ? (Array.isArray(cc) ? cc.join(', ') : cc) : undefined,
        bcc: bcc ? (Array.isArray(bcc) ? bcc.join(', ') : bcc) : undefined,
        subject, content: text || '', html,
      });
      await client.close();
      messageId = 'smtp-' + Date.now();
    }

    await supabaseClient.from('sent_emails').insert({
      sender_id: user.id, recipient_email: Array.isArray(to) ? to[0] : to,
      cc: Array.isArray(cc) ? cc : (cc ? [cc] : null),
      bcc: Array.isArray(bcc) ? bcc : (bcc ? [bcc] : null),
      subject, body_text: text, body_html: html, status: 'sent',
      provider_message_id: messageId, is_manual_recipient: isManualRecipient || false,
    });

    return new Response(JSON.stringify({ success: true, messageId }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error: any) {
    console.error('Error sending email:', error);
    return new Response(JSON.stringify({ error: error.message || 'Failed to send email' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 12: `fetch-emails`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: req.headers.get('Authorization')! } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { mailbox = 'INBOX', limit = 50, unreadOnly = false } = await req.json();

    const { data: settings } = await supabaseClient.from('general_settings').select('integration_providers, email_integration_active').single();
    if (!settings?.email_integration_active) {
      return new Response(JSON.stringify({ error: 'Email integration is not active' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: emailCreds } = await supabaseClient.from('email_credentials').select('email_address, email_password').eq('user_id', user.id).single();
    if (!emailCreds?.email_address || !emailCreds?.email_password) {
      return new Response(JSON.stringify({ error: 'Email credentials not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const providers = settings.integration_providers as any;
    const activeProvider = Object.entries(providers || {}).find(([category]: [string, any]) => category.startsWith('email_'));

    if (!activeProvider) {
      return new Response(JSON.stringify({ error: 'No active email provider configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const [, providerConfig] = activeProvider;
    const config = providerConfig as any;

    if (!config.host) {
      return new Response(JSON.stringify({ error: 'IMAP host not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { ImapClient } = await import('https://deno.land/x/imap_client@0.7.0/mod.ts');
    const client = new ImapClient({ hostname: config.host, port: 993, logLevel: 'DEBUG' });

    await client.connect({ username: emailCreds.email_address, password: emailCreds.email_password });
    await client.select(mailbox);

    const searchCriteria = unreadOnly ? ['UNSEEN'] : ['ALL'];
    const messageIds = await client.search(searchCriteria);
    const idsToFetch = messageIds.slice(-limit);

    const emails = [];
    for (const id of idsToFetch) {
      try {
        const message = await client.fetch(id, { envelope: true, bodyStructure: true, body: true });
        emails.push({
          id, uid: message.uid,
          subject: message.envelope?.subject || '(No Subject)',
          from: message.envelope?.from?.[0] || {},
          to: message.envelope?.to || [],
          date: message.envelope?.date || new Date().toISOString(),
          flags: message.flags || [],
          read: message.flags?.includes('\\Seen') || false,
        });
      } catch (msgError) {
        console.error(`Error fetching message ${id}:`, msgError);
      }
    }

    await client.close();

    // Store emails in database
    for (const email of emails) {
      const fromAddress = email.from?.address || email.from?.email || 'unknown@example.com';
      const messageId = email.uid?.toString() || `${Date.now()}-${Math.random()}`;

      await supabaseClient.from('received_emails').insert({
        user_id: user.id, sender_email: fromAddress, sender_name: email.from?.name || null,
        recipient_email: emailCreds.email_address, subject: email.subject || '(No Subject)',
        received_at: email.date || new Date().toISOString(), is_read: email.read || false, message_id: messageId,
      }).then(() => {}).catch(() => {});
    }

    return new Response(JSON.stringify({ success: true, emails, count: emails.length }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error: any) {
    console.error('Error fetching emails:', error);
    return new Response(JSON.stringify({ error: error.message || 'Failed to fetch emails' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 13: `test-email-provider`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const token = authHeader.replace('Bearer ', '');
    let userId: string | null = null;
    try {
      const payload = JSON.parse(atob(token.split('.')[1] || ''));
      userId = payload.sub ?? null;
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid auth token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    const { providerId, config, testEmail } = await req.json();
    console.log(`Testing email provider: ${providerId}`);

    const { data: emailCreds } = await supabaseClient.from('email_credentials').select('email_address, email_password').eq('user_id', userId).single();
    if (!emailCreds?.email_address || !emailCreds?.email_password) {
      return new Response(JSON.stringify({ error: 'Email credentials not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: profile } = await supabaseClient.from('profiles').select('full_name').eq('id', userId).single();
    const userCredentials = { email: emailCreds.email_address, password: emailCreds.email_password, name: profile?.full_name || 'User' };

    if (providerId === 'smtp') {
      if (!config?.host || !config?.port) {
        throw new Error('SMTP configuration is incomplete');
      }
      const { SMTPClient } = await import('https://deno.land/x/denomailer@1.6.0/mod.ts');
      const client = new SMTPClient({
        connection: {
          hostname: config.host, port: parseInt(config.port) || 465, tls: config.tls !== false,
          auth: { username: userCredentials.email, password: userCredentials.password },
        },
      });
      await client.send({
        from: `${userCredentials.name} <${userCredentials.email}>`, to: testEmail,
        subject: 'SMTP Test Email', content: 'This is a test email from your SMTP configuration.',
        html: '<p>This is a test email from your SMTP configuration.</p>',
      });
      await client.close();
      return new Response(JSON.stringify({ success: true, message: 'SMTP test email sent successfully!' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (providerId === 'sendgrid') {
      const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${config.api_key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          personalizations: [{ to: [{ email: testEmail }] }],
          from: { email: userCredentials.email, name: userCredentials.name },
          subject: 'SendGrid Test Email',
          content: [{ type: 'text/plain', value: 'This is a test email from your SendGrid configuration.' }],
        }),
      });
      if (!response.ok) throw new Error(`SendGrid test failed: ${await response.text()}`);
      return new Response(JSON.stringify({ success: true, message: 'SendGrid test email sent successfully!' }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    throw new Error(`Unsupported provider: ${providerId}`);
  } catch (error: any) {
    console.error('Error testing email provider:', error);
    return new Response(JSON.stringify({ error: error.message || 'Failed to test email provider' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## Function 14: `mark-email-read`

**JWT Required:** Yes

```typescript
import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: req.headers.get('Authorization')! } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { messageId, mailbox = 'INBOX', markAsRead } = await req.json();
    if (!messageId) {
      return new Response(JSON.stringify({ error: 'Message ID is required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: settings } = await supabaseClient.from('general_settings').select('integration_providers').single();
    const providers = settings?.integration_providers as any;
    const activeProvider = Object.entries(providers || {}).find(([category]: [string, any]) => category.startsWith('email_'));

    if (!activeProvider) {
      return new Response(JSON.stringify({ error: 'No active email provider configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const [, providerConfig] = activeProvider;
    const config = providerConfig as any;

    const { data: emailCreds } = await supabaseClient.from('email_credentials').select('email_address, email_password').eq('user_id', user.id).single();
    if (!emailCreds) {
      return new Response(JSON.stringify({ error: 'Email credentials not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    if (!config.host) {
      return new Response(JSON.stringify({ error: 'IMAP host not configured' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { ImapClient } = await import('https://deno.land/x/imap_client@0.7.0/mod.ts');
    const client = new ImapClient({ hostname: config.host, port: 993, logLevel: 'DEBUG' });

    await client.connect({ username: emailCreds.email_address, password: emailCreds.email_password });
    await client.select(mailbox);

    if (markAsRead) {
      await client.addFlags(messageId, ['\\Seen']);
    } else {
      await client.removeFlags(messageId, ['\\Seen']);
    }

    await client.close();

    return new Response(JSON.stringify({ success: true, message: `Email ${markAsRead ? 'marked as read' : 'marked as unread'}` }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error: any) {
    console.error('Error marking email:', error);
    return new Response(JSON.stringify({ error: error.message || 'Failed to mark email' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

---

## config.toml Settings

After deploying, configure JWT verification in the Supabase Dashboard:

**Functions that need `verify_jwt = false`:**
- `health-check`
- `call-webhook`
- `security-monitor`

All other functions require JWT authentication (default).

---

## Complete Functions Summary

| # | Function Name | JWT Required | Purpose |
|---|---------------|--------------|---------|
| 1 | `health-check` | No | System health monitoring |
| 2 | `create-user` | Yes | Create new users (admin only) |
| 3 | `manage-user-password` | Yes | Reset passwords, delete users |
| 4 | `initiate-call` | Yes | Start CCC calls |
| 5 | `hangup-call` | Yes | End CCC calls |
| 6 | `call-webhook` | No | Receive CCC status updates |
| 7 | `security-monitor` | No | Scheduled security checks |
| 8 | `test-ccc-connection` | Yes | Test CCC API connection |
| 9 | `update-ccc-api-key` | Yes | Manage CCC API keys |
| 10 | `create-sample-users` | Yes | Create demo users |
| 11 | `send-email` | Yes | Send emails via SMTP |
| 12 | `fetch-emails` | Yes | Fetch emails via IMAP |
| 13 | `test-email-provider` | Yes | Test email provider |
| 14 | `mark-email-read` | Yes | Mark emails read/unread |

---

## Testing

After deployment, test each function:

```bash
# Health check (no auth required)
curl https://YOUR_PROJECT_REF.supabase.co/functions/v1/health-check

# Other functions (auth required)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/test-ccc-connection
```

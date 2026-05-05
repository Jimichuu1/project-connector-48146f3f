# Edge Functions Complete Deployment Guide

## JWT Verification Summary

| Function | JWT Required | Dashboard Setting |
|----------|-------------|-------------------|
| `call-webhook` | **OFF** | Turn OFF "Verify JWT" |
| `health-check` | **OFF** | Turn OFF "Verify JWT" |
| `security-monitor` | **OFF** | Turn OFF "Verify JWT" |
| All others | **ON** | Leave default (ON) |

---

## 1. call-webhook (JWT: OFF)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.84.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
};

const rateLimitStore = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW = 60 * 1000;
const RATE_LIMIT_MAX = 100;

function checkRateLimit(ip: string): { allowed: boolean; remaining: number; retryAfter?: number } {
  const now = Date.now();
  let entry = rateLimitStore.get(ip);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_LIMIT_WINDOW };
    rateLimitStore.set(ip, entry);
  }
  if (entry.count >= RATE_LIMIT_MAX) {
    return { allowed: false, remaining: 0, retryAfter: Math.ceil((entry.resetAt - now) / 1000) };
  }
  entry.count++;
  return { allowed: true, remaining: RATE_LIMIT_MAX - entry.count };
}

function getClientIp(req: Request): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
         req.headers.get('x-real-ip') ||
         req.headers.get('cf-connecting-ip') ||
         'unknown';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const clientIp = getClientIp(req);
  const rateLimit = checkRateLimit(clientIp);
  
  if (!rateLimit.allowed) {
    return new Response(JSON.stringify({ error: 'Too many requests', retryAfter: rateLimit.retryAfter }), {
      status: 429,
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': String(rateLimit.retryAfter) },
    });
  }

  try {
    const payload = await req.json();
    console.log(`[WEBHOOK_RECEIVED] IP: ${clientIp}, Payload: ${JSON.stringify(payload)}`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const callId = payload.call_id || payload.id;
    const callStatus = payload.status || payload.call_status;
    const duration = payload.duration || null;
    const errorMessage = payload.error_message || payload.error;

    if (!callId) {
      return new Response(JSON.stringify({ error: 'Missing call_id in payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: existingCall, error: findError } = await supabase
      .from('call_history')
      .select('*')
      .eq('call_id', callId)
      .single();

    if (findError || !existingCall) {
      return new Response(JSON.stringify({ error: 'Call record not found', call_id: callId }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let mappedStatus = callStatus;
    if (callStatus) {
      const statusLower = callStatus.toLowerCase();
      if (statusLower.includes('answer') || statusLower.includes('connect')) mappedStatus = 'answered';
      else if (statusLower.includes('busy')) mappedStatus = 'busy';
      else if (statusLower.includes('fail') || statusLower.includes('error')) mappedStatus = 'failed';
      else if (statusLower.includes('end') || statusLower.includes('complete')) mappedStatus = 'completed';
      else if (statusLower.includes('ring')) mappedStatus = 'ringing';
    }

    const updateData: Record<string, unknown> = { status: mappedStatus };
    if (duration !== null && duration !== undefined) updateData.duration = parseInt(duration, 10) || null;
    if (errorMessage) updateData.error_message = errorMessage;

    const { error: updateError } = await supabase.from('call_history').update(updateData).eq('id', existingCall.id);

    if (updateError) {
      return new Response(JSON.stringify({ error: 'Failed to update call record' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ success: true, message: 'Call status updated', call_id: callId, new_status: mappedStatus }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[EXCEPTION] Error in call-webhook function:', error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

---

## 2. health-check (JWT: OFF)

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
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '');
    const { error } = await supabase.from('profiles').select('id').limit(1);
    const latency = Date.now() - start;
    if (error) return { status: 'fail', latency_ms: latency, message: error.message };
    return { status: 'pass', latency_ms: latency };
  } catch (error) {
    return { status: 'fail', latency_ms: Date.now() - start, message: error instanceof Error ? error.message : 'Unknown error' };
  }
}

async function checkAuth() {
  const start = Date.now();
  try {
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '');
    const { error } = await supabase.auth.getSession();
    const latency = Date.now() - start;
    if (error) return { status: 'fail', latency_ms: latency, message: error.message };
    return { status: 'pass', latency_ms: latency };
  } catch (error) {
    return { status: 'fail', latency_ms: Date.now() - start, message: error instanceof Error ? error.message : 'Unknown error' };
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

  const url = new URL(req.url);
  const path = url.pathname.split('/').pop();

  if (path === 'live' || req.method === 'HEAD') {
    return new Response('OK', { status: 200, headers: { ...corsHeaders, 'Content-Type': 'text/plain' } });
  }

  if (path === 'ready') {
    const dbCheck = await checkDatabase();
    const isReady = dbCheck.status === 'pass';
    return new Response(JSON.stringify({ ready: isReady, checks: { database: dbCheck } }), {
      status: isReady ? 200 : 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const [dbCheck, authCheck] = await Promise.all([checkDatabase(), checkAuth()]);
    const allPassing = dbCheck.status === 'pass' && authCheck.status === 'pass';
    const overallStatus = allPassing ? 'healthy' : 'unhealthy';

    return new Response(JSON.stringify({
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: VERSION,
      uptime: Math.floor((Date.now() - startTime) / 1000),
      checks: { database: dbCheck, auth: authCheck },
    }, null, 2), {
      status: allPassing ? 200 : 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ status: 'unhealthy', error: error instanceof Error ? error.message : 'Unknown error' }), {
      status: 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

---

## 3. security-monitor (JWT: OFF)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    const now = new Date();
    const fifteenMinutesAgo = new Date(now.getTime() - 15 * 60 * 1000);
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    // Check failed logins
    const { data: failedLogins } = await supabaseClient.from('auth_attempts').select('ip_address, user_email').eq('success', false).gte('created_at', fifteenMinutesAgo.toISOString());
    if (failedLogins) {
      const ipCounts = new Map();
      for (const attempt of failedLogins) {
        if (!ipCounts.has(attempt.ip_address)) ipCounts.set(attempt.ip_address, { count: 0, emails: new Set() });
        const entry = ipCounts.get(attempt.ip_address);
        entry.count++;
        if (attempt.user_email) entry.emails.add(attempt.user_email);
      }
      for (const [ip, data] of ipCounts) {
        if (data.count >= 5) {
          const { data: adminRoles } = await supabaseClient.from('user_roles').select('user_id').eq('role', 'ADMIN');
          if (adminRoles) {
            for (const admin of adminRoles) {
              await supabaseClient.from('notifications').insert({
                user_id: admin.user_id,
                type: 'TICKET_CREATED',
                message: `Security Alert: ${data.count} failed login attempts from IP ${ip}`,
                related_entity_type: 'security_alert',
                related_entity_id: ip,
              });
            }
          }
        }
      }
    }

    // Check unusual access patterns
    const { data: recentSessions } = await supabaseClient.from('user_sessions').select('ip_address, user_id').eq('is_active', true).gte('created_at', oneHourAgo.toISOString());
    if (recentSessions) {
      const sessionsByIp = new Map();
      for (const session of recentSessions) {
        if (!session.ip_address) continue;
        if (!sessionsByIp.has(session.ip_address)) sessionsByIp.set(session.ip_address, new Set());
        sessionsByIp.get(session.ip_address).add(session.user_id);
      }
      for (const [ip, userIds] of sessionsByIp) {
        if (userIds.size >= 3) {
          const { data: adminRoles } = await supabaseClient.from('user_roles').select('user_id').eq('role', 'ADMIN');
          if (adminRoles) {
            for (const admin of adminRoles) {
              await supabaseClient.from('notifications').insert({
                user_id: admin.user_id,
                type: 'TICKET_CREATED',
                message: `Security Alert: ${userIds.size} users from IP ${ip}`,
                related_entity_type: 'security_alert',
                related_entity_id: ip,
              });
            }
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true, message: 'Security monitoring completed' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

---

## 4. call-control (JWT: ON)

See the full code in the project at `supabase/functions/call-control/index.ts`

---

## 5. create-sample-users (JWT: ON)

See the full code in the project at `supabase/functions/create-sample-users/index.ts`

---

## 6. create-user (JWT: ON)

See the full code in the project at `supabase/functions/create-user/index.ts`

---

## 7. fetch-emails (JWT: ON)

See the full code in the project at `supabase/functions/fetch-emails/index.ts`

---

## 8. hangup-call (JWT: ON)

See the full code in the project at `supabase/functions/hangup-call/index.ts`

---

## 9. initiate-call (JWT: ON)

See the full code in the project at `supabase/functions/initiate-call/index.ts`

---

## 10. manage-user-password (JWT: ON)

See the full code in the project at `supabase/functions/manage-user-password/index.ts`

---

## 11. mark-email-read (JWT: ON)

See the full code in the project at `supabase/functions/mark-email-read/index.ts`

---

## 12. send-email (JWT: ON)

See the full code in the project at `supabase/functions/send-email/index.ts`

---

## 13. test-ccc-connection (JWT: ON)

See the full code in the project at `supabase/functions/test-ccc-connection/index.ts`

---

## 14. test-email-provider (JWT: ON)

See the full code in the project at `supabase/functions/test-email-provider/index.ts`

---

## 15. update-ccc-api-key (JWT: ON)

See the full code in the project at `supabase/functions/update-ccc-api-key/index.ts`

---

## Deployment Instructions

### For Supabase Dashboard Manual Deployment:

1. Go to **Edge Functions** in Supabase Dashboard
2. Click **New Function** or select existing function
3. Paste the code for each function
4. For `call-webhook`, `health-check`, and `security-monitor`:
   - Find the JWT verification toggle/setting
   - **Turn OFF** "Verify JWT" or "Verify JWT with legacy secret"
5. For all other functions:
   - Leave JWT verification **ON** (default)
6. Click **Deploy**

### Required Secrets:

Make sure these secrets are configured in Supabase:
- `SUPABASE_URL` (auto-configured)
- `SUPABASE_ANON_KEY` (auto-configured)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-configured)
- `CALL_CENTER_API_KEY` (if using CCC integration)

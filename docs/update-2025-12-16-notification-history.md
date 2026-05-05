# Notification History & Archiving System

**Date:** 2025-12-16  
**Type:** Feature Addition  
**Impact:** Medium  

---

## Summary

Added a comprehensive notification history system with archiving support. Users can now view all their notifications through a dedicated history page, with notifications automatically archived (not deleted) after 1 month.

---

## Database Changes

### New Column: `archived_at`

Added to `public.notifications` table:

```sql
ALTER TABLE public.notifications 
ADD COLUMN archived_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
```

**Logic:**
- `archived_at = NULL` → Recent notification (within last 1 month)
- `archived_at = timestamp` → Archived notification

### New Indexes

```sql
-- Index for archived notifications queries
CREATE INDEX idx_notifications_archived 
ON public.notifications(archived_at) 
WHERE archived_at IS NOT NULL;

-- Index for recent notifications queries  
CREATE INDEX idx_notifications_recent 
ON public.notifications(user_id, created_at DESC) 
WHERE archived_at IS NULL;
```

### Archive Function

```sql
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

---

## Frontend Changes

### New Page: `/notifications`

**File:** `src/pages/NotificationHistory.tsx`

Features:
- **Three tabs:** Recent, Unread, Archived
- **Grouped by date:** Today, Yesterday, or full date
- **Mark as read:** Individual and bulk operations
- **Notification type icons:** Custom icons for each notification type
- **Archived badge:** Visual indicator for archived notifications
- **Loading states:** Skeleton loaders during data fetch
- **Empty states:** Contextual messages for each tab

### Updated: NotificationBell Component

**File:** `src/components/notifications/NotificationBell.tsx`

- Added "See all Notifications" button at bottom of popover
- Navigates to `/notifications` and closes popover

### New Route

**File:** `src/App.tsx`

```typescript
<Route path="/notifications" element={<NotificationHistory />} />
```

---

## Notification Types

Updated `notification_type` enum includes:

| Type | Icon | Description |
|------|------|-------------|
| `NEW_LEAD` | 🆕 | New lead created |
| `LEAD_ASSIGNED` | 📋 | Lead assigned to agent |
| `CLIENT_CONVERTED` | 🎉 | Lead converted to client |
| `CLIENT_ASSIGNED` | 👤 | Client assigned to agent |
| `WITHDRAWAL_REQUEST` | 💰 | Client withdrawal request |
| `TASK_DUE` | ⏰ | Task due reminder |
| `TICKET_CREATED` | 🎫 | Support ticket created |
| `CONVERSION_APPROVED` | ✅ | Conversion request approved |
| `CONVERSION_REJECTED` | ❌ | Conversion request rejected |
| `DEPOSIT_APPROVED` | ✅💰 | Deposit approved |
| `DEPOSIT_REJECTED` | ❌💰 | Deposit rejected |
| `DEPOSIT_SPLIT_RECEIVED` | 🤝💰 | Deposit split received |

---

## Query Patterns

### Fetch Recent Notifications

```typescript
const { data } = await supabase
  .from('notifications')
  .select('*')
  .eq('user_id', user.id)
  .is('archived_at', null)
  .gte('created_at', oneMonthAgo.toISOString())
  .order('created_at', { ascending: false });
```

### Fetch Archived Notifications

```typescript
const { data } = await supabase
  .from('notifications')
  .select('*')
  .eq('user_id', user.id)
  .not('archived_at', 'is', null)
  .order('created_at', { ascending: false })
  .limit(200);
```

### Mark as Read

```typescript
await supabase
  .from('notifications')
  .update({ is_read: true })
  .eq('id', notificationId);
```

### Mark All as Read

```typescript
await supabase
  .from('notifications')
  .update({ is_read: true })
  .eq('user_id', user.id)
  .eq('is_read', false);
```

---

## React Query Keys

| Key | Purpose |
|-----|---------|
| `['notification-history-recent', user.id]` | Recent notifications (last 1 month) |
| `['notification-history-archived', user.id]` | Archived notifications |
| `['notifications']` | Bell popover notifications |

**Invalidation:** When marking as read, invalidate all three keys for consistency.

---

## Multi-Tenant Support

All notification inserts now include `admin_id` for tenant-scoped visibility:

```typescript
await supabase.from('notifications').insert({
  user_id: targetUserId,
  type: 'LEAD_ASSIGNED',
  message: 'Lead has been assigned to you',
  admin_id: effectiveTenantId || null,  // Required for multi-tenant
  related_entity_type: 'lead',
  related_entity_id: leadId,
});
```

---

## Migration File

**Path:** `supabase/migrations/20251216192256_archive_notifications.sql`

---

## Testing Checklist

- [ ] Navigate to `/notifications` page
- [ ] Verify Recent tab shows last 1 month notifications
- [ ] Verify Unread tab filters correctly
- [ ] Verify Archived tab shows older notifications
- [ ] Mark individual notification as read
- [ ] Mark all notifications as read
- [ ] Check badge counts update correctly
- [ ] Verify "See all Notifications" link in bell popover
- [ ] Test with no notifications (empty states)
- [ ] Test notification types display correct icons

---

## Future Considerations

1. **Scheduled archiving:** Consider a cron job to run `archive_old_notifications()` daily
2. **Notification preferences:** Allow users to configure notification types
3. **Real-time updates:** Add Supabase realtime subscription for new notifications
4. **Bulk delete:** Add ability to delete archived notifications
5. **Search/filter:** Add search within notification history

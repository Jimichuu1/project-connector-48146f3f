# Database Clean State Backup

**Created:** 2025-12-09  
**Purpose:** Reference backup after cleaning all test data, keeping only SUPER_ADMIN users.

## Current State Summary

| Table | Count |
|-------|-------|
| profiles | 2 |
| user_roles | 2 |
| leads | 0 |
| clients | 0 |
| deposits | 0 |
| general_settings | 1 |
| admin_settings | 0 |
| lead_groups | 0 |
| sale_branches | 0 |

## Preserved SUPER_ADMIN Users

| ID | Username | Email | Full Name |
|----|----------|-------|-----------|
| 1fabcb03-41c7-4fcd-b733-0d3f7461ac93 | Sadmin | admin@test.com | SuperAdmin |
| f5a65cdc-0d6c-4e21-8943-cada09c9cc5f | k1bal10n | k1bal10n@crm.internal | Test Super Admin |

## How to Restore to This Clean State

Run the following SQL to clean all data while preserving SUPER_ADMIN users:

```sql
-- Get SUPER_ADMIN user IDs
WITH super_admins AS (
  SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN'
)

-- Delete in order respecting foreign keys
DELETE FROM notifications WHERE user_id NOT IN (SELECT user_id FROM super_admins);
DELETE FROM reminders WHERE user_id NOT IN (SELECT user_id FROM super_admins);
DELETE FROM lead_activities;
DELETE FROM lead_comments;
DELETE FROM lead_tasks;
DELETE FROM lead_group_members;
DELETE FROM lead_groups;
DELETE FROM client_activities;
DELETE FROM client_comments;
DELETE FROM client_tasks;
DELETE FROM client_withdrawals;
DELETE FROM deposits;
DELETE FROM kyc_records;
DELETE FROM documents;
DELETE FROM leads;
DELETE FROM clients;
DELETE FROM sale_branches;
DELETE FROM call_history;
DELETE FROM user_sessions WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM auth_attempts;
DELETE FROM audit_logs WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM attendance WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM email_credentials WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM email_signatures WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM email_templates WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM ip_whitelist WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM user_permissions WHERE user_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM user_roles WHERE role != 'SUPER_ADMIN';
DELETE FROM admin_settings WHERE admin_id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
DELETE FROM profiles WHERE id NOT IN (SELECT user_id FROM user_roles WHERE role = 'SUPER_ADMIN');
```

## Notes

- All test users, leads, clients, deposits, and related data have been removed
- Only SUPER_ADMIN accounts are preserved
- General settings (1 row) preserved for system configuration
- Application is ready for production use with clean data

-- ============================================================
-- COMPLETE DATABASE SCHEMA FOR FOREX CRM
-- Generated from all migrations
-- Run this in your Supabase SQL Editor in order
-- ============================================================

-- ============================================================
-- PART 1: EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- ============================================================
-- PART 2: ENUMS
-- ============================================================

-- User roles enum
CREATE TYPE public.app_role AS ENUM ('SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER', 'SUPER_AGENT', 'AGENT');

-- Permissions enum
CREATE TYPE public.app_permission AS ENUM (
  'CAN_VIEW_REPORTS',
  'CAN_VIEW_SETTINGS',
  'CAN_MANAGE_USERS',
  'CAN_DELETE_LEADS',
  'CAN_ASSIGN_ALL',
  'CAN_TRANSFER_LEADS'
);

-- Lead status enum
CREATE TYPE public.lead_status AS ENUM (
  'NEW',
  'ACTIVE',
  'CALLBACK',
  'NOT_INTERESTED',
  'READY_TO_TRANSFER',
  'CALLED'
);

-- Lead source enum
CREATE TYPE public.lead_source AS ENUM (
  'WEBSITE',
  'REFERRAL',
  'SOCIAL_MEDIA',
  'COLD_CALL',
  'EMAIL_CAMPAIGN',
  'PAID_ADS',
  'WEBINAR',
  'TRADE_SHOW',
  'OTHER'
);

-- Client status enum
CREATE TYPE public.client_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'VIP');

-- KYC status enum
CREATE TYPE public.kyc_status AS ENUM ('VERIFIED', 'PENDING', 'REJECTED');

-- Pipeline status enum
CREATE TYPE public.pipeline_status AS ENUM ('PROSPECT', 'QUALIFIED', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST');

-- Pipeline stage enum
CREATE TYPE public.pipeline_stage AS ENUM (
  'WORK_IN_PROCESS',
  'UPCOMING_SALE',
  'STUCK',
  'FLIPPED',
  'DEPOSIT'
);

-- Withdrawal status enum
CREATE TYPE public.withdrawal_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'COMPLETED');

-- Document type enum
CREATE TYPE public.document_type AS ENUM ('ID', 'PROOF_OF_ADDRESS', 'BANK_STATEMENT', 'CONTRACT', 'OTHER');

-- Notification type enum
CREATE TYPE public.notification_type AS ENUM (
  'NEW_LEAD',
  'LEAD_ASSIGNED',
  'LEAD_TRANSFERRED',
  'CLIENT_CONVERTED',
  'WITHDRAWAL_REQUEST',
  'DEPOSIT_APPROVED',
  'DEPOSIT_REJECTED',
  'REMINDER_DUE',
  'SYSTEM_ALERT'
);

-- ============================================================
-- PART 3: CORE TABLES
-- ============================================================

-- Profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  last_name TEXT,
  username TEXT UNIQUE,
  avatar_url TEXT,
  ccc_phone_number TEXT,
  ccc_username TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

-- User permissions table
CREATE TABLE public.user_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  permission app_permission NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, permission)
);

-- User preferences table
CREATE TABLE public.user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  timezone TEXT DEFAULT 'UTC',
  group_last_read JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User sessions table
CREATE TABLE public.user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL UNIQUE,
  refresh_token_hash TEXT,
  ip_address TEXT,
  user_agent TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_activity TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_refresh_at TIMESTAMPTZ,
  refresh_count INTEGER DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 4: SETTINGS TABLES
-- ============================================================

-- Admin settings table (per tenant)
CREATE TABLE public.admin_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES public.profiles(id) UNIQUE,
  work_start_time TIME NOT NULL DEFAULT '09:00:00',
  work_end_time TIME NOT NULL DEFAULT '18:00:00',
  late_start_fee NUMERIC NOT NULL DEFAULT 0.00,
  excessive_break_fee NUMERIC NOT NULL DEFAULT 0.00,
  max_break_minutes INTEGER NOT NULL DEFAULT 60,
  day_off_fee NUMERIC NOT NULL DEFAULT 0.00,
  show_phone_to_agents BOOLEAN NOT NULL DEFAULT false,
  show_email_to_agents BOOLEAN NOT NULL DEFAULT false,
  show_phone_to_super_agents BOOLEAN DEFAULT true,
  show_email_to_super_agents BOOLEAN DEFAULT true,
  celebration_sound_url TEXT,
  celebration_video_url TEXT,
  ccc_integration_enabled BOOLEAN DEFAULT false,
  ccc_api_key TEXT,
  ccc_api_key_new TEXT,
  ccc_initiate_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/call/',
  ccc_end_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/ctc/end',
  ccc_control_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/call/control',
  ccc_webhook_url TEXT,
  ccc_clip_url TEXT,
  call_integration_access_granted BOOLEAN DEFAULT false,
  email_integration_access_granted BOOLEAN DEFAULT false,
  email_integration_active BOOLEAN DEFAULT false,
  integration_providers JSONB DEFAULT '{}'::jsonb,
  password_protection_config JSONB DEFAULT '{"require_numbers": true, "require_lowercase": true, "require_uppercase": true, "min_password_length": 8, "require_special_chars": true, "enable_leaked_password_check": true}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- General settings table (legacy, kept for compatibility)
CREATE TABLE public.general_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES public.profiles(id) UNIQUE,
  work_start_time TIME NOT NULL DEFAULT '09:00:00',
  work_end_time TIME NOT NULL DEFAULT '18:00:00',
  late_start_fee NUMERIC NOT NULL DEFAULT 0.00,
  excessive_break_fee NUMERIC NOT NULL DEFAULT 0.00,
  max_break_minutes INTEGER NOT NULL DEFAULT 60,
  day_off_fee NUMERIC NOT NULL DEFAULT 0.00,
  show_phone_to_agents BOOLEAN NOT NULL DEFAULT false,
  show_email_to_agents BOOLEAN NOT NULL DEFAULT false,
  show_phone_to_super_agents BOOLEAN DEFAULT true,
  show_email_to_super_agents BOOLEAN DEFAULT true,
  celebration_sound_url TEXT,
  celebration_video_url TEXT,
  ccc_integration_enabled BOOLEAN DEFAULT false,
  ccc_api_key TEXT,
  ccc_api_key_new TEXT,
  ccc_initiate_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/call/',
  ccc_end_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/ctc/end',
  ccc_control_endpoint TEXT DEFAULT 'https://ccc.mmdsmart.com/api/call/control',
  ccc_webhook_url TEXT,
  ccc_clip_url TEXT,
  email_integration_active BOOLEAN DEFAULT false,
  integration_providers JSONB DEFAULT '{}'::jsonb,
  password_protection_config JSONB DEFAULT '{"require_numbers": true, "require_lowercase": true, "require_uppercase": true, "min_password_length": 8, "require_special_chars": true, "enable_leaked_password_check": true}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 5: LEADS TABLES
-- ============================================================

-- Leads table
CREATE TABLE public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  country TEXT,
  source lead_source NOT NULL DEFAULT 'OTHER',
  status lead_status NOT NULL DEFAULT 'NEW',
  job_title TEXT,
  company TEXT,
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  conversion_probability DECIMAL(5,2) DEFAULT 0.00,
  balance NUMERIC(15,2) DEFAULT 0.00,
  equity NUMERIC(15,2) DEFAULT 0.00,
  estimated_close_date DATE,
  best_contact_time TEXT,
  next_best_action TEXT,
  is_transferred BOOLEAN DEFAULT false,
  transferred_by UUID REFERENCES public.profiles(id),
  pending_conversion BOOLEAN DEFAULT false,
  position INTEGER DEFAULT 0,
  last_contacted_at TIMESTAMPTZ,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lead activities table
CREATE TABLE public.lead_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lead tasks table
CREATE TABLE public.lead_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  assigned_to UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ,
  completed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lead comments table
CREATE TABLE public.lead_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lead groups table
CREATE TABLE public.lead_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lead group members table
CREATE TABLE public.lead_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.lead_groups(id) ON DELETE CASCADE,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  added_by UUID NOT NULL REFERENCES auth.users(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id, lead_id)
);

-- Lead statuses table (custom statuses)
CREATE TABLE public.lead_statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  color TEXT DEFAULT '#6366f1',
  position INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 6: CLIENTS TABLES
-- ============================================================

-- Clients table
CREATE TABLE public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  country TEXT,
  home_phone TEXT,
  join_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  source lead_source NOT NULL DEFAULT 'OTHER',
  status client_status NOT NULL DEFAULT 'ACTIVE',
  balance NUMERIC(15,2) DEFAULT 0.00,
  equity NUMERIC(15,2) DEFAULT 0.00,
  margin_level NUMERIC(5,2) DEFAULT 0.00,
  open_trades INTEGER DEFAULT 0,
  deposits NUMERIC(15,2) DEFAULT 0.00,
  kyc_status kyc_status NOT NULL DEFAULT 'PENDING',
  satisfaction_score INTEGER DEFAULT 0,
  assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  pipeline_status pipeline_status NOT NULL DEFAULT 'PROSPECT',
  potential_value NUMERIC(15,2),
  actual_value NUMERIC(15,2),
  converted_from_lead_id UUID REFERENCES public.leads(id),
  transferred_by UUID REFERENCES public.profiles(id),
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client activities table
CREATE TABLE public.client_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  activity_type TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client tasks table
CREATE TABLE public.client_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  assigned_to UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ,
  completed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client comments table
CREATE TABLE public.client_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client withdrawals table
CREATE TABLE public.client_withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  status withdrawal_status NOT NULL DEFAULT 'PENDING',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Client statuses table (custom statuses)
CREATE TABLE public.client_statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  color TEXT DEFAULT '#6366f1',
  position INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

-- Index for client groups performance
CREATE INDEX idx_client_groups_admin_id ON public.client_groups(admin_id);
CREATE INDEX idx_client_group_members_client_id ON public.client_group_members(client_id);
CREATE INDEX idx_client_group_members_group_id ON public.client_group_members(group_id);

-- ============================================================
-- PART 7: PIPELINE & DEPOSITS TABLES
-- ============================================================

-- Sale branches table
CREATE TABLE public.sale_branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  status pipeline_stage NOT NULL DEFAULT 'WORK_IN_PROCESS',
  value NUMERIC(15,2) NOT NULL DEFAULT 0.00,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deposits table
CREATE TABLE public.deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  lead_id UUID REFERENCES public.leads(id),
  sale_branch_id UUID NOT NULL REFERENCES public.sale_branches(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  super_agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  agent_percentage INTEGER NOT NULL,
  super_agent_percentage INTEGER NOT NULL,
  agent_amount NUMERIC(15,2) NOT NULL,
  super_agent_amount NUMERIC(15,2) NOT NULL,
  exchanges TEXT[],
  status TEXT NOT NULL DEFAULT 'pending',
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 8: KYC & DOCUMENTS TABLES
-- ============================================================

-- KYC records table
CREATE TABLE public.kyc_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  bank_name TEXT,
  notes TEXT,
  status kyc_status NOT NULL DEFAULT 'PENDING',
  verified_date TIMESTAMPTZ,
  verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_id UUID REFERENCES public.profiles(id),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Documents table
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  size BIGINT NOT NULL,
  type document_type NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  kyc_record_id UUID REFERENCES public.kyc_records(id) ON DELETE CASCADE,
  admin_id UUID REFERENCES public.profiles(id),
  uploaded_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 9: COMMUNICATION TABLES
-- ============================================================

-- Conversations table
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID NOT NULL REFERENCES public.profiles(id),
  user2_id UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Messages table
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Group chats table
CREATE TABLE public.group_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_static BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Group chat members table
CREATE TABLE public.group_chat_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_chat_id UUID NOT NULL REFERENCES public.group_chats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_chat_id, user_id)
);

-- Group chat messages table
CREATE TABLE public.group_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_chat_id UUID NOT NULL REFERENCES public.group_chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notifications table
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  type notification_type NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  related_entity_type TEXT,
  related_entity_id UUID,
  related_profile_id UUID,
  admin_id UUID REFERENCES public.profiles(id),
  archived_at TIMESTAMPTZ,  -- NULL = recent, NOT NULL = archived
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for notifications archiving (performance)
CREATE INDEX idx_notifications_archived ON public.notifications(archived_at) WHERE archived_at IS NOT NULL;
CREATE INDEX idx_notifications_recent ON public.notifications(user_id, created_at DESC) WHERE archived_at IS NULL;

-- Function to archive old notifications (older than 1 month)
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

-- Reminders table
CREATE TABLE public.reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ NOT NULL,
  priority TEXT NOT NULL DEFAULT 'medium',
  completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  related_entity_type TEXT,
  related_entity_id UUID,
  timezone TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 10: EMAIL TABLES
-- ============================================================

-- Email credentials table
CREATE TABLE public.email_credentials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
  email_address TEXT NOT NULL,
  email_password TEXT NOT NULL,
  email_address_encrypted TEXT,
  email_password_encrypted TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Email signatures table
CREATE TABLE public.email_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  signature_html TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Email templates table
CREATE TABLE public.email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  subject TEXT,
  header_html TEXT,
  body_html TEXT NOT NULL,
  footer_html TEXT,
  is_shared BOOLEAN DEFAULT false,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sent emails table
CREATE TABLE public.sent_emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL,
  recipient_email TEXT NOT NULL,
  subject TEXT NOT NULL,
  body_html TEXT,
  body_text TEXT,
  cc TEXT[],
  bcc TEXT[],
  attachments JSONB,
  is_manual_recipient BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMPTZ,
  provider_message_id TEXT,
  error_message TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Received emails table
CREATE TABLE public.received_emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  message_id TEXT NOT NULL UNIQUE,
  sender_email TEXT NOT NULL,
  sender_name TEXT,
  recipient_email TEXT NOT NULL,
  subject TEXT NOT NULL,
  body_html TEXT,
  body_text TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  in_reply_to TEXT,
  email_references TEXT,
  received_at TIMESTAMPTZ NOT NULL,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 11: ATTENDANCE & CALL HISTORY TABLES
-- ============================================================

-- Attendance table
CREATE TABLE public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  clock_in TIMESTAMPTZ NOT NULL DEFAULT now(),
  clock_out TIMESTAMPTZ,
  break_minutes INTEGER DEFAULT 0,
  working_started_at TIMESTAMPTZ,
  working_periods JSONB DEFAULT '[]'::jsonb,
  is_late BOOLEAN DEFAULT false,
  late_start_fee NUMERIC DEFAULT 0.00,
  break_time_fee NUMERIC DEFAULT 0.00,
  total_fees NUMERIC DEFAULT 0.00,
  notes TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Call history table
CREATE TABLE public.call_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  lead_id UUID REFERENCES public.leads(id),
  client_id UUID REFERENCES public.clients(id),
  phone_number TEXT NOT NULL,
  agent_email TEXT NOT NULL,
  call_id TEXT,
  status TEXT NOT NULL DEFAULT 'initiated',
  duration INTEGER,
  error_message TEXT,
  admin_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 12: SECURITY TABLES
-- ============================================================

-- Audit logs table
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  action_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auth attempts table
CREATE TABLE public.auth_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL,
  user_email TEXT,
  attempt_type TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT false,
  failure_reason TEXT,
  user_agent TEXT,
  blocked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- IP whitelist table
CREATE TABLE public.ip_whitelist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  ip_address TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PART 13: HELPER FUNCTIONS
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Function to check if user has a role
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
$$;

-- Function to check if user has a permission
CREATE OR REPLACE FUNCTION public.has_permission(_user_id UUID, _permission app_permission)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_permissions
    WHERE user_id = _user_id AND permission = _permission
  );
$$;

-- Function to get user role directly
CREATE OR REPLACE FUNCTION public.get_user_role_direct(check_user_id UUID)
RETURNS TEXT
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::text FROM public.user_roles WHERE user_id = check_user_id LIMIT 1
$$;

-- Function to get user's admin_id (tenant)
CREATE OR REPLACE FUNCTION public.get_user_admin_id(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
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
    SELECT role INTO v_role
    FROM user_roles
    WHERE user_id = v_current_user
    LIMIT 1;
    
    IF v_role = 'TENANT_OWNER' THEN
      RETURN v_current_user;
    END IF;
    
    SELECT created_by INTO v_created_by
    FROM profiles
    WHERE id = v_current_user;
    
    IF v_created_by IS NULL OR v_created_by = v_current_user THEN
      RETURN NULL;
    END IF;
    
    v_current_user := v_created_by;
    v_depth := v_depth + 1;
  END LOOP;
  
  RETURN NULL;
END;
$$;

-- Function to check if user can access tenant
CREATE OR REPLACE FUNCTION public.can_access_tenant(_admin_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_admin_id uuid;
  v_profile_admin_id uuid;
BEGIN
  IF has_role(auth.uid(), 'SUPER_ADMIN') THEN
    RETURN true;
  END IF;
  
  SELECT p.admin_id INTO v_profile_admin_id
  FROM profiles p
  WHERE p.id = auth.uid();
  
  IF has_role(auth.uid(), 'TENANT_OWNER') AND (_admin_id = auth.uid() OR _admin_id IS NULL) THEN
    RETURN true;
  END IF;
  
  IF _admin_id IS NULL THEN
    RETURN false;
  END IF;
  
  IF v_profile_admin_id IS NOT NULL THEN
    RETURN v_profile_admin_id = _admin_id;
  END IF;
  
  v_user_admin_id := get_user_admin_id(auth.uid());
  
  IF v_user_admin_id IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN v_user_admin_id = _admin_id;
END;
$$;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = 'SUPER_ADMIN'
  )
$$;

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'AGENT');
  
  RETURN NEW;
END;
$$;

-- Function to set profile admin_id
CREATE OR REPLACE FUNCTION public.set_profile_admin_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_creator_admin_id uuid;
  v_creator_role text;
BEGIN
  IF NEW.created_by IS NOT NULL THEN
    SELECT role INTO v_creator_role
    FROM user_roles
    WHERE user_id = NEW.created_by
    LIMIT 1;
    
    IF v_creator_role = 'TENANT_OWNER' THEN
      NEW.admin_id := NEW.created_by;
    ELSE
      SELECT admin_id INTO v_creator_admin_id
      FROM profiles
      WHERE id = NEW.created_by;
      
      NEW.admin_id := v_creator_admin_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Function to get or create tenant settings
CREATE OR REPLACE FUNCTION public.get_or_create_tenant_settings(p_tenant_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings_id uuid;
BEGIN
  SELECT id INTO v_settings_id
  FROM admin_settings
  WHERE admin_id = p_tenant_id;
  
  IF v_settings_id IS NULL THEN
    INSERT INTO admin_settings (admin_id)
    VALUES (p_tenant_id)
    RETURNING id INTO v_settings_id;
  END IF;
  
  RETURN v_settings_id;
END;
$$;

-- Function for encryption key
CREATE OR REPLACE FUNCTION public.get_encryption_key()
RETURNS bytea
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public
AS $$
BEGIN
  RETURN extensions.digest('crm_encryption_key_2024_secure', 'sha256');
END;
$$;

-- Function to log audit event
CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_user_id UUID, 
  p_action_type TEXT, 
  p_entity_type TEXT DEFAULT NULL, 
  p_entity_id UUID DEFAULT NULL, 
  p_details JSONB DEFAULT NULL, 
  p_ip_address TEXT DEFAULT NULL, 
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    user_id, action_type, entity_type, entity_id, details, ip_address, user_agent
  ) VALUES (
    p_user_id, p_action_type, p_entity_type, p_entity_id, p_details, p_ip_address, p_user_agent
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- Function to cleanup expired sessions
CREATE OR REPLACE FUNCTION public.cleanup_expired_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.user_sessions
  WHERE expires_at < now() OR (last_activity < now() - INTERVAL '30 minutes' AND is_active = true);
END;
$$;

-- Function to count failed attempts
CREATE OR REPLACE FUNCTION public.count_failed_attempts(p_ip_address TEXT, p_minutes INTEGER DEFAULT 15)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*)
  FROM public.auth_attempts
  WHERE ip_address = p_ip_address
    AND success = false
    AND created_at > now() - (p_minutes || ' minutes')::INTERVAL
  INTO v_count;
  
  RETURN v_count;
END;
$$;

-- Function to check if IP is blocked
CREATE OR REPLACE FUNCTION public.is_ip_blocked(p_ip_address TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.auth_attempts
    WHERE ip_address = p_ip_address
      AND blocked_until IS NOT NULL
      AND blocked_until > now()
  ) INTO v_blocked;
  
  RETURN v_blocked;
END;
$$;

-- Function to get agents for deposit
CREATE OR REPLACE FUNCTION public.get_agents_for_deposit()
RETURNS TABLE(id UUID, full_name TEXT, email TEXT, role app_role)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT p.id, p.full_name, p.email, ur.role
  FROM profiles p
  INNER JOIN user_roles ur ON ur.user_id = p.id
  WHERE ur.role IN ('AGENT', 'SUPER_AGENT')
  ORDER BY p.full_name, p.email;
END;
$$;

-- ============================================================
-- PART 14: TRIGGERS
-- ============================================================

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Trigger for profile admin_id
CREATE TRIGGER set_profile_admin_id_trigger
  BEFORE INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_profile_admin_id();

-- Updated_at triggers
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_clients_updated_at
  BEFORE UPDATE ON public.clients
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_sale_branches_updated_at
  BEFORE UPDATE ON public.sale_branches
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_attendance_updated_at
  BEFORE UPDATE ON public.attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_reminders_updated_at
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- PART 15: ENABLE RLS ON ALL TABLES
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.general_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sent_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.received_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ip_whitelist ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PART 16: INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_leads_assigned_to ON public.leads(assigned_to);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_created_by ON public.leads(created_by);
CREATE INDEX IF NOT EXISTS idx_leads_admin_id ON public.leads(admin_id);
CREATE INDEX IF NOT EXISTS idx_clients_assigned_to ON public.clients(assigned_to);
CREATE INDEX IF NOT EXISTS idx_clients_created_by ON public.clients(created_by);
CREATE INDEX IF NOT EXISTS idx_clients_admin_id ON public.clients(admin_id);
CREATE INDEX IF NOT EXISTS idx_deposits_client_id ON public.deposits(client_id);
CREATE INDEX IF NOT EXISTS idx_deposits_admin_id ON public.deposits(admin_id);
CREATE INDEX IF NOT EXISTS idx_sale_branches_client_id ON public.sale_branches(client_id);
CREATE INDEX IF NOT EXISTS idx_call_history_user_id ON public.call_history(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_user_id ON public.attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_user_id ON public.reminders(user_id);

-- ============================================================
-- PART 17: STORAGE BUCKETS
-- ============================================================

-- Create storage buckets (run in Supabase dashboard or via SQL)
INSERT INTO storage.buckets (id, name, public) VALUES ('documents', 'documents', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('celebration-sounds', 'celebration-sounds', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('celebration-videos', 'celebration-videos', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('email-images', 'email-images', true) ON CONFLICT DO NOTHING;

-- ============================================================
-- PART 18: REALTIME
-- ============================================================

-- Enable realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.call_history;
ALTER PUBLICATION supabase_realtime ADD TABLE public.deposits;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reminders;

-- ============================================================
-- NOTE: RLS POLICIES
-- ============================================================
-- RLS policies are extensive and defined in individual migration files.
-- For the complete RLS policies, please run the individual migration files
-- or check the Supabase dashboard after running this schema.
-- The policies implement tenant isolation and role-based access control.
-- ============================================================

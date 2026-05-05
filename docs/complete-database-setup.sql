-- =============================================================================
-- KYBALION CRM - COMPLETE DATABASE SETUP SCRIPT (CORRECTED)
-- =============================================================================
-- This script matches the actual database schema and function signatures
-- Run in Supabase SQL Editor
-- =============================================================================

-- =============================================================================
-- PART 1: ENUMS (if not already created)
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    CREATE TYPE public.app_role AS ENUM (
      'ADMIN',
      'MANAGER',
      'SUPER_AGENT',
      'AGENT',
      'SUPER_ADMIN',
      'TENANT_OWNER'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_permission') THEN
    CREATE TYPE public.app_permission AS ENUM (
      'CAN_VIEW_REPORTS',
      'CAN_VIEW_SETTINGS',
      'CAN_MANAGE_USERS',
      'CAN_DELETE_LEADS',
      'CAN_ASSIGN_ALL',
      'CAN_TRANSFER_LEADS'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lead_status') THEN
    CREATE TYPE public.lead_status AS ENUM (
      'NEW',
      'ACTIVE',
      'CALLBACK',
      'NOT_INTERESTED',
      'READY_TO_TRANSFER',
      'CALLED',
      'DON''T_CALL'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lead_source') THEN
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
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_status') THEN
    CREATE TYPE public.client_status AS ENUM (
      'ACTIVE',
      'FLIPPED',
      'FREELOADER',
      'NO_ANSWER'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_status') THEN
    CREATE TYPE public.pipeline_status AS ENUM (
      'PROSPECT',
      'QUALIFIED',
      'NEGOTIATION',
      'CLOSED_WON',
      'CLOSED_LOST'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_stage') THEN
    CREATE TYPE public.pipeline_stage AS ENUM (
      'UPCOMING_SALE',
      'STUCK',
      'FLIPPED',
      'DEPOSIT'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_status') THEN
    CREATE TYPE public.kyc_status AS ENUM (
      'VERIFIED',
      'PENDING',
      'REJECTED'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type') THEN
    CREATE TYPE public.document_type AS ENUM (
      'PDF',
      'DOCX',
      'XLSX',
      'IMAGE',
      'OTHER'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
    CREATE TYPE public.notification_type AS ENUM (
      'NEW_LEAD',
      'WITHDRAWAL_REQUEST',
      'LEAD_ASSIGNED',
      'CLIENT_CONVERTED',
      'TASK_DUE',
      'TICKET_CREATED'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'withdrawal_status') THEN
    CREATE TYPE public.withdrawal_status AS ENUM (
      'PENDING',
      'APPROVED',
      'REJECTED',
      'COMPLETED'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'churn_risk') THEN
    CREATE TYPE public.churn_risk AS ENUM (
      'LOW',
      'MEDIUM',
      'HIGH'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_profile') THEN
    CREATE TYPE public.risk_profile AS ENUM (
      'LOW',
      'MEDIUM',
      'HIGH'
    );
  END IF;
END $$;

-- =============================================================================
-- PART 1a: DROP ALL EXISTING RLS POLICIES (prevents "already exists" errors)
-- =============================================================================
-- This section drops all existing policies to allow clean recreation

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT schemaname, tablename, policyname
    FROM pg_policies 
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- =============================================================================
-- PART 1b: CORE TABLES (Create these first - order matters for FKs)
-- =============================================================================

-- profiles table (core user profile data)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  email text NOT NULL,
  full_name text,
  last_name text,
  username text UNIQUE,
  avatar_url text,
  ccc_phone_number text,
  ccc_username text,
  admin_id uuid REFERENCES profiles(id),
  created_by uuid REFERENCES profiles(id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- user_roles table (role assignments)
CREATE TABLE IF NOT EXISTS public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role app_role NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

-- user_preferences table
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  timezone text,
  group_last_read jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- leads table
CREATE TABLE IF NOT EXISTS public.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  phone text,
  country text,
  company text,
  job_title text,
  source lead_source NOT NULL DEFAULT 'OTHER',
  status lead_status NOT NULL DEFAULT 'NEW',
  conversion_probability integer,
  last_contacted_at timestamp with time zone,
  best_contact_time text,
  estimated_close_date date,
  next_best_action text,
  balance numeric DEFAULT 0,
  equity numeric DEFAULT 0,
  pending_conversion boolean DEFAULT false,
  is_transferred boolean DEFAULT false,
  transferred_by uuid,
  position integer,
  assigned_to uuid,
  created_by uuid NOT NULL,
  admin_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- clients table
CREATE TABLE IF NOT EXISTS public.clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  home_phone text,
  country text,
  status client_status NOT NULL DEFAULT 'ACTIVE',
  source lead_source NOT NULL DEFAULT 'OTHER',
  balance numeric DEFAULT 0,
  equity numeric DEFAULT 0,
  margin_level numeric DEFAULT 0,
  open_trades integer DEFAULT 0,
  deposits numeric DEFAULT 0,
  kyc_status kyc_status NOT NULL DEFAULT 'PENDING',
  satisfaction_score integer DEFAULT 0,
  pipeline_status pipeline_status NOT NULL DEFAULT 'PROSPECT',
  potential_value numeric,
  actual_value numeric,
  converted_from_lead_id uuid,
  assigned_to uuid,
  created_by uuid NOT NULL,
  transferred_by uuid,
  admin_id uuid,
  join_date timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- =============================================================================
-- PART 1c: RLS POLICIES FOR CORE TABLES
-- =============================================================================

-- Enable RLS on core tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Note: Full RLS policies for these tables are defined after helper functions
-- because they depend on functions like has_role, can_access_tenant, etc.

-- =============================================================================
-- PART 2: CORE HELPER FUNCTIONS FOR RLS
-- =============================================================================
-- These functions MUST match the signatures used in RLS policies

-- Function: has_role(_user_id uuid, _role app_role) -> boolean
-- Used by RLS policies to check if a user has a specific role
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
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

-- Function: has_permission(_user_id uuid, _permission app_permission) -> boolean
CREATE OR REPLACE FUNCTION public.has_permission(_user_id uuid, _permission app_permission)
RETURNS boolean
LANGUAGE sql
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

-- Function: is_super_admin(_user_id uuid) -> boolean
CREATE OR REPLACE FUNCTION public.is_super_admin(_user_id uuid)
RETURNS boolean
LANGUAGE sql
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

-- Function: is_admin_or_tenant_owner(_user_id uuid) -> boolean
CREATE OR REPLACE FUNCTION public.is_admin_or_tenant_owner(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN ('SUPER_ADMIN', 'TENANT_OWNER', 'ADMIN', 'MANAGER')
  )
$$;

-- Function: get_user_role_direct(check_user_id uuid) -> text
-- Returns the role as text for direct comparison in RLS
CREATE OR REPLACE FUNCTION public.get_user_role_direct(check_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::text FROM public.user_roles WHERE user_id = check_user_id LIMIT 1
$$;

-- Function: get_user_admin_id(p_user_id uuid) -> uuid
-- Traverses the user creation chain to find the tenant owner (admin_id)
CREATE OR REPLACE FUNCTION public.get_user_admin_id(p_user_id uuid)
RETURNS uuid
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

-- Function: can_access_tenant(_admin_id uuid) -> boolean
-- Core tenant isolation function used by most RLS policies
CREATE OR REPLACE FUNCTION public.can_access_tenant(_admin_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
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
  
  -- Get current user's admin_id from profile (faster than traversing chain)
  SELECT p.admin_id INTO v_profile_admin_id
  FROM profiles p
  WHERE p.id = auth.uid();
  
  -- TENANT_OWNER checking their own data
  IF has_role(auth.uid(), 'TENANT_OWNER') AND (_admin_id = auth.uid() OR _admin_id IS NULL) THEN
    RETURN true;
  END IF;
  
  -- If record has no admin_id, only SUPER_ADMIN can see (handled above)
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

-- Function: get_tenant_user_ids(_user_id uuid) -> SETOF uuid
-- Returns all user IDs belonging to the same tenant
CREATE OR REPLACE FUNCTION public.get_tenant_user_ids(_user_id uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p2.id
  FROM public.profiles p1
  JOIN public.profiles p2 ON (
    p1.admin_id = p2.admin_id 
    OR p1.id = p2.admin_id 
    OR p2.id = p1.admin_id
    OR p1.admin_id IS NULL AND p2.admin_id IS NULL
  )
  WHERE p1.id = _user_id
$$;

-- Function: is_group_member(p_group_chat_id uuid, p_user_id uuid) -> boolean
-- Drop existing function first to avoid parameter name conflicts (CASCADE drops dependent policies)
DROP FUNCTION IF EXISTS public.is_group_member(uuid, uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_chat_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.group_chat_members
    WHERE group_chat_id = p_group_chat_id
      AND user_id = p_user_id
  )
$$;

-- Function: is_static_group(p_group_chat_id uuid) -> boolean
-- Drop existing function first to avoid parameter name conflicts (CASCADE drops dependent policies)
DROP FUNCTION IF EXISTS public.is_static_group(uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.is_static_group(p_group_chat_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.group_chats
    WHERE id = p_group_chat_id
      AND is_static = true
  )
$$;

-- Function: can_delete_user(_target_user_id uuid, _current_user_id uuid) -> boolean
CREATE OR REPLACE FUNCTION public.can_delete_user(_target_user_id uuid, _current_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If target user is a SUPER_ADMIN, only another SUPER_ADMIN can delete them
  IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _target_user_id AND role = 'SUPER_ADMIN') THEN
    RETURN EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _current_user_id AND role = 'SUPER_ADMIN');
  END IF;
  
  -- For non-super-admin users, both ADMIN and SUPER_ADMIN can delete
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = _current_user_id 
    AND role IN ('ADMIN', 'SUPER_ADMIN')
  );
END;
$$;

-- =============================================================================
-- PART 3: PHONE/EMAIL VISIBILITY FUNCTIONS
-- =============================================================================

-- Function: can_view_phone() -> boolean
CREATE OR REPLACE FUNCTION public.can_view_phone()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role app_role;
  show_to_agents boolean;
  show_to_super_agents boolean;
BEGIN
  -- Admins and Managers can always see phone numbers
  IF has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER') THEN
    RETURN true;
  END IF;
  
  -- Get visibility settings
  SELECT gs.show_phone_to_agents, gs.show_phone_to_super_agents
  INTO show_to_agents, show_to_super_agents
  FROM general_settings gs
  LIMIT 1;
  
  -- Check for AGENT role
  IF has_role(auth.uid(), 'AGENT') THEN
    RETURN COALESCE(show_to_agents, false);
  END IF;
  
  -- Check for SUPER_AGENT role
  IF has_role(auth.uid(), 'SUPER_AGENT') THEN
    RETURN COALESCE(show_to_super_agents, true);
  END IF;
  
  RETURN false;
END;
$$;

-- Function: can_view_email() -> boolean
CREATE OR REPLACE FUNCTION public.can_view_email()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role app_role;
  show_to_agents boolean;
  show_to_super_agents boolean;
BEGIN
  -- Admins and Managers can always see emails
  IF has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER') THEN
    RETURN true;
  END IF;
  
  -- Get visibility settings
  SELECT gs.show_email_to_agents, gs.show_email_to_super_agents
  INTO show_to_agents, show_to_super_agents
  FROM general_settings gs
  LIMIT 1;
  
  -- Check for AGENT role
  IF has_role(auth.uid(), 'AGENT') THEN
    RETURN COALESCE(show_to_agents, false);
  END IF;
  
  -- Check for SUPER_AGENT role
  IF has_role(auth.uid(), 'SUPER_AGENT') THEN
    RETURN COALESCE(show_to_super_agents, true);
  END IF;
  
  RETURN false;
END;
$$;

-- =============================================================================
-- PART 4: ENCRYPTION FUNCTIONS (requires pgcrypto in extensions schema)
-- =============================================================================

-- Function: get_encryption_key() -> bytea
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

-- Function: encrypt_sensitive(p_data text) -> text
CREATE OR REPLACE FUNCTION public.encrypt_sensitive(p_data text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public
AS $$
DECLARE
  v_key bytea;
  v_iv bytea;
  v_encrypted bytea;
BEGIN
  IF p_data IS NULL OR p_data = '' THEN
    RETURN NULL;
  END IF;
  
  v_key := public.get_encryption_key();
  v_iv := extensions.gen_random_bytes(16);
  v_encrypted := extensions.encrypt_iv(convert_to(p_data, 'UTF8'), v_key, v_iv, 'aes-cbc');
  
  RETURN encode(v_iv || v_encrypted, 'base64');
END;
$$;

-- Function: decrypt_sensitive(p_encrypted text) -> text
CREATE OR REPLACE FUNCTION public.decrypt_sensitive(p_encrypted text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public
AS $$
DECLARE
  v_key bytea;
  v_data bytea;
  v_iv bytea;
  v_encrypted bytea;
BEGIN
  IF p_encrypted IS NULL OR p_encrypted = '' THEN
    RETURN NULL;
  END IF;
  
  v_key := public.get_encryption_key();
  v_data := decode(p_encrypted, 'base64');
  v_iv := substring(v_data from 1 for 16);
  v_encrypted := substring(v_data from 17);
  
  RETURN convert_from(extensions.decrypt_iv(v_encrypted, v_key, v_iv, 'aes-cbc'), 'UTF8');
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- Function: hash_token(p_token text) -> text
CREATE OR REPLACE FUNCTION public.hash_token(p_token text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public
AS $$
BEGIN
  RETURN encode(extensions.digest(p_token, 'sha256'), 'hex');
END;
$$;

-- =============================================================================
-- PART 5: SETTINGS HELPER FUNCTIONS
-- =============================================================================

-- Function: get_or_create_tenant_settings(p_tenant_id uuid) -> uuid
CREATE OR REPLACE FUNCTION public.get_or_create_tenant_settings(p_tenant_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings_id uuid;
BEGIN
  -- Check if settings exist
  SELECT id INTO v_settings_id
  FROM admin_settings
  WHERE admin_id = p_tenant_id;
  
  -- If no settings exist, create default settings
  IF v_settings_id IS NULL THEN
    INSERT INTO admin_settings (admin_id)
    VALUES (p_tenant_id)
    RETURNING id INTO v_settings_id;
  END IF;
  
  RETURN v_settings_id;
END;
$$;

-- Function: get_or_create_general_settings(p_tenant_id uuid) -> uuid
CREATE OR REPLACE FUNCTION public.get_or_create_general_settings(p_tenant_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings_id uuid;
BEGIN
  -- Check if settings exist for this tenant
  SELECT id INTO v_settings_id
  FROM general_settings
  WHERE admin_id = p_tenant_id;
  
  -- If no settings exist, create default settings for tenant
  IF v_settings_id IS NULL THEN
    INSERT INTO general_settings (admin_id)
    VALUES (p_tenant_id)
    RETURNING id INTO v_settings_id;
  END IF;
  
  RETURN v_settings_id;
END;
$$;

-- =============================================================================
-- PART 6: SECURITY FUNCTIONS
-- =============================================================================

-- Function: is_ip_blocked(p_ip_address text) -> boolean
CREATE OR REPLACE FUNCTION public.is_ip_blocked(p_ip_address text)
RETURNS boolean
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

-- Function: count_failed_attempts(p_ip_address text, p_minutes integer) -> integer
CREATE OR REPLACE FUNCTION public.count_failed_attempts(p_ip_address text, p_minutes integer DEFAULT 15)
RETURNS integer
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

-- Function: check_ip_whitelist(p_user_id uuid, p_ip_address text) -> boolean
CREATE OR REPLACE FUNCTION public.check_ip_whitelist(p_user_id uuid, p_ip_address text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user has any active whitelist entries
  IF NOT EXISTS (
    SELECT 1 FROM ip_whitelist 
    WHERE user_id = p_user_id AND is_active = true
  ) THEN
    -- No IP restrictions for this user
    RETURN true;
  END IF;
  
  -- Check if the specific IP is whitelisted
  RETURN EXISTS (
    SELECT 1 FROM ip_whitelist
    WHERE user_id = p_user_id 
      AND ip_address = p_ip_address 
      AND is_active = true
  );
END;
$$;

-- Function: log_audit_event(...) -> uuid
CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_user_id uuid, 
  p_action_type text, 
  p_entity_type text DEFAULT NULL, 
  p_entity_id uuid DEFAULT NULL, 
  p_details jsonb DEFAULT NULL, 
  p_ip_address text DEFAULT NULL, 
  p_user_agent text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    user_id,
    action_type,
    entity_type,
    entity_id,
    details,
    ip_address,
    user_agent
  ) VALUES (
    p_user_id,
    p_action_type,
    p_entity_type,
    p_entity_id,
    p_details,
    p_ip_address,
    p_user_agent
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- Function: cleanup_expired_sessions() -> void
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

-- =============================================================================
-- PART 7: TRIGGERS FOR AUTO-SETTING admin_id
-- =============================================================================

-- Trigger function to set admin_id on profiles
CREATE OR REPLACE FUNCTION public.set_profile_admin_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_creator_admin_id uuid;
  v_creator_role text;
BEGIN
  -- If created_by is set, determine the admin_id
  IF NEW.created_by IS NOT NULL THEN
    -- Check if creator is a TENANT_OWNER
    SELECT role INTO v_creator_role
    FROM user_roles
    WHERE user_id = NEW.created_by
    LIMIT 1;
    
    IF v_creator_role = 'TENANT_OWNER' THEN
      -- If creator is TENANT_OWNER, set admin_id to creator
      NEW.admin_id := NEW.created_by;
    ELSE
      -- Otherwise, inherit admin_id from creator
      SELECT admin_id INTO v_creator_admin_id
      FROM profiles
      WHERE id = NEW.created_by;
      
      NEW.admin_id := v_creator_admin_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_profile_admin_id_trigger ON profiles;
CREATE TRIGGER set_profile_admin_id_trigger
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_profile_admin_id();

-- Trigger function to set admin_id on leads
CREATE OR REPLACE FUNCTION public.set_admin_id_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.admin_id IS NULL AND NEW.created_by IS NOT NULL THEN
    NEW.admin_id := get_user_admin_id(NEW.created_by);
  END IF;
  RETURN NEW;
END;
$$;

-- Apply to leads table
DROP TRIGGER IF EXISTS set_lead_admin_id_trigger ON leads;
CREATE TRIGGER set_lead_admin_id_trigger
  BEFORE INSERT ON leads
  FOR EACH ROW
  EXECUTE FUNCTION set_admin_id_on_insert();

-- Apply to clients table
DROP TRIGGER IF EXISTS set_client_admin_id_trigger ON clients;
CREATE TRIGGER set_client_admin_id_trigger
  BEFORE INSERT ON clients
  FOR EACH ROW
  EXECUTE FUNCTION set_admin_id_on_insert();

-- Trigger function to set admin_id from current user
CREATE OR REPLACE FUNCTION public.set_admin_id_from_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  -- If admin_id is already set, keep it
  IF NEW.admin_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  
  -- Get the tenant (admin_id) for the current user
  v_admin_id := get_user_admin_id(auth.uid());
  
  IF v_admin_id IS NOT NULL THEN
    NEW.admin_id := v_admin_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- PART 8: GROUP CHAT SYNC FUNCTIONS
-- =============================================================================

-- Function: sync_static_group_members() -> void
CREATE OR REPLACE FUNCTION public.sync_static_group_members()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  info_group_id UUID;
  ret_group_id UUID;
  con_group_id UUID;
BEGIN
  -- Get group IDs
  SELECT id INTO info_group_id FROM group_chats WHERE name = 'Info' AND is_static = true;
  SELECT id INTO ret_group_id FROM group_chats WHERE name = 'Ret' AND is_static = true;
  SELECT id INTO con_group_id FROM group_chats WHERE name = 'Con' AND is_static = true;

  -- Clear existing members for static groups
  DELETE FROM group_chat_members WHERE group_chat_id IN (info_group_id, ret_group_id, con_group_id);

  -- Info group: All users with any role
  INSERT INTO group_chat_members (group_chat_id, user_id)
  SELECT DISTINCT info_group_id, ur.user_id
  FROM user_roles ur
  WHERE ur.role IN ('ADMIN', 'MANAGER', 'SUPER_AGENT', 'AGENT')
  ON CONFLICT (group_chat_id, user_id) DO NOTHING;

  -- Ret group: Super Agents + Managers
  INSERT INTO group_chat_members (group_chat_id, user_id)
  SELECT DISTINCT ret_group_id, ur.user_id
  FROM user_roles ur
  WHERE ur.role IN ('MANAGER', 'SUPER_AGENT')
  ON CONFLICT (group_chat_id, user_id) DO NOTHING;

  -- Con group: Agents + Managers
  INSERT INTO group_chat_members (group_chat_id, user_id)
  SELECT DISTINCT con_group_id, ur.user_id
  FROM user_roles ur
  WHERE ur.role IN ('MANAGER', 'AGENT')
  ON CONFLICT (group_chat_id, user_id) DO NOTHING;
END;
$$;

-- Trigger function: handle_role_change_for_groups
CREATE OR REPLACE FUNCTION public.handle_role_change_for_groups()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.sync_static_group_members();
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- =============================================================================
-- PART 9: DEPOSIT NOTIFICATION TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_of_pending_deposit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_name text;
BEGIN
  -- Get the client name
  SELECT name INTO v_client_name
  FROM clients
  WHERE id = NEW.client_id;
  
  -- Insert notification for each admin user
  INSERT INTO notifications (user_id, type, message, related_entity_type, related_entity_id)
  SELECT 
    ur.user_id,
    'WITHDRAWAL_REQUEST'::notification_type,
    'New deposit request of $' || NEW.amount || ' from ' || COALESCE(v_client_name, 'Unknown Client') || ' awaiting approval',
    'deposit',
    NEW.id
  FROM user_roles ur
  WHERE ur.role = 'ADMIN';
  
  RETURN NEW;
END;
$$;

-- =============================================================================
-- PART 10: WORKING HOURS CALCULATION
-- =============================================================================

CREATE OR REPLACE FUNCTION public.calculate_working_hours(p_clock_in timestamp with time zone, p_clock_out timestamp with time zone)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_clock_out IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN EXTRACT(EPOCH FROM (p_clock_out - p_clock_in)) / 3600;
END;
$$;

-- =============================================================================
-- PART 11: AGENT DROPDOWN HELPER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_agents_for_deposit()
RETURNS TABLE(id uuid, full_name text, email text, role app_role)
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

-- =============================================================================
-- PART 12: SESSION MANAGEMENT
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rotate_refresh_token(p_user_id uuid, p_old_token_hash text, p_new_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session_id uuid;
BEGIN
  UPDATE user_sessions
  SET 
    refresh_token_hash = hash_token(p_new_token),
    refresh_count = refresh_count + 1,
    last_refresh_at = now(),
    last_activity = now()
  WHERE user_id = p_user_id 
    AND refresh_token_hash = p_old_token_hash
    AND is_active = true
  RETURNING id INTO v_session_id;
  
  RETURN v_session_id IS NOT NULL;
END;
$$;

-- =============================================================================
-- PART 13: ENABLE REALTIME FOR KEY TABLES
-- =============================================================================

DO $$
DECLARE
  tables_to_add TEXT[] := ARRAY['attendance', 'reminders', 'notifications', 'messages', 'group_chat_messages', 'leads', 'clients', 'deposits', 'call_history'];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables_to_add LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' 
      AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- =============================================================================
-- PART 14: SECURE VIEWS (matching actual table columns)
-- =============================================================================

-- Create secure leads view that hides phone/email based on settings
DROP VIEW IF EXISTS leads_secure CASCADE;
CREATE VIEW leads_secure AS
SELECT 
  l.id,
  l.name,
  CASE 
    WHEN can_view_email() THEN l.email
    ELSE '***hidden***'
  END AS email,
  CASE 
    WHEN can_view_phone() THEN l.phone
    ELSE '***hidden***'
  END AS phone,
  l.country,
  l.source,
  l.status,
  l.conversion_probability,
  l.last_contacted_at,
  l.assigned_to,
  l.created_by,
  l.admin_id,
  l.created_at,
  l.updated_at,
  l.company,
  l.job_title,
  l.best_contact_time,
  l.estimated_close_date,
  l.next_best_action,
  l.balance,
  l.equity,
  l.pending_conversion,
  l.is_transferred,
  l.transferred_by,
  l.position
FROM leads l
WHERE can_access_tenant(l.admin_id);

-- Create secure clients view (matching actual columns)
DROP VIEW IF EXISTS clients_secure CASCADE;
CREATE VIEW clients_secure AS
SELECT 
  c.id,
  c.name,
  CASE 
    WHEN can_view_email() THEN c.email
    ELSE '***hidden***'
  END AS email,
  CASE 
    WHEN can_view_phone() THEN c.home_phone
    ELSE '***hidden***'
  END AS home_phone,
  c.country,
  c.status,
  c.source,
  c.balance,
  c.equity,
  c.margin_level,
  c.open_trades,
  c.deposits,
  c.kyc_status,
  c.satisfaction_score,
  c.pipeline_status,
  c.potential_value,
  c.actual_value,
  c.converted_from_lead_id,
  c.assigned_to,
  c.created_by,
  c.transferred_by,
  c.admin_id,
  c.created_at,
  c.updated_at,
  c.join_date
FROM clients c
WHERE can_access_tenant(c.admin_id);

-- =============================================================================
-- PART 15: AUTH USER TRIGGER (CRITICAL - Creates profile on signup)
-- =============================================================================

-- Function: handle_new_user() -> trigger
-- This function is triggered when a new user signs up via Supabase Auth
-- It creates their profile and assigns the default AGENT role
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert profile
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  
  -- Assign default role (AGENT) to new users
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'AGENT');
  
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users (only works if you have access to auth schema)
-- NOTE: This trigger may already exist. Run separately if needed:
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- PART 16: REMINDERS UPDATED_AT TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_reminders_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Apply updated_at triggers to tables that need them
DROP TRIGGER IF EXISTS update_reminders_updated_at ON reminders;
CREATE TRIGGER update_reminders_updated_at
  BEFORE UPDATE ON reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_reminders_updated_at();

DROP TRIGGER IF EXISTS update_leads_updated_at ON leads;
CREATE TRIGGER update_leads_updated_at
  BEFORE UPDATE ON leads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_clients_updated_at ON clients;
CREATE TRIGGER update_clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_attendance_updated_at ON attendance;
CREATE TRIGGER update_attendance_updated_at
  BEFORE UPDATE ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_admin_settings_updated_at ON admin_settings;
CREATE TRIGGER update_admin_settings_updated_at
  BEFORE UPDATE ON admin_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_general_settings_updated_at ON general_settings;
CREATE TRIGGER update_general_settings_updated_at
  BEFORE UPDATE ON general_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_kyc_records_updated_at ON kyc_records;
CREATE TRIGGER update_kyc_records_updated_at
  BEFORE UPDATE ON kyc_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_email_templates_updated_at ON email_templates;
CREATE TRIGGER update_email_templates_updated_at
  BEFORE UPDATE ON email_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_email_credentials_updated_at ON email_credentials;
CREATE TRIGGER update_email_credentials_updated_at
  BEFORE UPDATE ON email_credentials
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- =============================================================================
-- PART 17: ROLE CHANGE TRIGGER FOR GROUP SYNC
-- =============================================================================

DROP TRIGGER IF EXISTS on_role_change_sync_groups ON user_roles;
CREATE TRIGGER on_role_change_sync_groups
  AFTER INSERT OR UPDATE OR DELETE ON user_roles
  FOR EACH ROW
  EXECUTE FUNCTION handle_role_change_for_groups();

-- =============================================================================
-- PART 18: DEPOSIT NOTIFICATION TRIGGER
-- =============================================================================

DROP TRIGGER IF EXISTS notify_on_pending_deposit ON deposits;
CREATE TRIGGER notify_on_pending_deposit
  AFTER INSERT ON deposits
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION notify_admins_of_pending_deposit();

-- =============================================================================
-- PART 19: STORAGE BUCKETS (Run if buckets don't exist)
-- =============================================================================

-- Note: Storage buckets are typically created via Supabase Dashboard
-- These are for reference:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('documents', 'documents', false) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('celebration-sounds', 'celebration-sounds', true) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('celebration-videos', 'celebration-videos', true) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('email-images', 'email-images', true) ON CONFLICT DO NOTHING;

-- =============================================================================
-- PART 20: DEFAULT STATIC GROUP CHATS
-- =============================================================================

-- Create default static groups if they don't exist
INSERT INTO group_chats (name, description, is_static, created_by)
VALUES 
  ('Info', 'Information channel for all team members', true, NULL),
  ('Ret', 'Retention team channel', true, NULL),
  ('Con', 'Conversion team channel', true, NULL)
ON CONFLICT DO NOTHING;

-- Sync members after creating groups
SELECT sync_static_group_members();

-- =============================================================================
-- PART 21: USER_PERMISSIONS TABLE (if not exists)
-- =============================================================================

-- This table is referenced by has_permission function
CREATE TABLE IF NOT EXISTS public.user_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  permission app_permission NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id, permission)
);

-- =============================================================================
-- PART 21b: REMINDERS TABLE (if not exists)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  due_date timestamp with time zone NOT NULL,
  priority text NOT NULL DEFAULT 'medium',
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamp with time zone,
  related_entity_type text,
  related_entity_id uuid,
  timezone text,
  admin_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own reminders" ON public.reminders;
DROP POLICY IF EXISTS "Users can create their own reminders" ON public.reminders;
DROP POLICY IF EXISTS "Users can update their own reminders" ON public.reminders;
DROP POLICY IF EXISTS "Users can delete their own reminders" ON public.reminders;

CREATE POLICY "Users can view their own reminders"
  ON public.reminders FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can create their own reminders"
  ON public.reminders FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own reminders"
  ON public.reminders FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own reminders"
  ON public.reminders FOR DELETE
  USING (user_id = auth.uid());

-- =============================================================================
-- PART 21c: RECEIVED_EMAILS TABLE (if not exists)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.received_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  message_id text NOT NULL,
  sender_email text NOT NULL,
  sender_name text,
  recipient_email text NOT NULL,
  subject text NOT NULL,
  body_text text,
  body_html text,
  received_at timestamp with time zone NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  in_reply_to text,
  email_references text,
  admin_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.received_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their received emails"
  ON public.received_emails FOR SELECT
  USING (can_access_tenant(admin_id) AND (user_id = auth.uid() OR has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER')));

CREATE POLICY "Users can insert their received emails"
  ON public.received_emails FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their received emails"
  ON public.received_emails FOR UPDATE
  USING (user_id = auth.uid());

-- =============================================================================
-- PART 21d: SENT_EMAILS TABLE (if not exists)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.sent_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL,
  recipient_email text NOT NULL,
  subject text NOT NULL,
  body_text text,
  body_html text,
  cc text[],
  bcc text[],
  attachments jsonb,
  status text NOT NULL DEFAULT 'pending',
  provider_message_id text,
  error_message text,
  is_manual_recipient boolean NOT NULL DEFAULT false,
  sent_at timestamp with time zone,
  admin_id uuid,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.sent_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view sent emails in their tenant"
  ON public.sent_emails FOR SELECT
  USING (can_access_tenant(admin_id) AND (sender_id = auth.uid() OR has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER')));

CREATE POLICY "Users can send emails"
  ON public.sent_emails FOR INSERT
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update their sent emails"
  ON public.sent_emails FOR UPDATE
  USING (sender_id = auth.uid());

ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own permissions"
  ON public.user_permissions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage permissions"
  ON public.user_permissions FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER'));

-- =============================================================================
-- PART 21e: NOTIFICATIONS TABLE (if not exists)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type notification_type NOT NULL,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  related_entity_type text,
  related_entity_id uuid,
  related_profile_id uuid,
  admin_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can delete their own notifications"
  ON public.notifications FOR DELETE
  USING (user_id = auth.uid());

-- =============================================================================
-- PART 22: USER_SESSIONS TABLE (if not exists)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  session_token text NOT NULL,
  refresh_token_hash text,
  ip_address text,
  user_agent text,
  is_active boolean DEFAULT true,
  refresh_count integer DEFAULT 0,
  last_refresh_at timestamp with time zone,
  last_activity timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sessions"
  ON public.user_sessions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can manage their own sessions"
  ON public.user_sessions FOR ALL
  USING (user_id = auth.uid());

-- =============================================================================
-- PART 23: SALE_BRANCHES TABLE (referenced by deposits)
-- =============================================================================

-- Note: sale_branches tracks opportunities/branches per client in pipeline
CREATE TABLE IF NOT EXISTS public.sale_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  name text NOT NULL,
  value numeric NOT NULL DEFAULT 0,
  status pipeline_stage NOT NULL DEFAULT 'UPCOMING_SALE',
  admin_id uuid REFERENCES profiles(id),
  created_by uuid NOT NULL REFERENCES profiles(id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.sale_branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view sale branches in their tenant"
  ON public.sale_branches FOR SELECT
  USING (can_access_tenant(admin_id));

CREATE POLICY "Users can create sale branches"
  ON public.sale_branches FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Admins can manage sale branches"
  ON public.sale_branches FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER'));

-- =============================================================================
-- PART 24: RLS POLICIES FOR CORE TABLES (Defined after helper functions)
-- =============================================================================

-- PROFILES RLS
CREATE POLICY "Users can view profiles in their tenant"
  ON public.profiles FOR SELECT
  USING (can_access_tenant(admin_id) OR id = auth.uid());

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Admins can manage all profiles in tenant"
  ON public.profiles FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER'));

-- USER_ROLES RLS
CREATE POLICY "Users can view roles"
  ON public.user_roles FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage roles"
  ON public.user_roles FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'ADMIN'));

-- USER_PREFERENCES RLS
CREATE POLICY "Users can view their own preferences"
  ON public.user_preferences FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can manage their own preferences"
  ON public.user_preferences FOR ALL
  USING (user_id = auth.uid());

-- LEADS RLS
CREATE POLICY "Users can view leads in their tenant"
  ON public.leads FOR SELECT
  USING (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR 
    has_role(auth.uid(), 'TENANT_OWNER') OR 
    has_role(auth.uid(), 'MANAGER') OR 
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  ));

CREATE POLICY "Users can create leads in their tenant"
  ON public.leads FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update leads in their tenant"
  ON public.leads FOR UPDATE
  USING (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR 
    has_role(auth.uid(), 'TENANT_OWNER') OR 
    has_role(auth.uid(), 'MANAGER') OR 
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  ));

CREATE POLICY "Admins manage all leads"
  ON public.leads FOR ALL
  USING (can_access_tenant(admin_id) AND (
    get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER'])
  ));

CREATE POLICY "Users with delete permission can delete leads"
  ON public.leads FOR DELETE
  USING (has_permission(auth.uid(), 'CAN_DELETE_LEADS'));

-- CLIENTS RLS
CREATE POLICY "Users can view clients in their tenant"
  ON public.clients FOR SELECT
  USING (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR 
    has_role(auth.uid(), 'TENANT_OWNER') OR 
    has_role(auth.uid(), 'MANAGER') OR 
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  ));

CREATE POLICY "Users can create clients in their tenant"
  ON public.clients FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update clients in their tenant"
  ON public.clients FOR UPDATE
  USING (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'SUPER_ADMIN') OR 
    has_role(auth.uid(), 'TENANT_OWNER') OR 
    has_role(auth.uid(), 'MANAGER') OR 
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  ));

CREATE POLICY "Admins manage all clients"
  ON public.clients FOR ALL
  USING (can_access_tenant(admin_id) AND (
    get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER'])
  ));

CREATE POLICY "Users with delete permission can delete clients"
  ON public.clients FOR DELETE
  USING (has_permission(auth.uid(), 'CAN_DELETE_LEADS'));

-- =============================================================================
-- PART 25: VERIFICATION QUERIES
-- =============================================================================

-- Check all functions were created
SELECT proname, pronargs, proargnames
FROM pg_proc 
WHERE proname IN (
  'has_role', 
  'has_permission',
  'get_user_admin_id', 
  'can_access_tenant', 
  'is_super_admin',
  'is_admin_or_tenant_owner',
  'get_user_role_direct',
  'get_tenant_user_ids',
  'can_view_phone',
  'can_view_email',
  'encrypt_sensitive',
  'decrypt_sensitive',
  'hash_token',
  'get_or_create_tenant_settings',
  'get_or_create_general_settings',
  'is_ip_blocked',
  'count_failed_attempts',
  'check_ip_whitelist',
  'log_audit_event',
  'cleanup_expired_sessions',
  'sync_static_group_members',
  'handle_role_change_for_groups',
  'handle_new_user',
  'update_updated_at',
  'update_reminders_updated_at',
  'set_profile_admin_id',
  'set_admin_id_on_insert',
  'set_admin_id_from_user',
  'calculate_working_hours',
  'get_agents_for_deposit',
  'rotate_refresh_token',
  'notify_admins_of_pending_deposit',
  'is_group_member',
  'is_static_group',
  'can_delete_user'
)
ORDER BY proname;

-- Check all triggers
SELECT tgname, tgrelid::regclass::text as table_name, tgenabled
FROM pg_trigger 
WHERE NOT tgisinternal
ORDER BY table_name, tgname;

-- Check views exist
SELECT viewname FROM pg_views WHERE schemaname = 'public' AND viewname LIKE '%_secure';

-- Check enums exist
SELECT typname FROM pg_type WHERE typtype = 'e' AND typnamespace = 'public'::regnamespace;

-- Check realtime publications
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- =============================================================================
-- PART 26: REMAINING TABLES (lead_tasks, lead_comments, lead_activities, etc.)
-- =============================================================================

-- Lead activities table
CREATE TABLE IF NOT EXISTS public.lead_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL,
  user_id uuid NOT NULL,
  activity_type text NOT NULL,
  description text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view activities for accessible leads"
  ON public.lead_activities FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_activities.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() 
         OR has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'))
  ));

CREATE POLICY "Users can create activities for accessible leads"
  ON public.lead_activities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Lead tasks table
CREATE TABLE IF NOT EXISTS public.lead_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL,
  assigned_to uuid NOT NULL,
  title text NOT NULL,
  description text,
  due_date timestamp with time zone,
  completed boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view tasks for accessible leads"
  ON public.lead_tasks FOR SELECT
  USING (assigned_to = auth.uid() OR EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_tasks.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() 
         OR has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'))
  ));

CREATE POLICY "Users can create tasks for accessible leads"
  ON public.lead_tasks FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_tasks.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() 
         OR has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'))
  ));

CREATE POLICY "Users can update their assigned tasks"
  ON public.lead_tasks FOR UPDATE
  USING (assigned_to = auth.uid());

CREATE POLICY "Users can delete their assigned tasks"
  ON public.lead_tasks FOR DELETE
  USING (assigned_to = auth.uid());

CREATE POLICY "Managers can manage all tasks"
  ON public.lead_tasks FOR ALL
  USING (has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'));

-- Lead comments table
CREATE TABLE IF NOT EXISTS public.lead_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL,
  user_id uuid NOT NULL,
  comment text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view comments for accessible leads"
  ON public.lead_comments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_comments.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() 
         OR has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'))
  ));

CREATE POLICY "Users can create comments for accessible leads"
  ON public.lead_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_comments.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() 
         OR has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'))
  ));

CREATE POLICY "Users can delete their own comments"
  ON public.lead_comments FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "Managers can delete all comments"
  ON public.lead_comments FOR DELETE
  USING (has_role(auth.uid(), 'ADMIN') OR has_role(auth.uid(), 'MANAGER'));

-- Lead groups table
CREATE TABLE IF NOT EXISTS public.lead_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  admin_id uuid,
  created_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view lead groups in their tenant"
  ON public.lead_groups FOR SELECT
  USING (can_access_tenant(admin_id));

CREATE POLICY "Users can create lead groups"
  ON public.lead_groups FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Admins can manage lead groups"
  ON public.lead_groups FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER'));

-- Lead group members table
CREATE TABLE IF NOT EXISTS public.lead_group_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL,
  lead_id uuid NOT NULL,
  added_by uuid NOT NULL,
  added_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(group_id, lead_id)
);

ALTER TABLE public.lead_group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view group members"
  ON public.lead_group_members FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM lead_groups WHERE lead_groups.id = lead_group_members.group_id AND can_access_tenant(lead_groups.admin_id)
  ));

CREATE POLICY "Users can add leads to groups"
  ON public.lead_group_members FOR INSERT
  WITH CHECK (auth.uid() = added_by);

CREATE POLICY "Admins can manage group members"
  ON public.lead_group_members FOR ALL
  USING (has_role(auth.uid(), 'SUPER_ADMIN') OR has_role(auth.uid(), 'TENANT_OWNER') OR has_role(auth.uid(), 'MANAGER'));

-- Lead statuses table (custom statuses)
CREATE TABLE IF NOT EXISTS public.lead_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color text DEFAULT '#6366f1',
  position integer DEFAULT 0,
  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lead_statuses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view lead statuses"
  ON public.lead_statuses FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage lead statuses"
  ON public.lead_statuses FOR ALL
  USING (has_role(auth.uid(), 'ADMIN'));

-- Messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their conversations"
  ON public.messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM conversations
    WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
  ));

CREATE POLICY "Users can send messages in their conversations"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id AND EXISTS (
    SELECT 1 FROM conversations
    WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
  ));

CREATE POLICY "Users can update their own messages"
  ON public.messages FOR UPDATE
  USING (sender_id = auth.uid());

-- =============================================================================
-- SUMMARY OF ALL CORE TABLES CREATED:
-- =============================================================================
-- profiles, user_roles, user_preferences, leads, clients, user_permissions,
-- user_sessions, sale_branches, reminders, notifications, received_emails,
-- sent_emails, group_chats, group_chat_members, group_chat_messages,
-- admin_settings, general_settings, attendance, call_history, documents,
-- kyc_records, deposits, email_credentials, email_signatures, email_templates,
-- audit_logs, auth_attempts, ip_whitelist, lead_groups, lead_group_members,
-- lead_activities, lead_comments, lead_tasks, lead_statuses,
-- client_activities, client_comments, client_tasks, client_statuses,
-- client_withdrawals, conversations, messages

-- =============================================================================
-- SUMMARY OF ALL FUNCTIONS CREATED:
-- =============================================================================
-- 1.  has_role(_user_id uuid, _role app_role) -> boolean
-- 2.  has_permission(_user_id uuid, _permission app_permission) -> boolean
-- 3.  is_super_admin(_user_id uuid) -> boolean
-- 4.  is_admin_or_tenant_owner(_user_id uuid) -> boolean
-- 5.  get_user_role_direct(check_user_id uuid) -> text
-- 6.  get_user_admin_id(p_user_id uuid) -> uuid
-- 7.  can_access_tenant(_admin_id uuid) -> boolean
-- 8.  get_tenant_user_ids(_user_id uuid) -> SETOF uuid
-- 9.  is_group_member(p_group_chat_id uuid, p_user_id uuid) -> boolean
-- 10. is_static_group(p_group_chat_id uuid) -> boolean
-- 11. can_delete_user(_target_user_id uuid, _current_user_id uuid) -> boolean
-- 12. can_view_phone() -> boolean
-- 13. can_view_email() -> boolean
-- 14. get_encryption_key() -> bytea
-- 15. encrypt_sensitive(p_data text) -> text
-- 16. decrypt_sensitive(p_encrypted text) -> text
-- 17. hash_token(p_token text) -> text
-- 18. get_or_create_tenant_settings(p_tenant_id uuid) -> uuid
-- 19. get_or_create_general_settings(p_tenant_id uuid) -> uuid
-- 20. is_ip_blocked(p_ip_address text) -> boolean
-- 21. count_failed_attempts(p_ip_address text, p_minutes integer) -> integer
-- 22. check_ip_whitelist(p_user_id uuid, p_ip_address text) -> boolean
-- 23. log_audit_event(...) -> uuid
-- 24. cleanup_expired_sessions() -> void
-- 25. set_profile_admin_id() -> trigger
-- 26. set_admin_id_on_insert() -> trigger
-- 27. set_admin_id_from_user() -> trigger
-- 28. update_updated_at() -> trigger
-- 29. update_reminders_updated_at() -> trigger
-- 30. sync_static_group_members() -> void
-- 31. handle_role_change_for_groups() -> trigger
-- 32. notify_admins_of_pending_deposit() -> trigger
-- 33. calculate_working_hours(p_clock_in, p_clock_out) -> numeric
-- 34. get_agents_for_deposit() -> TABLE
-- 35. rotate_refresh_token(p_user_id, p_old_token_hash, p_new_token) -> boolean
-- 36. handle_new_user() -> trigger

-- =============================================================================
-- DONE! Complete database setup script for Kybalion CRM.
-- Run in Supabase SQL Editor to set up a fresh database.
-- =============================================================================

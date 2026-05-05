-- ============================================================================
-- RLS POLICIES EXPORT
-- Generated: 2026-01-15
-- Project: Kybalion CRM
-- ============================================================================

-- ============================================================================
-- SECURITY DEFINER FUNCTIONS
-- These functions are used by RLS policies to check roles/permissions
-- ============================================================================

-- Check if user has a specific role
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
$$;

-- Check if user has a specific permission
CREATE OR REPLACE FUNCTION public.has_permission(_user_id uuid, _permission app_permission)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_permissions
    WHERE user_id = _user_id AND permission = _permission
  );
$$;

-- Get user role directly (returns text)
CREATE OR REPLACE FUNCTION public.get_user_role_direct(check_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT role::text FROM public.user_roles WHERE user_id = check_user_id LIMIT 1
$$;

-- Check if user can access tenant data
CREATE OR REPLACE FUNCTION public.can_access_tenant(_admin_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_admin_id uuid;
  v_profile_admin_id uuid;
BEGIN
  -- SUPER_ADMIN can access everything
  IF has_role(auth.uid(), 'SUPER_ADMIN') THEN
    RETURN true;
  END IF;
  
  -- Get current user's admin_id from profile
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

-- Get managed agent IDs for super agent
CREATE OR REPLACE FUNCTION public.get_managed_agent_ids(_super_agent_id uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT id FROM profiles WHERE created_by = _super_agent_id
$$;

-- Check if group chat is static
CREATE OR REPLACE FUNCTION public.is_static_group(p_group_chat_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.group_chats
    WHERE id = p_group_chat_id
      AND is_static = true
  )
$$;

-- Check if user is member of group chat
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_chat_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.group_chat_members
    WHERE group_chat_id = p_group_chat_id
      AND user_id = p_user_id
  )
$$;


-- ============================================================================
-- TABLE: admin_settings
-- ============================================================================

-- Policy: Admins can manage their own settings
CREATE POLICY "Admins can manage their own settings"
ON public.admin_settings FOR ALL
TO public
USING ((admin_id = auth.uid()) OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role))
WITH CHECK ((admin_id = auth.uid()) OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: Super admins can view all admin settings
CREATE POLICY "Super admins can view all admin settings"
ON public.admin_settings FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: Users can view their admin settings
CREATE POLICY "Users can view their admin settings"
ON public.admin_settings FOR SELECT
TO public
USING (can_access_tenant(admin_id));


-- ============================================================================
-- TABLE: attendance
-- ============================================================================

-- Policy: Admins manage all attendance in tenant
CREATE POLICY "Admins manage all attendance in tenant"
ON public.attendance FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text])))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text]));

-- Policy: Admins view all attendance in tenant
CREATE POLICY "Admins view all attendance in tenant"
ON public.attendance FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text])));

-- Policy: Users insert own attendance
CREATE POLICY "Users insert own attendance"
ON public.attendance FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy: Users update own attendance
CREATE POLICY "Users update own attendance"
ON public.attendance FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users view own attendance
CREATE POLICY "Users view own attendance"
ON public.attendance FOR SELECT
TO authenticated
USING (user_id = auth.uid());


-- ============================================================================
-- TABLE: audit_logs
-- ============================================================================

-- Policy: Authenticated users can insert audit logs
CREATE POLICY "Authenticated users can insert audit logs"
ON public.audit_logs FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Managers can view audit logs in tenant
CREATE POLICY "Managers can view audit logs in tenant"
ON public.audit_logs FOR SELECT
TO public
USING (has_role(auth.uid(), 'MANAGER'::app_role) AND can_access_tenant(admin_id));

-- Policy: Super admins can view all audit logs
CREATE POLICY "Super admins can view all audit logs"
ON public.audit_logs FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: Tenant owners can view audit logs in their tenant
CREATE POLICY "Tenant owners can view audit logs in their tenant"
ON public.audit_logs FOR SELECT
TO public
USING (has_role(auth.uid(), 'TENANT_OWNER'::app_role) AND ((admin_id = auth.uid()) OR (user_id IN (
  SELECT profiles.id FROM profiles WHERE profiles.admin_id = auth.uid()
))));

-- Policy: Users can view own audit logs
CREATE POLICY "Users can view own audit logs"
ON public.audit_logs FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- TABLE: auth_attempts
-- ============================================================================

-- Policy: Admins can read all auth attempts
CREATE POLICY "Admins can read all auth attempts"
ON public.auth_attempts FOR SELECT
TO authenticated
USING (EXISTS (
  SELECT 1 FROM user_roles
  WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = ANY (ARRAY['SUPER_ADMIN'::app_role, 'ADMIN'::app_role, 'MANAGER'::app_role])
));

-- Policy: Admins can view all auth attempts
CREATE POLICY "Admins can view all auth attempts"
ON public.auth_attempts FOR SELECT
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role));

-- Policy: Anyone can insert auth attempts
CREATE POLICY "Anyone can insert auth attempts"
ON public.auth_attempts FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Policy: System can insert auth attempts
CREATE POLICY "System can insert auth attempts"
ON public.auth_attempts FOR INSERT
TO public
WITH CHECK (true);

-- Policy: Users can read own auth attempts
CREATE POLICY "Users can read own auth attempts"
ON public.auth_attempts FOR SELECT
TO authenticated
USING (user_email = (SELECT users.email FROM auth.users WHERE users.id = auth.uid())::text);


-- ============================================================================
-- TABLE: call_history
-- ============================================================================

-- Policy: Service role can update call history
CREATE POLICY "Service role can update call history"
ON public.call_history FOR UPDATE
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Users can create their own call history
CREATE POLICY "Users can create their own call history"
ON public.call_history FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own call history
CREATE POLICY "Users can update their own call history"
ON public.call_history FOR UPDATE
TO public
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view call history in their tenant
CREATE POLICY "Users can view call history in their tenant"
ON public.call_history FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR
  has_role(auth.uid(), 'ADMIN'::app_role) OR
  has_role(auth.uid(), 'MANAGER'::app_role) OR
  user_id = auth.uid()
));

-- Policy: Users can view their own call history
CREATE POLICY "Users can view their own call history"
ON public.call_history FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- TABLE: client_activities
-- ============================================================================

-- Policy: Users can create client activities
CREATE POLICY "Users can create client activities"
ON public.client_activities FOR INSERT
TO public
WITH CHECK ((auth.uid() = user_id) AND (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_activities.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
         OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
         OR has_role(auth.uid(), 'MANAGER'::app_role))
)));

-- Policy: Users can view client activities
CREATE POLICY "Users can view client activities"
ON public.client_activities FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = client_activities.client_id
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid() OR can_access_tenant(clients.admin_id))
  ));


-- ============================================================================
-- TABLE: client_comments
-- ============================================================================

-- Policy: Managers and admins can delete all comments
CREATE POLICY "Managers and admins can delete all comments"
ON public.client_comments FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Users can create comments for accessible clients
CREATE POLICY "Users can create comments for accessible clients"
ON public.client_comments FOR INSERT
TO public
WITH CHECK ((auth.uid() = user_id) AND (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_comments.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
)));

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete their own comments"
ON public.client_comments FOR DELETE
TO public
USING (user_id = auth.uid());

-- Policy: Users can view comments for accessible clients
CREATE POLICY "Users can view comments for accessible clients"
ON public.client_comments FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_comments.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));


-- ============================================================================
-- TABLE: client_group_members
-- ============================================================================

-- Policy: Authorized users can add client group members
CREATE POLICY "Authorized users can add client group members"
ON public.client_group_members FOR INSERT
TO public
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role));

-- Policy: Authorized users can remove client group members
CREATE POLICY "Authorized users can remove client group members"
ON public.client_group_members FOR DELETE
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role));

-- Policy: Users can view client group members in tenant
CREATE POLICY "Users can view client group members in tenant"
ON public.client_group_members FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM client_groups g
  WHERE g.id = client_group_members.group_id AND can_access_tenant(g.admin_id)
));


-- ============================================================================
-- TABLE: client_groups
-- ============================================================================

-- Policy: Authorized users can create client groups
CREATE POLICY "Authorized users can create client groups"
ON public.client_groups FOR INSERT
TO public
WITH CHECK ((auth.uid() = created_by) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Authorized users can delete non-system client groups
CREATE POLICY "Authorized users can delete non-system client groups"
ON public.client_groups FOR DELETE
TO public
USING ((is_system = false) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR ((has_role(auth.uid(), 'TENANT_OWNER'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
      AND (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id)))
));

-- Policy: Authorized users can update client groups
CREATE POLICY "Authorized users can update client groups"
ON public.client_groups FOR UPDATE
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR ((has_role(auth.uid(), 'TENANT_OWNER'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
      AND (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id))));

-- Policy: Users can view client groups in tenant
CREATE POLICY "Users can view client groups in tenant"
ON public.client_groups FOR SELECT
TO public
USING (can_access_tenant(admin_id));


-- ============================================================================
-- TABLE: client_statuses
-- ============================================================================

-- Policy: Admins and tenant owners can delete client statuses
CREATE POLICY "Admins and tenant owners can delete client statuses"
ON public.client_statuses FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Admins and tenant owners can insert client statuses
CREATE POLICY "Admins and tenant owners can insert client statuses"
ON public.client_statuses FOR INSERT
TO public
WITH CHECK (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Admins and tenant owners can update client statuses
CREATE POLICY "Admins and tenant owners can update client statuses"
ON public.client_statuses FOR UPDATE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Anyone can view client statuses
CREATE POLICY "Anyone can view client statuses"
ON public.client_statuses FOR SELECT
TO public
USING (auth.uid() IS NOT NULL);


-- ============================================================================
-- TABLE: client_tasks
-- ============================================================================

-- Policy: Managers and admins can delete all tasks
CREATE POLICY "Managers and admins can delete all tasks"
ON public.client_tasks FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Managers and admins can update all tasks
CREATE POLICY "Managers and admins can update all tasks"
ON public.client_tasks FOR UPDATE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Users can create tasks for accessible clients
CREATE POLICY "Users can create tasks for accessible clients"
ON public.client_tasks FOR INSERT
TO public
WITH CHECK (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_tasks.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can delete their assigned tasks
CREATE POLICY "Users can delete their assigned tasks"
ON public.client_tasks FOR DELETE
TO public
USING (assigned_to = auth.uid());

-- Policy: Users can update their assigned tasks
CREATE POLICY "Users can update their assigned tasks"
ON public.client_tasks FOR UPDATE
TO public
USING (assigned_to = auth.uid());

-- Policy: Users can view tasks for accessible clients
CREATE POLICY "Users can view tasks for accessible clients"
ON public.client_tasks FOR SELECT
TO public
USING ((assigned_to = auth.uid()) OR EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_tasks.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));


-- ============================================================================
-- TABLE: client_withdrawals
-- ============================================================================

-- Policy: Admins can update all withdrawals
CREATE POLICY "Admins can update all withdrawals"
ON public.client_withdrawals FOR UPDATE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role));

-- Policy: Users can create withdrawals for accessible clients
CREATE POLICY "Users can create withdrawals for accessible clients"
ON public.client_withdrawals FOR INSERT
TO public
WITH CHECK (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_withdrawals.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can view withdrawals for accessible clients
CREATE POLICY "Users can view withdrawals for accessible clients"
ON public.client_withdrawals FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = client_withdrawals.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));


-- ============================================================================
-- TABLE: clients
-- ============================================================================

-- Policy: Admins manage all clients
CREATE POLICY "Admins manage all clients"
ON public.clients FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text])))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text]));

-- Policy: Super agents with assign permission can view all clients in tenant
CREATE POLICY "Super agents with assign permission can view all clients in ten"
ON public.clients FOR SELECT
TO public
USING (can_access_tenant(admin_id)
  AND has_role(auth.uid(), 'SUPER_AGENT'::app_role)
  AND has_permission(auth.uid(), 'CAN_ASSIGN_ALL'::app_permission));

-- Policy: Users can create clients in their tenant
CREATE POLICY "Users can create clients in their tenant"
ON public.clients FOR INSERT
TO public
WITH CHECK (auth.uid() = created_by);

-- Policy: Users can update clients in their tenant
CREATE POLICY "Users can update clients in their tenant"
ON public.clients FOR UPDATE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR assigned_to = auth.uid()
  OR created_by = auth.uid()
));

-- Policy: Users can view clients in their tenant
CREATE POLICY "Users can view clients in their tenant"
ON public.clients FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR (has_role(auth.uid(), 'SUPER_AGENT'::app_role) AND (
      assigned_to = auth.uid() OR assigned_to IN (SELECT get_managed_agent_ids(auth.uid()))
  ))
  OR (has_role(auth.uid(), 'AGENT'::app_role) AND transferring_agent = auth.uid())
));

-- Policy: Users with delete permission can delete clients
CREATE POLICY "Users with delete permission can delete clients"
ON public.clients FOR DELETE
TO public
USING (has_permission(auth.uid(), 'CAN_DELETE_LEADS'::app_permission));

-- Policy: clients_delete_policy
CREATE POLICY "clients_delete_policy"
ON public.clients FOR DELETE
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid()
    AND ur.role = ANY (ARRAY['SUPER_ADMIN'::app_role, 'TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role])
));

-- Policy: clients_insert_policy
CREATE POLICY "clients_insert_policy"
ON public.clients FOR INSERT
TO public
WITH CHECK (true);

-- Policy: clients_select_policy
CREATE POLICY "clients_select_policy"
ON public.clients FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid() AND (
    ur.role = 'SUPER_ADMIN'::app_role
    OR ((ur.role = ANY (ARRAY['TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role]))
        AND clients.admin_id = (SELECT profiles.admin_id FROM profiles WHERE profiles.id = auth.uid()))
    OR (ur.role = 'TENANT_OWNER'::app_role AND clients.admin_id = auth.uid())
    OR (ur.role = 'SUPER_AGENT'::app_role AND clients.assigned_to = auth.uid())
  )
));

-- Policy: clients_update_policy
CREATE POLICY "clients_update_policy"
ON public.clients FOR UPDATE
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid() AND (
    ur.role = ANY (ARRAY['SUPER_ADMIN'::app_role, 'TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role])
    OR clients.assigned_to = auth.uid()
  )
));


-- ============================================================================
-- TABLE: commission_tier_settings
-- ============================================================================

-- Policy: Tenant owners can delete commission tiers
CREATE POLICY "Tenant owners can delete commission tiers"
ON public.commission_tier_settings FOR DELETE
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid()));

-- Policy: Tenant owners can manage commission tiers
CREATE POLICY "Tenant owners can manage commission tiers"
ON public.commission_tier_settings FOR INSERT
TO authenticated
WITH CHECK ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid()));

-- Policy: Tenant owners can update commission tiers
CREATE POLICY "Tenant owners can update commission tiers"
ON public.commission_tier_settings FOR UPDATE
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid()))
WITH CHECK ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid()));

-- Policy: Users can view commission tiers in their tenant
CREATE POLICY "Users can view commission tiers in their tenant"
ON public.commission_tier_settings FOR SELECT
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid())
  OR ((SELECT p.admin_id FROM profiles p WHERE p.id = auth.uid()) IS NOT NULL
      AND admin_id = (SELECT p.admin_id FROM profiles p WHERE p.id = auth.uid())));


-- ============================================================================
-- TABLE: conversations
-- ============================================================================

-- Policy: Admins can view all conversations
CREATE POLICY "Admins can view all conversations"
ON public.conversations FOR SELECT
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role));

-- Policy: Users can create conversations
CREATE POLICY "Users can create conversations"
ON public.conversations FOR INSERT
TO public
WITH CHECK ((auth.uid() = user1_id) OR (auth.uid() = user2_id));

-- Policy: Users can update their conversations
CREATE POLICY "Users can update their conversations"
ON public.conversations FOR UPDATE
TO public
USING ((auth.uid() = user1_id) OR (auth.uid() = user2_id));

-- Policy: Users can view their own conversations
CREATE POLICY "Users can view their own conversations"
ON public.conversations FOR SELECT
TO public
USING ((auth.uid() = user1_id) OR (auth.uid() = user2_id));


-- ============================================================================
-- TABLE: deposits
-- ============================================================================

-- Policy: Tenant owners and super agents can delete deposits
CREATE POLICY "Tenant owners and super agents can delete deposits"
ON public.deposits FOR DELETE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role)
));

-- Policy: Users can create deposits in their tenant
CREATE POLICY "Users can create deposits in their tenant"
ON public.deposits FOR INSERT
TO public
WITH CHECK ((auth.uid() = created_by) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role)
));

-- Policy: Users can update deposits in their tenant
CREATE POLICY "Users can update deposits in their tenant"
ON public.deposits FOR UPDATE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Users can view deposits in their tenant
CREATE POLICY "Users can view deposits in their tenant"
ON public.deposits FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR ((admin_id IS NOT NULL) AND can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'TENANT_OWNER'::app_role)
    OR has_role(auth.uid(), 'ADMIN'::app_role)
    OR has_role(auth.uid(), 'MANAGER'::app_role)
    OR agent_id = auth.uid()
    OR super_agent_id = auth.uid()
    OR split_super_agent_id = auth.uid()
  )));


-- ============================================================================
-- TABLE: documents
-- ============================================================================

-- Policy: Admins can delete documents in tenant
CREATE POLICY "Admins can delete documents in tenant"
ON public.documents FOR DELETE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Users can delete their own documents
CREATE POLICY "Users can delete their own documents"
ON public.documents FOR DELETE
TO public
USING (uploaded_by = auth.uid());

-- Policy: Users can upload documents in tenant
CREATE POLICY "Users can upload documents in tenant"
ON public.documents FOR INSERT
TO public
WITH CHECK ((auth.uid() = uploaded_by) AND (
  ((lead_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = documents.lead_id
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
  OR ((client_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = documents.client_id
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
));

-- Policy: Users can view documents in tenant
CREATE POLICY "Users can view documents in tenant"
ON public.documents FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  ((lead_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = documents.lead_id
      AND can_access_tenant(leads.admin_id)
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
  OR ((client_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = documents.client_id
      AND can_access_tenant(clients.admin_id)
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
));


-- ============================================================================
-- TABLE: email_credentials
-- ============================================================================

-- Policy: Admins can manage credentials in tenant
CREATE POLICY "Admins can manage credentials in tenant"
ON public.email_credentials FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
))
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Users can view their credentials in tenant
CREATE POLICY "Users can view their credentials in tenant"
ON public.email_credentials FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  user_id = auth.uid()
  OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
));


-- ============================================================================
-- TABLE: email_signatures
-- ============================================================================

-- Policy: Users can create their signature
CREATE POLICY "Users can create their signature"
ON public.email_signatures FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their signature
CREATE POLICY "Users can delete their signature"
ON public.email_signatures FOR DELETE
TO public
USING (user_id = auth.uid());

-- Policy: Users can update their signature
CREATE POLICY "Users can update their signature"
ON public.email_signatures FOR UPDATE
TO public
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users can view their signature in tenant
CREATE POLICY "Users can view their signature in tenant"
ON public.email_signatures FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND user_id = auth.uid());


-- ============================================================================
-- TABLE: email_templates
-- ============================================================================

-- Policy: Users can create templates in tenant
CREATE POLICY "Users can create templates in tenant"
ON public.email_templates FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete own templates
CREATE POLICY "Users can delete own templates"
ON public.email_templates FOR DELETE
TO public
USING (user_id = auth.uid());

-- Policy: Users can update own templates
CREATE POLICY "Users can update own templates"
ON public.email_templates FOR UPDATE
TO public
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users can view templates in tenant
CREATE POLICY "Users can view templates in tenant"
ON public.email_templates FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (user_id = auth.uid() OR is_shared = true));


-- ============================================================================
-- TABLE: general_settings
-- ============================================================================

-- Policy: Super admins can manage all settings
CREATE POLICY "Super admins can manage all settings"
ON public.general_settings FOR ALL
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role))
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: Tenant owners can manage their settings
CREATE POLICY "Tenant owners can manage their settings"
ON public.general_settings FOR ALL
TO public
USING ((admin_id = auth.uid()) AND has_role(auth.uid(), 'TENANT_OWNER'::app_role))
WITH CHECK ((admin_id = auth.uid()) AND has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Users can view their tenant settings
CREATE POLICY "Users can view their tenant settings"
ON public.general_settings FOR SELECT
TO public
USING (can_access_tenant(admin_id));


-- ============================================================================
-- TABLE: group_chat_members
-- ============================================================================

-- Policy: Users can view members of their groups
CREATE POLICY "Users can view members of their groups"
ON public.group_chat_members FOR SELECT
TO public
USING (is_static_group(group_chat_id) OR user_id = auth.uid() OR is_group_member(group_chat_id, auth.uid()));


-- ============================================================================
-- TABLE: group_chat_messages
-- ============================================================================

-- Policy: Users can send messages to groups
CREATE POLICY "Users can send messages to groups"
ON public.group_chat_messages FOR INSERT
TO public
WITH CHECK ((auth.uid() = sender_id) AND (is_static_group(group_chat_id) OR is_group_member(group_chat_id, auth.uid())));

-- Policy: Users can view messages in groups
CREATE POLICY "Users can view messages in groups"
ON public.group_chat_messages FOR SELECT
TO public
USING (is_static_group(group_chat_id) OR is_group_member(group_chat_id, auth.uid()));


-- ============================================================================
-- TABLE: group_chats
-- ============================================================================

-- Policy: Users can view static groups or groups they are members of
CREATE POLICY "Users can view static groups or groups they are members of"
ON public.group_chats FOR SELECT
TO public
USING ((is_static = true) OR EXISTS (
  SELECT 1 FROM group_chat_members
  WHERE group_chat_members.group_chat_id = group_chats.id
    AND group_chat_members.user_id = auth.uid()
));


-- ============================================================================
-- TABLE: ip_whitelist
-- ============================================================================

-- Policy: Super admins can view all IP whitelist entries
CREATE POLICY "Super admins can view all IP whitelist entries"
ON public.ip_whitelist FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: Tenant admins can manage IP whitelist
CREATE POLICY "Tenant admins can manage IP whitelist"
ON public.ip_whitelist FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text])))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text]));

-- Policy: Users can view their own IP whitelist in tenant
CREATE POLICY "Users can view their own IP whitelist in tenant"
ON public.ip_whitelist FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND user_id = auth.uid());


-- ============================================================================
-- TABLE: kyc_records
-- ============================================================================

-- Policy: Admins can delete kyc records in tenant
CREATE POLICY "Admins can delete kyc records in tenant"
ON public.kyc_records FOR DELETE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Users can create kyc records in tenant
CREATE POLICY "Users can create kyc records in tenant"
ON public.kyc_records FOR INSERT
TO public
WITH CHECK ((auth.uid() = created_by) AND (
  ((lead_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = kyc_records.lead_id
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
  OR ((client_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = kyc_records.client_id
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
));

-- Policy: Users can update kyc records in tenant
CREATE POLICY "Users can update kyc records in tenant"
ON public.kyc_records FOR UPDATE
TO public
USING (can_access_tenant(admin_id) AND (
  ((lead_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = kyc_records.lead_id
      AND can_access_tenant(leads.admin_id)
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
  OR ((client_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = kyc_records.client_id
      AND can_access_tenant(clients.admin_id)
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
));

-- Policy: Users can view kyc records in tenant
CREATE POLICY "Users can view kyc records in tenant"
ON public.kyc_records FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  ((lead_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = kyc_records.lead_id
      AND can_access_tenant(leads.admin_id)
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
  OR ((client_id IS NOT NULL) AND EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = kyc_records.client_id
      AND can_access_tenant(clients.admin_id)
      AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
           OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
           OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
           OR has_role(auth.uid(), 'MANAGER'::app_role))
  ))
));


-- ============================================================================
-- TABLE: lead_activities
-- ============================================================================

-- Policy: Users can create lead activities
CREATE POLICY "Users can create lead activities"
ON public.lead_activities FOR INSERT
TO public
WITH CHECK ((auth.uid() = user_id) AND EXISTS (
  SELECT 1 FROM leads
  WHERE leads.id = lead_activities.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
         OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
         OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
         OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can view lead activities
CREATE POLICY "Users can view lead activities"
ON public.lead_activities FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR EXISTS (
    SELECT 1 FROM leads
    WHERE leads.id = lead_activities.lead_id
      AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid() OR can_access_tenant(leads.admin_id))
  ));


-- ============================================================================
-- TABLE: lead_comments
-- ============================================================================

-- Policy: Managers and admins can delete all comments
CREATE POLICY "Managers and admins can delete all comments"
ON public.lead_comments FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Users can create comments for accessible leads
CREATE POLICY "Users can create comments for accessible leads"
ON public.lead_comments FOR INSERT
TO public
WITH CHECK ((auth.uid() = user_id) AND EXISTS (
  SELECT 1 FROM leads
  WHERE leads.id = lead_comments.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete their own comments"
ON public.lead_comments FOR DELETE
TO public
USING (user_id = auth.uid());

-- Policy: Users can view comments for accessible leads
CREATE POLICY "Users can view comments for accessible leads"
ON public.lead_comments FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM leads
  WHERE leads.id = lead_comments.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));


-- ============================================================================
-- TABLE: lead_group_members
-- ============================================================================

-- Policy: Admins can add leads to groups in tenant
CREATE POLICY "Admins can add leads to groups in tenant"
ON public.lead_group_members FOR INSERT
TO public
WITH CHECK ((auth.uid() = added_by) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
) AND EXISTS (
  SELECT 1 FROM lead_groups lg
  WHERE lg.id = lead_group_members.group_id AND can_access_tenant(lg.admin_id)
));

-- Policy: Admins can remove leads from groups in tenant
CREATE POLICY "Admins can remove leads from groups in tenant"
ON public.lead_group_members FOR DELETE
TO public
USING ((has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role))
  AND EXISTS (
    SELECT 1 FROM lead_groups lg
    WHERE lg.id = lead_group_members.group_id AND can_access_tenant(lg.admin_id)
  ));

-- Policy: Users can view group members in tenant
CREATE POLICY "Users can view group members in tenant"
ON public.lead_group_members FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM lead_groups lg
  WHERE lg.id = lead_group_members.group_id AND can_access_tenant(lg.admin_id)
));


-- ============================================================================
-- TABLE: lead_groups
-- ============================================================================

-- Policy: Admins can manage lead groups in tenant
CREATE POLICY "Admins can manage lead groups in tenant"
ON public.lead_groups FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
))
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Authorized users can create groups
CREATE POLICY "Authorized users can create groups"
ON public.lead_groups FOR INSERT
TO public
WITH CHECK ((auth.uid() = created_by) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Authorized users can delete groups
CREATE POLICY "Authorized users can delete groups"
ON public.lead_groups FOR DELETE
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR ((has_role(auth.uid(), 'TENANT_OWNER'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
      AND (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id))));

-- Policy: Authorized users can update groups
CREATE POLICY "Authorized users can update groups"
ON public.lead_groups FOR UPDATE
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR ((has_role(auth.uid(), 'TENANT_OWNER'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
      AND (admin_id = auth.uid() OR created_by = auth.uid() OR can_access_tenant(admin_id))));

-- Policy: Users can create lead groups in tenant
CREATE POLICY "Users can create lead groups in tenant"
ON public.lead_groups FOR INSERT
TO public
WITH CHECK (auth.uid() = created_by);

-- Policy: Users can view groups in their tenant
CREATE POLICY "Users can view groups in their tenant"
ON public.lead_groups FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR created_by = auth.uid()
  OR can_access_tenant(admin_id));

-- Policy: Users can view lead groups in tenant
CREATE POLICY "Users can view lead groups in tenant"
ON public.lead_groups FOR SELECT
TO public
USING (can_access_tenant(admin_id));


-- ============================================================================
-- TABLE: lead_statuses
-- ============================================================================

-- Policy: Admins can delete lead statuses
CREATE POLICY "Admins can delete lead statuses"
ON public.lead_statuses FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Admins can insert lead statuses
CREATE POLICY "Admins can insert lead statuses"
ON public.lead_statuses FOR INSERT
TO public
WITH CHECK (has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Admins can update lead statuses
CREATE POLICY "Admins can update lead statuses"
ON public.lead_statuses FOR UPDATE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Anyone can view lead statuses
CREATE POLICY "Anyone can view lead statuses"
ON public.lead_statuses FOR SELECT
TO public
USING (auth.uid() IS NOT NULL);


-- ============================================================================
-- TABLE: lead_tasks
-- ============================================================================

-- Policy: Managers and admins can delete all tasks
CREATE POLICY "Managers and admins can delete all tasks"
ON public.lead_tasks FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Managers and admins can update all tasks
CREATE POLICY "Managers and admins can update all tasks"
ON public.lead_tasks FOR UPDATE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Users can create tasks for accessible leads
CREATE POLICY "Users can create tasks for accessible leads"
ON public.lead_tasks FOR INSERT
TO public
WITH CHECK (EXISTS (
  SELECT 1 FROM leads
  WHERE leads.id = lead_tasks.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can delete their assigned tasks
CREATE POLICY "Users can delete their assigned tasks"
ON public.lead_tasks FOR DELETE
TO public
USING (assigned_to = auth.uid());

-- Policy: Users can update their assigned tasks
CREATE POLICY "Users can update their assigned tasks"
ON public.lead_tasks FOR UPDATE
TO public
USING (assigned_to = auth.uid());

-- Policy: Users can view tasks for accessible leads
CREATE POLICY "Users can view tasks for accessible leads"
ON public.lead_tasks FOR SELECT
TO public
USING ((assigned_to = auth.uid()) OR EXISTS (
  SELECT 1 FROM leads
  WHERE leads.id = lead_tasks.lead_id
    AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));


-- ============================================================================
-- TABLE: leads
-- ============================================================================

-- Policy: leads_delete_policy
CREATE POLICY "leads_delete_policy"
ON public.leads FOR DELETE
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid()
    AND ur.role = ANY (ARRAY['SUPER_ADMIN'::app_role, 'TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role])
));

-- Policy: leads_insert_policy
CREATE POLICY "leads_insert_policy"
ON public.leads FOR INSERT
TO public
WITH CHECK (true);

-- Policy: leads_select_policy
CREATE POLICY "leads_select_policy"
ON public.leads FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid() AND (
    ur.role = 'SUPER_ADMIN'::app_role
    OR ((ur.role = ANY (ARRAY['TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role]))
        AND leads.admin_id = (SELECT profiles.admin_id FROM profiles WHERE profiles.id = auth.uid()))
    OR (ur.role = 'TENANT_OWNER'::app_role AND leads.admin_id = auth.uid())
    OR ((ur.role = ANY (ARRAY['AGENT'::app_role, 'SUPER_AGENT'::app_role]))
        AND (leads.assigned_to = auth.uid() OR leads.created_by = auth.uid()))
  )
));

-- Policy: leads_update_policy
CREATE POLICY "leads_update_policy"
ON public.leads FOR UPDATE
TO public
USING (EXISTS (
  SELECT 1 FROM user_roles ur
  WHERE ur.user_id = auth.uid() AND (
    ur.role = ANY (ARRAY['SUPER_ADMIN'::app_role, 'TENANT_OWNER'::app_role, 'MANAGER'::app_role, 'ADMIN'::app_role])
    OR leads.assigned_to = auth.uid()
    OR leads.created_by = auth.uid()
  )
));


-- ============================================================================
-- TABLE: manager_commission_settings
-- ============================================================================

-- Policy: Admins can manage manager commission settings
CREATE POLICY "Admins can manage manager commission settings"
ON public.manager_commission_settings FOR ALL
TO authenticated
USING ((get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text]))
  AND ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text) OR admin_id = auth.uid()))
WITH CHECK ((get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text]))
  AND ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text) OR admin_id = auth.uid()));

-- Policy: Admins can manage manager commissions
CREATE POLICY "Admins can manage manager commissions"
ON public.manager_commission_settings FOR ALL
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
))
WITH CHECK (has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR has_role(auth.uid(), 'TENANT_OWNER'::app_role));

-- Policy: Users can view manager commission settings in their tenant
CREATE POLICY "Users can view manager commission settings in their tenant"
ON public.manager_commission_settings FOR SELECT
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND admin_id = auth.uid())
  OR admin_id = (SELECT profiles.admin_id FROM profiles WHERE profiles.id = auth.uid()));

-- Policy: Users can view manager commissions in tenant
CREATE POLICY "Users can view manager commissions in tenant"
ON public.manager_commission_settings FOR SELECT
TO public
USING (can_access_tenant(admin_id));


-- ============================================================================
-- TABLE: messages
-- ============================================================================

-- Policy: Admins can view all messages
CREATE POLICY "Admins can view all messages"
ON public.messages FOR SELECT
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role));

-- Policy: Users can mark their messages as read
CREATE POLICY "Users can mark their messages as read"
ON public.messages FOR UPDATE
TO public
USING (EXISTS (
  SELECT 1 FROM conversations
  WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
));

-- Policy: Users can send messages in their conversations
CREATE POLICY "Users can send messages in their conversations"
ON public.messages FOR INSERT
TO public
WITH CHECK ((auth.uid() = sender_id) AND EXISTS (
  SELECT 1 FROM conversations
  WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
));

-- Policy: Users can view messages in their conversations
CREATE POLICY "Users can view messages in their conversations"
ON public.messages FOR SELECT
TO public
USING (EXISTS (
  SELECT 1 FROM conversations
  WHERE conversations.id = messages.conversation_id
    AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
));


-- ============================================================================
-- TABLE: notifications
-- ============================================================================

-- Policy: Admins can delete deposit notifications
CREATE POLICY "Admins can delete deposit notifications"
ON public.notifications FOR DELETE
TO public
USING ((related_entity_type = 'deposit'::text) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Managers can view tenant notifications
CREATE POLICY "Managers can view tenant notifications"
ON public.notifications FOR SELECT
TO public
USING (has_role(auth.uid(), 'MANAGER'::app_role) AND can_access_tenant(admin_id));

-- Policy: Super admins can view all notifications
CREATE POLICY "Super admins can view all notifications"
ON public.notifications FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role));

-- Policy: System can create notifications in tenant
CREATE POLICY "System can create notifications in tenant"
ON public.notifications FOR INSERT
TO public
WITH CHECK (true);

-- Policy: Tenant owners can view tenant notifications
CREATE POLICY "Tenant owners can view tenant notifications"
ON public.notifications FOR SELECT
TO public
USING (has_role(auth.uid(), 'TENANT_OWNER'::app_role) AND admin_id = auth.uid());

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
ON public.notifications FOR DELETE
TO public
USING (user_id = auth.uid());

-- Policy: Users can update their own notifications
CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE
TO public
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT
TO public
USING (user_id = auth.uid());


-- ============================================================================
-- TABLE: profiles
-- ============================================================================

-- Policy: Admins can manage profiles
CREATE POLICY "Admins can manage profiles"
ON public.profiles FOR ALL
TO public
USING (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'ADMIN'::text, 'MANAGER'::text]))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'ADMIN'::text, 'MANAGER'::text]));

-- Policy: Admins can update created_by on profiles
CREATE POLICY "Admins can update created_by on profiles"
ON public.profiles FOR UPDATE
TO authenticated
USING (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'ADMIN'::text, 'TENANT_OWNER'::text]))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'ADMIN'::text, 'TENANT_OWNER'::text]));

-- Policy: Admins can view users they created
CREATE POLICY "Admins can view users they created"
ON public.profiles FOR SELECT
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR ((get_user_role_direct(auth.uid()) = ANY (ARRAY['ADMIN'::text, 'MANAGER'::text, 'TENANT_OWNER'::text]))
      AND (created_by = auth.uid() OR id = auth.uid())));

-- Policy: Admins insert profiles
CREATE POLICY "Admins insert profiles"
ON public.profiles FOR INSERT
TO public
WITH CHECK ((get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'ADMIN'::text, 'MANAGER'::text]))
  OR id = auth.uid());

-- Policy: Admins update profiles
CREATE POLICY "Admins update profiles"
ON public.profiles FOR UPDATE
TO public
USING (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'ADMIN'::text, 'MANAGER'::text]))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'TENANT_OWNER'::text, 'ADMIN'::text, 'MANAGER'::text]));

-- Policy: Agents can view super agent profiles
CREATE POLICY "Agents can view super agent profiles"
ON public.profiles FOR SELECT
TO public
USING (id IN (SELECT get_client_related_profile_ids(auth.uid())));

-- Policy: Allow username lookup for login
CREATE POLICY "Allow username lookup for login"
ON public.profiles FOR SELECT
TO anon
USING (true);

-- Policy: Super agents can view all agent and super agent profiles
CREATE POLICY "Super agents can view all agent and super agent profiles"
ON public.profiles FOR SELECT
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_AGENT'::text)
  AND (get_user_role_direct(id) = ANY (ARRAY['AGENT'::text, 'SUPER_AGENT'::text])));

-- Policy: Update own profile
CREATE POLICY "Update own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy: Users can view profiles in their tenant
CREATE POLICY "Users can view profiles in their tenant"
ON public.profiles FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR id = auth.uid()
  OR admin_id = get_user_admin_id_safe(auth.uid())
  OR ((admin_id IS NULL) AND has_role(auth.uid(), 'TENANT_OWNER'::app_role) AND created_by = auth.uid()));


-- ============================================================================
-- TABLE: received_emails
-- ============================================================================

-- Policy: Service role can insert received emails
CREATE POLICY "Service role can insert received emails"
ON public.received_emails FOR INSERT
TO public
WITH CHECK (true);

-- Policy: Users can create received emails
CREATE POLICY "Users can create received emails"
ON public.received_emails FOR INSERT
TO public
WITH CHECK (user_id = auth.uid());

-- Policy: Users can update their received emails
CREATE POLICY "Users can update their received emails"
ON public.received_emails FOR UPDATE
TO public
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users can view received emails in tenant
CREATE POLICY "Users can view received emails in tenant"
ON public.received_emails FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'TENANT_OWNER'::app_role)
    OR has_role(auth.uid(), 'MANAGER'::app_role)
    OR user_id = auth.uid()
  )));


-- ============================================================================
-- TABLE: reminders
-- ============================================================================

-- Policy: Users can delete their own reminders
CREATE POLICY "Users can delete their own reminders"
ON public.reminders FOR DELETE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can insert their own reminders
CREATE POLICY "Users can insert their own reminders"
ON public.reminders FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own reminders
CREATE POLICY "Users can update their own reminders"
ON public.reminders FOR UPDATE
TO public
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own reminders
CREATE POLICY "Users can view their own reminders"
ON public.reminders FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- TABLE: sale_branches
-- ============================================================================

-- Policy: Admins can delete sale branches
CREATE POLICY "Admins can delete sale branches"
ON public.sale_branches FOR DELETE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Admins can delete sale branches in tenant
CREATE POLICY "Admins can delete sale branches in tenant"
ON public.sale_branches FOR DELETE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
));

-- Policy: Admins can update sale branches in tenant
CREATE POLICY "Admins can update sale branches in tenant"
ON public.sale_branches FOR UPDATE
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role)
));

-- Policy: Users can create sale branches
CREATE POLICY "Users can create sale branches"
ON public.sale_branches FOR INSERT
TO public
WITH CHECK ((auth.uid() = created_by) AND can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR has_role(auth.uid(), 'SUPER_AGENT'::app_role)
  OR EXISTS (
    SELECT 1 FROM clients
    WHERE clients.id = sale_branches.client_id
      AND (clients.assigned_to = auth.uid() OR clients.transferring_agent = auth.uid())
  )
));

-- Policy: Users can delete branches for accessible clients
CREATE POLICY "Users can delete branches for accessible clients"
ON public.sale_branches FOR DELETE
TO public
USING (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = sale_branches.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can update branches for accessible clients
CREATE POLICY "Users can update branches for accessible clients"
ON public.sale_branches FOR UPDATE
TO public
USING (EXISTS (
  SELECT 1 FROM clients
  WHERE clients.id = sale_branches.client_id
    AND (clients.assigned_to = auth.uid() OR clients.created_by = auth.uid()
         OR has_role(auth.uid(), 'ADMIN'::app_role) OR has_role(auth.uid(), 'MANAGER'::app_role))
));

-- Policy: Users can update sale branches in their tenant
CREATE POLICY "Users can update sale branches in their tenant"
ON public.sale_branches FOR UPDATE
TO public
USING (can_access_tenant(admin_id));

-- Policy: Users can view sale branches in their tenant
CREATE POLICY "Users can view sale branches in their tenant"
ON public.sale_branches FOR SELECT
TO public
USING (can_access_tenant(admin_id) AND (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role)
  OR (has_role(auth.uid(), 'SUPER_AGENT'::app_role) AND EXISTS (
    SELECT 1 FROM clients WHERE clients.id = sale_branches.client_id AND clients.assigned_to = auth.uid()
  ))
  OR (has_role(auth.uid(), 'AGENT'::app_role) AND EXISTS (
    SELECT 1 FROM clients WHERE clients.id = sale_branches.client_id AND clients.transferring_agent = auth.uid()
  ))
));


-- ============================================================================
-- TABLE: sent_emails
-- ============================================================================

-- Policy: Users can create sent emails in tenant
CREATE POLICY "Users can create sent emails in tenant"
ON public.sent_emails FOR INSERT
TO public
WITH CHECK (sender_id = auth.uid());

-- Policy: Users can view their own sent emails in tenant
CREATE POLICY "Users can view their own sent emails in tenant"
ON public.sent_emails FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR (can_access_tenant(admin_id) AND (
    has_role(auth.uid(), 'TENANT_OWNER'::app_role)
    OR has_role(auth.uid(), 'MANAGER'::app_role)
    OR sender_id = auth.uid()
  )));


-- ============================================================================
-- TABLE: user_integration_credentials
-- ============================================================================

-- Policy: Admins can delete credentials in their tenant
CREATE POLICY "Admins can delete credentials in their tenant"
ON public.user_integration_credentials FOR DELETE
TO public
USING (auth.uid() = admin_id);

-- Policy: Admins can insert credentials for their tenant
CREATE POLICY "Admins can insert credentials for their tenant"
ON public.user_integration_credentials FOR INSERT
TO public
WITH CHECK (auth.uid() = admin_id);

-- Policy: Admins can update credentials in their tenant
CREATE POLICY "Admins can update credentials in their tenant"
ON public.user_integration_credentials FOR UPDATE
TO public
USING (auth.uid() = admin_id);

-- Policy: Admins can view all credentials in their tenant
CREATE POLICY "Admins can view all credentials in their tenant"
ON public.user_integration_credentials FOR SELECT
TO public
USING (auth.uid() = admin_id);

-- Policy: Users can delete their own credentials
CREATE POLICY "Users can delete their own credentials"
ON public.user_integration_credentials FOR DELETE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can insert their own credentials
CREATE POLICY "Users can insert their own credentials"
ON public.user_integration_credentials FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own credentials
CREATE POLICY "Users can update their own credentials"
ON public.user_integration_credentials FOR UPDATE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can view their own credentials
CREATE POLICY "Users can view their own credentials"
ON public.user_integration_credentials FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- TABLE: user_permissions
-- ============================================================================

-- Policy: Admins can delete permissions
CREATE POLICY "Admins can delete permissions"
ON public.user_permissions FOR DELETE
TO public
USING (has_role(auth.uid(), 'ADMIN'::app_role));

-- Policy: Users can view their own permissions
CREATE POLICY "Users can view their own permissions"
ON public.user_permissions FOR SELECT
TO public
USING (auth.uid() = user_id);

-- Policy: Users with CAN_MANAGE_USERS can insert permissions
CREATE POLICY "Users with CAN_MANAGE_USERS can insert permissions"
ON public.user_permissions FOR INSERT
TO public
WITH CHECK (has_permission(auth.uid(), 'CAN_MANAGE_USERS'::app_permission));

-- Policy: Users with CAN_MANAGE_USERS can update permissions
CREATE POLICY "Users with CAN_MANAGE_USERS can update permissions"
ON public.user_permissions FOR UPDATE
TO public
USING (has_permission(auth.uid(), 'CAN_MANAGE_USERS'::app_permission));

-- Policy: Users with CAN_MANAGE_USERS can view all permissions
CREATE POLICY "Users with CAN_MANAGE_USERS can view all permissions"
ON public.user_permissions FOR SELECT
TO public
USING (has_permission(auth.uid(), 'CAN_MANAGE_USERS'::app_permission));


-- ============================================================================
-- TABLE: user_preferences
-- ============================================================================

-- Policy: Users can insert own preferences
CREATE POLICY "Users can insert own preferences"
ON public.user_preferences FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update own preferences
CREATE POLICY "Users can update own preferences"
ON public.user_preferences FOR UPDATE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can view own preferences
CREATE POLICY "Users can view own preferences"
ON public.user_preferences FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- TABLE: user_roles
-- ============================================================================

-- Policy: Allow admin manage roles
CREATE POLICY "Allow admin manage roles"
ON public.user_roles FOR ALL
TO public
USING (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text]))
WITH CHECK (get_user_role_direct(auth.uid()) = ANY (ARRAY['SUPER_ADMIN'::text, 'ADMIN'::text, 'TENANT_OWNER'::text, 'MANAGER'::text]));

-- Policy: Allow authenticated read roles
CREATE POLICY "Allow authenticated read roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (true);

-- Policy: Users can view own role
CREATE POLICY "Users can view own role"
ON public.user_roles FOR SELECT
TO public
USING (user_id = auth.uid());

-- Policy: Users can view roles in their tenant
CREATE POLICY "Users can view roles in their tenant"
ON public.user_roles FOR SELECT
TO authenticated
USING ((get_user_role_direct(auth.uid()) = 'SUPER_ADMIN'::text)
  OR user_id = auth.uid()
  OR ((get_user_role_direct(auth.uid()) = 'TENANT_OWNER'::text) AND get_profile_admin_id_direct(user_id) = auth.uid())
  OR ((get_profile_admin_id_direct(auth.uid()) IS NOT NULL) AND get_profile_admin_id_direct(user_id) = get_profile_admin_id_direct(auth.uid())));


-- ============================================================================
-- TABLE: user_sessions
-- ============================================================================

-- Policy: Admins can update all sessions
CREATE POLICY "Admins can update all sessions"
ON public.user_sessions FOR UPDATE
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Admins can view all sessions
CREATE POLICY "Admins can view all sessions"
ON public.user_sessions FOR SELECT
TO public
USING (has_role(auth.uid(), 'SUPER_ADMIN'::app_role)
  OR has_role(auth.uid(), 'TENANT_OWNER'::app_role)
  OR has_role(auth.uid(), 'ADMIN'::app_role)
  OR has_role(auth.uid(), 'MANAGER'::app_role));

-- Policy: Users can delete their own sessions
CREATE POLICY "Users can delete their own sessions"
ON public.user_sessions FOR DELETE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can insert their own sessions
CREATE POLICY "Users can insert their own sessions"
ON public.user_sessions FOR INSERT
TO public
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own sessions
CREATE POLICY "Users can update their own sessions"
ON public.user_sessions FOR UPDATE
TO public
USING (auth.uid() = user_id);

-- Policy: Users can view their own sessions
CREATE POLICY "Users can view their own sessions"
ON public.user_sessions FOR SELECT
TO public
USING (auth.uid() = user_id);


-- ============================================================================
-- END OF RLS POLICIES EXPORT
-- ============================================================================

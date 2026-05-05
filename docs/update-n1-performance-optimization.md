# 📋 Update n1: Performance Optimization Implementation Plan

> **Document Version:** 1.0  
> **Created:** December 2024  
> **Status:** Planning Phase  
> **Priority:** Critical

## Executive Summary

This document outlines a comprehensive performance optimization strategy for the Kybalion CRM application. The plan addresses critical issues including database statement timeouts, duplicate queries, and slow page loads that are severely impacting user experience.

### Current Performance Issues

| Issue | Impact | Root Cause |
|-------|--------|------------|
| Page load: 8-15 seconds | Critical | 20+ database queries per page |
| Statement timeout errors | Critical | Complex RLS policies, no indexes |
| Duplicate role queries | High | `useUserRole` called in 28 files |
| Cascading context dependencies | High | Sequential data fetching |
| N+1 query pattern | High | Dashboard fetching tenant stats individually |

---

## Table of Contents

1. [Phase 1: Centralized User Data Provider](#phase-1-centralized-user-data-provider)
2. [Phase 2: Database Function Optimization](#phase-2-database-function-optimization)
3. [Phase 3: Database Index Optimization](#phase-3-database-index-optimization)
4. [Phase 4: Hook Consolidation](#phase-4-hook-consolidation)
5. [Phase 5: React Query Configuration](#phase-5-react-query-configuration)
6. [Phase 6: Component-Level Optimizations](#phase-6-component-level-optimizations)
7. [Implementation Timeline](#implementation-timeline)
8. [Expected Results](#expected-results)
9. [Risk Assessment](#risk-assessment)
10. [Testing Checklist](#testing-checklist)

---

## Phase 1: Centralized User Data Provider

**Priority:** 🔴 Critical  
**Timeline:** Day 1  
**Expected Impact:** -70% role queries

### 1.1 Problem Analysis

Currently, user data is fetched from multiple sources:

```
Files calling useUserRole: 28 files
├── src/pages/Dashboard.tsx
├── src/pages/Leads.tsx
├── src/pages/Clients.tsx
├── src/pages/Pipeline.tsx
├── src/components/AppLayout.tsx
├── src/contexts/TenantContext.tsx (ALSO fetches role!)
├── ... and 22 more files
```

Each call to `useUserRole` triggers:
1. Query to `user_roles` table
2. RLS policy evaluation
3. Network round-trip

**Total: 28+ duplicate queries per session**

### 1.2 Solution: UserDataContext

Create a new unified context that serves as the single source of truth for all user-related data.

**File:** `src/contexts/UserDataContext.tsx` (NEW)

```typescript
import React, { createContext, useContext, ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from './AuthContext';
import { supabase } from '@/integrations/supabase/client';

type AppRole = 'SUPER_ADMIN' | 'TENANT_OWNER' | 'MANAGER' | 'SUPER_AGENT' | 'AGENT';

interface UserData {
  // Core data
  user: User | null;
  role: AppRole | null;
  profile: Profile | null;
  tenantId: string | null;
  
  // Visibility settings (from admin_settings)
  settings: {
    showPhoneToAgents: boolean;
    showPhoneToSuperAgents: boolean;
    showEmailToAgents: boolean;
    showEmailToSuperAgents: boolean;
  };
  
  // Role boolean helpers
  isSuperAdmin: boolean;
  isTenantOwner: boolean;
  isManager: boolean;
  isSuperAgent: boolean;
  isAgent: boolean;
  
  // Access level helpers
  hasAdminAccess: boolean;      // SUPER_ADMIN | TENANT_OWNER
  hasManagerAccess: boolean;    // Above + MANAGER
  hasSuperAgentAccess: boolean; // Above + SUPER_AGENT
  
  // Computed visibility
  canViewPhone: boolean;
  canViewEmail: boolean;
  
  // Loading state
  isLoading: boolean;
}

const UserDataContext = createContext<UserData | undefined>(undefined);

export function UserDataProvider({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const userId = session?.user?.id;

  const { data, isLoading } = useQuery({
    queryKey: ['user-data', userId],
    enabled: !!userId,
    staleTime: 5 * 60 * 1000, // 5 minutes cache
    gcTime: 30 * 60 * 1000,   // 30 minutes garbage collection
    queryFn: async () => {
      // Single RPC call to get all user data
      const { data, error } = await supabase.rpc('get_user_data', {
        p_user_id: userId
      });
      
      if (error) throw error;
      return data;
    },
  });

  // Compute all derived values
  const role = data?.role as AppRole | null;
  const settings = data?.settings || {};
  
  const isSuperAdmin = role === 'SUPER_ADMIN';
  const isTenantOwner = role === 'TENANT_OWNER';
  const isManager = role === 'MANAGER';
  const isSuperAgent = role === 'SUPER_AGENT';
  const isAgent = role === 'AGENT';
  
  const hasAdminAccess = isSuperAdmin || isTenantOwner;
  const hasManagerAccess = hasAdminAccess || isManager;
  const hasSuperAgentAccess = hasManagerAccess || isSuperAgent;
  
  const canViewPhone = hasAdminAccess ||
    (isAgent && settings.showPhoneToAgents) ||
    (isSuperAgent && settings.showPhoneToSuperAgents);
    
  const canViewEmail = hasAdminAccess ||
    (isAgent && settings.showEmailToAgents) ||
    (isSuperAgent && settings.showEmailToSuperAgents);

  const value: UserData = {
    user: session?.user || null,
    role,
    profile: data?.profile || null,
    tenantId: data?.admin_id || null,
    settings: {
      showPhoneToAgents: settings.show_phone_to_agents ?? true,
      showPhoneToSuperAgents: settings.show_phone_to_super_agents ?? true,
      showEmailToAgents: settings.show_email_to_agents ?? true,
      showEmailToSuperAgents: settings.show_email_to_super_agents ?? true,
    },
    isSuperAdmin,
    isTenantOwner,
    isManager,
    isSuperAgent,
    isAgent,
    hasAdminAccess,
    hasManagerAccess,
    hasSuperAgentAccess,
    canViewPhone,
    canViewEmail,
    isLoading,
  };

  return (
    <UserDataContext.Provider value={value}>
      {children}
    </UserDataContext.Provider>
  );
}

export function useUserData() {
  const context = useContext(UserDataContext);
  if (context === undefined) {
    throw new Error('useUserData must be used within a UserDataProvider');
  }
  return context;
}
```

### 1.3 Modify TenantContext

Remove role fetching from TenantContext since it will be handled by UserDataContext.

**Changes to `src/contexts/TenantContext.tsx`:**
- Remove the role fetching query
- Import and use `useUserData()` for role information
- Keep only tenant selection logic for SUPER_ADMIN users

### 1.4 Create Compatibility Wrapper

To allow gradual migration, create a wrapper for the old `useUserRole` hook:

**File:** `src/hooks/useUserRole.ts` (MODIFY)

```typescript
import { useUserData } from '@/contexts/UserDataContext';

/**
 * @deprecated Use useUserData() directly instead
 * This hook is a compatibility wrapper during migration
 */
export function useUserRole() {
  const userData = useUserData();
  
  return {
    role: userData.role,
    loading: userData.isLoading,
    isSuperAdmin: userData.isSuperAdmin,
    isTenantOwner: userData.isTenantOwner,
    isManager: userData.isManager,
    isSuperAgent: userData.isSuperAgent,
    isAgent: userData.isAgent,
    hasTenantOwnerAccess: userData.hasAdminAccess,
    hasManagerAccess: userData.hasManagerAccess,
    hasSuperAgentAccess: userData.hasSuperAgentAccess,
  };
}
```

### 1.5 Files Requiring Migration

The following 28 files need to be updated to use the new context:

```
High Priority (Core functionality):
├── src/contexts/TenantContext.tsx
├── src/components/AppLayout.tsx
├── src/components/AppSidebar.tsx
├── src/pages/Dashboard.tsx
├── src/pages/Leads.tsx
├── src/pages/Clients.tsx

Medium Priority (Feature pages):
├── src/pages/Pipeline.tsx
├── src/pages/ConvertQueue.tsx
├── src/pages/Reports.tsx
├── src/pages/Email.tsx
├── src/pages/Attendance.tsx
├── src/pages/CallHistory.tsx

Lower Priority (Admin pages):
├── src/pages/UserManagement.tsx
├── src/pages/TenantManagement.tsx
├── src/pages/TeamManagement.tsx
├── src/pages/SecurityMonitoring.tsx
├── src/pages/GeneralSettings.tsx
├── src/pages/Integrations.tsx

Components:
├── src/components/leads/*.tsx (multiple)
├── src/components/clients/*.tsx (multiple)
├── src/components/pipeline/*.tsx (multiple)
└── ... additional components
```

---

## Phase 2: Database Function Optimization

**Priority:** 🔴 Critical  
**Timeline:** Day 1-2  
**Expected Impact:** -90% auth queries, -95% dashboard queries

### 2.1 Create `get_user_data` Function

This function fetches all user-related data in a single database call.

```sql
-- Migration: Create get_user_data function
CREATE OR REPLACE FUNCTION public.get_user_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
  v_role text;
  v_admin_id uuid;
  v_settings jsonb;
  v_profile jsonb;
BEGIN
  -- Get profile and role in one query using LEFT JOIN
  SELECT 
    ur.role::text,
    p.admin_id,
    jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'last_name', p.last_name,
      'email', p.email,
      'username', p.username,
      'avatar_url', p.avatar_url,
      'created_by', p.created_by,
      'created_at', p.created_at
    )
  INTO v_role, v_admin_id, v_profile
  FROM public.profiles p
  LEFT JOIN public.user_roles ur ON ur.user_id = p.id
  WHERE p.id = p_user_id;

  -- Handle case where user not found
  IF v_profile IS NULL THEN
    RETURN jsonb_build_object(
      'role', null,
      'admin_id', null,
      'profile', null,
      'settings', '{}'::jsonb
    );
  END IF;

  -- Determine effective tenant ID
  -- TENANT_OWNER is their own admin
  IF v_role = 'TENANT_OWNER' THEN
    v_admin_id := p_user_id;
  END IF;

  -- Get visibility settings from admin_settings
  IF v_admin_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'show_phone_to_agents', COALESCE(show_phone_to_agents, true),
      'show_phone_to_super_agents', COALESCE(show_phone_to_super_agents, true),
      'show_email_to_agents', COALESCE(show_email_to_agents, true),
      'show_email_to_super_agents', COALESCE(show_email_to_super_agents, true)
    )
    INTO v_settings
    FROM public.admin_settings
    WHERE admin_id = v_admin_id;
  END IF;

  -- Fallback to general_settings if admin_settings not found
  IF v_settings IS NULL AND v_admin_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'show_phone_to_agents', COALESCE(show_phone_to_agents, true),
      'show_phone_to_super_agents', COALESCE(show_phone_to_super_agents, true),
      'show_email_to_agents', COALESCE(show_email_to_agents, true),
      'show_email_to_super_agents', COALESCE(show_email_to_super_agents, true)
    )
    INTO v_settings
    FROM public.general_settings
    WHERE admin_id = v_admin_id;
  END IF;

  -- Build and return final result
  RETURN jsonb_build_object(
    'role', v_role,
    'admin_id', v_admin_id,
    'profile', v_profile,
    'settings', COALESCE(v_settings, jsonb_build_object(
      'show_phone_to_agents', true,
      'show_phone_to_super_agents', true,
      'show_email_to_agents', true,
      'show_email_to_super_agents', true
    ))
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_data(uuid) TO authenticated;
```

### 2.2 Create `get_dashboard_stats` Function

Replaces 8+ individual dashboard queries with a single optimized call.

```sql
-- Migration: Create get_dashboard_stats function
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_tenant_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_leads_count bigint := 0;
  v_clients_count bigint := 0;
  v_users_count bigint := 0;
  v_tenants_count bigint := 0;
  v_total_deposits numeric := 0;
  v_pending_deposits numeric := 0;
  v_pending_conversions bigint := 0;
  v_active_sessions bigint := 0;
  v_week_leads bigint := 0;
  v_week_clients bigint := 0;
  v_week_start date := date_trunc('week', CURRENT_DATE)::date;
BEGIN
  IF p_tenant_id IS NOT NULL THEN
    -- Tenant-specific stats
    SELECT COUNT(*) INTO v_leads_count 
    FROM public.leads WHERE admin_id = p_tenant_id;
    
    SELECT COUNT(*) INTO v_clients_count 
    FROM public.clients WHERE admin_id = p_tenant_id;
    
    SELECT COUNT(*) INTO v_users_count 
    FROM public.profiles WHERE admin_id = p_tenant_id;
    
    SELECT COALESCE(SUM(amount), 0) INTO v_total_deposits 
    FROM public.deposits 
    WHERE admin_id = p_tenant_id AND status = 'approved';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_pending_deposits 
    FROM public.deposits 
    WHERE admin_id = p_tenant_id AND status = 'pending';
    
    SELECT COUNT(*) INTO v_pending_conversions 
    FROM public.leads 
    WHERE admin_id = p_tenant_id AND pending_conversion = true;
    
    SELECT COUNT(*) INTO v_week_leads 
    FROM public.leads 
    WHERE admin_id = p_tenant_id AND created_at >= v_week_start;
    
    SELECT COUNT(*) INTO v_week_clients 
    FROM public.clients 
    WHERE admin_id = p_tenant_id AND created_at >= v_week_start;
  ELSE
    -- Super admin: all data
    SELECT COUNT(*) INTO v_leads_count FROM public.leads;
    SELECT COUNT(*) INTO v_clients_count FROM public.clients;
    SELECT COUNT(*) INTO v_users_count FROM public.profiles;
    
    SELECT COUNT(*) INTO v_tenants_count 
    FROM public.user_roles WHERE role = 'TENANT_OWNER';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_total_deposits 
    FROM public.deposits WHERE status = 'approved';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_pending_deposits 
    FROM public.deposits WHERE status = 'pending';
    
    SELECT COUNT(*) INTO v_pending_conversions 
    FROM public.leads WHERE pending_conversion = true;
    
    SELECT COUNT(*) INTO v_week_leads 
    FROM public.leads WHERE created_at >= v_week_start;
    
    SELECT COUNT(*) INTO v_week_clients 
    FROM public.clients WHERE created_at >= v_week_start;
  END IF;

  -- Calculate conversion rate
  RETURN jsonb_build_object(
    'total_leads', v_leads_count,
    'total_clients', v_clients_count,
    'total_users', v_users_count,
    'total_tenants', v_tenants_count,
    'total_deposits', v_total_deposits,
    'pending_deposits', v_pending_deposits,
    'pending_conversions', v_pending_conversions,
    'week_leads', v_week_leads,
    'week_clients', v_week_clients,
    'conversion_rate', CASE 
      WHEN v_leads_count + v_clients_count > 0 
      THEN ROUND((v_clients_count::numeric / (v_leads_count + v_clients_count) * 100), 1)
      ELSE 0 
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_stats(uuid) TO authenticated;
```

### 2.3 Create `get_all_tenant_stats` Function

For SUPER_ADMIN dashboard - fetches all tenant statistics in one query.

```sql
-- Migration: Create get_all_tenant_stats function
CREATE OR REPLACE FUNCTION public.get_all_tenant_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(tenant_stats ORDER BY tenant_stats->>'created_at' DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'tenant_id', p.id,
      'tenant_name', COALESCE(p.full_name, p.email),
      'email', p.email,
      'created_at', p.created_at,
      'leads_count', (SELECT COUNT(*) FROM public.leads WHERE admin_id = p.id),
      'clients_count', (SELECT COUNT(*) FROM public.clients WHERE admin_id = p.id),
      'users_count', (SELECT COUNT(*) FROM public.profiles WHERE admin_id = p.id),
      'total_deposits', (
        SELECT COALESCE(SUM(amount), 0) 
        FROM public.deposits 
        WHERE admin_id = p.id AND status = 'approved'
      )
    ) as tenant_stats
    FROM public.profiles p
    INNER JOIN public.user_roles ur ON ur.user_id = p.id
    WHERE ur.role = 'TENANT_OWNER'
  ) subq;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_tenant_stats() TO authenticated;
```

### 2.4 Usage in Dashboard Component

```typescript
// src/pages/Dashboard.tsx - Optimized version
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useUserData } from '@/contexts/UserDataContext';

export default function Dashboard() {
  const { isSuperAdmin, tenantId, isLoading: userLoading } = useUserData();

  // Single query for all dashboard stats
  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['dashboard-stats', tenantId],
    enabled: !userLoading,
    staleTime: 2 * 60 * 1000, // 2 minutes
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_dashboard_stats', {
        p_tenant_id: isSuperAdmin ? null : tenantId
      });
      if (error) throw error;
      return data;
    },
  });

  // Only for SUPER_ADMIN: tenant overview
  const { data: tenantStats } = useQuery({
    queryKey: ['tenant-stats'],
    enabled: isSuperAdmin && !userLoading,
    staleTime: 5 * 60 * 1000, // 5 minutes
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_all_tenant_stats');
      if (error) throw error;
      return data;
    },
  });

  // Render dashboard with stats...
}
```

---

## Phase 3: Database Index Optimization

**Priority:** 🟠 High  
**Timeline:** Day 2  
**Expected Impact:** -60% query time, -50% RLS evaluation time

### 3.1 Add Performance Indexes

```sql
-- Migration: Add performance indexes for RLS and common queries

-- Composite indexes for tenant-scoped queries (most common pattern)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_leads_admin_status 
ON public.leads(admin_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_leads_admin_assigned 
ON public.leads(admin_id, assigned_to);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_leads_admin_created 
ON public.leads(admin_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clients_admin_status 
ON public.clients(admin_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clients_admin_assigned 
ON public.clients(admin_id, assigned_to);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clients_admin_created 
ON public.clients(admin_id, created_at DESC);

-- Profile lookups (critical for RLS)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_admin_id 
ON public.profiles(admin_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_email 
ON public.profiles(email);

-- User roles (called in every RLS policy)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_roles_user_role 
ON public.user_roles(user_id, role);

-- Deposits filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deposits_admin_status 
ON public.deposits(admin_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deposits_admin_created 
ON public.deposits(admin_id, created_at DESC);

-- Attendance lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_attendance_user_date 
ON public.attendance(user_id, date DESC);

-- Notifications (with archiving support)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_read 
ON public.notifications(user_id, is_read, created_at DESC);

-- Notification archiving indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_archived 
ON public.notifications(archived_at) WHERE archived_at IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_recent 
ON public.notifications(user_id, created_at DESC) WHERE archived_at IS NULL;

-- Reminders
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_user_completed 
ON public.reminders(user_id, completed, due_date);
```

### 3.2 Optimize RLS Helper Functions

Replace multiple `has_role()` calls with a single optimized function:

```sql
-- Migration: Optimize RLS helper functions

-- Create optimized admin access check
CREATE OR REPLACE FUNCTION public.has_admin_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
    AND role IN ('SUPER_ADMIN', 'TENANT_OWNER', 'MANAGER')
  )
$$;

-- Create optimized tenant membership check
CREATE OR REPLACE FUNCTION public.is_same_tenant(_user_id uuid, _admin_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = _user_id
    AND (admin_id = _admin_id OR id = _admin_id)
  )
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.has_admin_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_same_tenant(uuid, uuid) TO authenticated;
```

### 3.3 Example RLS Policy Optimization

**Before (multiple function calls):**
```sql
CREATE POLICY "leads_select" ON leads FOR SELECT USING (
  has_role(auth.uid(), 'SUPER_ADMIN'::app_role) OR
  has_role(auth.uid(), 'TENANT_OWNER'::app_role) OR
  has_role(auth.uid(), 'MANAGER'::app_role) OR
  (
    has_role(auth.uid(), 'AGENT'::app_role) AND
    (assigned_to = auth.uid() OR created_by = auth.uid())
  )
);
```

**After (optimized):**
```sql
CREATE POLICY "leads_select" ON leads FOR SELECT USING (
  has_admin_access(auth.uid()) OR
  assigned_to = auth.uid() OR 
  created_by = auth.uid()
);
```

---

## Phase 4: Hook Consolidation

**Priority:** 🟡 Medium  
**Timeline:** Day 2-3  
**Expected Impact:** Code cleanup, maintainability

### 4.1 Remove Redundant Hooks

The following hooks become unnecessary after implementing UserDataContext:

| Hook | Replacement | Action |
|------|-------------|--------|
| `useUserRole` | `useUserData()` | Keep as wrapper during migration |
| `usePhoneVisibility` | `useUserData().canViewPhone` | Delete after migration |
| `useEmailVisibility` | `useUserData().canViewEmail` | Delete after migration |

### 4.2 Consolidated Settings Hook

**File:** `src/hooks/useSettings.ts` (NEW or MODIFY)

```typescript
import { useUserData } from '@/contexts/UserDataContext';

/**
 * Hook for accessing tenant settings
 * All data comes from the centralized UserDataContext
 */
export function useSettings() {
  const { settings, tenantId, isLoading } = useUserData();
  
  return {
    tenantId,
    isLoading,
    // Phone visibility
    showPhoneToAgents: settings.showPhoneToAgents,
    showPhoneToSuperAgents: settings.showPhoneToSuperAgents,
    // Email visibility
    showEmailToAgents: settings.showEmailToAgents,
    showEmailToSuperAgents: settings.showEmailToSuperAgents,
  };
}
```

### 4.3 Migration Pattern for Components

**Before:**
```typescript
import { useUserRole } from '@/hooks/useUserRole';
import { usePhoneVisibility } from '@/hooks/usePhoneVisibility';
import { useEmailVisibility } from '@/hooks/useEmailVisibility';
import { useTenant } from '@/contexts/TenantContext';

function LeadsPage() {
  const { isSuperAdmin, isManager, loading: roleLoading } = useUserRole();
  const { showPhoneToAgents, isLoading: phoneLoading } = usePhoneVisibility();
  const { showEmailToAgents, isLoading: emailLoading } = useEmailVisibility();
  const { effectiveTenantId } = useTenant();
  
  const isLoading = roleLoading || phoneLoading || emailLoading;
  // ...
}
```

**After:**
```typescript
import { useUserData } from '@/contexts/UserDataContext';

function LeadsPage() {
  const { 
    isSuperAdmin, 
    isManager, 
    canViewPhone,
    canViewEmail,
    tenantId,
    isLoading 
  } = useUserData();
  
  // Single loading state, all data available
  // ...
}
```

---

## Phase 5: React Query Configuration

**Priority:** 🟡 Medium  
**Timeline:** Day 3  
**Expected Impact:** -30% background refetches

### 5.1 Optimize Global QueryClient

**File:** `src/App.tsx`

```typescript
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Cache data for 5 minutes before considering stale
      staleTime: 5 * 60 * 1000,
      
      // Keep unused data in cache for 30 minutes
      gcTime: 30 * 60 * 1000,
      
      // Only retry once on failure
      retry: 1,
      
      // Don't refetch when window regains focus
      refetchOnWindowFocus: false,
      
      // Don't refetch on component mount if data exists
      refetchOnMount: false,
      
      // Don't refetch on reconnect if data exists
      refetchOnReconnect: false,
    },
    mutations: {
      // Retry mutations once
      retry: 1,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      {/* ... */}
    </QueryClientProvider>
  );
}
```

### 5.2 Prefetch Critical Data on Auth

**File:** `src/contexts/AuthContext.tsx`

```typescript
import { useQueryClient } from '@tanstack/react-query';

export function AuthProvider({ children }) {
  const queryClient = useQueryClient();

  const signIn = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (data.user) {
      // Immediately prefetch user data after successful login
      queryClient.prefetchQuery({
        queryKey: ['user-data', data.user.id],
        queryFn: () => supabase.rpc('get_user_data', { p_user_id: data.user.id }),
      });
    }

    return { data, error };
  };

  // ...
}
```

### 5.3 Query Key Structure

Standardize query keys for better cache management:

```typescript
// Query key factory
export const queryKeys = {
  // User data
  userData: (userId: string) => ['user-data', userId] as const,
  
  // Dashboard
  dashboardStats: (tenantId: string | null) => ['dashboard-stats', tenantId] as const,
  tenantStats: () => ['tenant-stats'] as const,
  
  // Leads
  leads: (tenantId: string, filters?: object) => ['leads', tenantId, filters] as const,
  lead: (leadId: string) => ['lead', leadId] as const,
  
  // Clients
  clients: (tenantId: string, filters?: object) => ['clients', tenantId, filters] as const,
  client: (clientId: string) => ['client', clientId] as const,
  
  // Settings
  settings: (tenantId: string) => ['settings', tenantId] as const,
};
```

---

## Phase 6: Component-Level Optimizations

**Priority:** 🟢 Low  
**Timeline:** Day 3-4  
**Expected Impact:** Polish, final performance gains

### 6.1 AppLayout Optimization

Current issues:
- Fetches user role independently
- Fetches attendance record on every page load
- Re-renders on every route change

**Optimizations:**
1. Use UserDataContext instead of useUserRole
2. Memoize attendance check
3. Add React.memo to prevent unnecessary re-renders

```typescript
import React, { memo } from 'react';
import { useUserData } from '@/contexts/UserDataContext';

const AppLayout = memo(function AppLayout({ children }) {
  const { role, isLoading } = useUserData();
  
  // Use cached role from context instead of separate query
  // ...
});
```

### 6.2 Verify Lazy Loading

Ensure all page components are properly lazy loaded:

```typescript
// src/App.tsx
import { lazy, Suspense } from 'react';
import { lazyWithRetry } from '@/utils/lazyWithRetry';

// Lazy load all pages
const Dashboard = lazyWithRetry(() => import('./pages/Dashboard'));
const Leads = lazyWithRetry(() => import('./pages/Leads'));
const Clients = lazyWithRetry(() => import('./pages/Clients'));
const Pipeline = lazyWithRetry(() => import('./pages/Pipeline'));
// ... etc

function App() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/leads" element={<Leads />} />
        {/* ... */}
      </Routes>
    </Suspense>
  );
}
```

### 6.3 Memoize Expensive Computations

```typescript
// In data-heavy components
import { useMemo } from 'react';

function LeadsTable({ leads, filters }) {
  // Memoize filtered leads
  const filteredLeads = useMemo(() => {
    return leads.filter(lead => {
      // Complex filtering logic
    });
  }, [leads, filters]);

  // Memoize sorted leads
  const sortedLeads = useMemo(() => {
    return [...filteredLeads].sort((a, b) => {
      // Complex sorting logic
    });
  }, [filteredLeads, sortOrder]);

  return (
    // Render table with sortedLeads
  );
}
```

### 6.4 Virtual Scrolling for Large Lists

For tables with 1000+ rows, implement virtual scrolling:

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualizedTable({ data }) {
  const parentRef = useRef<HTMLDivElement>(null);
  
  const virtualizer = useVirtualizer({
    count: data.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48, // Row height
    overscan: 5,
  });

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <TableRow key={virtualRow.key} data={data[virtualRow.index]} />
        ))}
      </div>
    </div>
  );
}
```

---

## Implementation Timeline

| Day | Phase | Tasks | Owner | Status |
|-----|-------|-------|-------|--------|
| **Day 1** | Phase 1 | Create UserDataContext | Dev | ⬜ Todo |
| **Day 1** | Phase 2.1 | Create get_user_data function | Dev | ⬜ Todo |
| **Day 1** | Phase 1 | Modify TenantContext | Dev | ⬜ Todo |
| **Day 2** | Phase 2.2 | Create dashboard stats functions | Dev | ⬜ Todo |
| **Day 2** | Phase 3.1 | Add database indexes | Dev | ⬜ Todo |
| **Day 2** | Phase 3.2 | Optimize RLS functions | Dev | ⬜ Todo |
| **Day 2-3** | Phase 4 | Migrate components to useUserData | Dev | ⬜ Todo |
| **Day 3** | Phase 5 | Configure React Query | Dev | ⬜ Todo |
| **Day 3-4** | Phase 6 | Component optimizations | Dev | ⬜ Todo |
| **Day 4** | Testing | Full regression testing | QA | ⬜ Todo |

---

## Expected Results

### Performance Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Page load time | 8-15 seconds | 1-2 seconds | **85% faster** |
| Database queries per page | 20+ | 3-5 | **80% reduction** |
| Role queries per session | 28+ | 1 | **96% reduction** |
| Statement timeout errors | Frequent | None | **100% elimination** |
| Dashboard load time | 10+ seconds | <1 second | **90% faster** |

### User Experience Improvements

- ✅ Instant page navigation after initial load
- ✅ No more "Unable to load page" errors
- ✅ Smooth transitions between pages
- ✅ Responsive UI even with large datasets
- ✅ Consistent loading states

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|---------------------|
| Breaking existing functionality | Medium | High | Phased rollout, thorough testing, feature flags |
| Cache staleness issues | Low | Medium | Proper invalidation on mutations, reasonable staleTime |
| Database function errors | Low | High | Extensive testing in staging, rollback plan |
| Migration conflicts | Low | Medium | Backup database before migrations |
| Performance regression | Low | High | Benchmark before/after each phase |

### Rollback Plan

Each phase can be independently reverted:

1. **Phase 1**: Remove UserDataContext, restore original useUserRole
2. **Phase 2**: Drop new database functions (existing queries still work)
3. **Phase 3**: Drop indexes (no functional impact, only performance)
4. **Phase 4**: Restore original hooks from git history
5. **Phase 5**: Reset QueryClient to default options
6. **Phase 6**: Revert component changes

---

## Testing Checklist

### Phase 1: UserDataContext Testing
- [ ] Login as SUPER_ADMIN - verify role detection works
- [ ] Login as TENANT_OWNER - verify tenant isolation
- [ ] Login as MANAGER - verify access levels
- [ ] Login as SUPER_AGENT - verify visibility settings applied
- [ ] Login as AGENT - verify visibility settings applied
- [ ] Verify Network tab shows only 1 role query per session
- [ ] Test session expiry and re-authentication
- [ ] Test role changes (admin updates user role)

### Phase 2: Database Functions Testing
- [ ] Call get_user_data with valid user ID
- [ ] Call get_user_data with invalid user ID
- [ ] Call get_dashboard_stats with tenant ID
- [ ] Call get_dashboard_stats without tenant ID (super admin)
- [ ] Verify get_all_tenant_stats returns all tenants
- [ ] Verify stats accuracy matches original queries
- [ ] Test with empty database (0 leads, clients, etc.)
- [ ] Test with large dataset (1000+ records)

### Phase 3: Index Testing
- [ ] Run EXPLAIN ANALYZE on common queries
- [ ] Verify indexes are being used in query plans
- [ ] Check for any query regressions
- [ ] Test RLS policy performance before/after

### Phase 4: Hook Migration Testing
- [ ] All pages load without errors
- [ ] Role-based UI elements show/hide correctly
- [ ] Phone/email visibility works per settings
- [ ] Tenant context works for SUPER_ADMIN switching

### Phase 5: Query Configuration Testing
- [ ] Verify staleTime prevents unnecessary refetches
- [ ] Test cache invalidation after mutations
- [ ] Verify prefetching works on auth
- [ ] Check memory usage doesn't grow excessively

### Phase 6: Component Testing
- [ ] AppLayout renders without extra queries
- [ ] Lazy loading works for all pages
- [ ] Large tables remain responsive
- [ ] No UI jank or layout shifts

### Integration Testing
- [ ] Complete user workflow: Login → Dashboard → Leads → Create Lead
- [ ] Complete admin workflow: Login → User Management → Create User
- [ ] Complete SUPER_ADMIN workflow: Switch tenants, view all data
- [ ] Test on slow network (3G simulation)
- [ ] Test on mobile devices

---

## Appendix A: Code Snippets

### A.1 Complete UserDataContext Implementation

See Phase 1.2 for the full implementation.

### A.2 Migration SQL Scripts

All SQL migrations should be run in order:
1. `create_get_user_data_function.sql`
2. `create_dashboard_stats_functions.sql`
3. `create_performance_indexes.sql`
4. `optimize_rls_functions.sql`

### A.3 Component Migration Examples

Detailed examples for migrating each major component from the old pattern to the new UserDataContext pattern.

---

## Appendix B: Monitoring Queries

### Check Query Performance

```sql
-- View slow queries
SELECT 
  query,
  calls,
  mean_exec_time,
  total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Check Index Usage

```sql
-- View index usage statistics
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Check RLS Policy Performance

```sql
-- View RLS policy execution times
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public';
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | AI Assistant | Initial document creation |

---

**End of Document**

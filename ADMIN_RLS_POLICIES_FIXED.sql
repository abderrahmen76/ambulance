-- ==========================================
-- ADMIN RLS POLICIES - FIXED VERSION
-- ==========================================
-- 
-- REMOVED: Direct SELECT queries in USING clauses
-- ADDED: Helper function to check user role safely
-- 
-- This version fixes the "infinite recursion detected" error
-- by using a SECURITY DEFINER function that bypasses RLS

-- ==========================================
-- STEP 1: Create helper function (SECURITY DEFINER)
-- ==========================================
-- This function bypasses RLS to safely check user role

CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
AS $$
  SELECT role FROM public.users 
  WHERE auth_user_id = $1 
  LIMIT 1
$$;

-- Verify function created:
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'get_user_role';

-- ==========================================
-- STEP 2: Drop old recursive policies (if they exist)
-- ==========================================
-- These will be the ones causing infinite recursion

DROP POLICY IF EXISTS "Admin SELECT tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin INSERT tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin UPDATE tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin DELETE tenants" ON public.tenants;

DROP POLICY IF EXISTS "Admin SELECT users" ON public.users;
DROP POLICY IF EXISTS "Admin INSERT users" ON public.users;
DROP POLICY IF EXISTS "Admin UPDATE users" ON public.users;
DROP POLICY IF EXISTS "Admin DELETE users" ON public.users;

DROP POLICY IF EXISTS "Admin SELECT ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin INSERT ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin UPDATE ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin DELETE ambulances" ON public.ambulances;

DROP POLICY IF EXISTS "Admin SELECT missions" ON public.missions;
DROP POLICY IF EXISTS "Admin INSERT missions" ON public.missions;
DROP POLICY IF EXISTS "Admin UPDATE missions" ON public.missions;
DROP POLICY IF EXISTS "Admin DELETE missions" ON public.missions;

DROP POLICY IF EXISTS "Admin SELECT fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin INSERT fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin UPDATE fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin DELETE fuel_cards" ON public.fuel_cards;

DROP POLICY IF EXISTS "Admin SELECT maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin INSERT maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin UPDATE maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin DELETE maintenance_records" ON public.maintenance_records;

DROP POLICY IF EXISTS "Admin SELECT equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin INSERT equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin UPDATE equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin DELETE equipment_rentals" ON public.equipment_rentals;

DROP POLICY IF EXISTS "Admin SELECT user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin INSERT user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin UPDATE user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin DELETE user_fcm_tokens" ON public.user_fcm_tokens;

-- ==========================================
-- STEP 3: Create NEW policies using helper function
-- ==========================================

-- ========== TENANTS TABLE ==========
CREATE POLICY "Admin SELECT tenants"
ON public.tenants FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT tenants"
ON public.tenants FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE tenants"
ON public.tenants FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE tenants"
ON public.tenants FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== USERS TABLE ==========
CREATE POLICY "Admin SELECT users"
ON public.users FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT users"
ON public.users FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE users"
ON public.users FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE users"
ON public.users FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== AMBULANCES TABLE ==========
CREATE POLICY "Admin SELECT ambulances"
ON public.ambulances FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT ambulances"
ON public.ambulances FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE ambulances"
ON public.ambulances FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE ambulances"
ON public.ambulances FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== MISSIONS TABLE ==========
CREATE POLICY "Admin SELECT missions"
ON public.missions FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT missions"
ON public.missions FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE missions"
ON public.missions FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE missions"
ON public.missions FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== FUEL_CARDS TABLE ==========
CREATE POLICY "Admin SELECT fuel_cards"
ON public.fuel_cards FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT fuel_cards"
ON public.fuel_cards FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE fuel_cards"
ON public.fuel_cards FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE fuel_cards"
ON public.fuel_cards FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== MAINTENANCE_RECORDS TABLE ==========
CREATE POLICY "Admin SELECT maintenance_records"
ON public.maintenance_records FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT maintenance_records"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE maintenance_records"
ON public.maintenance_records FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE maintenance_records"
ON public.maintenance_records FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== EQUIPMENT_RENTALS TABLE ==========
CREATE POLICY "Admin SELECT equipment_rentals"
ON public.equipment_rentals FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT equipment_rentals"
ON public.equipment_rentals FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE equipment_rentals"
ON public.equipment_rentals FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE equipment_rentals"
ON public.equipment_rentals FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ========== USER_FCM_TOKENS TABLE ==========
CREATE POLICY "Admin SELECT user_fcm_tokens"
ON public.user_fcm_tokens FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin INSERT user_fcm_tokens"
ON public.user_fcm_tokens FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin UPDATE user_fcm_tokens"
ON public.user_fcm_tokens FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin DELETE user_fcm_tokens"
ON public.user_fcm_tokens FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ==========================================
-- STEP 4: Verify all policies were created
-- ==========================================
SELECT COUNT(*) as total_admin_policies 
FROM pg_policies 
WHERE policyname LIKE 'Admin%';

-- Expected: 32 policies (8 tables × 4 operations each)

SELECT tablename, policyname, permissive, cmd
FROM pg_policies
WHERE policyname LIKE 'Admin%'
ORDER BY tablename, cmd;

-- ==========================================
-- NOTE: This fixes the infinite recursion by:
-- ✅ Using SECURITY DEFINER function for role checks
-- ✅ Bypassing RLS for the helper function
-- ✅ Allowing policies on users table without self-reference
-- ✅ Cleaner, more efficient policy logic
-- ==========================================

-- ==========================================
-- COMPLETE ADMIN POLICY CLEANUP & FIX
-- ==========================================
--
-- This script:
-- 1. Drops ALL admin policies (case-insensitive)
-- 2. Verifies helper function
-- 3. Deploys clean non-recursive policies
-- 4. Removes any conflicting policies

-- ==========================================
-- STEP 1: Remove ALL admin policies (cleanup duplicates)
-- ==========================================

-- Tenants
DROP POLICY IF EXISTS "Admin DELETE tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin delete tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin INSERT tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin insert tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin SELECT tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin view all tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin UPDATE tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admin update tenants" ON public.tenants;
DROP POLICY IF EXISTS "Admins can view their tenant" ON public.tenants;
DROP POLICY IF EXISTS "Admins can update their tenant" ON public.tenants;

-- Users
DROP POLICY IF EXISTS "Admin DELETE users" ON public.users;
DROP POLICY IF EXISTS "Admin delete users" ON public.users;
DROP POLICY IF EXISTS "Admin INSERT users" ON public.users;
DROP POLICY IF EXISTS "Admin insert users" ON public.users;
DROP POLICY IF EXISTS "Admin SELECT users" ON public.users;
DROP POLICY IF EXISTS "Admin view all users" ON public.users;
DROP POLICY IF EXISTS "Admin UPDATE users" ON public.users;
DROP POLICY IF EXISTS "Admin update users" ON public.users;

-- Ambulances
DROP POLICY IF EXISTS "Admin DELETE ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin delete ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin INSERT ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin insert ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin SELECT ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin view all ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin UPDATE ambulances" ON public.ambulances;
DROP POLICY IF EXISTS "Admin update ambulances" ON public.ambulances;

-- Missions
DROP POLICY IF EXISTS "Admin DELETE missions" ON public.missions;
DROP POLICY IF EXISTS "Admin delete missions" ON public.missions;
DROP POLICY IF EXISTS "Admin INSERT missions" ON public.missions;
DROP POLICY IF EXISTS "Admin insert missions" ON public.missions;
DROP POLICY IF EXISTS "Admin SELECT missions" ON public.missions;
DROP POLICY IF EXISTS "Admin view all missions" ON public.missions;
DROP POLICY IF EXISTS "Admin UPDATE missions" ON public.missions;
DROP POLICY IF EXISTS "Admin update missions" ON public.missions;

-- Fuel Cards
DROP POLICY IF EXISTS "Admin DELETE fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin delete fuel cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin INSERT fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin insert fuel cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin SELECT fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin view all fuel cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin UPDATE fuel_cards" ON public.fuel_cards;
DROP POLICY IF EXISTS "Admin update fuel cards" ON public.fuel_cards;

-- Maintenance Records
DROP POLICY IF EXISTS "Admin DELETE maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin delete maintenance records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin INSERT maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin insert maintenance records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin SELECT maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin view all maintenance records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin UPDATE maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Admin update maintenance records" ON public.maintenance_records;

-- Equipment Rentals
DROP POLICY IF EXISTS "Admin DELETE equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin delete equipment rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin INSERT equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin insert equipment rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin SELECT equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin view all equipment rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin UPDATE equipment_rentals" ON public.equipment_rentals;
DROP POLICY IF EXISTS "Admin update equipment rentals" ON public.equipment_rentals;

-- FCM Tokens
DROP POLICY IF EXISTS "Admin DELETE user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin delete fcm tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin INSERT user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin insert fcm tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin SELECT user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin view all fcm tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin UPDATE user_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Admin update fcm tokens" ON public.user_fcm_tokens;

-- Verify all deleted
SELECT COUNT(*) as remaining_admin_policies
FROM pg_policies
WHERE policyname ILIKE 'Admin%';
-- Expected: 0

-- ==========================================
-- STEP 2: Recreate helper function
-- ==========================================

DROP FUNCTION IF EXISTS public.get_user_role(UUID);

CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(role, 'none') 
  FROM public.users 
  WHERE auth_user_id = $1 
  LIMIT 1
$$;

-- Test the function
SELECT public.get_user_role(auth.uid()) as current_user_role;

-- ==========================================
-- STEP 3: Deploy new clean policies
-- ==========================================

-- TENANTS
CREATE POLICY "Admin: SELECT tenants"
ON public.tenants FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT tenants"
ON public.tenants FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE tenants"
ON public.tenants FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE tenants"
ON public.tenants FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- USERS
CREATE POLICY "Admin: SELECT users"
ON public.users FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT users"
ON public.users FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE users"
ON public.users FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE users"
ON public.users FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- AMBULANCES
CREATE POLICY "Admin: SELECT ambulances"
ON public.ambulances FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT ambulances"
ON public.ambulances FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE ambulances"
ON public.ambulances FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE ambulances"
ON public.ambulances FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- MISSIONS
CREATE POLICY "Admin: SELECT missions"
ON public.missions FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT missions"
ON public.missions FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE missions"
ON public.missions FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE missions"
ON public.missions FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- FUEL_CARDS
CREATE POLICY "Admin: SELECT fuel_cards"
ON public.fuel_cards FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT fuel_cards"
ON public.fuel_cards FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE fuel_cards"
ON public.fuel_cards FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE fuel_cards"
ON public.fuel_cards FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- MAINTENANCE_RECORDS
CREATE POLICY "Admin: SELECT maintenance_records"
ON public.maintenance_records FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT maintenance_records"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE maintenance_records"
ON public.maintenance_records FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE maintenance_records"
ON public.maintenance_records FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- EQUIPMENT_RENTALS
CREATE POLICY "Admin: SELECT equipment_rentals"
ON public.equipment_rentals FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT equipment_rentals"
ON public.equipment_rentals FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE equipment_rentals"
ON public.equipment_rentals FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE equipment_rentals"
ON public.equipment_rentals FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- USER_FCM_TOKENS
CREATE POLICY "Admin: SELECT user_fcm_tokens"
ON public.user_fcm_tokens FOR SELECT TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: INSERT user_fcm_tokens"
ON public.user_fcm_tokens FOR INSERT TO authenticated
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: UPDATE user_fcm_tokens"
ON public.user_fcm_tokens FOR UPDATE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin')
WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admin: DELETE user_fcm_tokens"
ON public.user_fcm_tokens FOR DELETE TO authenticated
USING (public.get_user_role(auth.uid()) = 'admin');

-- ==========================================
-- STEP 4: Verify deployment
-- ==========================================

SELECT COUNT(*) as total_admin_policies
FROM pg_policies
WHERE policyname LIKE 'Admin:%';
-- Expected: 32

SELECT tablename, policyname, cmd
FROM pg_policies
WHERE policyname LIKE 'Admin:%'
ORDER BY tablename, cmd;

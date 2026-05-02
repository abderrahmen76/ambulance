-- ==========================================
-- ADMIN RLS POLICIES
-- ==========================================
-- 
-- These policies allow ADMIN role to perform CRUD operations
-- across all tenants without restrictions
--
-- Run this in Supabase SQL Editor ONLY
-- After running, verify with: SELECT * FROM pg_policies ORDER BY tablename;

-- ==========================================
-- 1. TENANTS - Admin CRUD
-- ==========================================

-- Admin can SELECT all tenants
CREATE POLICY "Admin view all tenants"
ON public.tenants FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT tenants
CREATE POLICY "Admin insert tenants"
ON public.tenants FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE tenants
CREATE POLICY "Admin update tenants"
ON public.tenants FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE tenants
CREATE POLICY "Admin delete tenants"
ON public.tenants FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 2. USERS - Admin CRUD (cross-tenant)
-- ==========================================

-- Admin can SELECT all users (across all tenants)
CREATE POLICY "Admin view all users"
ON public.users FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT users
CREATE POLICY "Admin insert users"
ON public.users FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE users
CREATE POLICY "Admin update users"
ON public.users FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE users
CREATE POLICY "Admin delete users"
ON public.users FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 3. AMBULANCES - Admin CRUD (cross-tenant)
-- ==========================================

-- Admin can SELECT all ambulances
CREATE POLICY "Admin view all ambulances"
ON public.ambulances FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT ambulances
CREATE POLICY "Admin insert ambulances"
ON public.ambulances FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE ambulances
CREATE POLICY "Admin update ambulances"
ON public.ambulances FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE ambulances
CREATE POLICY "Admin delete ambulances"
ON public.ambulances FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 4. MISSIONS - Admin CRUD (cross-tenant)
-- ==========================================

-- Admin can SELECT all missions
CREATE POLICY "Admin view all missions"
ON public.missions FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT missions
CREATE POLICY "Admin insert missions"
ON public.missions FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE missions
CREATE POLICY "Admin update missions"
ON public.missions FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE missions
CREATE POLICY "Admin delete missions"
ON public.missions FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 5. FUEL_CARDS - Admin CRUD (cross-tenant)
-- ==========================================

-- Admin can SELECT all fuel cards
CREATE POLICY "Admin view all fuel cards"
ON public.fuel_cards FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT fuel cards
CREATE POLICY "Admin insert fuel cards"
ON public.fuel_cards FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE fuel cards
CREATE POLICY "Admin update fuel cards"
ON public.fuel_cards FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE fuel cards
CREATE POLICY "Admin delete fuel cards"
ON public.fuel_cards FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 6. MAINTENANCE_RECORDS - Admin CRUD
-- ==========================================

-- Admin can SELECT all maintenance records
CREATE POLICY "Admin view all maintenance records"
ON public.maintenance_records FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT maintenance records
CREATE POLICY "Admin insert maintenance records"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE maintenance records
CREATE POLICY "Admin update maintenance records"
ON public.maintenance_records FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE maintenance records
CREATE POLICY "Admin delete maintenance records"
ON public.maintenance_records FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 7. EQUIPMENT_RENTALS - Admin CRUD
-- ==========================================

-- Admin can SELECT all equipment rentals
CREATE POLICY "Admin view all equipment rentals"
ON public.equipment_rentals FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT equipment rentals
CREATE POLICY "Admin insert equipment rentals"
ON public.equipment_rentals FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE equipment rentals
CREATE POLICY "Admin update equipment rentals"
ON public.equipment_rentals FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE equipment rentals
CREATE POLICY "Admin delete equipment rentals"
ON public.equipment_rentals FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- 8. USER_FCM_TOKENS - Admin CRUD
-- ==========================================

-- Admin can SELECT all FCM tokens
CREATE POLICY "Admin view all fcm tokens"
ON public.user_fcm_tokens FOR SELECT TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can INSERT FCM tokens
CREATE POLICY "Admin insert fcm tokens"
ON public.user_fcm_tokens FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can UPDATE FCM tokens
CREATE POLICY "Admin update fcm tokens"
ON public.user_fcm_tokens FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);

-- Admin can DELETE FCM tokens
CREATE POLICY "Admin delete fcm tokens"
ON public.user_fcm_tokens FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'admin'
);


-- ==========================================
-- VERIFICATION QUERY
-- ==========================================
/*
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  cmd
FROM pg_policies 
WHERE schemaname = 'public' AND policyname LIKE 'Admin%'
ORDER BY tablename;

-- Expected: 48 admin policies (6 operations per table × 8 tables)
-- Tables: tenants, users, ambulances, missions, fuel_cards, 
--         maintenance_records, equipment_rentals, user_fcm_tokens
*/

-- ==========================================
-- ✅ ADMIN RLS COMPLETE
-- ==========================================
-- Admin users can now:
-- ✅ CRUD all tenants (cross-tenant access)
-- ✅ CRUD all users (admin user management)
-- ✅ CRUD all ambulances (fleet management)
-- ✅ CRUD all missions
-- ✅ CRUD all fuel cards
-- ✅ CRUD all maintenance records
-- ✅ CRUD all equipment rentals
-- ✅ CRUD all FCM tokens

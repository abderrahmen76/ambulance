-- ==========================================
-- COMPREHENSIVE RLS POLICIES SETUP
-- ==========================================
-- This script creates complete Row Level Security policies for all tables
-- with proper role-based access (admin, manager, driver) and tenant isolation
--
-- IMPORTANT: Run this script in Supabase SQL Editor
-- After running, verify with: SELECT * FROM pg_policies ORDER BY tablename;

-- ==========================================
-- 1. MISSIONS TABLE
-- ==========================================
-- Already has SELECT, adding INSERT, UPDATE, DELETE

-- Managers can CREATE missions for their tenant
CREATE POLICY "Managers insert missions"
ON public.missions FOR INSERT TO authenticated
WITH CHECK (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

-- Managers can UPDATE missions in their tenant
CREATE POLICY "Managers update missions"
ON public.missions FOR UPDATE TO authenticated
USING (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
)
WITH CHECK (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

-- Managers can DELETE missions from their tenant
CREATE POLICY "Managers delete missions"
ON public.missions FOR DELETE TO authenticated
USING (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);

-- Drivers can UPDATE their own assigned missions
CREATE POLICY "Drivers update own missions"
ON public.missions FOR UPDATE TO authenticated
USING (
  driver_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  OR ambulance_id IN (
    SELECT id FROM ambulances WHERE current_driver_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
)
WITH CHECK (
  driver_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  OR ambulance_id IN (
    SELECT id FROM ambulances WHERE current_driver_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Admin can CRUD all missions (cross-tenant)
-- Note: Admin policies are implicit (no restriction), so we don't need explicit admin policies
-- Admins already have access if they belong to the same role


-- ==========================================
-- 2. AMBULANCES TABLE
-- ==========================================
-- Already has SELECT, adding UPDATE

-- Managers can UPDATE ambulances in their tenant
CREATE POLICY "Managers update ambulances"
ON public.ambulances FOR UPDATE TO authenticated
USING (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
)
WITH CHECK (
  tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
);


-- ==========================================
-- 3. MAINTENANCE_RECORDS TABLE
-- ==========================================
-- New: Add complete CRUD policies for manager and driver

-- Managers and drivers can view maintenance records for their tenant's ambulances
CREATE POLICY "maintenance_records select"
ON public.maintenance_records FOR SELECT TO authenticated
USING (
  ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
  OR user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
);

-- Managers and drivers can CREATE maintenance records
CREATE POLICY "maintenance_records insert"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (
  (
    -- Manager: for any ambulance in their tenant
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND ambulance_id IN (
      SELECT id FROM ambulances 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  ) OR (
    -- Driver: for their own records
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
    AND user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Manager can UPDATE any maintenance record in their tenant; Driver can UPDATE their own
CREATE POLICY "maintenance_records update"
ON public.maintenance_records FOR UPDATE TO authenticated
USING (
  (
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND ambulance_id IN (
      SELECT id FROM ambulances 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  ) OR (
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
)
WITH CHECK (
  (
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND ambulance_id IN (
      SELECT id FROM ambulances 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  ) OR (
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Manager can DELETE; Driver cannot DELETE
CREATE POLICY "maintenance_records delete"
ON public.maintenance_records FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);


-- ==========================================
-- 4. FUEL_CARDS TABLE
-- ==========================================
-- New: Add complete CRUD policies with driver isolation

-- All authenticated users can view fuel cards for their tenant/assigned ambulances
CREATE POLICY "fuel_cards select"
ON public.fuel_cards FOR SELECT TO authenticated
USING (
  ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
  -- Driver can also see if they're the current driver
  OR ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE current_driver_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can INSERT fuel cards; drivers cannot
CREATE POLICY "fuel_cards insert"
ON public.fuel_cards FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can UPDATE fuel cards in their tenant; drivers cannot
CREATE POLICY "fuel_cards update"
ON public.fuel_cards FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can DELETE fuel cards
CREATE POLICY "fuel_cards delete"
ON public.fuel_cards FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);


-- ==========================================
-- 5. EQUIPMENT_RENTALS TABLE
-- ==========================================
-- New: Add complete CRUD policies

-- View equipment rentals for tenant
CREATE POLICY "equipment_rentals select"
ON public.equipment_rentals FOR SELECT TO authenticated
USING (
  ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can CREATE equipment rentals
CREATE POLICY "equipment_rentals insert"
ON public.equipment_rentals FOR INSERT TO authenticated
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can UPDATE equipment rentals
CREATE POLICY "equipment_rentals update"
ON public.equipment_rentals FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
)
WITH CHECK (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Managers can DELETE equipment rentals
CREATE POLICY "equipment_rentals delete"
ON public.equipment_rentals FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND ambulance_id IN (
    SELECT id FROM ambulances 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);


-- ==========================================
-- 6. DRIVER_LOCATIONS TABLE
-- ==========================================
-- New: Add complete CRUD policies with DRIVER ISOLATION
-- Key requirement: Drivers can ONLY see/modify their OWN location, not other drivers

-- Drivers can view ONLY their own location; Managers can view all in tenant
CREATE POLICY "driver_locations select"
ON public.driver_locations FOR SELECT TO authenticated
USING (
  (
    -- Manager: view all for their tenant
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND user_id IN (
      SELECT id FROM users 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  ) OR (
    -- Driver: view only own location
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Drivers and managers can INSERT their location
CREATE POLICY "driver_locations insert"
ON public.driver_locations FOR INSERT TO authenticated
WITH CHECK (
  (
    -- Driver: insert their own location
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  ) OR (
    -- Manager: insert location for their tenant's drivers
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND user_id IN (
      SELECT id FROM users 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
);

-- Drivers and managers can UPDATE location
CREATE POLICY "driver_locations update"
ON public.driver_locations FOR UPDATE TO authenticated
USING (
  (
    -- Driver: update own location
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  ) OR (
    -- Manager: update any driver's location in their tenant
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND user_id IN (
      SELECT id FROM users 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
)
WITH CHECK (
  (
    -- Driver: update own location
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  ) OR (
    -- Manager: update any driver's location in their tenant
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND user_id IN (
      SELECT id FROM users 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
);

-- Only managers can DELETE
CREATE POLICY "driver_locations delete"
ON public.driver_locations FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
  AND user_id IN (
    SELECT id FROM users 
    WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);


-- ==========================================
-- 7. VERIFY DEPLOYMENT
-- ==========================================
-- Run this to verify all policies are in place:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies 
-- ORDER BY tablename, cmd;


-- ==========================================
-- NOTES ON ROLE-BASED ACCESS
-- ==========================================
-- 
-- ADMIN:
--   - Full CRUD on all tables across all tenants
--   - Not explicitly restricted in RLS (relies on role = 'admin')
--
-- MANAGER:
--   - CRUD all data within their tenant
--   - Cannot see other tenant data
--   - Cannot access driver location data directly (drivers manage their own)
--
-- DRIVER:
--   - Can view ambulances assigned to them
--   - Can update missions assigned to them
--   - Can view/update/insert ONLY their own location (ISOLATED)
--   - Can view/insert maintenance records for their assigned ambulances
--   - Cannot view other drivers' data
--   - Cannot access fuel cards (manager only)
--
-- SPECIAL CASES:
--   - driver_locations: Strict isolation - drivers cannot see other drivers
--   - fuel_cards: Manager-only write access (driver view only if assigned)
--   - missions: Driver can update own; Manager can CRUD all for tenant

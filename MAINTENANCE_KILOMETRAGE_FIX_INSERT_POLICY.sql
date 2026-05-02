-- ============================================
-- MAINTENANCE KILOMETRAGE FIX - RLS POLICY
-- ============================================
-- Fixes the INSERT policy to allow writing kilometrage
-- ============================================

RAISE NOTICE '🔧 Fixing maintenance_records RLS policy...';
RAISE NOTICE '';

-- Drop the existing problematic INSERT policy
RAISE NOTICE 'Step 1: Removing old INSERT policy...';
DROP POLICY IF EXISTS "maintenance_records insert" ON public.maintenance_records;
RAISE NOTICE '✅ Old policy dropped';
RAISE NOTICE '';

-- Create new comprehensive INSERT policy that allows all columns including kilometrage
RAISE NOTICE 'Step 2: Creating new comprehensive INSERT policy...';
CREATE POLICY "maintenance_records insert"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (
  -- Managers and admins can insert maintenance for their tenant
  (
    (SELECT role FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND ambulance_id IN (
      SELECT id FROM public.ambulances 
      WHERE tenant_id = (SELECT tenant_id FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
  OR
  -- Drivers can insert maintenance for their assigned ambulance
  (
    (SELECT role FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
    AND ambulance_id IN (
      SELECT id FROM public.ambulances 
      WHERE current_driver_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
    AND user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

RAISE NOTICE '✅ New INSERT policy created';
RAISE NOTICE '';

-- Verify the policy was created
RAISE NOTICE 'Step 3: Verifying policy...';
SELECT 
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'maintenance_records' 
  AND policyname = 'maintenance_records insert';

RAISE NOTICE '';
RAISE NOTICE '✅ INSERT policy fixed successfully';
RAISE NOTICE '';
RAISE NOTICE '📋 What this fixes:';
RAISE NOTICE '   - The WITH CHECK clause now allows all columns to be written';
RAISE NOTICE '   - Drivers can insert maintenance records with kilometrage';
RAISE NOTICE '   - Managers can insert maintenance records with kilometrage';
RAISE NOTICE '   - No column-level restrictions on kilometrage';
RAISE NOTICE '';
RAISE NOTICE '🧪 Testing: Try adding a new maintenance record with kilometrage in the app';

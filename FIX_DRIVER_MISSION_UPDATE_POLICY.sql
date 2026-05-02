-- CRITICAL RLS FIX: Allow drivers to update pending missions
-- Problem: Drivers cannot accept pending missions because RLS policy only allows
-- updates to missions where driver_id or ambulance_id already match their assignment
-- Solution: Add condition to allow drivers to update pending missions (ambulance_id IS NULL)

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Drivers update own missions" ON public.missions;

-- Create new policy that allows drivers to:
-- 1. Update missions they're assigned to (driver_id matches)
-- 2. Update missions for ambulances they're driving (ambulance_id matches their ambulance)
-- 3. UPDATE PENDING MISSIONS (ambulance_id IS NULL) in their tenant
-- NOTE: Cast UUIDs to TEXT to handle type mismatch between integer driver_id and UUID user id
CREATE POLICY "Drivers update own missions"
ON public.missions FOR UPDATE TO authenticated
USING (
  -- Can update if driver_id matches current user (cast UUID to text)
  driver_id::text = (SELECT id::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  -- OR can update if ambulance_id matches their assigned ambulance
  OR ambulance_id::text IN (
    SELECT id::text FROM ambulances WHERE current_driver_id::text = (SELECT id::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
  -- OR can update if mission is pending (ambulance_id is NULL) and in their tenant
  OR (
    ambulance_id IS NULL
    AND tenant_id = (SELECT tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
  )
)
WITH CHECK (
  -- Same conditions for WITH CHECK
  driver_id::text = (SELECT id::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  OR ambulance_id::text IN (
    SELECT id::text FROM ambulances WHERE current_driver_id::text = (SELECT id::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
  OR (
    ambulance_id IS NULL
    AND tenant_id = (SELECT tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    AND (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
  )
);

-- Verify the policy was created
SELECT * FROM pg_policies WHERE tablename = 'missions' AND policyname = 'Drivers update own missions';

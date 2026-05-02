-- CRITICAL RLS FIX: Allow drivers to insert fuel card records
-- Problem: Drivers cannot refuel (insert fuel_cards) because policy only allows admin/manager
-- Solution: Add driver role to fuel_cards INSERT policy for their assigned ambulances

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "fuel_cards insert" ON public.fuel_cards;

-- Create new policy that allows:
-- 1. Admins/Managers to insert fuel cards for ambulances in their tenant
-- 2. Drivers to insert fuel cards for their assigned ambulance
-- NOTE: Cast UUIDs to TEXT to handle type mismatches
CREATE POLICY "fuel_cards insert"
ON public.fuel_cards FOR INSERT TO authenticated
WITH CHECK (
  -- Managers can insert for any ambulance in their tenant
  (
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND (ambulance_id)::text IN (
      SELECT (id)::text FROM ambulances 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
  -- OR Drivers can insert for their assigned ambulance (cast to TEXT for comparison)
  OR (
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
    AND (ambulance_id)::text IN (
      SELECT (id)::text FROM ambulances 
      WHERE (current_driver_id)::text = (SELECT (id)::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  )
);

-- Verify the policy was created
SELECT * FROM pg_policies WHERE tablename = 'fuel_cards' AND policyname = 'fuel_cards insert';

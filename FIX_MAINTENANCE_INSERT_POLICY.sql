-- CRITICAL RLS FIX: Allow drivers to insert maintenance records
-- Problem: Drivers cannot insert maintenance records due to type mismatch or incorrect policy logic
-- Solution: Fix type casting and ensure drivers can record maintenance for their ambulance

-- Drop the old policy
DROP POLICY IF EXISTS "maintenance_records insert" ON public.maintenance_records;

-- Create new policy with proper type casting
CREATE POLICY "maintenance_records insert"
ON public.maintenance_records FOR INSERT TO authenticated
WITH CHECK (
  (
    -- Managers can insert for any ambulance in their tenant
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
    AND (ambulance_id)::text IN (
      SELECT (id)::text FROM ambulances 
      WHERE tenant_id = (SELECT users.tenant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
  ) OR (
    -- Drivers can insert maintenance records for their assigned ambulance
    -- Cast UUIDs to TEXT for comparison
    (SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1) = 'driver'
    AND (ambulance_id)::text IN (
      SELECT (id)::text FROM ambulances 
      WHERE (current_driver_id)::text = (SELECT (id)::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
    )
    AND (user_id)::text = (SELECT (id)::text FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
  )
);

-- Verify the policy was created
SELECT * FROM pg_policies WHERE tablename = 'maintenance_records' AND policyname = 'maintenance_records insert';

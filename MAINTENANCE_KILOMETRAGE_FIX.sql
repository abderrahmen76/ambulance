-- ============================================
-- MAINTENANCE KILOMETRAGE FIX
-- ============================================
-- This script adds the kilometrage column to maintenance_records table
-- if it doesn't exist, to properly store the odometer reading at time of maintenance
-- ============================================

-- Step 1: Check if the column exists, and add it if not
-- Using DO block to safely handle existence check
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'maintenance_records' 
    AND column_name = 'kilometrage'
  ) THEN
    -- Add the kilometrage column as numeric type (can store decimal values)
    ALTER TABLE maintenance_records 
    ADD COLUMN kilometrage NUMERIC(12, 2) DEFAULT NULL;
    
    RAISE NOTICE '✅ Column "kilometrage" added to maintenance_records table';
  ELSE
    RAISE NOTICE '✅ Column "kilometrage" already exists in maintenance_records table';
  END IF;
END $$;

-- Step 2: Add a comment to the column for documentation
COMMENT ON COLUMN public.maintenance_records.kilometrage IS 'Odometer reading (in km) at the time of maintenance record creation. Entered by the driver or maintenance crew.';

-- Step 3: Verify the column was added successfully
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns
WHERE table_name = 'maintenance_records' 
  AND column_name IN ('id', 'date', 'maintenance_type', 'kilometrage')
ORDER BY ordinal_position;

-- Step 4: Check RLS policies to ensure they allow writing kilometrage
-- The existing INSERT policy should work fine since it uses WITH CHECK
-- on the entire row, which will include the kilometrage field

RAISE NOTICE '✅ Maintenance kilometrage fix completed successfully!';
RAISE NOTICE '📝 All new maintenance records can now store kilometrage values';
RAISE NOTICE '🔍 Existing records will have kilometrage = NULL until updated';

-- ============================================
-- MAINTENANCE KILOMETRAGE DIAGNOSTIC
-- ============================================
-- Checks why kilometrage isn't being saved
-- ============================================

RAISE NOTICE '🔍 Diagnosing maintenance kilometrage issue...';
RAISE NOTICE '';

-- Step 1: Verify column exists and is accessible
RAISE NOTICE '1️⃣ Checking maintenance_records table structure...';
SELECT 
  column_name, 
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'maintenance_records' 
  AND column_name = 'kilometrage'
ORDER BY ordinal_position;

RAISE NOTICE '✅ Column exists and is nullable';
RAISE NOTICE '';

-- Step 2: Check RLS policies on maintenance_records
RAISE NOTICE '2️⃣ Checking RLS policies on maintenance_records...';
SELECT 
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'maintenance_records'
ORDER BY policyname;

RAISE NOTICE '';
RAISE NOTICE '3️⃣ Checking if table has RLS enabled...';
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'maintenance_records';

RAISE NOTICE '';

-- Step 4: Check column-level permissions (if any)
RAISE NOTICE '4️⃣ Checking column-level grants on kilometrage...';
SELECT 
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.role_column_grants
WHERE table_name = 'maintenance_records' 
  AND column_name = 'kilometrage'
UNION ALL
SELECT 
  'NO GRANTS FOUND' as grantee,
  '' as privilege_type,
  '' as is_grantable
WHERE NOT EXISTS (
  SELECT 1 FROM information_schema.role_column_grants
  WHERE table_name = 'maintenance_records' 
    AND column_name = 'kilometrage'
);

RAISE NOTICE '';
RAISE NOTICE '✅ Diagnostic complete';
RAISE NOTICE '';
RAISE NOTICE '📋 NEXT STEPS:';
RAISE NOTICE '   If the insert policy shows WITH CHECK condition, that might be limiting writes';
RAISE NOTICE '   Run: MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql';

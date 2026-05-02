-- ============================================
-- MAINTENANCE KILOMETRAGE - DISABLE RLS
-- ============================================
-- Simplest possible fix: turn OFF RLS on maintenance_records table
-- All authenticated users can then insert/update freely
-- ============================================

-- Disable RLS entirely on maintenance_records
ALTER TABLE public.maintenance_records DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'maintenance_records';

-- That's it. Drivers can now save kilometrage.

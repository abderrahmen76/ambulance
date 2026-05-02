-- ============================================
-- MAINTENANCE KILOMETRAGE - SIMPLE FIX
-- ============================================
-- Just grant INSERT permission to authenticated role
-- No complex RLS policies, no conditions - SIMPLE
-- ============================================

-- Grant INSERT permission on kilometrage column to authenticated role
GRANT INSERT (kilometrage) ON TABLE public.maintenance_records TO authenticated;

-- Verify the grant
SELECT grantee, privilege_type, is_grantable
FROM information_schema.role_column_grants
WHERE table_name = 'maintenance_records' 
  AND column_name = 'kilometrage'
  AND grantee = 'authenticated';

-- ==========================================
-- FIX ADMIN USER TENANT_ID
-- ==========================================
--
-- Issue: Admin user (id=11) has tenant_id=NULL
-- This causes FCM token insertion to fail
--
-- Solution: Assign admin user to the first/only tenant

-- STEP 1: Check admin user status
SELECT id, email, name, role, tenant_id 
FROM public.users 
WHERE role = 'admin' AND id = 11;

-- STEP 2: Check available tenants
SELECT id, name 
FROM public.tenants 
LIMIT 1;

-- STEP 3: Update admin user with first tenant_id
UPDATE public.users
SET tenant_id = (
  SELECT id FROM public.tenants LIMIT 1
)
WHERE role = 'admin' AND id = 11;

-- STEP 4: Verify admin user now has tenant_id
SELECT id, email, name, role, tenant_id 
FROM public.users 
WHERE role = 'admin' AND id = 11;

-- EXPECTED OUTPUT:
-- id | email               | name             | role  | tenant_id
-- 11 | admin@yourtenant.com| Administrator    | admin | [TENANT_UUID]

-- ==========================================
-- OPTIONAL: Alternative fix for FCM function
-- ==========================================
-- If you want to allow NULL tenant_id for admin users,
-- modify the FCM trigger function:
--
-- In user_fcm_tokens trigger:
-- CHANGE FROM:
-- IF NEW.tenant_id IS NULL THEN
--   RAISE EXCEPTION 'User must belong to a tenant';
-- END IF;
--
-- CHANGE TO:
-- IF NEW.tenant_id IS NULL AND (SELECT role FROM users WHERE id = NEW.user_id) != 'admin' THEN
--   RAISE EXCEPTION 'User must belong to a tenant';
-- END IF;
--
-- This allows NULL tenant_id ONLY for admin users
-- ==========================================

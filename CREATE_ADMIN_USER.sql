-- ==========================================
-- CREATE ADMIN USER - Diagnostic & Fix
-- ==========================================
-- 
-- ERROR: auth_user_id already exists in database
-- This means the UUID 'fb2232c2-687b-49f6-8791-556e42ca901a' 
-- is already linked to another user

-- STEP 1: Check current admin auth_user_id mapping
SELECT id, email, name, role, auth_user_id 
FROM public.users 
WHERE auth_user_id = 'fb2232c2-687b-49f6-8791-556e42ca901a';

-- STEP 2: Check if admin@test.com exists
SELECT id, email, name, role, auth_user_id 
FROM public.users 
WHERE email = 'admin@test.com';

-- ==========================================
-- SOLUTION: Create NEW admin user in Supabase Auth first
-- ==========================================
-- 
-- 1. Go to Supabase Dashboard → Authentication → Users
-- 2. Click "Create Account" button
-- 3. Enter:
--    - Email: admin@yourtenant.com (MUST be verified email)
--    - Password: Strong password
-- 4. Copy the NEW UUID (e.g., 550e8400-e29b-41d4-a716-446655440000)
-- 5. Replace 'YOUR_NEW_UUID_HERE' below with that UUID
-- 6. Run the INSERT below

INSERT INTO public.users (
  email, 
  name, 
  role, 
  is_active, 
  auth_user_id
) VALUES (
  'admin@yourtenant.com',
  'Administrator',
  'admin',
  true,
  'YOUR_NEW_UUID_HERE'  -- <-- REPLACE WITH YOUR NEW SUPABASE UUID
)
ON CONFLICT (email) DO UPDATE
SET 
  role = 'admin',
  is_active = true,
  auth_user_id = 'YOUR_NEW_UUID_HERE'
RETURNING id, email, name, role, auth_user_id;

-- ==========================================
-- If above fails, use Option 2: Update existing
-- ==========================================
-- If admin@test.com already exists, just update it:
/*
UPDATE public.users 
SET 
  role = 'admin',
  is_active = true,
  auth_user_id = 'fb2232c2-687b-49f6-8791-556e42ca901a',
  name = 'Administrator'
WHERE email = 'admin@test.com'
RETURNING *;
*/

-- ==========================================
-- Verify admin user was created/updated
-- ==========================================
/*
SELECT id, email, name, role, is_active, auth_user_id, tenant_id
FROM public.users 
WHERE email = 'admin@test.com';

-- Expected result:
-- id | email           | name             | role  | is_active | auth_user_id                        | tenant_id
-- -- | --------------- | -----------      | ----- | --------- | ----------------------------------- | ---------
-- ?? | admin@test.com  | Administrator    | admin | true      | fb2232c2-687b-49f6-8791-556e42ca901a | NULL
*/

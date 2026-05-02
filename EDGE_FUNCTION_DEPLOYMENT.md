# Edge Function Deployment Guide

## 🚀 What Changed

**OLD (unsafe):** Direct SQL inserts into `auth.users` via RPC
**NEW (safe):** Edge Function with Supabase Admin API

---

## ✅ Deployment Steps

### Step 1: Create Edge Function Directory

In your Supabase project, create:

```
supabase/functions/create-user/index.ts
```

### Step 2: Copy the Function Code

Copy the contents of `EDGE_FUNCTION_create_user.ts` to:

```
supabase/functions/create-user/index.ts
```

### Step 3: Create CORS Helper (if needed)

Create `supabase/functions/_shared/cors.ts`:

```ts
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
```

### Step 4: Deploy

**Using Supabase CLI:**

```bash
supabase functions deploy create-user --project-id YOUR_PROJECT_ID
```

**Or via Supabase Dashboard:**

1. Go to Functions → Create Function
2. Name: `create-user`
3. Paste the TypeScript code
4. Deploy

---

## 🔐 Verify Deployment

The function should appear in Supabase Dashboard:

- Functions → create-user → Status: Active

---

## 🧪 Test the Function

### Test in Supabase Dashboard

1. Go to Functions → create-user
2. Click "Test"
3. Sample payload:

```json
{
  "email": "testuser@example.com",
  "password": "TempPass123!@",
  "name": "Test User",
  "tenant_id": "62a79092-42a9-4146-adec-e75935fccd69",
  "role": "driver"
}
```

### Expected Success Response:

```json
{
  "auth_user_id": "uuid-here",
  "user_id": "uuid-here",
  "email": "testuser@example.com",
  "name": "Test User",
  "role": "driver",
  "tenant_id": "62a79092-42a9-4146-adec-e75935fccd69",
  "is_active": true,
  "temporary_password": "TempPass123!@",
  "message": "User created successfully"
}
```

---

## 🔍 Security - What This Does

✅ Uses `auth.admin.createUser()` - SAFE official API
✅ Service role key stays on backend - NEVER exposed
✅ Supabase Auth handles all security:

- Argon2 password hashing
- Email verification logic
- Session management
- MFA compatibility
  ✅ Then inserts into `public.users` - links to auth user
  ✅ Rollback if database insert fails - maintains consistency

---

## 🚨 Security - What This Blocks

❌ Direct `auth.users` inserts - NOT POSSIBLE
❌ Incompatible password hashing - None (uses official hashing)
❌ Unauthenticated user creation - Requires JWT token
❌ Anon user creation - Only authenticated users can call function

---

## 🐛 Troubleshooting

**Error: "Edge function not found"**

- Make sure function is deployed and active in dashboard
- Check function name matches: `create-user`

**Error: "Missing authorization header"**

- Flutter app isn't sending JWT token
- Check user is logged in before creating user

**Error: "Email already exists"**

- User already registered in Supabase Auth
- Check: Auth → Users for duplicates

**Database rollback happened (user deleted from auth)**

- `public.users` insert failed after auth user created
- Check:
  - Tenant ID exists
  - RLS policies allow insert
  - public.users table structure

---

## 📝 What Flutter does now

1. Admin clicks "Create User" button
2. Flutter calls Edge Function via `supabase.functions.invoke()`
3. Edge Function uses **service role key** to create auth user
4. Edge Function inserts into `public.users`
5. Flutter receives response with temporary password
6. Flutter shows password dialog

---

## ✅ Checklist

- [ ] Copied EDGE_FUNCTION_create_user.ts code
- [ ] Created supabase/functions/create-user/index.ts
- [ ] Deployed function via CLI or Dashboard
- [ ] Function status shows "Active"
- [ ] Tested function in dashboard
- [ ] Hot restart Flutter app
- [ ] Test user creation from UI

---

## 🎉 Benefits of This Approach

✅ Production-grade security
✅ Follows Supabase official patterns
✅ Maintainable long-term
✅ Works with OAuth, MFA, etc.
✅ No manual password hashing
✅ Service role key never exposed
✅ Proper error handling + rollback

# Supabase Configuration Diagnostic

## Issue

Edge Function receiving `401 Invalid JWT` from Supabase gateway when Flutter calls `create-user` function.

### Current Status

✅ JWT is valid (`eyJhbGciOiJFUzI1NiIs...`)  
✅ Session is valid  
❌ Gateway rejects with 401 BEFORE function code runs

---

## Root Cause Analysis

The `401 Invalid JWT` at the gateway level means **Supabase's authentication middleware is rejecting the request before it reaches the function code**.

This happens when:

1. The JWT was signed with a different Supabase project's secret key
2. Environment variables in Edge Function don't match Flutter's configuration
3. The JWT's claims (iss, aud) don't match the target Supabase project

---

## Configuration Checklist

### Step 1: Verify Flutter Supabase Configuration

**File:** `lib/config/constants.dart`

```dart
static const String supabaseUrl = 'https://uxsimhenmvyessotnnmx.supabase.co';
static const String anonKey = 'sb_publishable_nlrCg7avzbCpLMzaAs-MBw_usjdOpTL';
```

✅ **Verified**: Project ID is `uxsimhenmvyessotnnmx`

### Step 2: Verify Edge Function Environment Configuration

The Edge Function needs these environment variables set in Supabase dashboard:

- `SUPABASE_URL`: Must match Flutter's URL (`https://uxsimhenmvyessotnnmx.supabase.co`)
- `SUPABASE_ANON_KEY`: Must match Flutter's anonKey (`sb_publishable_nlrCg7avzbCpLMzaAs-MBw_usjdOpTL`)
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key for admin operations

**YOUR TASK**:

1. Go to Supabase Dashboard
2. Navigate to **Project Settings** → **API** section
3. Verify that the URL and anon key match your Flutter configuration above
4. Check the Edge Function environment variables under **Functions**

### Step 3: Decode JWT to Check Claims

Copy the JWT from the debug output:

```
eyJhbGciOiJFUzI1NiIsImtpZCI6Ij...
```

Use https://jwt.io to decode it and verify:

- **iss** (issuer) claim should be your Supabase project URL
- **aud** (audience) claim should match expected audience
- **sub** (subject) should be the user ID

### Step 4: Root Cause - Most Likely

**Check if the problem is:**

Option A: **Incorrect environment variables in Edge Function**

- Edge Function is using wrong `SUPABASE_ANON_KEY`
- This would cause JWT verification to fail

Option B: **JWT is expired or corrupted**

- Session was created from cache and is stale
- Login session needs to be refreshed

Option C: **Different Supabase project used**

- Flutter connected to project A
- Edge Function configured for project B

---

## Solution Steps

### **Immediate Fix - Try This First:**

**Remove JWT verification from Edge Function** and let Supabase handle it.

The updated Edge Function now:

1. Takes the Authorization header
2. Extracts the JWT token
3. Uses it with anonClient to verify: `const { data: { user }, error } = await anonClient.auth.getUser(token)`

**To deploy:**

```bash
cd supabase/functions/create-user
supabase functions deploy create-user
```

### **If Above Fails - Debug Steps:**

1. **Add logging to Edge Function:**

   ```typescript
   console.log(`SUPABASE_URL: ${Deno.env.get("SUPABASE_URL")}`);
   console.log(
     `SUPABASE_ANON_KEY: ${Deno.env.get("SUPABASE_ANON_KEY")?.substring(0, 20)}...`,
   );
   ```

2. **Check Supabase project ID:**
   - Your project: **uxsimhenmvyessotnnmx**
   - Verify in Supabase dashboard that this is the correct project

3. **Refresh Flutter session:**
   - Sign out and sign back in
   - This will get a fresh JWT token from the current session

4. **Check Edge Function logs in Supabase dashboard:**
   - Go to **Functions** → **create-user** → **Logs**
   - Look for actual error messages

---

## What to Check RIGHT NOW

### 🔍 **Critical - Do This:**

1. **Verify Edge Function environment variables are set**
   - Supabase Dashboard → Functions → Environment Variables
   - Check that `SUPABASE_ANON_KEY` matches: `sb_publishable_nlrCg7avzbCpLMzaAs-MBw_usjdOpTL`

2. **Verify Supabase project is correct**
   - Dashboard should show project: `uxsimhenmvyessotnnmx`
   - If you see a different project ID, that's the issue!

3. **Check if Edge Function was correctly deployed**
   - Logs might show deployment errors

4. **Re-deploy Edge Function after environment setup**
   ```bash
   supabase functions deploy create-user
   ```

---

## Next Steps

1. **Please verify the Supabase project configuration** and let me know:
   - Is the Edge Function in the same Supabase project?
   - What is shown in the Edge Function environment variables?

2. **Share JWT decode results** from jwt.io:
   - Copy the full JWT token from the logs
   - Decode at https://jwt.io
   - Share the `iss` and `aud` claims

3. **Check Edge Function logs in Supabase dashboard:**
   - Any error messages before the 401?

Once you provide this information, I can identify the exact cause and fix it.

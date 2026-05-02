// Deploy this to Supabase Edge Functions
// Path: supabase/functions/create-user/index.ts
// SECURE VERSION with JWT verification + Role-based access + Tenant isolation

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body = await req.json()
    const { email, password, name, tenant_id, role } = body

    if (!email || !password || !name || !tenant_id || !role) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: email, password, name, tenant_id, role" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ✅ LAYER 1: JWT VERIFICATION
    console.log(`[CreateUser] Verifying JWT...`)
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      console.error(`[CreateUser] Missing authorization header`)
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Verify JWT using anon key
    const jwtClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    const { data: { user: callingUser }, error: authError } = await jwtClient.auth.getUser()

    if (authError || !callingUser) {
      console.error(`[CreateUser] JWT verification failed: ${authError?.message}`)
      return new Response(
        JSON.stringify({ error: "Invalid or expired JWT" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log(`[CreateUser] JWT verified for user: ${callingUser.id}`)

    // Create service role client for admin operations
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // ✅ LAYER 2: ROLE CHECK (Admin only)
    console.log(`[CreateUser] Checking if caller is admin...`)
    const { data: callerProfile, error: profileError } = await supabase
      .from("users")
      .select("id, role, tenant_id")
      .eq("auth_user_id", callingUser.id)
      .single()

    if (profileError || !callerProfile) {
      console.error(`[CreateUser] Failed to fetch caller profile: ${profileError?.message}`)
      return new Response(
        JSON.stringify({ error: "User profile not found" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (callerProfile.role !== "admin") {
      console.error(`[CreateUser] Caller is not admin (role: ${callerProfile.role})`)
      return new Response(
        JSON.stringify({ error: "Only admins can create users" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log(`[CreateUser] Caller is admin ✓`)

    // ✅ LAYER 3: TENANT ISOLATION CHECK
    // Admin can only create users in their own tenant
    console.log(`[CreateUser] Checking tenant isolation...`)
    if (callerProfile.tenant_id !== tenant_id) {
      console.error(
        `[CreateUser] Cross-tenant creation blocked (caller: ${callerProfile.tenant_id}, requested: ${tenant_id})`
      )
      return new Response(
        JSON.stringify({ error: "Cannot create users in other tenants" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log(`[CreateUser] Tenant isolation check passed ✓`)

    // ✅ LAYER 4: CREATE AUTH USER
    console.log(`[CreateUser] Creating user: ${email} (role: ${role}, tenant: ${tenant_id})`)
    const { data: authData, error: authCreateError } = 
      await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name, tenant_id, role },
      })

    if (authCreateError || !authData.user?.id) {
      console.error(`[CreateUser] Auth creation failed: ${authCreateError?.message}`)
      return new Response(
        JSON.stringify({ error: `Auth creation failed: ${authCreateError?.message}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const auth_user_id = authData.user.id
    console.log(`[CreateUser] Auth user created: ${auth_user_id}`)

    // ✅ LAYER 5: CREATE DATABASE RECORD
    console.log(`[CreateUser] Creating user profile in public.users...`)
    const { data: userData, error: dbError } = await supabase
      .from("users")
      .insert({
        auth_user_id,
        email,
        name,
        role,
        tenant_id,
        is_active: true,
      })
      .select()
      .single()

    if (dbError) {
      console.error(`[CreateUser] Database error: ${dbError.message}, rolling back auth user...`)
      try {
        await supabase.auth.admin.deleteUser(auth_user_id)
        console.log(`[CreateUser] Auth user rolled back`)
      } catch (deleteError) {
        console.error(`[CreateUser] Failed to rollback: ${deleteError}`)
      }
      return new Response(
        JSON.stringify({ error: `Database error: ${dbError.message}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const user_id = userData?.id
    console.log(`[CreateUser] ✅ User created successfully`)
    console.log(`[CreateUser] Auth ID: ${auth_user_id}, User ID: ${user_id}`)

    // Return success response
    return new Response(
      JSON.stringify({
        auth_user_id,
        user_id: user_id || "",
        email,
        name,
        role,
        tenant_id,
        is_active: true,
        temporary_password: password,
        message: "User created successfully",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (e) {
    console.error(`[CreateUser] Unexpected error:`, e)
    return new Response(
      JSON.stringify({ error: `Server error: ${String(e)}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

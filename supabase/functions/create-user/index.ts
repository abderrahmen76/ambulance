import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// Helper to generate UUID v4
function generateUUID(): string {
  return crypto.randomUUID()
}

Deno.serve(async (req) => {
  console.log("[ENTRY] Function handler called - method:", req.method)

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    console.log("[STEP] 1 - Get environment variables")
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

    console.log("[CHECK] SUPABASE_URL:", supabaseUrl ? "✓" : "✗")
    console.log("[CHECK] SERVICE_ROLE_KEY:", supabaseKey ? "✓" : "✗")

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing environment variables")
    }

    console.log("[STEP] 2 - Parse request body")
    const body = await req.json()
    const { email, password, name, tenant_id, role } = body

    console.log("[DATA] Email:", email)
    console.log("[DATA] Name:", name)
    console.log("[DATA] Tenant:", tenant_id)
    console.log("[DATA] Role:", role)

    if (!email || !password || !name || !tenant_id || !role) {
      throw new Error("Missing required fields")
    }

    console.log("[STEP] 3 - Create Supabase admin client")
    const admin = createClient(supabaseUrl, supabaseKey)
    console.log("[SUCCESS] Admin client created")

    console.log("[STEP] 4 - Create auth user FIRST")
    const { data: authData, error: authError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, tenant_id, role },
    })

    if (authError) {
      console.log("[AUTH] Error:", JSON.stringify(authError))
      console.log("[AUTH] Error message:", authError.message)
      throw new Error(`Auth creation failed: ${authError.message}`)
    }

    const auth_user_id = authData?.user?.id
    console.log("[AUTH] Auth user created:", auth_user_id)

    console.log("[STEP] 5 - Get authorization header")
    const authHeader = req.headers.get("Authorization")
    console.log("[AUTH] Header present:", authHeader ? "yes" : "no")

    let userId = null
    if (authHeader && authHeader.startsWith("Bearer ")) {
      console.log("[JWT] Decoding JWT...")
      const token = authHeader.substring(7)
      const parts = token.split(".")
      
      if (parts.length === 3) {
        try {
          const payload = JSON.parse(atob(parts[1]))
          userId = payload.sub
          console.log("[JWT] Caller ID:", userId)
        } catch (jwtError) {
          console.log("[JWT] Decode error:", jwtError)
        }
      }
    }

    console.log("[STEP] 6 - Check permissions")
    if (userId) {
      const { data: profile, error: fetchError } = await admin
        .from("users")
        .select("role, tenant_id, id")
        .eq("auth_user_id", userId)
        .single()

      if (fetchError) {
        console.log("[PERM] Query error:", JSON.stringify(fetchError))
        await admin.auth.admin.deleteUser(auth_user_id)
        throw new Error(`Permission check failed: ${fetchError.message}`)
      }

      console.log("[PERM] - Role:", profile?.role)
      console.log("[PERM] - Tenant:", profile?.tenant_id)

      if (profile?.role !== "admin") {
        console.log("[PERM] Not admin, denying access")
        await admin.auth.admin.deleteUser(auth_user_id)
        throw new Error("User is not admin")
      }

      const isSystemAdmin = !profile?.tenant_id
      const isSameTenant = profile?.tenant_id === tenant_id

      console.log("[PERM] Is system admin:", isSystemAdmin)
      console.log("[PERM] Same tenant:", isSameTenant)

      if (!isSystemAdmin && !isSameTenant) {
        console.log("[PERM] Tenant mismatch")
        await admin.auth.admin.deleteUser(auth_user_id)
        throw new Error(`User can only manage tenant ${profile?.tenant_id}`)
      }

      console.log("[PERM] ✓ Permissions OK")
    } else {
      console.log("[PERM] No user context - skipping permission checks")
    }

    console.log("[STEP] 7 - Clean up orphaned records with this email")
    // Delete orphaned records (auth_user_id IS NULL) before inserting new one
    const { error: deleteError } = await admin
      .from("users")
      .delete()
      .eq("email", email)
      .eq("tenant_id", tenant_id)
      .is("auth_user_id", null)

    if (deleteError) {
      console.log("[DB] Warning - cleanup error:", deleteError.message)
      // Continue anyway - might not have orphaned records
    } else {
      console.log("[DB] ✓ Cleanup completed for email:", email)
    }

    console.log("[STEP] 8 - Generate Account ID")
    const newAccountId = generateUUID()
    console.log("[DB_INSERT] Generated new account ID:", newAccountId)

    // Log the exact data being inserted
    console.log("[DB_INSERT] About to insert with:")
    console.log("[DB_INSERT]   - id:", newAccountId)
    console.log("[DB_INSERT]   - auth_user_id:", auth_user_id)
    console.log("[DB_INSERT]   - email:", email)
    console.log("[DB_INSERT]   - name:", name)
    console.log("[DB_INSERT]   - role:", role, "(type:", typeof role, ")")
    console.log("[DB_INSERT]   - tenant_id:", tenant_id)
    console.log("[DB_INSERT]   - is_active: true")

    const insertPayload = {
      id: newAccountId,
      auth_user_id,
      email,
      name,
      role,
      tenant_id,
      is_active: true,
    }

    console.log("[DB_INSERT] Full payload:", JSON.stringify(insertPayload))

    const { data: userData, error: dbError } = await admin
      .from("users")
      .insert(insertPayload)
      .select()
      .single()

    if (dbError) {
      console.log("[DB] Error:", JSON.stringify(dbError))
      console.log("[DB] Error message:", dbError.message)
      console.log("[DB] Error code:", dbError.code)
      console.log("[DB] Full error:", dbError)
      await admin.auth.admin.deleteUser(auth_user_id)
      throw new Error(`Database error: ${dbError.message}`)
    }

    const user_id = userData?.id
    console.log("[DB] Profile created:", user_id)
    console.log("[DB_CONFIRM] Inserted user role:", userData?.role, "(should be:", role, ")")

    // STEP 9 - If driver role, create corresponding ambulance
    let ambulanceData = null
    if (role === "driver") {
      console.log("[AMBULANCE] Creating ambulance for new driver...")
      const ambulanceId = generateUUID()
      // Generate ambulance number: AMB-<YYYY><MM><DD><HHMM>
      const now = new Date()
      const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '')
      const timeStr = now.toTimeString().slice(0, 5).replace(/:/g, '')
      const ambulanceNumber = `AMB-${dateStr}${timeStr}`
      
      const ambulancePayload = {
        id: ambulanceId,
        tenant_id,
        ambulance_number: ambulanceNumber,
        current_driver_id: user_id,
      }

      console.log("[AMBULANCE] Inserting ambulance:", JSON.stringify(ambulancePayload))
      console.log("[AMBULANCE] Using service role (should bypass RLS)...")

      const { data: ambData, error: ambError } = await admin
        .from("ambulances")
        .insert([ambulancePayload])
        .select()

      if (ambError) {
        console.log("[AMBULANCE] ❌ Error creating ambulance:")
        console.log("[AMBULANCE]   - Code:", ambError.code)
        console.log("[AMBULANCE]   - Message:", ambError.message)
        console.log("[AMBULANCE]   - Details:", ambError.details)
        console.log("[AMBULANCE]   - Hint:", ambError.hint)
        console.log("[AMBULANCE] Continuing anyway - user profile created successfully")
        // Don't fail - user is already created, just warn about ambulance
      } else {
        ambulanceData = ambData && ambData[0] ? ambData[0] : null
        console.log("[AMBULANCE] ✓ Ambulance created successfully!")
        console.log("[AMBULANCE]   - ID:", ambulanceId)
        console.log("[AMBULANCE]   - Number:", ambulanceNumber)
        console.log("[AMBULANCE]   - Driver ID:", user_id)
        console.log("[AMBULANCE]   - Tenant ID:", tenant_id)
      }
    }

    console.log("[FINAL] SUCCESS - User created")

    return new Response(
      JSON.stringify({
        id: user_id,
        auth_user_id,
        email,
        name,
        role,
        tenant_id,
        is_active: true,
        temporary_password: password,
        ambulance_id: ambulanceData?.id || null,
        ambulance_number: ambulanceData?.ambulance_number || null,
        message: role === "driver" 
          ? "Driver account and ambulance created successfully"
          : "User created successfully",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )

  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.log("[ERROR]", message)

    return new Response(
      JSON.stringify({
        id: null,
        auth_user_id: null,
        email: null,
        name: null,
        role: null,
        tenant_id: null,
        is_active: false,
        temporary_password: null,
        message: message,
        error: true,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    )
  }
})


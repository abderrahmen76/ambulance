# Admin User & Dashboard Setup Guide

## 🎯 Overview

This guide helps you create an admin user and deploy the complete admin dashboard for managing:

- **Tenants** (create, read, update, delete)
- **Users** (create, read, update, delete across all tenants)
- **Ambulances** (create, read, update, delete fleet-wide)

---

## 📋 Prerequisites

✅ Supabase project set up  
✅ Database tables created (tenants, users, ambulances, etc.)  
✅ RLS policies deployed for manager/driver (DEPLOY_MISSING_RLS_POLICIES.sql)  
✅ Flutter app built and running

---

## 🚀 Step-by-Step Setup

### Step 1: Deploy Admin RLS Policies

**File**: `ADMIN_RLS_POLICIES.sql`

1. Open **Supabase Dashboard** → Your Project
2. Go to **SQL Editor**
3. Click **New Query**
4. Copy entire content of `ADMIN_RLS_POLICIES.sql`
5. Paste into SQL Editor
6. Click **Run**

**Expected Result**:

```
✅ 48 admin policies created
✅ No errors
```

**Verify** with verification query in the file or:

```sql
SELECT COUNT(*) as admin_policies FROM pg_policies
WHERE policyname LIKE 'Admin%';
-- Should return: 48
```

---

### Step 2: Create Admin User in Database

Admin users must be created manually in the database. You have two options:

#### Option A: Via Supabase Dashboard (Manual)

1. Go to **Supabase Dashboard** → **Authentication**
2. Click **Users**
3. Create a new user:
   - Email: `admin@yourdomain.com`
   - Password: (auto-generate or set your own)
   - Auto Confirm: ✅ ON

4. Once created, note the **User ID** (UUID)

5. Add user to `public.users` table:
   - Go to **SQL Editor** → **New Query**
   - Run this SQL (replace values):

```sql
INSERT INTO public.users (
  email,
  name,
  role,
  tenant_id,
  is_active,
  auth_user_id
) VALUES (
  'admin@yourdomain.com',           -- your admin email
  'System Administrator',            -- display name
  'admin',                           -- role MUST be 'admin'
  (SELECT id FROM tenants LIMIT 1),  -- any tenant ID (or NULL for global)
  true,                              -- active
  'YOUR_AUTH_UUID_HERE'              -- paste the User ID from step 4
);
```

#### Option B: Via SQL (Automated)

If you haven't created the auth user yet, use this approach:

```sql
-- First, create the auth user via backend API or manual creation
-- Then insert into users table

-- Create user record
INSERT INTO public.users (
  email,
  name,
  role,
  tenant_id,
  is_active,
  auth_user_id
) VALUES (
  'admin@yourdomain.com',
  'System Administrator',
  'admin',
  (SELECT id FROM tenants LIMIT 1),
  true,
  'UUID-FROM-AUTH-USER'  -- Replace with actual UUID from auth.users
)
ON CONFLICT (email) DO UPDATE
SET role = 'admin', is_active = true;
```

---

### Step 3: Test Admin Login

1. **Start Flutter app** (or rebuild if needed)
2. Go to **Login Screen**
3. Enter admin email: `admin@yourdomain.com`
4. Enter password: (the one you set)
5. Click **Login**

**Expected Result**:

```
✅ [STEP 1] Auth successful
✅ [STEP 2] User profile fetched (role: admin)
✅ [STEP 3] Redirects to Admin Dashboard (red header)
```

---

### Step 4: Verify Admin Dashboard

Once logged in as admin, you should see:

```
┌─────────────────────────────────────────────┐
│  Admin Dashboard              Admin: [Name] │
├─────────┬──────────┬──────────────────────────┤
│ Tenants │  Users   │  Ambulances              │
├─────────┴──────────┴──────────────────────────┤
│                                               │
│  ┌─────────┐  ┌─────────┐  ┌─────────────┐  │
│  │ Tenants │  │  Users  │  │ Ambulances  │  │
│  │    N    │  │   M     │  │      A      │  │
│  └─────────┘  └─────────┘  └─────────────┘  │
│                                               │
│  [List of Tenants]                            │
│  [List of Users]                              │
│  [List of Ambulances]                         │
└─────────────────────────────────────────────┘
```

---

## 🎮 Admin Features

### Tenants Management

**View**:

- See all tenants across entire system
- View name, slug, description, subscription status

**Create**:

- Click **+ Create Tenant**
- Enter: Name, Slug (URL-friendly), Description
- Auto-assigns: basic tier, 10 ambulances limit, 50 users limit

**Edit**:

- Click **⋮** → **Edit**
- Modify name, description, subscription tier, limits

**Delete**:

- Click **⋮** → **Delete**
- Confirmation required

### Users Management

**View**:

- Filter by role: All, Admin, Manager, Driver
- See email, name, role, active status
- Color-coded avatars (Red=Admin, Orange=Manager, Green=Driver)

**Create**:

- Click **+ Create User**
- Enter: Email, Name, Role
- Auto-assigned to active status

**Edit**:

- Click **⋮** → **Edit**
- Change: Name, Role, Active Status

**Delete**:

- Click **⋮** → **Delete**
- Confirmation required

### Ambulances Management

**View**:

- See all ambulances from all tenants
- View number, phone, kilometrage

**Create**:

- Click **+ Create Ambulance**
- Enter: Ambulance Number, Phone, Tenant

**Edit**:

- Click **⋮** → **Edit**
- Modify: Number, Phone, Kilometrage

**Delete**:

- Click **⋮** → **Delete**
- Confirmation required

---

## 🔐 Security Model

### Admin Role

- ✅ CRUD all **tenants** (system-wide)
- ✅ CRUD all **users** (any tenant)
- ✅ CRUD all **ambulances** (any tenant)
- ✅ View all **missions**, **fuel cards**, **maintenance**, **equipment**
- ✅ View **statistics** and **analytics**
- ❌ Cannot view driver **locations** (privacy policy)

### Manager Role

- ✅ CRUD own tenant **users**, **ambulances**, **missions**
- ✅ View own tenant **fuel cards**, **maintenance**
- ❌ Cannot access other tenants
- ❌ Cannot view driver locations

### Driver Role

- ✅ View assigned **ambulances**
- ✅ Update own **missions**, **locations**
- ✅ Add **maintenance records**, **fuel cards**
- ❌ Cannot CRUD anything globally

---

## 🔗 Implementation Files

### Code Files

- `lib/services/admin_service.dart` - Admin API operations
- `lib/screens/admin_dashboard_screen.dart` - Main admin interface
- `lib/screens/admin_tenants_screen.dart` - Tenant management
- `lib/screens/admin_users_screen.dart` - User management
- `lib/screens/admin_ambulances_screen.dart` - Ambulance management

### SQL Files

- `ADMIN_RLS_POLICIES.sql` - RLS policies for admin role
- `DEPLOY_MISSING_RLS_POLICIES.sql` - Manager/driver policies

### Configuration

- `lib/main.dart` - Updated routing for admin dashboard

---

## 🧪 Testing Admin Functionality

### Test 1: Create Tenant

```
1. Login as admin
2. Go to "Tenants" tab
3. Click "+ Create Tenant"
4. Fill: Name="Test Org", Slug="test-org", Description="Test"
5. Click Create
✅ Expect: New tenant appears in list
```

### Test 2: Create User

```
1. Go to "Users" tab
2. Click "+ Create User"
3. Fill: Email="driver@test.com", Name="John", Role="driver"
4. Click Create
✅ Expect: User appears in list with correct role color
```

### Test 3: Create Ambulance

```
1. Go to "Ambulances" tab
2. Click "+ Create Ambulance"
3. Fill: Number="AMB-001", Phone="555-1234"
4. Click Create
✅ Expect: Ambulance appears in list
```

### Test 4: Cross-Tenant Access

```
1. Admin creates two tenants: "Tenant A", "Tenant B"
2. Admin can see BOTH in dashboard
3. Manager from Tenant A logs in
4. Manager only sees Tenant A data
✅ Expect: Proper tenant isolation works
```

---

## ⚠️ Common Issues

### Issue: "Permission denied" when creating tenant

```
Check: User role is exactly 'admin' (case-sensitive)
Fix: SELECT * FROM users WHERE email = 'admin@...';
Should show: role = 'admin'
```

### Issue: Admin dashboard shows no data

```
Check: RLS policies were deployed (ADMIN_RLS_POLICIES.sql)
Fix: Verify policies exist:
SELECT COUNT(*) FROM pg_policies WHERE policyname LIKE 'Admin%';
Should return: 48
```

### Issue: Can't login even with correct credentials

```
Check: Auth user exists in Supabase
Go to: Authentication → Users
Should see: admin@yourdomain.com with email_confirmed = true
```

### Issue: User appears in database but still can't login

```
Cause: Email not yet confirmed in auth
Fix:
1. Go to Supabase Authentication section
2. Find the user
3. Click to expand
4. Set "Email Confirmed At" to current timestamp
```

---

## 📊 Admin Dashboard API Endpoints

All requests made through `AdminService`:

```dart
// Initialize
final adminService = AdminService();

// Tenants
await adminService.getAllTenants()           // GET all
await adminService.getTenantById(id)         // GET one
await adminService.createTenant(...)         // POST
await adminService.updateTenant(...)         // PATCH
await adminService.deleteTenant(id)          // DELETE

// Users
await adminService.getAllUsers()             // GET all
await adminService.getUserById(id)           // GET one
await adminService.createUser(...)           // POST
await adminService.updateUser(...)           // PATCH
await adminService.deleteUser(id)            // DELETE
await adminService.deactivateUser(id)        // Deactivate

// Ambulances
await adminService.getAllAmbulances()        // GET all
await adminService.getAmbulanceById(id)      // GET one
await adminService.createAmbulance(...)      // POST
await adminService.updateAmbulance(...)      // PATCH
await adminService.deleteAmbulance(id)       // DELETE

// Statistics
await adminService.getDashboardStats()       // Analytics
```

---

## 🔄 Flow Diagram

```
User Login
    ↓
[AuthService.login()]
    ↓
Check role: auth_user.role
    ├─ admin    → AdminDashboardScreen
    ├─ manager  → ManagerDashboardScreen
    └─ driver   → DashboardScreen
    ↓
[Admin sees 3 tabs]
    ├─ Tenants    → AdminTenantsScreen
    ├─ Users      → AdminUsersScreen
    └─ Ambulances → AdminAmbulancesScreen
    ↓
[Each screen calls AdminService]
    ├─ getAllTenants()
    ├─ getAllUsers()
    └─ getAllAmbulances()
    ↓
[Results filtered by RLS policies]
    → Only data admin can see
    → Cross-tenant access allowed
```

---

## ✅ Deployment Checklist

- [ ] ADMIN_RLS_POLICIES.sql deployed to Supabase
- [ ] 48 admin policies confirmed in pg_policies
- [ ] Admin auth user created in Supabase
- [ ] Admin user record created in public.users
- [ ] Admin user role set to 'admin'
- [ ] Flutter app rebuilt with new admin screens
- [ ] Logged in successfully as admin
- [ ] Can see all three tabs (Tenants, Users, Ambulances)
- [ ] Can create/read/update/delete in each
- [ ] Cross-tenant access working correctly
- [ ] Non-admin users cannot become admin via RLS

---

## 🎓 What's Next?

1. **Audit Logging** - Log all admin actions
2. **Two-Factor Auth** - Require 2FA for admin login
3. **Admin Reports** - Analytics & system health
4. **Bulk Operations** - Import/export users and ambulances
5. **Permissions UI** - Fine-grained role editor
6. **Webhooks** - Notify external systems of changes

---

**Status**: ✅ Ready for Production  
**Version**: 1.0  
**Last Updated**: April 12, 2026

# Admin User Creation - Full Auth Integration

## Overview

Admin users are now created with **proper Supabase Auth integration**. When an admin creates a user, the system:

1. **Creates auth user** in Supabase Authentication
2. **Creates user record** in public.users table
3. **Links them** via auth_user_id
4. **Assigns tenant and role**
5. **Shows temporary password** to admin

---

## User Creation Flow

### Step 1: Admin Opens "Create User" Dialog

- Admin clicks "+ Create User" button in Users tab
- Dialog shows:
  - Email field
  - Full Name field
  - **Tenant dropdown** (required)
  - **Role dropdown** (admin/manager/driver)

### Step 2: Admin Submits Form

- System validates all fields
- Calls `AdminService.createUser()`

### Step 3: Backend Creates Auth User

```dart
// In AdminService.createUser():
1. Generate temporary password (16 chars, mixed case + symbols)
2. Call Supabase.auth.admin.createUser() with:
   - email: email_from_form
   - password: generated_password
   - emailConfirm: true (auto-verified)
3. Get auth_user_id from response
4. Create public.users record with auth_user_id
5. Set role = 'admin'|'manager'|'driver'
6. Set tenant_id from form
7. Return user data + temporary_password
```

### Step 4: Show Password Dialog

After success, displays green dialog with:

- ✅ Confirmation: "User Created Successfully!"
- 📧 User email
- 🔐 **Temporary Password** (selectable, can copy)
- ⚠️ Note: "User should change password on first login"

### Step 5: User Can Login

New user can immediately login with:

- **Email**: whatever@domain.com
- **Password**: [temporary password shown]

On first login, user should:

1. Go to Settings/Profile
2. Change password to something permanent
3. Continue using app

---

## Code Changes

### AdminService Updates

#### Added Imports

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
```

#### New Method: `_generateTemporaryPassword()`

```dart
String _generateTemporaryPassword() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
  final random = Random.secure();
  return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
}
```

#### Updated Method: `createUser()`

Now handles full auth creation:

```dart
Future<Map<String, dynamic>> createUser({
  required String email,
  required String name,
  required String tenantId,
  required String role,
  String? password,  // Optional custom password
}) async {
  // 1. Generate temp password
  final tempPassword = password ?? _generateTemporaryPassword();

  // 2. Create auth user
  final authResponse = await Supabase.instance.client.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: tempPassword,
      emailConfirm: true,
    ),
  );

  // 3. Create public.users record
  final userResponse = await _apiClient.post('/rest/v1/users', {
    'email': email,
    'name': name,
    'tenant_id': tenantId,
    'role': role,
    'auth_user_id': authResponse.user.id,
    'is_active': true,
  });

  // 4. Return with password
  return {
    ...userResponse,
    'auth_user_id': authResponse.user.id,
    'temporary_password': tempPassword,
  };
}
```

### Admin Users Screen Updates

#### Added Import

```dart
import 'package:flutter/services.dart';
```

#### New Method: `_showPasswordDialog()`

Displays dialog with:

- Temporary password in selectable text
- Copy button (uses Clipboard)
- Done button

#### Updated Create Dialog

- Shows password dialog after successful creation
- Captures response with temporary_password
- Calls `_showPasswordDialog(email, tempPassword)`

---

## Temporary Password Properties

- **Length**: 16 characters
- **Complexity**: Mixed case + numbers + symbols (!@#$%^&\*)
- **Security**: Generated using `Random.secure()`
- **Auto-confirmed**: Email is auto-verified (no confirmation email needed)
- **First login**: User should change password immediately

### Example Temporary Password

```
Px7#qL2@nR9$kM4!
```

---

## User Table After Creation

After creating a user "john@company.com":

```sql
SELECT id, email, name, role, tenant_id, auth_user_id, is_active
FROM public.users
WHERE email = 'john@company.com';

-- Result:
-- id  | email              | name | role    | tenant_id | auth_user_id | is_active
-- 12  | john@company.com   | John | manager | [UUID]    | [UUID]       | true
```

---

## Authentication Tables

### Supabase auth.users (Created by Supabase)

```
id: [AUTO-GENERATED UUID]
email: john@company.com
email_confirmed_at: [NOW]
encrypted_password: [HASHED]
```

### public.users (Created by AdminService)

```
id: [AUTO-INCREMENT]
email: john@company.com
name: John
role: manager
tenant_id: [TENANT_UUID]
auth_user_id: [MATCHES auth.users.id]
is_active: true
```

---

## Testing

### Test Case 1: Create Manager User

1. Click "+ Create User"
2. Enter:
   - Email: `manager@test.com`
   - Name: `Test Manager`
   - Tenant: Select a tenant
   - Role: Manager
3. Click Create
4. ✅ Password dialog appears with temporary password
5. ✅ User appears in list
6. ✅ Can login with email + temp password

### Test Case 2: Admin User Creation

Same as above, but Role = Admin

User should then be able to:

- Access admin dashboard
- Create other users
- Manage tenants

### Test Case 3: Failed Creation (Missing Tenant)

1. Try to create user without selecting tenant
2. ❌ Error: "Email, Name, and Tenant are required"

---

## User Experience

### For Admin

1. Click "+ Create User"
2. Fill form (email, name, pick tenant, pick role)
3. Click "Create"
4. See password dialog
5. Copy password & Send to new user (via email, chat, etc)
6. User list refreshes with new user

### For New User

1. Receive email with credentials
2. Login with email + temporary password
3. App logs them in
4. Go to Settings → Change Password
5. Update to permanent password
6. Continue using app

---

## Security Notes

✅ **Passwords are NOT sent via email** - Admin copies & sends separately  
✅ **Passwords are NOT stored in database** - Only Supabase Auth stores hash  
✅ **Email is auto-confirmed** - No confirmation email needed  
✅ **RLS policies enforce tenant isolation** - User can only see their tenant's data  
✅ **Admin-only operation** - Only users with role='admin' can create users

---

## Troubleshooting

### Error: "Auth User Already Exists"

**Issue**: User with that email already exists in Supabase Auth  
**Fix**: Use different email or delete existing auth user in Supabase Dashboard

### Error: "Tenant Not Found"

**Issue**: Tenant dropdown is empty  
**Fix**: Make sure at least one tenant exists. Create a tenant first.

### Error: "Invalid Email"

**Issue**: Email format is wrong  
**Fix**: Enter valid email (e.g., user@company.com)

### Password Dialog Doesn't Show

**Issue**: User creation succeeded but dialog didn't display  
**Fix**: Check console for errors, try creating another user

---

## Future Enhancements

- [ ] Send invitation email with password automatically
- [ ] Allow admin to set custom password instead of generating
- [ ] Show creation timestamp in user list
- [ ] Log admin actions (who created which users)
- [ ] Bulk user import from CSV
- [ ] Send password reset email instead of temp password
- [ ] Require password change on first login (forced)

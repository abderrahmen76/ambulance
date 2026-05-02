# Admin Hierarchical Tenant Management

## Overview

The admin dashboard now implements **hierarchical tenant-based CRUD operations**. When creating or editing users and ambulances, admins must select the tenant they belong to, enabling proper multi-tenant data isolation and organization.

---

## Features

### 1. **Users Management - Hierarchical**

#### Create User

- **New Required Field**: Tenant dropdown (fetches all available tenants)
- **Fields**:
  - Email (required)
  - Full Name (required)
  - **Tenant (required)** ← NEW
  - Role (admin/manager/driver)
- **Validation**: All fields including tenant must be selected
- **Result**: User is created with assigned tenant_id

#### Edit User

- **Tenant Dropdown**: Shows current tenant, can be changed
- **Actions**: Can move user to different tenant
- **Editable Fields**:
  - Full Name
  - **Tenant** ← NEW EDITABLE
  - Role
  - Active status

#### Display

- **User List Shows**:
  - Name, Email, Role, Active status
  - **Tenant ID** displayed in subtitle (UUID format)

---

### 2. **Ambulances Management - Hierarchical**

#### Create Ambulance

- **New Required Field**: Tenant dropdown (fetches all available tenants)
- **Fields**:
  - **Tenant (required)** ← NEW (appears first)
  - Ambulance Number (required)
  - Phone Number (optional)
- **Validation**: Tenant must be selected
- **Result**: Ambulance is created with assigned tenant_id

#### Edit Ambulance

- **Tenant Dropdown**: Shows current tenant, can be changed
- **Actions**: Can move ambulance to different tenant
- **Editable Fields**:
  - **Tenant** ← NEW EDITABLE
  - Ambulance Number
  - Phone Number
  - Kilometrage

#### Display

- **Ambulance List Shows**:
  - Vehicle number, phone, kilometrage
  - **Tenant ID** displayed in subtitle (UUID format)

---

### 3. **Tenants Management - No Change**

Tenants screen remains unchanged. Admins still:

- Create tenants (name, slug, description)
- View all tenants
- Edit tenant details
- Delete tenants

**Note**: Tenants do not have a "parent tenant" - they are top-level organizations.

---

## Code Changes

### **AdminService Updates**

#### `updateUser()` - Added tenant parameter

```dart
Future<void> updateUser(
  String userId, {
  String? name,
  String? email,
  String? tenantId,      // ← NEW
  String? role,
  bool? isActive,
}) async
```

#### `updateAmbulance()` - Added tenant parameter

```dart
Future<void> updateAmbulance(
  String ambulanceId, {
  String? ambulanceNumber,
  String? telephone,
  String? tenantId,       // ← NEW
  String? currentDriverId,
  double? kilometrage,
}) async
```

### **Admin Users Screen Updates**

1. **Create Dialog**:
   - Added `FutureBuilder` to load tenants
   - Added tenant dropdown field
   - Added validation: `selectedTenantId == null`
   - Pass `tenantId` to `createUser()`

2. **Edit Dialog**:
   - Added `FutureBuilder` to load tenants
   - Added tenant dropdown field (editable)
   - Pass `tenantId` to `updateUser()`

3. **User List**:
   - Added tenant_id display in subtitle
   - Format: `Tenant: [UUID]`

### **Admin Ambulances Screen Updates**

1. **Create Dialog**:
   - Added `FutureBuilder` to load tenants
   - Added tenant dropdown field (appears first)
   - Added validation: `selectedTenantId == null`
   - Pass `tenantId` to `createAmbulance()` (replaces hardcoded UUID)

2. **Edit Dialog**:
   - Added `FutureBuilder` to load tenants
   - Added tenant dropdown field (editable)
   - Pass `tenantId` to `updateAmbulance()`

3. **Ambulance List**:
   - Added tenant_id display in subtitle
   - Format: `Tenant: [UUID]`

---

## User Flows

### **Creating a User Hierarchy**

1. Admin: "Create User"
2. Admin: Selects TENANT from dropdown
3. Admin: Enters email, name, selects role
4. System: Validates all fields including tenant
5. System: Calls `createUser(tenantId=selected)`
6. Result: User belongs to selected tenant
7. RLS Policy: User can only see tenant-scoped data

### **Moving a User to Different Tenant**

1. Admin: Clicks "Edit" on user
2. Dialog Opens: Shows current tenant in dropdown
3. Admin: **Changes tenant dropdown** to new tenant
4. Admin: Clicks "Update"
5. System: Calls `updateUser(tenantId=newTenant)`
6. Result: User now belongs to new tenant
7. RLS Policy: User access updates based on new tenant_id

### **Creating an Ambulance Hierarchy**

1. Admin: "Create Ambulance"
2. Admin: Selects TENANT from dropdown
3. Admin: Enters ambulance number, phone
4. System: Calls `createAmbulance(tenantId=selected)`
5. Result: Ambulance belongs to selected tenant
6. RLS Policy: Only managers/drivers of that tenant see it

---

## Data Integrity

### Cascading Effects

When changing a user's or ambulance's tenant:

**User Change**:

- User will see missions/fuel data only for NEW tenant
- Old tenant data becomes invisible
- User token still valid (no re-login needed)

**Ambulance Change**:

- Ambulance missions/fuel records belong to BOTH old and new tenant (data preserved)
- New assignments only go to new tenant
- Historical data visible to both tenants

### RLS Enforcement

All operations go through Supabase RLS:

- Admin policies: `get_user_role(auth.uid()) = 'admin'`
- Manager policies: `tenant_id = current_user.tenant_id`
- Driver policies: Checked against assigned ambulance tenant

---

## Testing Checklist

### ✅ Users Screen

- [ ] Create user: Tenant dropdown appears and is required
- [ ] Create user: Can select different tenants
- [ ] Create user: Fails if tenant not selected
- [ ] Edit user: Can change tenant
- [ ] Edit user: Tenant ID displayed in list
- [ ] Filter still works with hierarchical data

### ✅ Ambulances Screen

- [ ] Create ambulance: Tenant dropdown appears first
- [ ] Create ambulance: Can select different tenants
- [ ] Create ambulance: Fails if tenant not selected
- [ ] Edit ambulance: Can change tenant
- [ ] Edit ambulance: Tenant ID displayed in list
- [ ] Old hardcoded UUID replaced with dynamic tenant selection

### ✅ Tenants Screen

- [ ] No changes to existing interface
- [ ] Create/Edit/Delete still working

### ✅ Admin Dashboard

- [ ] Statistics still show all cross-tenant counts
- [ ] All three tabs load with hierarchical data
- [ ] No permission errors after tenant changes

---

## Deployment Notes

1. **No Database Changes Required** - All tenant_id columns already exist
2. **No RLS Policy Changes** - Admin policies already support cross-tenant access
3. **Backward Compatible** - Works with existing users/ambulances
4. **Immediate Testing** - Can test by creating new users/ambulances

### Deploy Steps:

1. Update Flutter app code (all files completed)
2. Hot restart: `flutter pub get && flutter run`
3. Test user creation with tenant selection
4. Test ambulance creation with tenant selection
5. Verify tenant_id displays in lists

---

## Future Enhancements

- [ ] Batch move users/ambulances between tenants
- [ ] Tenant-specific user quotas display
- [ ] Audit log showing which admin moved which resource
- [ ] Filter users/ambulances by tenant
- [ ] Default tenant for admin to speed up creation
- [ ] Tenant name display instead of UUID (join query)

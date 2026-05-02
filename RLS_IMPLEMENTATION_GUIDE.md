# Complete RLS Security Implementation Guide

## ✅ Current Status

**Already Deployed** (16 policies):

- `users` - SELECT via auth_user_id match, UPDATE permissive
- `ambulances` - SELECT with tenant_id subquery
- `missions` - SELECT with tenant_id subquery
- `user_fcm_tokens` - INSERT/SELECT/DELETE user isolation
- `tenants` - Admin/manager permissions with EXIST clauses
- `roles` - Public read
- `role_user` - Tenant-scoped read

**Missing** (~35 new policies needed):

- missions: INSERT, UPDATE, DELETE
- ambulances: UPDATE
- maintenance_records: SELECT, INSERT, UPDATE, DELETE (4 operations)
- fuel_cards: SELECT, INSERT, UPDATE, DELETE (4 operations)
- equipment_rentals: SELECT, INSERT, UPDATE, DELETE (4 operations)
- driver_locations: SELECT, INSERT, UPDATE, DELETE (4 operations)

---

## 🔐 Security Architecture

### Role-Based Access Matrix

| Operation               | Admin              | Manager                 | Driver                   |
| ----------------------- | ------------------ | ----------------------- | ------------------------ |
| **Missions**            |
| - SELECT                | All (cross-tenant) | Own tenant              | Own assigned             |
| - INSERT                | Yes                | Yes (own tenant)        | yes (own tenant)         |
| - UPDATE                | Yes                | Yes (own tenant)        | Assigned only            |
| - DELETE                | Yes                | Yes (own tenant)        | No                       |
| **Ambulances**          |
| - SELECT                | All                | Own tenant              | Assigned only            |
| - INSERT                | Yes                | No                      | No                       |
| - UPDATE                | Yes                | Yes (own tenant)        | No                       |
| - DELETE                | Yes                | No                      | No                       |
| **Maintenance Records** |
| - SELECT                | All                | Own tenant's ambulances | Own + tenant ambulances  |
| - INSERT                | Yes                | Yes                     | Yes (own records)        |
| - UPDATE                | Yes                | Yes                     | Own records              |
| - DELETE                | Yes                | Yes                     | No                       |
| **Fuel Cards**          |
| - SELECT                | All                | Own tenant              | Assigned ambulances only |
| - INSERT                | Yes                | Yes                     | yes                      |
| - UPDATE                | Yes                | Yes                     | No                       |
| - DELETE                | Yes                | Yes                     | No                       |
| **Equipment Rentals**   |
| - SELECT                | All                | Own tenant              | Own tenant               |
| - INSERT                | Yes                | Yes                     | No                       |
| - UPDATE                | Yes                | Yes                     | No                       |
| - DELETE                | Yes                | Yes                     | No                       |
| **Driver Locations**    |
| - SELECT                | All                | All (tenant)            | **Own only** ⚠️          |
| - INSERT                | Yes                | Yes                     | Yes (own)                |
| - UPDATE                | Yes                | Yes                     | Yes (own)                |
| - DELETE                | Yes                | Yes                     | No                       |

### Key Security Principles

1. **Tenant Isolation**: Multi-tenant data isolation via `tenant_id`
   - Users from Tenant A cannot see Tenant B data
   - Even if they manipulate URLs/API parameters

2. **Driver Isolation**: Strict driver location privacy
   - Drivers cannot see other drivers' locations
   - Only their own location data
   - Managers can see all drivers in their tenant

3. **Role-Based Permissions**: Clear hierarchy
   - **Admin**: Unrestricted (all tables, all operations)
   - **Manager**: Full tenant control (but not cross-tenant)
   - **Driver**: Limited to own data + assigned resources

4. **JWT-Based Context**: Only uses authenticated session
   - No custom JWT hooks needed
   - `auth.uid()` provides authenticated user context
   - Subqueries resolve to actual user role/tenant

---

## 📋 Implementation Checklist

### Phase 1: Core Data Operations (Missions & Ambulances)

- [ ] ADD INSERT policy for missions
- [ ] ADD UPDATE policy for missions
- [ ] ADD DELETE policy for missions
- [ ] ADD UPDATE policy for ambulances
- [ ] Test: Manager can create/update/delete missions
- [ ] Test: Manager cannot create/update ambulances for OTHER tenants

### Phase 2: Maintenance Records (Manager & Driver)

- [ ] ADD SELECT policy for maintenance_records
- [ ] ADD INSERT policy (manager all, driver own)
- [ ] ADD UPDATE policy (manager all, driver own)
- [ ] ADD DELETE policy (manager only)
- [ ] Test: Driver can add maintenance record
- [ ] Test: Manager can delete driver's record
- [ ] Test: Driver cannot delete

### Phase 3: Financial Records (Fuel Cards & Equipment)

- [ ] ADD SELECT, INSERT, UPDATE, DELETE for fuel_cards
- [ ] ADD SELECT, INSERT, UPDATE, DELETE for equipment_rentals
- [ ] Test: Driver cannot add fuel card (manager only)
- [ ] Test: Manager can manage all fuel cards

### Phase 4: Location Tracking (with Driver Isolation)

- [ ] ADD SELECT, INSERT, UPDATE, DELETE for driver_locations
- [ ] Test: Driver A cannot see Driver B location ⚠️ **CRITICAL**
- [ ] Test: Manager can see all driver locations
- [ ] Test: Driver can update own location

### Phase 5: Verification

- [ ] Verify all 50+ policies deployed
- [ ] Run security tests for each role
- [ ] Document any exceptions
- [ ] Deploy to production

---

## 🚀 Deployment Instructions

### Step 1: Connect to Supabase SQL Editor

1. Open [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Go to **SQL Editor**
4. New query

### Step 2: Run the SQL Script

```sql
-- Copy the entire content from COMPREHENSIVE_RLS_POLICIES.sql
-- Paste into SQL Editor
-- Click "Run"
```

### Step 3: Verify Deployment

```sql
-- Check all policies are created
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
ORDER BY tablename, cmd;

-- Expected results:
-- - ambulances: 2 policies (SELECT, UPDATE)
-- - driver_locations: 4 policies (SELECT, INSERT, UPDATE, DELETE)
-- - equipment_rentals: 4 policies (SELECT, INSERT, UPDATE, DELETE)
-- - fuel_cards: 4 policies (SELECT, INSERT, UPDATE, DELETE)
-- - maintenance_records: 4 policies (SELECT, INSERT, UPDATE, DELETE)
-- - missions: 4 policies (SELECT, INSERT, UPDATE, DELETE)
-- - roles, role_user, user_fcm_tokens, users, tenants: existing policies
-- TOTAL: ~50+ policies
```

### Step 4: Test Each Policy

**Test 1: Manager Mission CRUD**

```dart
// Login as manager_user
// Try:
final mission = await apiClient.post(missionsTable, {
  'mission_number': 'TEST123',
  'mission_date': DateTime.now().toIso8601String(),
  'from_location': 'Hospital A',
  'to_location': 'Hospital B',
  'status': 'pending',
  'priority': 'high',
  'tenant_id': manager_user.tenantId,
});
// Expected: ✅ Should create successfully
```

**Test 2: Driver Location Isolation**

```dart
// Login as driver_user_A
// Try:
final locations = await apiClient.get(driverLocationsTable);
// Expected: ✅ Should return ONLY driver_A's locations, not other drivers
```

**Test 3: Cross-Tenant Access Blocked**

```dart
// Login as tenant_A_user
// Try:
final OTHER_TENANT_ID = 'different-uuid';
final missions = await apiClient.get(missionsTable, filters: {
  'tenant_id': 'eq.$OTHER_TENANT_ID'
});
// Expected: ❌ Should return 0 results (RLS blocks)
```

---

## ⚠️ Common Issues & Fixes

### Issue 1: "Permission denied" on INSERT

✅ **Fix**: Ensure role is 'manager' or 'admin' in users table

```sql
SELECT id, role FROM users WHERE auth_user_id = auth.uid();
-- Should show role: 'manager'
```

### Issue 2: Driver can see other drivers' locations

✅ **Fix**: Verify driver_locations policy with strict user_id check

```sql
SELECT * FROM pg_policies WHERE tablename = 'driver_locations' AND cmd = 'SELECT';
-- Should show user_id comparison, NOT subqueries
```

### Issue 3: Slow queries on large datasets

✅ **Fix**: Add database indexes

```sql
CREATE INDEX IF NOT EXISTS idx_missions_tenant_id ON public.missions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ambulances_tenant_id ON public.ambulances(tenant_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_user_id ON public.driver_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_fuel_cards_ambulance_id ON public.fuel_cards(ambulance_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_ambulance_id ON public.maintenance_records(ambulance_id);
CREATE INDEX IF NOT EXISTS idx_equipment_rentals_ambulance_id ON public.equipment_rentals(ambulance_id);
```

---

## 📊 Policy Complexity Breakdown

### Simple Policies (Tenant Isolation Only)

- `fuel_cards INSERT/UPDATE/DELETE`
- `equipment_rentals INSERT/UPDATE/DELETE`
- Total: Easy to understand, fewer edge cases

### Medium Policies (Tenant + Role Check)

- `missions INSERT/UPDATE/DELETE`
- `ambulances UPDATE`
- `maintenance_records INSERT/UPDATE/DELETE`
- Total: Consider role in context

### Complex Policies (Tenant + Role + Driver Isolation)

- `driver_locations SELECT/INSERT/UPDATE/DELETE`
- Total: Multi-level checks, most secure but slowest

---

## 🔒 Production Checklist

- [ ] All 50+ policies deployed
- [ ] Performance tests: Query response times < 200ms
- [ ] Security tests: Cross-tenant access blocked
- [ ] Driver isolation verified: Cannot see other drivers
- [ ] Admin escalation works: Admin can access all data
- [ ] Audit logging enabled: Track data access
- [ ] Backups configured: Daily automated backups
- [ ] Documentation updated: For support team
- [ ] User communication: Notify affected users

---

## 📚 Related Files

- `lib/services/api_client.dart` - Sends JWT in headers ✅
- `lib/services/auth_service.dart` - Manages authentication ✅
- `lib/utils/jwt_decoder.dart` - Debugging tool ✅
- `IMPLEMENTATION_SUMMARY.md` - Overall progress tracking

---

## 🎯 Success Metrics

After deployment, these should all be true:

✅ **Manager dashboard** shows only their tenant's missions/ambulances  
✅ **Driver location** shows only that driver's coordinates  
✅ **Manager can create/update** missions but not other tenants' data  
✅ **Cross-tenant query** returns 0 results (RLS prevents access)  
✅ **Query performance** remains < 200ms even with large datasets  
✅ **Audit logs** show which users accessed what data

---

## 🆘 Troubleshooting

If policies don't work:

1. **Check authentication context**

   ```dart
   // In Flutter
   final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
   print('JWT present: ${jwt != null}');
   ```

2. **Verify user record exists**

   ```sql
   SELECT * FROM public.users WHERE auth_user_id = 'your-auth-uid';
   -- Must return exactly 1 row with role and tenant_id
   ```

3. **Test policy directly**

   ```sql
   -- Manual test as authenticated user
   -- Supabase automatically applies RLS in queries
   SELECT COUNT(*) FROM missions;
   -- Should only count missions in your tenant
   ```

4. **Review PostgreSQL logs**
   - Supabase Dashboard → Logs → Database
   - Look for RLS denials

---

**Document Version**: 1.0  
**Last Updated**: April 12, 2026  
**Created by**: Copilot Security Audit  
**Status**: Ready for Deployment

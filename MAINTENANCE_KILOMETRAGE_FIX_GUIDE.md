# Maintenance Kilometrage Fix - Complete Guide

## Problem Summary

The kilometrage field entered in the maintenance form is NOT being saved to the database. All existing maintenance records show `"kilometrage": null`.

## Status Update ✅

✅ **Column EXISTS**: The `kilometrage` column is properly created as `NUMERIC` and nullable  
❌ **RLS Policy Issue**: The INSERT policy is likely blocking writes to this column

## Solution - 3 Step Process

### Step 1: Fix the RLS INSERT Policy (THIS IS THE FIX!)

The issue is that the Row Level Security policy on `maintenance_records` may have a WITH CHECK clause that's too restrictive.

1. Go to your Supabase dashboard → SQL Editor
2. Create a new query and copy-paste the contents of `MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql`
3. Run the query
4. You should see "INSERT policy fixed successfully"

**What this does:**

- Replaces the INSERT policy to properly allow all columns (including kilometrage) to be written
- Maintains security for drivers (can only write their own records) and managers (can write for their tenant)
- No column-level restrictions on kilometrage

### Step 2: Test with New Maintenance Record

1. In the app, go to an ambulance
2. Click "Add Maintenance" (+Ajouter)
3. Fill ALL required fields INCLUDING the "Kilométrage Actuel (km)" field (e.g., 261530)
4. Submit the form
5. The kilometrage should NOW be saved ✅

### Step 3: Verify Data is Saved

In Supabase SQL Editor:

```sql
SELECT
  id,
  date,
  maintenance_type,
  driver_name,
  kilometrage,
  notes
FROM maintenance_records
ORDER BY date DESC
LIMIT 10;
```

**Expected result:** New records should show numeric values in the `kilometrage` column (not NULL).

## Code Components - Already Ready ✅

### Frontend Components

- **add_maintenance_screen.dart**: Has input field for "Kilométrage Actuel (km)" ✅
- **maintenance_service.dart**: Sends kilometrage in POST request ✅
- **MaintenanceRecord model**: Parses kilometrage from JSON ✅
- **manager_ambulances_screen.dart**: Displays kilometrage in details dialog ✅

### Database

- **Column**: Already exists as `NUMERIC` in `maintenance_records` table ✅
- **RLS Policy**: Will be fixed by `MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql` ✅

## Troubleshooting

### Issue: "Still shows NULL after adding maintenance record"

**Cause**: RLS policy fix hasn't been run yet
**Solution**:

1. Run `MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql` in Supabase SQL Editor
2. Wait 5 seconds
3. Test again with a new maintenance record

### Issue: "Manager still doesn't see kilometrage"

**Cause**: Browser cache or record was added before fix
**Solution**:

1. Hard refresh the app (Force close and restart)
2. Try clicking a NEWLY added maintenance record (after the fix was applied)

### Issue: Permission denied / Access denied error

**Cause**: RLS policy may have syntax issues
**Solution**:

1. Check that you're logged in as the correct user (driver or manager)
2. Run the diagnostic: `MAINTENANCE_KILOMETRAGE_DIAGNOSTIC.sql`
3. Contact Supabase support if policy still blocks writes

### Issue: "Column doesn't exist" error when submitting form

**Cause**: Column may not have been added properly
**Solution**:

1. Run `MAINTENANCE_KILOMETRAGE_FIX.sql` to ensure column exists
2. Verify: Run the SELECT query from Supabase to check column

## Expected Behavior After Fix

1. **Driver adds maintenance**:
   - Enters kilometrage value (e.g., 261530 km)
   - Clicks Save → data sent to API

2. **Data saved to DB**:
   - `maintenance_records.kilometrage` = 261530.00

3. **Manager views details**:
   - Opens maintenance record details dialog
   - Sees "Kilométrage: 261530.00 km" ✅

## Files Provided

| File                                            | Purpose                                |
| ----------------------------------------------- | -------------------------------------- |
| `MAINTENANCE_KILOMETRAGE_FIX.sql`               | Adds column (if missing) - run once    |
| `MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql` | **Fixes RLS policy - RUN THIS NOW** ⭐ |
| `MAINTENANCE_KILOMETRAGE_DIAGNOSTIC.sql`        | Diagnoses issues (optional)            |
| `MAINTENANCE_KILOMETRAGE_FIX_GUIDE.md`          | This guide                             |

## Summary

✅ **Column exists and is accessible**  
❌ **RLS policy needs fixing**  
✅ **All frontend code ready**

**Next action**: Run `MAINTENANCE_KILOMETRAGE_FIX_INSERT_POLICY.sql` in Supabase SQL Editor

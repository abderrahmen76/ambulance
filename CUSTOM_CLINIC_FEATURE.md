# Custom Clinic Feature - Setup Guide

## Overview

This guide explains how to set up and use the custom clinic feature in the ambulance app.

## Components Created

### 1. **CustomClinicService** (`lib/services/custom_clinic_service.dart`)

- Manages custom clinic storage in Supabase
- Methods:
  - `getAllClinics()` - Returns all built-in + custom clinics
  - `getClinicsWithOther()` - Returns all clinics + "autre" option
  - `addCustomClinic(String name)` - Adds a new custom clinic
  - `_loadCustomClinics()` - Private method to fetch from database

### 2. **CustomClinicDialog** (`lib/widgets/custom_clinic_dialog.dart`)

- Dialog widget for adding custom clinics
- Features:
  - Forms validation (empty name prevention)
  - Duplicate checking
  - Error messaging
  - Loading states

### 3. **ClinicDropdownField** (`lib/widgets/clinic_dropdown_field.dart`)

- Reusable dropdown widget with custom clinic support
- Features:
  - Loads clinics from CustomClinicService
  - Displays all built-in + custom clinics
  - Shows "autre" option at bottom
  - Opens CustomClinicDialog when "autre" is selected
  - Automatically updates after custom clinic is added

### 4. **Updated Screens**

Updated clinic dropdowns in:

- `lib/screens/dashboard_screen.dart` (driver view)
- `lib/screens/manager_dashboard_screen.dart` (manager view - mission creation)
- `lib/screens/manager_missions_screen.dart` (manager view - 2 dialogs)

## Database Setup

### Run this SQL in Supabase:

```sql
CREATE TABLE IF NOT EXISTS custom_clinics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_clinics_name ON custom_clinics(clinic_name);

ALTER TABLE custom_clinics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON custom_clinics
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON custom_clinics
  FOR INSERT WITH CHECK (true);
```

## How It Works

### User Flow:

1. User opens mission creation form
2. For "Lieu de Départ" or "Lieu de Destination", selects "Clinique" option
3. Clicks clinic dropdown
4. Scrolls to bottom and sees "Autre (Ajouter une nouvelle)"
5. Selects "Autre"
6. Dialog appears with text field
7. User types clinic name (e.g., "Clinique Privée Sfax")
8. Clicks "Ajouter"
9. Clinic is saved to Supabase `custom_clinics` table
10. Dialog closes, new clinic appears in dropdown
11. New clinic is automatically selected
12. User can now proceed with mission creation

### Persistence:

- Custom clinics are stored in Supabase `custom_clinics` table
- Service loads them on first use (`_loadCustomClinics()`)
- Clinics remain in dropdown across app sessions
- Works in all views: dashboard (driver), manager dashboard, manager missions

## Architecture

```
CustomClinicService
├── getAllClinics()
│   └── Combines LocationData.clinicsSfax + _customClinics
├── getClinicsWithOther()
│   └── Adds "autre" option for dropdown
├── addCustomClinic()
│   └── Validates, saves to Supabase, updates local list
└── _loadCustomClinics()
    └── Fetches from custom_clinics table on first use

ClinicDropdownField
├── Loads clinics via CustomClinicService
├── Displays in DropdownButtonFormField
├── Detects "autre" selection
└── Opens CustomClinicDialog

CustomClinicDialog
├── TextFormField for clinic name input
├── Validation (empty check, duplicate check)
├── Calls CustomClinicService.addCustomClinic()
└── Triggers onClinicAdded callback to refresh parent
```

## Testing Checklist

### Dashboard (Driver View)

- [ ] Open "Créer une Mission"
- [ ] Select "Lieu de Départ" > "CHU"
- [ ] Select a city
- [ ] Click clinic dropdown
- [ ] Verify "Autre" option appears
- [ ] Select "Autre"
- [ ] Type "Test Clinic"
- [ ] Click "Ajouter"
- [ ] Verify "Test Clinic" appears in dropdown
- [ ] Select "Test Clinic"
- [ ] Create mission
- [ ] Repeat for "Lieu de Destination"

### Manager Dashboard (Manager View)

- [ ] Same test as above in manager dashboard mission creation dialog
- [ ] Verify custom clinic persists if created in driver view

### Manager Missions Screen

- [ ] Open "Créer une Mission Complète"
- [ ] Repeat custom clinic test
- [ ] Open edit mission dialog
- [ ] Repeat custom clinic test

### Persistence

- [ ] Create a custom clinic
- [ ] Close app completely
- [ ] Reopen app
- [ ] Go to mission creation form
- [ ] Click clinic dropdown
- [ ] Verify custom clinic still appears

### Duplicate Prevention

- [ ] Try to add same clinic twice
- [ ] Verify error message appears
- [ ] Try case variation (e.g., "test clinic" and "Test Clinic")
- [ ] Verify both treated as duplicates

## Troubleshooting

### Custom clinics not appearing

1. Check RLS policies on `custom_clinics` table are enabled
2. Verify table exists in Supabase
3. Check ApiClient has correct Supabase credentials
4. Look for error logs in CustomClinicService (debugPrint statements)

### Dialog not opening

- Check ClinicDropdownField imports CustomClinicDialog
- Verify CustomClinicDialog is properly built

### Clinics not persisting

1. Check internet connection
2. Verify Supabase database is accessible
3. Check RLS policies allow inserts
4. Look for error messages in console

## Files Modified

- ✅ `lib/config/constants.dart` - No changes needed (clinicsSfax used as base)
- ✅ `lib/screens/dashboard_screen.dart` - Updated clinic dropdown
- ✅ `lib/screens/manager_dashboard_screen.dart` - Updated clinic dropdown
- ✅ `lib/screens/manager_missions_screen.dart` - Updated 2 clinic dropdowns

## Files Created

- ✅ `lib/services/custom_clinic_service.dart` - Service for managing custom clinics
- ✅ `lib/widgets/custom_clinic_dialog.dart` - Dialog widget for input
- ✅ `lib/widgets/clinic_dropdown_field.dart` - Reusable dropdown widget
- ✅ `CUSTOM_CLINICS_SETUP.sql` - Database setup script

## Next Steps

1. Run the SQL script in Supabase
2. Build and run the app
3. Follow manual testing checklist
4. Verify custom clinics appear in both manager and ambulance views

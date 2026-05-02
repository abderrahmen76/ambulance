# Mission Data Edit Feature - Implementation Guide

## Overview

Ambulance drivers can now update mission data after accepting a mission. The comprehensive edit dialog allows modification of all mission fields except technical sheet data.

## Feature Location

**Screen**: Active Missions Screen  
**Button**: "Modifier les Données" (Edit Data) - Purple button, full width  
**Accessible**: Only visible and active for active missions (status = 'active')

## Editable Fields

Ambulance drivers can edit the following fields:

### Location Fields

- **Lieu de Départ** (From Location) - Departure location
- **Lieu de Destination** (To Location) - Destination location

### Patient Information

- **Nom du Patient** (Patient Name) - Full name of the patient
- **Téléphone du Patient** (Patient Phone) - Patient contact number

### Staff Information

- **Infirmier/Médecin** (Nurse/Doctor Name) - Name of attending medical staff

### Additional Information

- **Notes** - Extra notes/observations (max 3 lines)
- **Type de Paiement** (Payment Type) - Cash or Sur Charge
- **Type de Rapport** (Report Type) - Simple transport, With intervention, or Not filled

## Protected Fields (Cannot Edit)

The following fields are protected and cannot be edited via this dialog:

- Mission number (MISS-XXXXX)
- Mission date
- Driver information
- Ambulance information
- Technical sheet data:
  - Medical history
  - Vital signs
  - Patient needs
  - Fractures/injuries
  - Any other technical observations

## How to Use

### For Ambulance Drivers:

1. View the list of active missions
2. Find the desired mission in the list
3. Click the purple **"Modifier les Données"** button
4. A dialog opens with all editable fields pre-filled with current values
5. Update any fields as needed
6. Click **"Enregistrer"** (Save) to submit changes
7. Dialog closes and mission list refreshes
8. Success message confirms the update

### For Technical Sheet Data:

If you need to update medical history, vital signs, or patient needs:

1. Click the **"Détails"** (Details) button
2. This opens the Mission Technical Sheet Screen
3. Edit the technical data there

## Dialog Layout

```
┌─────────────────────────────────────────────┐
│ Modifier les Données de la Mission          │
├─────────────────────────────────────────────┤
│ Lieu de Départ                              │
│ [Text field with sanitized input]           │
│                                              │
│ Lieu de Destination                         │
│ [Text field with sanitized input]           │
│                                              │
│ Nom du Patient                              │
│ [Text field with sanitized input]           │
│                                              │
│ Téléphone du Patient                        │
│ [Text field - phone keyboard]               │
│                                              │
│ Infirmier/Médecin                           │
│ [Text field with sanitized input]           │
│                                              │
│ Notes                                        │
│ [Text area - 3 lines max]                   │
│                                              │
│ Type de Paiement                            │
│ [Dropdown: Liquide / Sur Charge]            │
│                                              │
│ Type de Rapport                             │
│ [Dropdown: Transport Simple / Avec Interv...]│
│                                              │
│ ℹ️ Note about technical sheet               │
├─────────────────────────────────────────────┤
│ [Annuler]              [Enregistrer] (w/o)  │
└─────────────────────────────────────────────┘
```

## Code Structure

### New Methods in `active_missions_screen.dart`

**`_showEditMissionDataDialog(BuildContext context, Mission mission)`**

- Opens comprehensive mission edit dialog
- Pre-populates fields with current mission data
- Handles state management for dropdowns
- Shows loading state during save

**`_saveMissionEdits(...)`**

- Updates all 8 editable fields in database
- Calls `missionService.updateMissionField()` for each field
- Reloads mission list after successful save
- Shows success/error notifications

### Button Integration

Added purple "Modifier les Données" button:

- Full-width button at top of active mission action buttons
- Only visible when `isActive == true`
- Uses `Icons.edit` icon
- Calls `_showEditMissionDataDialog(context, mission)`

## Database Operations

Each field update uses:

```dart
await _missionService.updateMissionField(mission.id, fieldKey, newValue);
```

Database fields updated:

- `from_location` (String)
- `to_location` (String)
- `patient_name` (String)
- `patient_phone` (String)
- `infirmier_name` (String)
- `notes` (String)
- `payment_type` (String: 'cash' or 'sur charge')
- `report_type` (String: 'simple_transport', 'with_intervention', 'not_filled')

## User Experience

### Loading State

While saving:

- All input fields are disabled
- Buttons show loading spinner
- User cannot interact with dialog

### Validation

- All fields accept text input
- Phone field uses phone keyboard
- Dropdowns have predefined options
- No null/empty validation (allows updates to empty values)

### Notifications

- **Success**: "Mission mise à jour avec succès!" (Green snackbar)
- **Error**: Shows error message (Red snackbar)
- **Loading**: "..." during PDF generation

### Mission Refresh

After successful update:

1. Dialog closes automatically
2. Mission list reloads from database
3. Updated data reflects immediately

## Testing Checklist

- [ ] Edit button appears for active missions only
- [ ] Edit button is hidden for completed/cancelled missions
- [ ] Dialog opens with correct pre-filled values
- [ ] Can edit departure location
- [ ] Can edit destination location
- [ ] Can edit patient name
- [ ] Can edit patient phone
- [ ] Can edit nurse/doctor name
- [ ] Can edit notes
- [ ] Payment type dropdown works (cash/sur charge)
- [ ] Report type dropdown works (3 options)
- [ ] Save reloads mission list
- [ ] Changes persist after app restart
- [ ] Error handling works for invalid inputs
- [ ] Loading state shows during save
- [ ] Technical sheet data NOT editable from this dialog
- [ ] Close button cancels all changes without saving
- [ ] Multiple consecutive edits work correctly

## Permissions & Access Control

Currently: All ambulance drivers can edit their own missions
Future considerations:

- Manager-only edits for certain fields
- Field-level permissions
- Edit history/audit trail
- Approval workflow for critical fields

## Integration with Other Screens

- **Technical Sheet Screen**: Separate editing for medical data
- **Mission Details Screen**: View-only for now, can be extended
- **Mission Status**: Separate workflow (Complete/Cancel buttons)
- **Payment**: Can be edited together with other fields

## Files Modified

- ✅ `lib/screens/active_missions_screen.dart`:
  - Added "Modifier les Données" button in active mission action buttons
  - Added `_showEditMissionDataDialog()` method
  - Added `_saveMissionEdits()` method

## Compilation Status

✅ No errors - All code compiling successfully

## Next Steps

1. **Build & Deploy**: Run `flutter run -d 2201116SG`
2. **Test Feature**: Accept a mission and try editing it
3. **Verify Data**: Check that changes persist in database
4. **User Feedback**: Gather feedback from drivers
5. **Future Enhancements**:
   - Add image upload for mission photos
   - Add location picker for departure/destination
   - Add expense tracking
   - Add signature capture

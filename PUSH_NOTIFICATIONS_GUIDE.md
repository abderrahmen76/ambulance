# Push Notifications Implementation Guide

## Overview

This guide walks you through implementing real-time push notifications for your ambulance app using **Firebase Cloud Messaging (FCM)** - completely free and works when app is closed.

## What's Been Created

### 1. **notification_service.dart** (Main Service)

- Initializes Firebase Messaging
- Handles foreground, background, and terminated state notifications
- Manages local notifications display
- Stores FCM tokens in Supabase
- Handles notification taps

### 2. **mission_notification_manager.dart** (Helper Functions)

- Provides convenient methods to send notifications
- Types: mission assigned, status update, critical alert, payment, maintenance, availability

### 3. **FIREBASE_SETUP.md** (Firebase Configuration)

- Step-by-step Firebase project setup
- Android and iOS configuration
- APNs certificate setup for iOS

### 4. **NOTIFICATION_SETUP.sql** (Database)

- SQL to create tables in Supabase
- FCM tokens table
- Notification log table
- RLS policies for security

---

## Step-by-Step Implementation

### Step 1: Install Dependencies

```bash
flutter pub get
```

This installs:

- `firebase_messaging: ^14.6.0` (FCM)
- `flutter_local_notifications: ^16.0.0` (Local notification display)

### Step 2: Firebase Setup (5 minutes)

Follow **FIREBASE_SETUP.md** completely:

1. Create Firebase project
2. Add Android app + download google-services.json
3. Add iOS app + download GoogleService-Info.plist
4. Configure build files
5. Get Server Key for backend

### Step 3: Database Setup

Run **NOTIFICATION_SETUP.sql** in Supabase:

1. Open Supabase > SQL Editor
2. Copy entire content of NOTIFICATION_SETUP.sql
3. Run the query
4. Verify tables created: `user_fcm_tokens`, `notification_log`

### Step 4: Update Auth Service

Add FCM token storage when user logs in:

```dart
// In auth_service.dart, after successful login:
import 'notification_service.dart';

// After user login is successful:
final fcmToken = await NotificationService.instance.getFcmToken();
if (fcmToken != null) {
  await NotificationService.instance.storeFcmToken(user.id, fcmToken);
}
```

### Step 5: Integrate Notifications into Mission Service

**When assigning a mission to a driver:**

```dart
import 'mission_notification_manager.dart';

await MissionNotificationManager.notifyMissionAssigned(
  driverId: mission.driverId,
  missionNumber: mission.missionNumber,
  fromLocation: mission.fromLocation,
  toLocation: mission.toLocation,
);
```

**When mission status changes:**

```dart
await MissionNotificationManager.notifyMissionStatusUpdate(
  userId: managerId,
  missionNumber: mission.missionNumber,
  newStatus: mission.status,
  missionId: mission.id,
);
```

**For critical missions:**

```dart
if (mission.priority.toLowerCase() == 'critical') {
  await MissionNotificationManager.notifyCriticalMission(
    driverId: mission.driverId,
    missionNumber: mission.missionNumber,
    fromLocation: mission.fromLocation,
    toLocation: mission.toLocation,
    patientPhone: mission.patientPhone ?? 'Unknown',
  );
}
```

### Step 6: Handle Notification Taps

In main.dart or any screen that needs to respond to notification taps:

```dart
@override
void initState() {
  super.initState();

  // Set callback for notification taps
  NotificationService.instance.onNotificationTapped = (data) {
    final type = data['type'];
    final missionId = data['mission_id'];

    if (type == 'mission_assigned') {
      // Navigate to mission details
      Navigator.pushNamed(context, '/mission-details', arguments: missionId);
    }
  };
}
```

---

## Notification Types

### 1. **Mission Assigned** 🚑

- **Who receives:** Driver
- **When:** Manager assigns new mission
- **Data:** Mission number, from/to location
- **Action:** Navigate to mission details

### 2. **Mission Status Update** ✅

- **Who receives:** Manager / Driver
- **When:** Mission status changes (active→completed, etc)
- **Data:** Mission number, new status
- **Action:** Show status in dashboard

### 3. **Critical Alert** 🚨

- **Who receives:** Driver
- **When:** Critical priority mission assigned
- **Data:** Mission details + patient phone
- **Action:** Urgent navigation

### 4. **Payment Received** 💰

- **Who receives:** Driver
- **When:** Payment marked as paid
- **Data:** Amount, payment type
- **Action:** Show payment confirmation

### 5. **Maintenance Reminder** 🔧

- **Who receives:** Manager
- **When:** Maintenance is due
- **Data:** Ambulance ID, maintenance type, due date
- **Action:** Navigate to maintenance screen

### 6. **Ambulance Availability** ✅⏸️

- **Who receives:** Manager
- **When:** Ambulance availability changes
- **Data:** Ambulance ID, availability status
- **Action:** Update dashboard

---

## Testing Notifications

### Test 1: Firebase Console

1. Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Select your app
4. Check device receives notification

### Test 2: Curl Command

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -d '{
    "to": "FCM_TOKEN_FROM_DEVICE",
    "notification": {
      "title": "Test Mission",
      "body": "Test notification body"
    },
    "data": {
      "type": "mission_assigned",
      "mission_id": "123"
    }
  }'
```

### Test 3: In-App Testing

```dart
// Add this temporary code to test
ElevatedButton(
  onPressed: () async {
    await MissionNotificationManager.notifyMissionAssigned(
      driverId: 'test-driver-id',
      missionNumber: 'TEST-001',
      fromLocation: 'Test Location A',
      toLocation: 'Test Location B',
    );
  },
  child: const Text('Send Test Notification'),
)
```

---

## Debugging

### Check Logs

```
[NotificationService] Initializing...
[NotificationService] FCM Token: aw...xyz
[NotificationService] Local notifications initialized
[NotificationService] Initialization complete!
```

### Common Issues

**1. FCM Token is null**

- Check Google Services JSON is in correct folder
- Rebuild app after adding JSON file
- Test on real device, not emulator

**2. Notifications not appearing**

- Check "Allow notifications" permissions granted
- Verify FCM token stored in Supabase
- Check notification channels in Android

**3. App closed, no notifications**

- Verify background handler is set (@pragma decorator)
- Check device has internet connection
- Firebase Cloud Functions may have cold start delay

**4. iOS not receiving notifications**

- Upload APNs certificate to Firebase
- Check bundle ID matches
- Test on physical device

---

## Security Notes

1. **FCM Tokens:** Stored in Supabase with user association
2. **RLS Policies:** Users can only access their own tokens
3. **Server Key:** Keep server key secure, never commit to repo
4. **User Targeting:** Always verify user has permission to receive notification

---

## Next Steps

1. ✅ Dependencies added (pubspec.yaml)
2. ✅ Services created (notification_service.dart)
3. ⏳ Set up Firebase project (follow FIREBASE_SETUP.md)
4. ⏳ Run SQL setup (NOTIFICATION_SETUP.sql)
5. ⏳ Update Auth Service with FCM token storage
6. ⏳ Add notification triggers to Mission Service
7. ⏳ Test on real device

---

## File Structure

```
lib/
├── services/
│   ├── notification_service.dart (Main service)
│   ├── mission_notification_manager.dart (Helper functions)
│   └── auth_service.dart (Update to store FCM token)
├── main.dart (Updated to initialize notifications)
└── ...

Root files:
├── FIREBASE_SETUP.md (Firebase instructions)
├── NOTIFICATION_SETUP.sql (Database setup)
└── pubspec.yaml (Dependencies added)
```

---

## Cost

- **Firebase Cloud Messaging (FCM):** FREE
- **Send unlimited notifications** ✅
- **No per-message costs** ✅

---

Contact me if you need help with any step! 🚀

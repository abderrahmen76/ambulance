-- FIREBASE SETUP INSTRUCTIONS

## Your Firebase Project Details

**Project ID:** `ambulance-app-572b2`
**Sender ID:** `477713174917`
**Web API Key:** Available in Firebase Console → Project Settings

---

## Setup Firebase for Push Notifications

### Step 1: Firebase Project Already Created ✅

Your Firebase project is already set up:

- Project: `ambulance-app-572b2`
- Go to: https://console.firebase.google.com/project/ambulance-app-572b2

### Step 2: Add Android App to Firebase

1. In Firebase Console → Project Settings → Apps
2. Click "Add app" → Android
3. Fill in package name: `com.example.mobile_app` (match your app's package name in android/app/build.gradle.kts)
4. Download google-services.json
5. Copy to: `android/app/google-services.json`

### Step 3: Configure Android (build.gradle.kts files)

Since your project uses Kotlin DSL (.kts files), the configuration is already done:

**android/build.gradle.kts** (project level):
✅ Added Firebase plugin:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}
```

**android/app/build.gradle.kts** (app level):
✅ Added Firebase plugin:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")  // Firebase Cloud Messaging
    id("dev.flutter.flutter-gradle-plugin")
}
```

**No additional changes needed** - both files are already configured!

### Step 4: Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Fill in bundle ID: `com.example.ambulance` (match your app)
3. Download GoogleService-Info.plist
4. Open project in Xcode: `ios/Runner.xcworkspace`
5. Drag GoogleService-Info.plist to Runner folder
6. Select "Runner" target, ensure file is added to Runner target

### Step 5: Configure iOS capabilities

1. In Xcode: Runner → Signing & Capabilities
2. Click "+ Capability"
3. Add "Push Notifications"
4. Add "Background Modes"
5. Check "Remote notifications" and "Background fetch"

### Step 6: Enable Cloud Messaging API (Backend) ✅

Firebase Cloud Messaging is enabled for your project.

**Your Sender ID:** `477713174917`
**Your Server Key:** Available in Firebase Console → Project Settings → Cloud Messaging

### Step 7: Get FCM Credentials for Backend ✅

Your service account credentials are ready:

**Service Account Email:**

```
firebase-adminsdk-fbsvc@ambulance-app-572b2.iam.gserviceaccount.com
```

**Service Account JSON:** (Already provided - save securely!)

```json
{
  "type": "service_account",
  "project_id": "ambulance-app-572b2",
  "private_key_id": "e7930145c538965450aa0da665806545bb3aa0b7",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@ambulance-app-572b2.iam.gserviceaccount.com",
  ...
}
```

**Where to use these credentials:**

- Backend server that sends notifications
- Firebase Cloud Functions
- Supabase Edge Functions

### Step 8: Key Pair for Web/JS SDKs (Optional) ✅

If using web/JS SDKs:

- **Public Key:** `BO7vmlMq8XQzGHxAyrb-FfW-kLJLAZL5V_ypKPZRTthKIWsCEqHjkz9BBYhDHxwbR1VCJb9LWhXPAgZbM2-8Y_I`
- **Private Key:** `7TkfptHTQ5jH07Hv6xZ_BGPAiVAvkjAzHJULl1s558A`

### Step 8: Verify in Flutter

Run the app and check logs:

```
[NotificationService] FCM Token: ...
[NotificationService] Initialization complete!
```

---

## IMPORTANT: iOS Specific Setup

### Configure Notification Categories (optional)

Add to ios/Runner/GeneratedPluginRegistrant.swift if needed

### APNs Certificate Setup

For production, you need an APNs certificate:

1. Go to Apple Developer > Certificates, IDs & Profiles
2. Create an Apple Push Notification service (APNs) certificate
3. Upload to Firebase Console → Cloud Messaging → iOS

---

## Testing Push Notifications

### Method 1: Firebase Console

1. Firebase Console → Cloud Messaging tab
2. Click "Send your first message"
3. Enter title and body
4. Target your app
5. Send to a test user/device

### Method 2: Backend API Call

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "Test Mission",
      "body": "You have a new mission assigned",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "data": {
      "type": "mission_assigned",
      "mission_id": "123"
    }
  }'
```

---

## Next Steps

1. Run `flutter pub get` to download new packages
2. Run `flutter clean` then rebuild
3. Test on real device (emulator may have issues with FCM)
4. Implement notification triggers in mission_service.dart
5. Test sending notifications from manager app to driver app

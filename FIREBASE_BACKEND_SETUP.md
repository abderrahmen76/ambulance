## Firebase Backend Setup

This guide explains how to send push notifications from your backend using Firebase service account credentials.

---

## Firebase Project Details

**Project ID:** `ambulance-app-572b2`
**Sender ID:** `477713174917`
**Service Account Email:** `firebase-adminsdk-fbsvc@ambulance-app-572b2.iam.gserviceaccount.com`

---

## Option 1: Supabase Edge Functions (Recommended)

### Create Edge Function to Send Notifications

**File:** `supabase/functions/send-notification/index.ts`

```typescript
import * as admin from "firebase-admin";

const serviceAccount = {
  type: "service_account",
  project_id: "ambulance-app-572b2",
  private_key_id: "e7930145c538965450aa0da665806545bb3aa0b7",
  private_key:
    "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC17VMCYoghMg/Q\nH2eMFWkrm6SbLg7lhUmpDL2YicDUv0+mkvFMCZfFiQS50HUrpt1/CVo0xMmILnlF\n4PlS8IUDuLrR78PhtIOB+ThUAWcNb0NOI4MwEuLYztGmdTf2dgcNAVANXiMCrbm3\n6YOQ6eaQLmJIIsLlgoVS5wVzbcc1eKcLLDFQqm1MvMNPvfadtPDVAqemFBsQGNmw\nmStOSnf0CMEhVdtTVwQFEgDJh/REeCfMv0ifGDuDPpCOqmslUhecvQglzkQ/2Nbz\ni9DOMJ+3Uc0J6uKVj2Oe+ZQaXX3J0TAPJW8HdbopElG/DixCOKsfgWhMjnNk2Ex5\nLOda8qSxAgMBAAECggEAQpQHvOeySfO4NcJIcsujIYJkSyYf7X9J5cPz3s8K8tDQ\npXVBOUKJeJEcWaQgPUlj5gnWKVmbJ2talmgu1luPUj1YoVvNo9wcBITgSF37CL+f\nMgltCTrgKdgGgZSEVn37Npc0ZK/+wAwz20pqC66N4lYXQa73BGcvw5coN4YFUVuo\nRElTChmlBD0IjhORt/V2RWIBWzU5CFmfiMf8MCGZwdvwI5RfmxkVz663yuNyaV2y\nEDnB7veTXB/yyLdaO+ekbjnZY1xAXlBAaS00DX/Z9XmJhrzZIN8mAWvtSJnhcJVN\nmvH9SYa24Mjgk6LnxJY1/zt+s+US2Iq3QIfp711owQKBgQDdUIDFwbgQn5dKrUPe\n2pQlhgHNhPMJHNbek+YqLdMVeFH0bb94mtxJnr2OrZQ23cKVRqGIBQ/uXfyjRFOv\nC701fewNAqYcOrJ7IO5T82J2SCbhC3nhs6vDv1K0t5L9sVYebCe4CgzUnKzhsZSs\nvLIyj2UyYMty2LpS+ZYu0/DUbwKBgQDScIisax5DFPWEIREQox2ReBK2S5VTjkxQ\negkyDd/3tWCIvGt8V+VJFCLW8BzBiLGFvM+DBw9HTKwp/uqZZY8Suu2XQrDpZtRl\nzFJftTEii9JMI/HxtQ5qwTt3KVURJbrKE7XmLFTpOb23eeIQmuT4a2BfxMiQ4d/7\nxO8+gyvo3wKBgDj4Dg3Zze3JhwJcE4p8LYJzOmeS/5Sq7cyhua/F1/5A2KfY0F7V\nTjtNN3JQ0ERHVV1jrxT6aJ1taCkG35vBo9TvMyIuOmAt49+6HF9T2ValQAzSDW/B\n9kcPKtUGJDpVudte7+J6A89+/Smjsqe8cwp8ywnqzLQlgeD2CmjHecjVAoGAeSUP\niTKhWTzXmhjvGgTNINFe9FLOxCtHA409ffM+2/sud4kA17RB6rAM3m+cHk3y5Gqt\ni2ClCwa4lfSKWYR9uOqjnFBoR/VKkM/vG+nTP2/+wJZw0hTJF+vlr9O7hQOTZIG0\nVa1vtFPpQ5aG7cg9yEUIVhmS3NUrfGUC1ZntzUECgYEA2lV5n7Ak3Ejm9LzAOt1z\ntCsQNNbHj3ia1Ct/7kqNidFHCRpc4WofEAo5I5jbRZcVB4SJ9ph8kp/9jAqGLq84\nRGEdKJgKJysHtcIxIl/+DS71jhoCOj3ela7ANRcIAby26so1HPTArOUfoEVOnSiE\nasvVfjok+nrjD0/F7ezjmVw=\n-----END PRIVATE KEY-----\n",
  client_email:
    "firebase-adminsdk-fbsvc@ambulance-app-572b2.iam.gserviceaccount.com",
  client_id: "104457127681345794838",
  auth_uri: "https://accounts.google.com/o/oauth2/auth",
  token_uri: "https://oauth2.googleapis.com/token",
  auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
  client_x509_cert_url:
    "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40ambulance-app-572b2.iam.gserviceaccount.com",
  universe_domain: "googleapis.com",
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { fcmToken, title, body, data } = await req.json();

    const message = {
      notification: {
        title,
        body,
      },
      data: data || {},
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);

    return new Response(
      JSON.stringify({ success: true, messageId: response }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
```

---

## Option 2: Node.js Backend Server

### Install Firebase Admin SDK

```bash
npm install firebase-admin
```

### Send Notification Function

```javascript
const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./firebase-service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function sendNotification(fcmToken, title, body, data = {}) {
  try {
    const message = {
      notification: {
        title,
        body,
      },
      data: data,
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    console.log("Successfully sent message:", response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error("Error sending message:", error);
    throw error;
  }
}

// Send to multiple users
async function sendNotificationToUsers(fcmTokens, title, body, data = {}) {
  try {
    const message = {
      notification: {
        title,
        body,
      },
      data: data,
      tokens: fcmTokens,
    };

    const response = await admin.messaging().sendMulticast(message);
    console.log(`Successfully sent to ${response.successCount} users`);
    return response;
  } catch (error) {
    console.error("Error sending multicast message:", error);
    throw error;
  }
}

module.exports = { sendNotification, sendNotificationToUsers };
```

### Usage in Express.js

```javascript
const express = require("express");
const { sendNotification } = require("./notifications");

const app = express();
app.use(express.json());

// Send notification to driver when mission assigned
app.post("/api/missions/assign", async (req, res) => {
  try {
    const { driverFcmToken, missionNumber, fromLocation, toLocation } =
      req.body;

    await sendNotification(
      driverFcmToken,
      "📍 New Mission Assigned",
      `${missionNumber}: ${fromLocation} → ${toLocation}`,
      {
        type: "mission_assigned",
        mission_number: missionNumber,
      },
    );

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send notification when mission status updates
app.post("/api/missions/update-status", async (req, res) => {
  try {
    const { managerFcmToken, missionNumber, newStatus } = req.body;

    const statusLabels = {
      active: "🚑 Active",
      completed: "✅ Completed",
      cancelled: "❌ Cancelled",
    };

    await sendNotification(
      managerFcmToken,
      "Mission Status Update",
      `${missionNumber} is now ${statusLabels[newStatus] || newStatus}`,
      {
        type: "mission_status_update",
        mission_number: missionNumber,
        status: newStatus,
      },
    );

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => console.log("Server running on port 3000"));
```

---

## Option 3: Python Backend

### Install Firebase Admin SDK

```bash
pip install firebase-admin
```

### Send Notification

```python
import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)

def send_notification(fcm_token, title, body, data=None):
    """Send notification to a single user"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token,
        )

        response = messaging.send(message)
        print(f'Successfully sent message: {response}')
        return True
    except Exception as e:
        print(f'Error sending message: {e}')
        return False

def send_notification_to_users(fcm_tokens, title, body, data=None):
    """Send notification to multiple users"""
    try:
        responses = messaging.send_multicast(
            messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                tokens=fcm_tokens,
            )
        )
        print(f'Successfully sent to {responses.success_count} users')
        return responses
    except Exception as e:
        print(f'Error sending multicast: {e}')
        raise

# Usage
if __name__ == '__main__':
    fcm_token = 'your_fcm_token_here'
    send_notification(
        fcm_token,
        '📍 New Mission Assigned',
        'MISS-001: Location A → Location B',
        {
            'type': 'mission_assigned',
            'mission_id': '123',
        }
    )
```

---

## How to Get FCM Token from Database

### Query Supabase for User's FCM Tokens

```javascript
// Get user's FCM tokens
async function getUserFcmTokens(userId) {
  const { data, error } = await supabase
    .from("user_fcm_tokens")
    .select("fcm_token")
    .eq("user_id", userId);

  if (error) throw error;
  return data.map((row) => row.fcm_token);
}

// Send notification to user
async function notifyUser(userId, title, body, data) {
  const tokens = await getUserFcmTokens(userId);
  if (tokens.length === 0) {
    console.warn(`No FCM tokens found for user ${userId}`);
    return;
  }

  return sendNotificationToUsers(tokens, title, body, data);
}
```

---

## Testing via Curl

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "Test Mission",
      "body": "Test notification body",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "data": {
      "type": "mission_assigned",
      "mission_id": "123"
    }
  }'
```

**Get Server Key from:**
Firebase Console → Project Settings → Cloud Messaging tab

---

## Summary

- ✅ **Sender ID:** `477713174917`
- ✅ **Project ID:** `ambulance-app-572b2`
- ✅ **Service Account:** Ready to use
- 📝 **Choose backend:** Supabase / Node.js / Python
- 🚀 **Send notifications:** Use code examples above

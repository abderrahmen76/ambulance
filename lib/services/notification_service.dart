import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../config/constants.dart';
import 'location_request_service.dart';
import 'notification_app_service.dart';
import 'jwt_helper.dart';

String _safeNotificationType(RemoteMessage message) =>
    (message.data['type'] ?? 'unknown').toString();

Map<String, dynamic> _minimalNotificationData(Map<String, dynamic> data) {
  final safe = <String, dynamic>{};
  for (final entry in data.entries) {
    if (entry.key == 'mission_id' ||
        entry.key == 'mission_number' ||
        entry.key == 'type' ||
        entry.key == 'new_status' ||
        entry.key == 'priority' ||
        entry.key == 'tenant_id' ||
        entry.key == 'tenantId' ||
        entry.key == 'provider_tenant_id' ||
        entry.key == 'clinic_tenant_id') {
      safe[entry.key] = entry.value;
    }
  }
  return safe;
}

String? _extractTenantIdFromData(Map<String, dynamic> data) {
  for (final key in const [
    'tenant_id',
    'tenantId',
    'provider_tenant_id',
    'clinic_tenant_id',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }

  final nestedData = data['data'];
  if (nestedData is String && nestedData.isNotEmpty) {
    try {
      final parsed = jsonDecode(nestedData);
      if (parsed is Map<String, dynamic>) {
        return _extractTenantIdFromData(parsed);
      }
      if (parsed is Map) {
        return _extractTenantIdFromData(
          parsed.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Ignore malformed nested data.
    }
  }

  return null;
}

/// Global background notification handler
/// Must be a top-level function for FCM to work
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FCM] Background message received: id=${message.messageId} type=${_safeNotificationType(message)}',
  );

  if ((message.data['type'] ?? '').toString().toUpperCase() == 'LOCATION_REQUEST') {
    debugPrint('[FCM] Background LOCATION_REQUEST detected, starting one-shot location response');
    await LocationRequestService.instance.ensureBackgroundReady();
    await LocationRequestService.instance.handleLocationRequest(message.data);
  }

  if (!await NotificationService.instance._shouldDisplayNotification(message.data)) {
    debugPrint('[FCM] Background notification skipped due to tenant mismatch');
    return;
  }

  // Show local notification when app is in background
  await NotificationService.instance._showLocalNotification(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Callback for when notification is tapped
  Function(Map<String, dynamic> data)? onNotificationTapped;

  // Deduplication cache to prevent showing same notification twice
  final Set<String> _recentNotificationIds = {};
  static const int _DEDUPE_WINDOW_MS = 3000; // 3 second window

  // Flag to ensure channel is only created once
  bool _channelsInitialized = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _localNotifications = FlutterLocalNotificationsPlugin();
  }

  static NotificationService get instance => _instance;

  /// Initialize Firebase Messaging and Local Notifications
  Future<void> initialize() async {
    try {
      debugPrint('[NotificationService] Initializing...');

      // Request notification permissions (iOS & Android 13+)
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          '[NotificationService] User notification permission: ${settings.authorizationStatus}');

      // Set FCM background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] Foreground message received: id=${message.messageId} type=${_safeNotificationType(message)}',
        );

        if ((message.data['type'] ?? '').toString().toUpperCase() == 'LOCATION_REQUEST') {
          debugPrint('[FCM] Foreground LOCATION_REQUEST detected, starting one-shot location response');
          LocationRequestService.instance.handleLocationRequest(message.data).catchError((error) {
            debugPrint('[NotificationService] LOCATION_REQUEST handling failed: $error');
          });
        }

        _shouldDisplayNotification(message.data).then((shouldDisplay) {
          if (!shouldDisplay) {
            debugPrint('[FCM] Foreground notification skipped due to tenant mismatch');
            return;
          }
          _showLocalNotification(message);
        });
      });

      // Handle notification tap when app is terminated
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) async {
        if (message != null) {
          debugPrint(
              '[FCM] App opened from terminated state: ${message.messageId}');
          if (!await _shouldDisplayNotification(message.data)) {
            debugPrint('[FCM] Terminated-state notification tap ignored due to tenant mismatch');
            return;
          }
          _handleNotificationTap(message.data);
        }
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        debugPrint(
            '[FCM] Notification tapped from background: ${message.messageId}');
        if (!await _shouldDisplayNotification(message.data)) {
          debugPrint('[FCM] Background notification tap ignored due to tenant mismatch');
          return;
        }
        _handleNotificationTap(message.data);
      });

      // Initialize local notifications
      _initializeLocalNotifications();

      // Get and store FCM token
      await getFcmToken();

      debugPrint('[NotificationService] Initialization complete!');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing: $e');
    }
  }

  /// Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[LocalNotif] Notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          } catch (e) {
            debugPrint('[LocalNotif] Error parsing payload: $e');
          }
        }
      },
    );

    // Delete old channels to clear any stale configurations
    // ONLY DO THIS ONCE during first initialization
    if (!_channelsInitialized) {
      try {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel('ambulance_channel')
            .catchError((e) =>
                debugPrint('[NotificationService] Old channel deletion: $e'));

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel('ambulance_channel_silent')
            .catchError((e) => debugPrint(
                '[NotificationService] Silent channel deletion: $e'));

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel('ambulance_channel_sound')
            .catchError((e) =>
                debugPrint('[NotificationService] Sound channel deletion: $e'));

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel('ambulance_channel_sound_v2')
            .catchError((e) => debugPrint(
                '[NotificationService] Sound v2 channel deletion: $e'));

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel('ambulance_channel_updates_v2')
            .catchError((e) => debugPrint(
                '[NotificationService] Updates v2 channel deletion: $e'));

        debugPrint(
            '[NotificationService] ðŸ§¹ Cleaned up old notification channels');

        // Wait a moment for deletion to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Create notification channel with sound for ALL notifications
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                'ambulance_channel_v3',
                'Ambulance Notifications',
                description: 'All ambulance notifications with custom sound',
                importance: Importance.max,
                playSound: true,
                sound: RawResourceAndroidNotificationSound('mission_alert'),
                enableVibration: true,
                showBadge: true,
              ),
            )
            .then((_) => debugPrint(
                '[NotificationService] ðŸ”Š Created notification channel for ALL notifications'));

        // Mark channels as initialized so we don't recreate them
        _channelsInitialized = true;
        debugPrint(
            '[NotificationService] âœ… Channels initialized (will not recreate)');
      } catch (e) {
        debugPrint('[NotificationService] Channel setup error: $e');
      }
    } else {
      debugPrint(
          '[NotificationService] â„¹ï¸  Channels already initialized, skipping recreation');
    }

    debugPrint('[NotificationService] Local notifications initialized');
  }

  /// Get FCM Token and store in Supabase
  Future<String?> getFcmToken() async {
    try {
      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('[NotificationService] FCM token acquired');
        // Token will be stored when user logs in (in auth_service.dart)
        return token;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error getting FCM token: $e');
    }
    return null;
  }

  /// Store FCM token in Supabase for a user
  Future<void> storeFcmToken(String userId, String fcmToken) async {
    try {
      debugPrint('[NotificationService] Storing FCM token for authenticated user');
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        debugPrint(
            '[NotificationService] Skipping direct token store because no authenticated session is available');
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'secure_user_fcm_tokens',
        body: {
          'action': 'register',
          'user_id': userId,
          'fcm_token': fcmToken,
        },
      );

      if (response.data != null) {
        debugPrint('[NotificationService] FCM token stored successfully');
      } else {
        debugPrint('[NotificationService] FCM token store returned no data');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error storing FCM token: $e');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // Avoid logging full notification payloads because they may contain sensitive mission metadata.
      debugPrint(
          '[NotificationService] Showing notification type=${_safeNotificationType(message)} keys=${message.data.keys.toList()}');

      // Generate notification ID based on mission number and type
      final missionNumber = message.data['missionNumber'] ?? '';

      // Extract type - check multiple possible locations
      var notificationType = message.data['type'];

      // If type is not directly available, try parsing nested data JSON
      if (notificationType == null || notificationType.isEmpty) {
        final dataJsonString = message.data['data'];
        if (dataJsonString != null && dataJsonString is String) {
          try {
            final parsedData = jsonDecode(dataJsonString);
            notificationType = parsedData['type'] ?? 'unknown';
            debugPrint(
                '[NotificationService] ðŸ“¦ Extracted type from nested data JSON: $notificationType');
          } catch (e) {
            debugPrint(
                '[NotificationService] âš ï¸  Failed to parse nested data JSON: $e');
            notificationType = 'unknown';
          }
        } else {
          notificationType = 'unknown';
        }
      } else {
        debugPrint(
            '[NotificationService] âœ… Type found directly in message.data: $notificationType');
      }

      final notificationId = '$missionNumber-$notificationType';

      // Check if we've already shown this notification recently
      if (_recentNotificationIds.contains(notificationId)) {
        debugPrint(
            '[NotificationService] âš ï¸  DUPLICATE BLOCKED: $notificationId already shown in last ${_DEDUPE_WINDOW_MS}ms');
        return;
      }

      // Add to recent IDs
      _recentNotificationIds.add(notificationId);
      debugPrint(
          '[NotificationService] âœ… Showing notification: $notificationId');

      // Schedule cleanup after dedup window
      Future.delayed(Duration(milliseconds: _DEDUPE_WINDOW_MS), () {
        _recentNotificationIds.remove(notificationId);
        debugPrint(
            '[NotificationService] ðŸ§¹ Cleaned dedupe cache: $notificationId');
      });

      // Use single channel for ALL notification types
      const channelId = 'ambulance_channel_v3';
      debugPrint(
          '[NotificationService] ðŸ“¢ Using channel: $channelId (for $notificationType)');

      // Get cached sound path (or fall back to built-in)
      final soundPath = await getNotificationSoundPath();

      // Build Android notification sound based on availability
      AndroidNotificationSound androidSound;
      if (soundPath != 'mission_alert') {
        // Using cached file from Supabase
        debugPrint('[NotificationService] ðŸŽµ Using CACHED sound: $soundPath');
        androidSound = UriAndroidNotificationSound(soundPath);
      } else {
        // Using built-in resource
        debugPrint(
            '[NotificationService] ðŸŽµ Using BUILT-IN sound: mission_alert');
        androidSound =
            const RawResourceAndroidNotificationSound('mission_alert');
      }

      // Build Android notification details with runtime values
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        'Ambulance Notifications',
        channelDescription: 'All ambulance notifications with custom sound',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        // Use sound from cached file or built-in
        sound: androidSound,
        // Small notification icon - ambulance medical cross
        icon: '@drawable/notification_icon',
        // Ambulance blue color for the notification bar
        color: const Color.fromARGB(255, 41, 98, 255),
        // Notification LED - ambulance blue with blink pattern
        ledColor: const Color.fromARGB(255, 41, 98, 255),
        enableLights: true,
        ledOnMs: 500, // LED on for 500ms
        ledOffMs: 500, // LED off for 500ms
        // Vibration pattern - 500ms on, 300ms off, 500ms on
        vibrationPattern: Int64List.fromList([500, 300, 500]),
      );

      debugPrint('[NotificationService] Notification type: $notificationType');

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Build notification details with both platforms
      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint(
          '[NotificationService] ðŸ“¤ About to display notification with custom sound');
      debugPrint(
          '[NotificationService] ðŸ“‹ Channel: $channelId | Sound: mission_alert.mp3');

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Ambulance',
        message.notification?.body ?? 'New notification',
        platformDetails,
        payload: jsonEncode(_minimalNotificationData(message.data)),
      );

      debugPrint('[NotificationService] âœ… Notification displayed successfully');

      // Save notification to database
      await _saveNotification(message);
    } catch (e) {
      debugPrint('[NotificationService] Error showing local notification: $e');
    }
  }

  Future<bool> _shouldDisplayNotification(Map<String, dynamic> data) async {
    final messageTenantId = _extractTenantIdFromData(data)?.trim() ?? '';
    if (messageTenantId.isEmpty) {
      return true;
    }

    try {
      final currentTenantId = (await JWTHelper.getTenantId())?.trim() ?? '';
      if (currentTenantId.isEmpty) {
        debugPrint(
          '[NotificationService] Current tenant unavailable; suppressing tenant-scoped notification',
        );
        return false;
      }

      if (currentTenantId != messageTenantId) {
        debugPrint(
          '[NotificationService] Tenant mismatch; suppressing notification target=$messageTenantId current=$currentTenantId',
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[NotificationService] Failed to validate notification tenant: $e');
      return false;
    }
  }

  /// Save notification to database
  Future<void> _saveNotification(RemoteMessage message) async {
    try {
      await NotificationServiceApp.instance.saveNotification(
        title: message.notification?.title ?? 'Ambulance',
        body: message.notification?.body ?? 'New notification',
        type: message.data['type'],
        data: _minimalNotificationData(message.data),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error saving notification: $e');
      // Don't throw - notification display shouldn't fail if database save fails
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      debugPrint(
          '[NotificationService] Handling notification tap type=${data['type']} mission=${data['mission_id'] ?? data['mission_number']}');

      // Trigger callback if set
      onNotificationTapped?.call(data);

      // Navigate based on notification type
      final String? type = data['type'];
      final String? missionId = data['mission_id'];

      switch (type) {
        case 'LOCATION_REQUEST':
          debugPrint('[NotificationService] LOCATION_REQUEST tapped for mission: $missionId');
          break;
        case 'mission_assigned':
          debugPrint('[NotificationService] Navigate to mission: $missionId');
          // Navigation will be handled by callback in main app
          break;
        case 'mission_status_update':
          debugPrint(
              '[NotificationService] Navigate to mission details: $missionId');
          break;
        case 'MISSION_BROADCAST':
          debugPrint('[NotificationService] Navigate to broadcast mission: $missionId');
          break;
        case 'critical_alert':
          debugPrint(
              '[NotificationService] Navigate to critical mission: $missionId');
          break;
        default:
          debugPrint('[NotificationService] Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error handling notification tap: $e');
    }
  }

  /// Send notification via FCM to specific user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, String>? extraData,
  }) async {
    try {
      final Map<String, String> data = {
        'type': type,
        ...?extraData,
      };

      final response = await http.post(
        Uri.parse(
            '${SupabaseConfig.supabaseUrl}/rest/v1/rpc/send_notification'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[NotificationService] Notification sent successfully');
        return true;
      } else {
        debugPrint(
            '[NotificationService] Error sending notification: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error sending notification: $e');
      return false;
    }
  }

  /// Get device type (Android/iOS)
  String _getDeviceType() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    return 'unknown';
  }

  // ========== SOUND CACHING METHODS ==========
  static const String SOUND_CACHE_DIR = 'notification_sounds';
  static const String SOUND_VERSION_KEY = 'mission_alert_version';
  static const String SOUND_URL_KEY = 'mission_alert_url';

  /// Download and cache notification sound from Supabase on app startup
  /// Call this once during app initialization
  Future<void> preloadNotificationSounds() async {
    try {
      debugPrint('[NotificationService] ðŸ”„ Starting sound preload...');

      // Get preferences and config
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getInt(SOUND_VERSION_KEY) ?? 0;

      // Fetch current sound config from backend
      final configVersion = await _fetchSoundConfigVersion();

      if (configVersion == null) {
        debugPrint(
            '[NotificationService] âš ï¸  Could not fetch sound config - using built-in fallback');
        return;
      }

      debugPrint(
          '[NotificationService] Version check - Cached: $cachedVersion, Available: $configVersion');

      // Only download if version changed
      if (cachedVersion < configVersion) {
        await _downloadAndCacheSound(prefs, configVersion);
      } else {
        debugPrint(
            '[NotificationService] âœ… Sound is up-to-date (v$cachedVersion)');
      }
    } catch (e) {
      debugPrint('[NotificationService] âš ï¸  Error preloading sound: $e');
      // Continue anyway - will fall back to built-in sound
    }
  }

  /// Fetch latest sound configuration version and URL from backend
  Future<int?> _fetchSoundConfigVersion() async {
    try {
      // Replace with your actual backend URL
      const String configUrl =
          'https://ambulance-notification-server-new.onrender.com/api/notification-config';

      final response = await http
          .get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final config = jsonDecode(response.body);
        final version = config['version'] as int?;
        final url = config['url'] as String?;

        if (version != null) {
          // Store URL for later use
          final prefs = await SharedPreferences.getInstance();
          if (url != null) {
            await prefs.setString(SOUND_URL_KEY, url);
          }
          return version;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] âš ï¸  Error fetching config: $e');
    }
    return null;
  }

  /// Download sound from URL and cache locally
  Future<void> _downloadAndCacheSound(
      SharedPreferences prefs, int version) async {
    try {
      debugPrint(
          '[NotificationService] ðŸ“¥ Downloading mission_alert.mp3 v$version...');

      // Get sound URL from prefs (set by _fetchSoundConfigVersion)
      final soundUrl = prefs.getString(SOUND_URL_KEY);
      if (soundUrl == null) {
        debugPrint('[NotificationService] âš ï¸  No sound URL available');
        return;
      }

      // Download file
      final response = await http
          .get(Uri.parse(soundUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Get cache directory
        final appDir = await getApplicationDocumentsDirectory();
        final soundDir = Directory('${appDir.path}/$SOUND_CACHE_DIR');

        // Create directory if needed
        if (!await soundDir.exists()) {
          await soundDir.create(recursive: true);
          debugPrint(
              '[NotificationService] ðŸ“ Created cache directory: ${soundDir.path}');
        }

        // Write file
        final file = File('${soundDir.path}/mission_alert.mp3');
        await file.writeAsBytes(response.bodyBytes);

        // Update version
        await prefs.setInt(SOUND_VERSION_KEY, version);

        debugPrint(
            '[NotificationService] âœ… Sound cached successfully (${response.bodyBytes.length} bytes)');
      } else {
        debugPrint(
            '[NotificationService] âš ï¸  Download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[NotificationService] âš ï¸  Error downloading sound: $e');
    }
  }

  /// Get notification sound path - cached local file or built-in fallback
  /// Returns "mission_alert" for built-in, or file path for cached sound
  Future<String> getNotificationSoundPath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soundFile =
          File('${appDir.path}/$SOUND_CACHE_DIR/mission_alert.mp3');

      if (await soundFile.exists()) {
        debugPrint(
            '[NotificationService] ðŸŽµ Using cached sound: ${soundFile.path}');
        return soundFile.path;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error getting sound path: $e');
    }

    // Fallback to built-in
    debugPrint('[NotificationService] ðŸŽµ Using built-in sound: mission_alert');
    return 'mission_alert';
  }
}


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';

/// FCM Token Service
/// Manages Firebase Cloud Messaging tokens for push notifications
class FCMTokenService {
  static final FCMTokenService _instance = FCMTokenService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  factory FCMTokenService() {
    return _instance;
  }

  FCMTokenService._internal();

  /// Register FCM token for current user
  /// Called after user successfully logs in (in background, non-blocking)
  Future<void> registerFCMToken(User user) async {
    // Skip on web
    if (kIsWeb) {
      return;
    }

    try {
      debugPrint('📱 [FCMToken] FCM registration started');

      // Add delay
      await Future.delayed(const Duration(seconds: 1));

      if (kIsWeb) {
        return;
      }

      // Wrap Firebase call in a completely isolated Future
      String? fcmToken;

      try {
        debugPrint('🔄 [FCMToken] Getting token from Firebase...');

        // Try to get token with timeout
        fcmToken = await Future.value(null).then((_) async {
          try {
            final token = await _firebaseMessaging.getToken().timeout(
                  const Duration(seconds: 10),
                  onTimeout: () => null,
                );
            return token;
          } catch (e) {
            debugPrint('❌ [FCMToken] Firebase getToken failed: $e');
            return null;
          }
        });

        if (fcmToken != null) {
          debugPrint('📝 [FCMToken] Token received');
          await _saveFCMTokenToSupabase(user.id!, fcmToken);
        }
      } catch (innerError) {
        debugPrint('❌ [FCMToken] Inner error: $innerError');
      }
    } catch (outerError) {
      debugPrint('❌ [FCMToken] Outer error: $outerError');
    }
  }

  /// Save FCM token to Supabase
  Future<void> _saveFCMTokenToSupabase(String userId, String fcmToken) async {
    try {
      debugPrint('💾 [FCMToken] Saving authenticated device token');

      final payload = {
        'fcm_token': fcmToken,
        'device_name': _getDeviceName(),
      };

      debugPrint(
          '📤 [FCMToken] Payload prepared for current authenticated user');

      try {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_user_fcm_tokens',
          body: {
            'action': 'register',
            ...payload,
          },
        );
        debugPrint(
            '✅ [FCMToken] Token saved successfully (${((response.data as Map<String, dynamic>?) ?? const {}).keys.length} response fields)');
      } catch (e) {
        // Handle duplicate key constraint (409 conflict)
        // This is OK - token already exists in database
        if (e.toString().contains('409') ||
            e.toString().contains('duplicate') ||
            e.toString().contains('23505')) {
          debugPrint(
              'ℹ️  [FCMToken] Token already exists (duplicate). Treating as success.');
        } else {
          // Unknown error - rethrow
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('❌ [FCMToken] Error saving token: $e');
      // Log but don't crash - FCM registration failures should not block app
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeFCMToken(String userId, String fcmToken) async {
    try {
      if (kIsWeb) {
        debugPrint('⏭️  [FCMToken] Skipping FCM removal on web platform');
        return;
      }

      debugPrint('🗑️  [FCMToken] Removing authenticated device token');

      await Supabase.instance.client.functions.invoke(
        'secure_user_fcm_tokens',
        body: {
          'action': 'remove',
          'fcm_token': fcmToken,
        },
      );
      debugPrint('✅ [FCMToken] Token removed from Supabase');
    } catch (e) {
      debugPrint('❌ [FCMToken] Error removing token: $e');
      // Silently fail - logout should succeed even if token removal fails
    }
  }

  /// Get device name for identification
  String _getDeviceName() {
    // Could be enhanced to get actual device name
    // For now, return a generic name
    return 'Mobile Device ${DateTime.now().toString().split(' ')[0]}';
  }

  /// Listen for FCM token refresh
  /// Call this once on app startup
  void listenForTokenRefresh() {
    try {
      if (kIsWeb) {
        return;
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [FCMToken] Token refreshed');
        // Could update the token in Supabase here if needed
        // For now, the old token will just expire naturally
      });

      debugPrint('✅ [FCMToken] Listening for token refresh');
    } catch (e) {
      debugPrint('⚠️  [FCMToken] Error setting up token refresh listener: $e');
    }
  }
}

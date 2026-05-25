import '../config/constants.dart';
import '../models/user_model.dart';
import 'dashboard_preload_service.dart';
import 'app_realtime_service.dart';
import 'fleet_tracking/background_location_service.dart';
import 'fleet_tracking/fleet_tracking_service.dart';
import 'tracking_presence_service.dart';
import '../utils/jwt_decoder.dart';
import 'api_client.dart';
import 'app_memory_cache_service.dart';
import 'session_security_service.dart';
import 'fcm_token_service.dart';
import 'notification_service.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:convert';

/// Authentication Service
/// Handles user login and authentication with Supabase
/// Optimized for performance with minimal queries
class AuthService {
  static final AuthService _instance = AuthService._internal();
  final ApiClient _apiClient = ApiClient();
  final FleetTrackingService _fleetTrackingService = FleetTrackingService();
  final TrackingPresenceService _trackingPresenceService =
      TrackingPresenceService();
  final SessionSecurityService _sessionSecurityService =
      SessionSecurityService();

  // Cache for current user (improves performance)
  User? _cachedUser;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  /// Get cached user (returns null if not logged in)
  User? get cachedUser => _cachedUser;

  /// Check if user is logged in
  bool get isLoggedIn => _cachedUser != null;

  /// Login with email and password - SECURE FLOW
  /// STEP 1: Authenticate with Supabase Auth first (required for RLS)
  /// STEP 2: Then query user profile (RLS now allows it - user is authenticated)
  /// Returns User on success, throws exception on failure
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final mainStopwatch = Stopwatch()..start();
    print('\n📍 [AUTH SERVICE] login() method called');
    print('📧 Email: $email\n');

    try {
      // STEP 1: Authenticate with Supabase Auth first (SECURITY CRITICAL!)
      print('⏳ [STEP 1] Authenticating with Supabase Auth...');
      final step1Timer = Stopwatch()..start();

      final authResponse =
          await Supabase.instance.client.auth
              .signInWithPassword(
                email: email,
                password: password,
              )
              .timeout(
                const Duration(seconds: 20),
                onTimeout: () => throw Exception(
                  'Login timed out after 20 seconds. Please try again.',
                ),
              );

      final authenticatedUser = authResponse.user;
      if (authenticatedUser == null) {
        throw Exception('Authentication failed. User is null.');
      }

      step1Timer.stop();
      print(
          '✅ [STEP 1] Authenticated with Supabase Auth in ${step1Timer.elapsedMilliseconds}ms');
      print('   Auth User ID: ${authenticatedUser.id}');
      print('   Auth Email: ${authenticatedUser.email}');
      print('   User Metadata: ${authenticatedUser.userMetadata}\n');

      // DEBUG: Check JWT token and metadata
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('🔍 [DEBUG] Current Session JWT:');
        print('   Access Token exists: ${session.accessToken.isNotEmpty}');
        print('   Token expiry: ${session.expiresAt}');
        print('   Token length: ${session.accessToken.length} chars');
        // Show first 20 chars of token for verification
        print(
            '   Token (first 20 chars): ${session.accessToken.substring(0, 20)}...');

        // 🔥 DECODE JWT PAYLOAD TO CHECK FOR user_id AND tenant_id
        print('\n🔐 [CRITICAL] Checking JWT Payload for RLS fields...');
        JWTDecoder.printJWTPayload(session.accessToken);
      } else {
        print('❌ [DEBUG] No session available after auth!');
      }

      // IMPORTANT: Verify that the same session is available for API calls
      print('\n📋 [READY FOR API CALLS] Session is now available');
      print('   All subsequent REST API calls WILL include JWT token ✅');

      // STEP 2: Now query user profile (RLS will allow this - user is authenticated)
      // Query by auth_user_id since RLS policy filters on it
      print('⏳ [STEP 2] Fetching user profile from database...');
      final step2Timer = Stopwatch()..start();

      final authUserId = authenticatedUser.id;
      print('   📋 Query Parameters:');
      print('   - Table: ${SupabaseConfig.usersTable}');
      print('   - Filter: auth_user_id = eq.$authUserId');

      final users = await _apiClient.get(
        SupabaseConfig.usersTable,
        filters: {
          'auth_user_id': 'eq.$authUserId',
        },
      );

      step2Timer.stop();
      print(
          '✅ [STEP 2] User profile fetch completed in ${step2Timer.elapsedMilliseconds}ms');
      print('   Found ${users.length} user(s)');
      if (users.isNotEmpty) {
        print('   User Data: ${users.first}\n');
      } else {
        print('   ⚠️  No users returned (possible RLS policy blocking)\n');
      }

      if (users.isEmpty) {
        throw Exception('User profile not found in database. Check if:\n'
            '1. RLS policies are enabled on users table\n'
            '2. RLS policies are blocking queries\n'
            '3. User exists in public.users table');
      }

      final userData = users.first;
      final userId = _toString(userData['id']);
      final userName = _toStringNullable(userData['name']) ?? 'User';
      final userTenantId = _toStringNullable(userData['tenant_id']);

      // 🔥 Get role directly from user profile (already fetched!)
      final userRole = _toStringNullable(userData['role']) ?? 'driver';
      final userRoleLabel = userRole; // Display label is same as role for now

      print(
          '📝 [USER DATA] ID: $userId, Name: $userName, Tenant: $userTenantId, Role: $userRole');

      // Create user object and cache it
      print('💾 [CACHING] Caching user in memory...');
      final cacheTimer = Stopwatch()..start();

      final user = User(
        id: userId,
        name: userName,
        email: email,
        role: userRole,
        roleLabel: userRoleLabel,
        tenantId: userTenantId,
      );

      _cachedUser = user;

      await _saveLegacyUserToStorage(user);
      await _sessionSecurityService.registerCurrentDeviceSession();
      AppRealtimeService.instance.startForUser(user);
      DashboardPreloadService().preloadAfterAuth(user);

      // Register FCM token for push notifications (mobile only)
      // Skip on Web - Firebase Messaging doesn't work properly with web interop
      if (!kIsWeb) {
        Future(() async {
          try {
            debugPrint('🔔 [AUTH] Starting background FCM registration');

            await FCMTokenService().registerFCMToken(user).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('🔔 [AUTH] FCM registration timeout');
                return;
              },
            );

            debugPrint('🔔 [AUTH] FCM registration completed');
          } catch (e) {
            debugPrint('🔔 [AUTH] FCM error (caught): $e');
            // Silently ignore
          }
        });
      } else {
        debugPrint('🌐 [AUTH] Skipping FCM on Web');
      }

      cacheTimer.stop();
      print('✅ [CACHING] User cached in ${cacheTimer.elapsedMilliseconds}ms\n');

      mainStopwatch.stop();
      print('═══════════════════════════════════════════════════════');
      print('🎉 [SUCCESS] Authentication complete!');
      print(
          '⏱️  Total time: ${mainStopwatch.elapsedMilliseconds}ms (${(mainStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s)');
      print('═══════════════════════════════════════════════════════\n');

      return user;
    } catch (e) {
      mainStopwatch.stop();
      print('═══════════════════════════════════════════════════════');
      print(
          '❌ [FAILURE] Authentication failed after ${mainStopwatch.elapsedMilliseconds}ms');
      print('⚠️  Error: $e');
      print('═══════════════════════════════════════════════════════\n');
      rethrow;
    }
  }

  /// Logout - clears cached user and persistent storage
  Future<void> logout() async {
    // Remove FCM token from database if user is logged in
    if (_cachedUser != null && _cachedUser!.id != null) {
      try {
        final userId = _cachedUser!.id;

        // Get the current FCM token
        final fcmToken = await NotificationService.instance.getFcmToken();

        if (fcmToken != null) {
          debugPrint('🚪 [AUTH] Logout - Removing FCM token from database...');

          // Delete this device's FCM token from database using filters
          await _apiClient.deleteWithFilters(
            '/rest/v1/user_fcm_tokens',
            {
              'user_id': 'eq.$userId',
              'fcm_token': 'eq.$fcmToken',
            },
          );

          debugPrint('✅ [AUTH] FCM token removed for user: $userId');
        }
      } catch (e) {
        debugPrint('⚠️  [AUTH] Error removing FCM token: $e');
        // Continue with logout even if token removal fails
      }
    }

    await _stopAllTrackingRuntime();
    AppRealtimeService.instance.stop();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('⚠️  [AUTH] Error during Supabase signOut: $e');
    }
    await _clearLegacyUserFromStorage();
    _sessionSecurityService.clearSensitiveAccessWindow();
    AppMemoryCacheService.clearAll();
    _cachedUser = null;
  }

  /// Validate password using bcrypt
  /// For production: Verifies the entered password against the bcrypt hash
  bool _validatePassword(String enteredPassword, String storedPasswordHash) {
    try {
      // Use bcrypt to verify the password against the hash
      // storedPasswordHash is the bcrypt hash from database (e.g., $2y$12$...)
      return BCrypt.checkpw(enteredPassword, storedPasswordHash);
    } catch (e) {
      // If bcrypt fails, fallback to simple comparison for testing
      return enteredPassword.trim() == storedPasswordHash.trim();
    }
  }

  /// Helper to safely convert any value to string
  String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  /// Helper to safely convert any value to nullable string
  String? _toStringNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Update user password (hash with bcrypt on backend)
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.usersTable}?id=eq.$userId',
        {
          'password': newPassword, // Backend should hash this
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Clear cache (for testing or forced logout)
  void clearCache() {
    _cachedUser = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PERSISTENT STORAGE METHODS
  // ═══════════════════════════════════════════════════════════════════

  static const String _legacyUserStorageKey = 'cached_user';

  Future<void> _saveLegacyUserToStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _legacyUserStorageKey,
        jsonEncode(user.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _clearLegacyUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyUserStorageKey);
    } catch (_) {}
  }

  Future<User?> _loadUserProfileFromCurrentSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return null;
    }

    final authUserId = session.user.id;
    final users = await _apiClient.get(
      SupabaseConfig.usersTable,
      filters: {
        'auth_user_id': 'eq.$authUserId',
      },
      limit: 1,
    );

    if (users.isEmpty) {
      return null;
    }

    final userData = users.first;
    return User(
      id: _toString(userData['id']),
      name: _toStringNullable(userData['name']) ?? 'User',
      email: _toStringNullable(userData['email']) ?? session.user.email ?? '',
      role: _toStringNullable(userData['role']) ?? 'driver',
      roleLabel: _toStringNullable(userData['role']) ?? 'driver',
      tenantId: _toStringNullable(userData['tenant_id']),
    );
  }

  /// Restore user session from persistent storage on app startup
  Future<void> restoreSessionOnStartup() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        print('ℹ️  [SESSION] No Supabase session to restore');
        await _clearLegacyUserFromStorage();
        await _stopAllTrackingRuntime();
        return;
      }

      await _sessionSecurityService.ensureFreshSession(
        minRemaining: const Duration(minutes: 10),
      );
      _cachedUser = await _loadUserProfileFromCurrentSession();
      if (_cachedUser != null) {
        print('✅ [SESSION] User session restored on startup');
        await _saveLegacyUserToStorage(_cachedUser!);
        await _sessionSecurityService.registerCurrentDeviceSession();
        await _sessionSecurityService.assertCurrentDeviceSessionActive();
        AppRealtimeService.instance.startForUser(_cachedUser!);
        DashboardPreloadService().preloadAfterAuth(_cachedUser!);

        // Register FCM token on session restore (mobile only)
        if (!kIsWeb && _cachedUser != null) {
          debugPrint(
              '🔔 [SESSION] Starting FCM registration after session restore');
          Future(() async {
            try {
              await FCMTokenService().registerFCMToken(_cachedUser!).timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  debugPrint('🔔 [SESSION] FCM registration timeout');
                  return;
                },
              );
              debugPrint('🔔 [SESSION] FCM registration completed');
            } catch (e) {
              debugPrint('🔔 [SESSION] FCM error: $e');
            }
          });
        }
      } else {
        print('ℹ️  [SESSION] No user profile could be restored');
        await _stopAllTrackingRuntime();
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
      }
    } catch (e) {
      print('❌ [SESSION] Error restoring session: $e');
      _cachedUser = null;
      await _stopAllTrackingRuntime();
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }

  Future<void> _stopAllTrackingRuntime() async {
    try {
      debugPrint('🧹 [AUTH] Cleaning tracking runtime');
      await _fleetTrackingService.hardResetRuntime();
    } catch (e) {
      debugPrint('⚠️  [AUTH] Failed to reset fleet tracking runtime: $e');
    }

    try {
      if (await BackgroundLocationService.isServiceRunning()) {
        await BackgroundLocationService.stopBackgroundService();
      }
    } catch (e) {
      debugPrint('⚠️  [AUTH] Failed to stop background location service: $e');
    }

    try {
      _trackingPresenceService.dispose();
    } catch (e) {
      debugPrint('⚠️  [AUTH] Failed to dispose tracking presence: $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JWTHelper {
  /// Get the current JWT token
  static String? getToken() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  /// Get tenant_id from JWT
  static Future<String?> getTenantId() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final userMetadataTenant =
          session?.user.userMetadata?['tenant_id']?.toString().trim();
      if (userMetadataTenant != null && userMetadataTenant.isNotEmpty) {
        return userMetadataTenant;
      }

      final appMetadataTenant =
          session?.user.appMetadata['tenant_id']?.toString().trim();
      if (appMetadataTenant != null && appMetadataTenant.isNotEmpty) {
        return appMetadataTenant;
      }
    } catch (e) {
      debugPrint('[JWTHelper] Supabase tenant lookup failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString('cached_user');
      if (rawUser == null || rawUser.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rawUser);
      if (decoded is Map) {
        final tenantId = (decoded['tenantId'] ?? decoded['tenant_id'])
            ?.toString()
            .trim();
        if (tenantId != null && tenantId.isNotEmpty) {
          return tenantId;
        }
      }
    } catch (e) {
      debugPrint('[JWTHelper] Cached tenant lookup failed: $e');
    }

    return null;
  }

  /// Get user role from JWT
  static Future<String?> getRole() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.user.userMetadata?['role'] as String?;
  }

  /// Get list of accessible ambulances from JWT (if available)
  static Future<List<String>> getAmbulanceIds() async {
    final session = Supabase.instance.client.auth.currentSession;
    final ambulanceIds = session?.user.userMetadata?['ambulance_ids'];

    if (ambulanceIds is List) {
      return ambulanceIds.cast<String>();
    }
    return [];
  }

  /// Check if user is manager or admin
  static Future<bool> isManager() async {
    final role = await getRole();
    return role == 'manager' || role == 'owner' || role == 'admin';
  }

  /// Check if user is admin
  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == 'admin';
  }

  /// Decode JWT manually (for debugging)
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');

      final padded = payload + ('=' * (4 - payload.length % 4));
      final decoded = jsonDecode(utf8.decode(base64Decode(padded)));

      return decoded as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error decoding JWT: $e');
      return null;
    }
  }

  /// Get all JWT claims (useful for debugging)
  static Future<Map<String, dynamic>?> getAllClaims() async {
    final token = getToken();
    if (token == null) return null;
    return decodeToken(token);
  }

  /// Print JWT claims to console (DEBUG ONLY)
  static Future<void> debugPrintJWT() async {
    final claims = await getAllClaims();
    if (claims != null) {
      debugPrint('=== JWT CLAIMS ===');
      debugPrint('tenant_id: ${claims['tenant_id']}');
      debugPrint('role: ${claims['role']}');
      debugPrint('is_active: ${claims['is_active']}');
      debugPrint('ambulance_ids: ${claims['ambulance_ids']}');
      debugPrint('email: ${claims['email']}');
      debugPrint('exp: ${claims['exp']}');
      debugPrint('==================');
    } else {
      debugPrint('❌ No JWT token found');
    }
  }
}

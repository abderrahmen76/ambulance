import 'dart:convert';

/// Simple JWT decoder (just for debugging — not for production security checks)
class JWTDecoder {
  /// Decode JWT without verification (for debugging only!)
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('❌ Invalid JWT format (not 3 parts)');
        return null;
      }

      // Decode the payload (second part)
      String payload = parts[1];

      // Add padding if needed
      payload = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );

      final decoded = utf8.decode(base64Url.decode(payload));
      final jsonMap = jsonDecode(decoded) as Map<String, dynamic>;

      return jsonMap;
    } catch (e) {
      print('❌ Error decoding JWT: $e');
      return null;
    }
  }

  /// Pretty print JWT payload
  static void printJWTPayload(String token) {
    print('\n🔍 [JWT DECODER] Decoding token payload...\n');

    final payload = decodeToken(token);
    if (payload == null) {
      print('❌ Failed to decode token');
      return;
    }

    print('✅ JWT Payload:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    payload.forEach((key, value) {
      print('  $key: $value');
    });
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Check for critical fields
    print('🔐 Critical Fields:');
    print('  user_id: ${payload['user_id'] ?? '❌ MISSING'}');
    print('  tenant_id: ${payload['tenant_id'] ?? '❌ MISSING'}');
    print('  role: ${payload['role'] ?? '⚠️  MISSING'}');
    print('');
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import 'auth_service.dart';
import 'device_identity_service.dart';

class SessionSecurityService {
  static final SessionSecurityService _instance =
      SessionSecurityService._internal();

  factory SessionSecurityService() => _instance;

  SessionSecurityService._internal();

  final DeviceIdentityService _deviceIdentityService = DeviceIdentityService();
  DateTime? _lastSensitiveUnlockAt;
  DateTime? _lastDeviceStatusCheckAt;

  bool _isSensitiveUnlockFresh() {
    final unlockedAt = _lastSensitiveUnlockAt;
    if (unlockedAt == null) {
      return false;
    }

    return DateTime.now().difference(unlockedAt) <
        const Duration(minutes: 10);
  }

  void clearSensitiveAccessWindow() {
    _lastSensitiveUnlockAt = null;
  }

  Future<Session> ensureFreshSession({
    Duration minRemaining = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Your session expired. Please log in again.');
    }

    final expiry = session.expiresAt;
    if (!forceRefresh && expiry == null) {
      return session;
    }

    if (!forceRefresh && expiry != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiry * 1000,
        isUtc: true,
      );
      final remaining = expiresAt.difference(DateTime.now().toUtc());

      if (remaining > minRemaining) {
        return session;
      }
    }

    final refreshResponse = await client.auth.refreshSession();
    final refreshed = refreshResponse.session ?? client.auth.currentSession;
    if (refreshed == null) {
      throw Exception('Your session expired. Please log in again.');
    }

    return refreshed;
  }

  Future<Map<String, String>> buildFunctionHeaders({
    bool includeApiKey = true,
    bool forceRefresh = false,
  }) async {
    final session = await ensureFreshSession(forceRefresh: forceRefresh);
    final headers = <String, String>{
      'Authorization': 'Bearer ${session.accessToken}',
      'x-app-kind': _deviceIdentityService.appKind,
      'x-device-id': await _deviceIdentityService.getDeviceId(),
    };

    if (includeApiKey) {
      headers['apikey'] = SupabaseConfig.anonKey;
    }

    return headers;
  }

  Future<void> registerCurrentDeviceSession() async {
    final deviceId = await _deviceIdentityService.getDeviceId();

    await Supabase.instance.client.functions.invoke(
      'secure_device_sessions',
      headers: {
        'Authorization':
            'Bearer ${(await ensureFreshSession()).accessToken}',
        'apikey': SupabaseConfig.anonKey,
      },
      body: {
        'action': 'register',
        'app_kind': _deviceIdentityService.appKind,
        'device_id': deviceId,
        'device_name': _deviceIdentityService.deviceName,
        'device_type': _deviceIdentityService.deviceType,
      },
    );

    _lastDeviceStatusCheckAt = DateTime.now();
  }

  Future<void> assertCurrentDeviceSessionActive({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastDeviceStatusCheckAt != null &&
        now.difference(_lastDeviceStatusCheckAt!) <
            const Duration(minutes: 3)) {
      return;
    }

    final deviceId = await _deviceIdentityService.getDeviceId();
    final response = await Supabase.instance.client.functions.invoke(
      'secure_device_sessions',
      headers: await buildFunctionHeaders(),
      body: {
        'action': 'status',
        'app_kind': _deviceIdentityService.appKind,
        'device_id': deviceId,
      },
    );

    final payload = Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
    final isActive = payload['active'] == true;
    if (!isActive) {
      throw Exception(
        'This device session has been revoked. Please log in again.',
      );
    }

    _lastDeviceStatusCheckAt = now;
  }

  Future<bool> requireSensitiveAccess(
    BuildContext context, {
    String prompt =
        'Re-enter your password to continue with this sensitive action.',
  }) async {
    await ensureFreshSession();
    await assertCurrentDeviceSessionActive(forceRefresh: true);

    if (_isSensitiveUnlockFresh()) {
      return true;
    }

    final email = AuthService().cachedUser?.email.trim() ?? '';
    if (email.isEmpty) {
      _lastSensitiveUnlockAt = DateTime.now();
      return true;
    }

    final password = await _showPasswordPrompt(context, prompt);
    if (password == null || password.isEmpty) {
      return false;
    }

    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Re-authentication failed.');
    }

    _lastSensitiveUnlockAt = DateTime.now();
    await registerCurrentDeviceSession();
    return true;
  }

  Future<String?> _showPasswordPrompt(
    BuildContext context,
    String prompt,
  ) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmation requise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prompt),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

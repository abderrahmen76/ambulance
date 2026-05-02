import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  static final DeviceIdentityService _instance =
      DeviceIdentityService._internal();

  factory DeviceIdentityService() => _instance;

  DeviceIdentityService._internal();

  static const _deviceIdKey = 'app_device_id';
  String? _deviceId;

  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return existing;
    }

    final generated =
        'app_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_deviceIdKey, generated);
    _deviceId = generated;
    return generated;
  }

  String get appKind => 'mobile_app';

  String get deviceType {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String get deviceName => 'mobile_app_$deviceType';
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenProtectionService {
  static final ScreenProtectionService _instance =
      ScreenProtectionService._internal();

  factory ScreenProtectionService() => _instance;

  ScreenProtectionService._internal();

  static const MethodChannel _channel =
      MethodChannel('app.security/screen_protection');

  int _activeScopes = 0;

  Future<void> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _activeScopes += 1;
    if (_activeScopes > 1) {
      return;
    }

    await _channel.invokeMethod<void>('enable');
  }

  Future<void> disable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (_activeScopes == 0) {
      return;
    }

    _activeScopes -= 1;
    if (_activeScopes > 0) {
      return;
    }

    await _channel.invokeMethod<void>('disable');
  }
}

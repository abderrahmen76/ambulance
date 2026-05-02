/**
 * Background Location Service - Android Implementation
 * Handles GPS tracking in background using foreground service
 * 
 * This service continues tracking even when the app is in background
 * Uses flutter_background_service for continuous tracking
 * Stores locations in SharedPreferences for foreground app to read
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static const _prefsDriverId = 'bg_tracking_driver_id';
  static const _prefsAmbulanceId = 'bg_tracking_ambulance_id';
  static const _prefsDriverName = 'bg_tracking_driver_name';
  static const _prefsBackendUrl = 'bg_tracking_backend_url';
  static const _prefsAmbulanceNumber = 'bg_tracking_ambulance_number';
  static const _prefsAmbulanceTelephone = 'bg_tracking_ambulance_telephone';

  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  static IO.Socket? _backgroundSocket;
  static bool _socketConnected = false;

  factory BackgroundLocationService() {
    return _instance;
  }

  BackgroundLocationService._internal();

  bool _isServiceRunning = false;

  /**
   * Initialize background service
   */
  static Future<void> initializeService() async {
    debugPrint('');
    debugPrint('🔧 [INIT-BG] ════════════════════════════════════');
    debugPrint('🔧 [INIT-BG] Initializing background service...');
    try {
      final service = FlutterBackgroundService();

      debugPrint('⚙️ [INIT-BG] Configuring service...');
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
        ),
      );
      debugPrint('✅ [INIT-BG] Service configured successfully');
      debugPrint('🔧 [INIT-BG] ════════════════════════════════════');
    } catch (error) {
      debugPrint('❌ [INIT-BG] ERROR: $error');
      debugPrint('🔧 [INIT-BG] ════════════════════════════════════');
      rethrow;
    }
  }

  /**
   * Start background service
   */
  static Future<bool> startBackgroundService({
    required String driverId,
    required String ambulanceId,
    required String driverName,
    required String backendUrl,
    String? ambulanceNumber,
    String? ambulanceTelephone,
  }) async {
    debugPrint('');
    debugPrint('🎯 [START-BG] ════════════════════════════════════');
    debugPrint('🎯 [START-BG] Starting background service');
    debugPrint('🎯 [START-BG] Driver: $driverId | Ambulance: $ambulanceId');

    try {
      final service = FlutterBackgroundService();

      debugPrint('🔍 [START-BG] Checking if service already running...');
      final isServiceRunning = await service.isRunning();
      debugPrint('🔍 [START-BG] Service running: $isServiceRunning');

      if (isServiceRunning) {
        debugPrint('⚠️ [START-BG] Service already running - stopping first');
      }

      debugPrint('🚀 [START-BG] Starting service...');
      await service.startService();
      debugPrint('✅ [START-BG] Service started');

      debugPrint('📤 [START-BG] Sending data...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsDriverId, driverId);
      await prefs.setString(_prefsAmbulanceId, ambulanceId);
      await prefs.setString(_prefsDriverName, driverName);
      await prefs.setString(_prefsBackendUrl, backendUrl);
      if (ambulanceNumber != null && ambulanceNumber.isNotEmpty) {
        await prefs.setString(_prefsAmbulanceNumber, ambulanceNumber);
      }
      if (ambulanceTelephone != null && ambulanceTelephone.isNotEmpty) {
        await prefs.setString(_prefsAmbulanceTelephone, ambulanceTelephone);
      }

      service.invoke('sendData', {
        'driverId': driverId,
        'ambulanceId': ambulanceId,
        'driverName': driverName,
        'backendUrl': backendUrl,
        'ambulanceNumber': ambulanceNumber,
        'ambulanceTelephone': ambulanceTelephone,
      });
      debugPrint('✅ [START-BG] Successfully started');
      debugPrint('🎯 [START-BG] ════════════════════════════════════');
      return true;
    } catch (error) {
      debugPrint('❌ [START-BG] ERROR: $error');
      debugPrint('🎯 [START-BG] ════════════════════════════════════');
      return false;
    }
  }

  /**
   * Stop background service
   */
  static Future<bool> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isServiceRunning = await service.isRunning();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDriverId);
    await prefs.remove(_prefsAmbulanceId);
    await prefs.remove(_prefsDriverName);
    await prefs.remove(_prefsBackendUrl);
    await prefs.remove(_prefsAmbulanceNumber);
    await prefs.remove(_prefsAmbulanceTelephone);

    if (!isServiceRunning) {
      debugPrint('⚠️ Background service not running');
      await _disconnectBackgroundSocket();
      return false;
    }

    service.invoke('stop');
    await _disconnectBackgroundSocket();
    debugPrint('🛑 Background service stopped');
    return true;
  }

  /**
   * Check if service is running
   */
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /**
   * Callback when background service starts (Android)
   * This runs continuously in background
   */
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    debugPrint('✅ Background service started');

    DartPluginRegistrant.ensureInitialized();

    try {
      // Request location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied in background');
        return;
      }

      // Start location updates
      await _restoreBackgroundSocketFromPrefs();
      _startBackgroundLocationUpdates(service);
    } catch (error) {
      debugPrint('❌ Error in background service: $error');
    }

    // Handle stop command
    if (service is AndroidServiceInstance) {
      service.on('stop').listen((event) {
        _disconnectBackgroundSocket();
        service.stopSelf();
        debugPrint('🛑 Background service stopped by user');
      });

      service.on('sendData').listen((event) {
        debugPrint('📦 Received data in background service: $event');
        _saveBackgroundSocketContext(event);
        _connectBackgroundSocket(event);
      });
    }
  }

  /**
   * Start continuous location updates in background
   * Stores locations in SharedPreferences for foreground app to retrieve
   * @private
   */
  @pragma('vm:entry-point')
  static void _startBackgroundLocationUpdates(ServiceInstance service) {
    // Timer for periodic location updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          forceAndroidLocationManager: false,
        );

        debugPrint(
          '📍 Background location: ${position.latitude}, ${position.longitude}',
        );

        // Store location in SharedPreferences for foreground app to read
        final prefs = await SharedPreferences.getInstance();
        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Save location JSON to SharedPreferences
        await prefs.setString(
            'last_background_location', jsonEncode(locationData));
        debugPrint('💾 [BG-SERVICE] Location saved to SharedPreferences');

        await _emitBackgroundLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (error) {
        debugPrint('❌ Error getting background location: $error');
      }
    });
  }

  /**
   * Callback when service runs on iOS
   * Note: iOS requires different permissions setup
   */
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    debugPrint('✅ iOS background service started');

    // Handle stop
    service.on('stop').listen((event) {
      service.stopSelf();
    });

    // Start location updates
    _startBackgroundLocationUpdates(service);

    return true;
  }

  static Future<void> _restoreBackgroundSocketFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final backendUrl = prefs.getString(_prefsBackendUrl);
    final driverId = prefs.getString(_prefsDriverId);
    final ambulanceId = prefs.getString(_prefsAmbulanceId);
    final driverName = prefs.getString(_prefsDriverName);

    if ((backendUrl ?? '').isEmpty ||
        (driverId ?? '').isEmpty ||
        (ambulanceId ?? '').isEmpty ||
        (driverName ?? '').isEmpty) {
      debugPrint('ℹ️ [BG-SERVICE] No persisted socket context to restore');
      return;
    }

    await _connectBackgroundSocket({
      'backendUrl': backendUrl,
      'driverId': driverId,
      'ambulanceId': ambulanceId,
      'driverName': driverName,
      'ambulanceNumber': prefs.getString(_prefsAmbulanceNumber),
      'ambulanceTelephone': prefs.getString(_prefsAmbulanceTelephone),
    });
  }

  static Future<void> _saveBackgroundSocketContext(dynamic event) async {
    if (event is! Map) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final driverId = event['driverId']?.toString();
    final ambulanceId = event['ambulanceId']?.toString();
    final driverName = event['driverName']?.toString();
    final backendUrl = event['backendUrl']?.toString();
    final ambulanceNumber = event['ambulanceNumber']?.toString();
    final ambulanceTelephone = event['ambulanceTelephone']?.toString();

    if (driverId != null && driverId.isNotEmpty) {
      await prefs.setString(_prefsDriverId, driverId);
    }
    if (ambulanceId != null && ambulanceId.isNotEmpty) {
      await prefs.setString(_prefsAmbulanceId, ambulanceId);
    }
    if (driverName != null && driverName.isNotEmpty) {
      await prefs.setString(_prefsDriverName, driverName);
    }
    if (backendUrl != null && backendUrl.isNotEmpty) {
      await prefs.setString(_prefsBackendUrl, backendUrl);
    }
    if (ambulanceNumber != null && ambulanceNumber.isNotEmpty) {
      await prefs.setString(_prefsAmbulanceNumber, ambulanceNumber);
    }
    if (ambulanceTelephone != null && ambulanceTelephone.isNotEmpty) {
      await prefs.setString(_prefsAmbulanceTelephone, ambulanceTelephone);
    }
  }

  static Future<void> _connectBackgroundSocket(dynamic event) async {
    if (event is! Map) {
      return;
    }

    final backendUrl = event['backendUrl']?.toString() ?? '';
    if (backendUrl.isEmpty) {
      debugPrint('⚠️ [BG-SERVICE] Missing backendUrl for background socket');
      return;
    }

    if (_backgroundSocket != null) {
      try {
        _backgroundSocket!.dispose();
      } catch (_) {}
    }

    debugPrint('🔌 [BG-SERVICE] Connecting background socket to $backendUrl');
    _backgroundSocket = IO.io(
      backendUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _backgroundSocket!.onConnect((_) {
      _socketConnected = true;
      debugPrint('✅ [BG-SERVICE] Background socket connected');
    });
    _backgroundSocket!.onDisconnect((_) {
      _socketConnected = false;
      debugPrint('❌ [BG-SERVICE] Background socket disconnected');
    });
    _backgroundSocket!.onConnectError((data) {
      _socketConnected = false;
      debugPrint('⚠️ [BG-SERVICE] Background socket connect error: $data');
    });
    _backgroundSocket!.onError((data) {
      _socketConnected = false;
      debugPrint('⚠️ [BG-SERVICE] Background socket error: $data');
    });

    _backgroundSocket!.connect();
  }

  static Future<void> _emitBackgroundLocation({
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString(_prefsDriverId) ?? '';
    final ambulanceId = prefs.getString(_prefsAmbulanceId) ?? '';
    final driverName = prefs.getString(_prefsDriverName) ?? '';
    final backendUrl = prefs.getString(_prefsBackendUrl) ?? '';

    if (driverId.isEmpty ||
        ambulanceId.isEmpty ||
        driverName.isEmpty ||
        backendUrl.isEmpty) {
      debugPrint('⚠️ [BG-SERVICE] Missing socket context, skipping emit');
      return;
    }

    if (_backgroundSocket == null || !_socketConnected) {
      await _connectBackgroundSocket({
        'backendUrl': backendUrl,
        'driverId': driverId,
        'ambulanceId': ambulanceId,
        'driverName': driverName,
        'ambulanceNumber': prefs.getString(_prefsAmbulanceNumber),
        'ambulanceTelephone': prefs.getString(_prefsAmbulanceTelephone),
      });
    }

    if (_backgroundSocket == null || !_socketConnected) {
      debugPrint('⚠️ [BG-SERVICE] Background socket still disconnected, skipping emit');
      return;
    }

    final payload = {
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'ambulanceId': ambulanceId,
      'driverName': driverName,
      'ambulanceNumber': prefs.getString(_prefsAmbulanceNumber),
      'telephone': prefs.getString(_prefsAmbulanceTelephone),
    };

    _backgroundSocket!.emit('updateLocation', payload);
    debugPrint('📤 [BG-SERVICE] Background location emitted: $payload');
  }

  static Future<void> _disconnectBackgroundSocket() async {
    try {
      _socketConnected = false;
      _backgroundSocket?.disconnect();
      _backgroundSocket?.dispose();
      _backgroundSocket = null;
    } catch (_) {}
  }
}

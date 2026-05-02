import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fleet_socket_service.dart';

/// Driver-side location streaming service.
///
/// This service now treats the backend as the source of truth for whether
/// tracking is allowed. It no longer auto-resumes old local sessions after
/// logout/login and it fully disconnects when tracking is stopped.
class FleetTrackingService {
  static final FleetTrackingService _instance =
      FleetTrackingService._internal();

  factory FleetTrackingService() => _instance;

  FleetTrackingService._internal();

  late FleetSocketService _socketService;

  Timer? _locationTimer;
  Timer? _reconnectTimer;
  Timer? _backgroundLocationPollingTimer;

  bool _isTracking = false;
  bool _isConnected = false;
  Position? _lastPosition;
  int _updateCount = 0;
  String? _lastBackgroundLocationJson;

  late String driverId;
  late String ambulanceId;
  late String driverName;
  String? ambulanceNumber;
  String? ambulanceTelephone;

  static const int _locationUpdateIntervalMs = 5000;
  static const int _reconnectIntervalMs = 10000;

  final List<Function(Position)> _onLocationUpdated = [];
  final List<Function()> _onConnected = [];
  final List<Function()> _onDisconnected = [];
  final List<Function(String)> _onError = [];

  Future<void> initialize({
    required String driverId,
    required String ambulanceId,
    required String driverName,
    required String backendUrl,
    String? ambulanceNumber,
    String? ambulanceTelephone,
  }) async {
    debugPrint(
      '[FleetTracking] initialize resetting runtime state for ambulance=$ambulanceId driver=$driverId',
    );

    _locationTimer?.cancel();
    _backgroundLocationPollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _locationTimer = null;
    _backgroundLocationPollingTimer = null;
    _reconnectTimer = null;

    if (_isConnected) {
      await _disconnectSocket();
    } else {
      _isConnected = false;
    }

    _isTracking = false;

    this.driverId = driverId;
    this.ambulanceId = ambulanceId;
    this.driverName = driverName;
    this.ambulanceNumber = ambulanceNumber;
    this.ambulanceTelephone = ambulanceTelephone;

    _socketService = FleetSocketService(backendUrl: backendUrl);
    _setupSocketListeners();
    debugPrint('[FleetTracking] initialized for $driverName / $ambulanceId');
  }

  Future<void> startTracking() async {
    debugPrint(
      '[FleetTracking] startTracking entry: isTracking=$_isTracking '
      'isConnected=$_isConnected ambulance=$ambulanceId driver=$driverId',
    );
    if (_isTracking) {
      if (_isConnected) {
        debugPrint('[FleetTracking] startTracking ignored, already active');
        return;
      }

      debugPrint(
        '[FleetTracking] startTracking recovering active tracker with disconnected socket',
      );
      try {
        debugPrint('[FleetTracking] checking location permissions for recovery');
        await _checkLocationPermissions();
        debugPrint('[FleetTracking] connecting socket for recovery...');
        await _socketService.connect();
        _isConnected = true;
        _notifyConnected();
        debugPrint('[FleetTracking] recovery socket connected, restarting timers');
        _startLocationUpdates();
        await _saveTrackingState(true);
        debugPrint('[FleetTracking] recovery startTracking completed successfully');
        return;
      } catch (error) {
        debugPrint('[FleetTracking] recovery startTracking failed: $error');
        _notifyError('Failed to recover tracking connection: $error');
        rethrow;
      }
    }

      try {
        debugPrint('[FleetTracking] checking location permissions...');
        await _checkLocationPermissions();
        debugPrint('[FleetTracking] permissions OK');

        if (!_isConnected) {
          debugPrint('[FleetTracking] socket not connected, calling connect()');
          await _socketService.connect();
          _isConnected = true;
          _notifyConnected();
          debugPrint('[FleetTracking] socket connect() completed');
        }

        _isTracking = true;
        await _saveTrackingState(true);
        _startLocationUpdates();
      debugPrint(
        '[FleetTracking] tracking started for ambulance=$ambulanceId driver=$driverId name=$driverName',
      );
    } catch (error) {
      debugPrint('[FleetTracking] startTracking failed: $error');
      _notifyError('Failed to start tracking: $error');
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    try {
      _locationTimer?.cancel();
      _locationTimer = null;
      _backgroundLocationPollingTimer?.cancel();
      _backgroundLocationPollingTimer = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _isTracking = false;
      await _saveTrackingState(false);
      await _disconnectSocket();
      debugPrint('[FleetTracking] tracking stopped for $ambulanceId');
    } catch (error) {
      debugPrint('[FleetTracking] stopTracking failed: $error');
      _notifyError('Failed to stop tracking: $error');
    }
  }

  Future<void> hardResetRuntime() async {
    debugPrint('[FleetTracking] hard reset requested');
    _locationTimer?.cancel();
    _locationTimer = null;
    _backgroundLocationPollingTimer?.cancel();
    _backgroundLocationPollingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      if (_isConnected) {
        await _disconnectSocket();
      }
    } catch (error) {
      debugPrint('[FleetTracking] hard reset disconnect warning: $error');
    } finally {
      _isTracking = false;
      _isConnected = false;
    }
  }

  Future<void> _disconnectSocket() async {
    try {
      debugPrint('[FleetTracking] disconnecting socket...');
      await _socketService.disconnect();
    } finally {
      _isConnected = false;
      _notifyDisconnected();
      debugPrint('[FleetTracking] socket disconnected');
    }
  }

  void _startLocationUpdates() {
    debugPrint('[FleetTracking] starting location update timers');
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(milliseconds: _locationUpdateIntervalMs),
      (_) => _updateLocation(),
    );

    _startBackgroundLocationPolling();
    _updateLocation();
  }

  void _startBackgroundLocationPolling() {
    _backgroundLocationPollingTimer?.cancel();
    _backgroundLocationPollingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final locationJson = prefs.getString('last_background_location');

          if (locationJson == null ||
              locationJson == _lastBackgroundLocationJson ||
              !_isConnected) {
            return;
          }

          _lastBackgroundLocationJson = locationJson;
          final locationData = jsonDecode(locationJson) as Map<String, dynamic>;
          final latitude = (locationData['latitude'] as num).toDouble();
          final longitude = (locationData['longitude'] as num).toDouble();
          sendLocation(latitude: latitude, longitude: longitude);
        } catch (error) {
          debugPrint('[FleetTracking] background poll failed: $error');
        }
      },
    );
  }

  Future<void> _updateLocation() async {
    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        forceAndroidLocationManager: false,
      );
      _lastPosition = currentPosition;

      if (!_isConnected) {
        debugPrint(
          '[FleetTracking] location captured but socket is disconnected for ambulance=$ambulanceId',
        );
        return;
      }

      debugPrint(
        '[FleetTracking] sending live location ambulance=$ambulanceId '
        'driver=$driverId lat=${currentPosition.latitude} '
        'lng=${currentPosition.longitude} accuracy=${currentPosition.accuracy}',
      );
        _socketService.sendLocation(
          driverId: driverId,
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          ambulanceId: ambulanceId,
          driverName: driverName,
          ambulanceNumber: ambulanceNumber,
          telephone: ambulanceTelephone,
        );

      _updateCount++;
      _notifyLocationUpdated(currentPosition);
    } on LocationServiceDisabledException {
      _notifyError('Location service is disabled');
    } catch (error) {
      debugPrint('[FleetTracking] location update failed: $error');
    }
  }

  Future<void> _checkLocationPermissions() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }
  }

  void _setupSocketListeners() {
    _socketService.onConnected(() {
      _isConnected = true;
      _notifyConnected();
    });

    _socketService.onDisconnected(() {
      _isConnected = false;
      _notifyDisconnected();
      _attemptReconnect();
    });

    _socketService.onError(_notifyError);
  }

  void _attemptReconnect() {
    debugPrint('[FleetTracking] scheduling reconnect loop');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(
      const Duration(milliseconds: _reconnectIntervalMs),
      (_) async {
        if (!_isTracking || _isConnected) {
          debugPrint(
            '[FleetTracking] reconnect tick skipped: isTracking=$_isTracking isConnected=$_isConnected',
          );
          return;
        }

        try {
          debugPrint('[FleetTracking] reconnect tick calling socket.connect()');
          await _socketService.connect();
          _isConnected = true;
          _notifyConnected();
          _reconnectTimer?.cancel();
          debugPrint('[FleetTracking] reconnect succeeded');
        } catch (error) {
          debugPrint('[FleetTracking] reconnect failed: $error');
        }
      },
    );
  }

  void sendLocation({
    required double latitude,
    required double longitude,
  }) {
    if (!_isConnected) {
      return;
    }

    try {
      debugPrint(
        '[FleetTracking] sending background/manual location ambulance=$ambulanceId '
        'driver=$driverId lat=$latitude lng=$longitude',
      );
        _socketService.sendLocation(
          driverId: driverId,
          latitude: latitude,
          longitude: longitude,
          ambulanceId: ambulanceId,
          driverName: driverName,
          ambulanceNumber: ambulanceNumber,
          telephone: ambulanceTelephone,
        );
      _updateCount++;
    } catch (error) {
      debugPrint('[FleetTracking] manual send failed: $error');
    }
  }

  Future<void> _saveTrackingState(bool isActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fleet_tracking_active', isActive);
    } catch (error) {
      debugPrint('[FleetTracking] failed to save state: $error');
    }
  }

  bool get isTracking => _isTracking;
  bool get isConnected => _isConnected;
  Position? get lastPosition => _lastPosition;
  int get updateCount => _updateCount;

  void onLocationUpdated(Function(Position) callback) {
    _onLocationUpdated.add(callback);
  }

  void onConnected(Function() callback) {
    _onConnected.add(callback);
  }

  void onDisconnected(Function() callback) {
    _onDisconnected.add(callback);
  }

  void onError(Function(String) callback) {
    _onError.add(callback);
  }

  void _notifyLocationUpdated(Position position) {
    for (final callback in _onLocationUpdated) {
      callback(position);
    }
  }

  void _notifyConnected() {
    for (final callback in _onConnected) {
      callback();
    }
  }

  void _notifyDisconnected() {
    for (final callback in _onDisconnected) {
      callback();
    }
  }

  void _notifyError(String error) {
    for (final callback in _onError) {
      callback(error);
    }
  }

  Future<void> dispose() async {
    _locationTimer?.cancel();
    _reconnectTimer?.cancel();
    _backgroundLocationPollingTimer?.cancel();
    _locationTimer = null;
    _reconnectTimer = null;
    _backgroundLocationPollingTimer = null;
    await _disconnectSocket();
    _isTracking = false;
  }
}

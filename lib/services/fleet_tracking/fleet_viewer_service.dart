/**
 * Fleet Viewer Service - Real-Time Fleet Tracking for Fleet Coordinators
 * Connects to backend Socket.IO to receive live driver location updates
 * Displays all drivers on an interactive map
 */

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'fleet_tracking_models.dart';

class FleetViewerService {
  final String backendUrl;
  late IO.Socket _socket;

  bool _connected = false;
  List<DriverLocation> _drivers = [];

  // Callbacks
  final List<Function()> _onConnected = [];
  final List<Function()> _onDisconnected = [];
  final List<Function(String)> _onError = [];
  final List<Function(List<DriverLocation>)> _onDriversUpdate = [];
  final List<Function(DriverLocation)> _onLocationUpdate = [];
  final List<Function(String)> _onDriverOffline = [];

  FleetViewerService({required this.backendUrl});

  /**
   * Connect to Socket.IO server
   */
  Future<void> connect() async {
    try {
      _socket = IO.io(
        backendUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionDelay(3000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(10)
            .build(),
      );

      _setupSocketListeners();
      _socket.connect();

      debugPrint('🔌 Fleet Viewer connecting to $backendUrl');
    } catch (error) {
      debugPrint('❌ Error connecting to Socket.IO: $error');
      _notifyError('Connection failed: $error');
      rethrow;
    }
  }

  /**
   * Setup Socket.IO event listeners
   * @private
   */
  void _setupSocketListeners() {
    _socket.onConnect((_) {
      _connected = true;
      debugPrint('✅ Fleet Viewer connected');
      _notifyConnected();

      // Request initial drivers data
      _requestInitialData();
    });

    _socket.onDisconnect((_) {
      _connected = false;
      debugPrint('❌ Fleet Viewer disconnected');
      _notifyDisconnected();
    });

    // Listen for all drivers update (broadcast from server)
    _socket.on('driversUpdate', (data) {
      _handleDriversUpdate(data);
    });

    // Listen for single driver location update
    _socket.on('locationUpdate', (data) {
      _handleLocationUpdate(data);
    });

    // Listen for driver offline notification
    _socket.on('driverOffline', (data) {
      _handleDriverOffline(data);
    });

    _socket.on('error', (data) {
      debugPrint('❌ Socket error: $data');
      _notifyError('Socket error: $data');
    });

    _socket.onConnectError((data) {
      debugPrint('❌ Connection error: $data');
      _notifyError('Connection error: $data');
    });
  }

  /**
   * Request initial drivers data via REST API
   * @private
   */
  Future<void> _requestInitialData() async {
    try {
      // Could fetch via REST endpoint, but Socket.IO will provide updates
      debugPrint('📡 Fleet Viewer ready for updates');
    } catch (error) {
      debugPrint('❌ Error requesting initial data: $error');
    }
  }

  /**
   * Handle drivers update event
   * @private
   */
  void _handleDriversUpdate(dynamic data) {
    try {
      if (data is Map && data['drivers'] is List) {
        final driversList = (data['drivers'] as List)
            .map((driver) => DriverLocation.fromJson(driver))
            .toList();

        _drivers = driversList;

        debugPrint(
          '📡 Received update for ${driversList.length} drivers',
        );

        _notifyDriversUpdate(driversList);
      }
    } catch (error) {
      debugPrint('❌ Error parsing drivers update: $error');
    }
  }

  /**
   * Handle single location update
   * @private
   */
  void _handleLocationUpdate(dynamic data) {
    try {
      final driver = DriverLocation.fromJson(data);

      // Update or add driver
      final index = _drivers.indexWhere((d) => d.driverId == driver.driverId);
      if (index >= 0) {
        _drivers[index] = driver;
      } else {
        _drivers.add(driver);
      }

      debugPrint('📍 Location update for driver: ${driver.driverId}');
      _notifyLocationUpdate(driver);
    } catch (error) {
      debugPrint('❌ Error parsing location update: $error');
    }
  }

  /**
   * Handle driver offline event
   * @private
   */
  void _handleDriverOffline(dynamic data) {
    try {
      final driverId = data['driverId'] ?? '';
      _drivers.removeWhere((d) => d.driverId == driverId);

      debugPrint('🔴 Driver went offline: $driverId');
      _notifyDriverOffline(driverId);
    } catch (error) {
      debugPrint('❌ Error handling driver offline: $error');
    }
  }

  /**
   * Disconnect from Socket.IO
   */
  Future<void> disconnect() async {
    _connected = false;
    _drivers.clear();
    _socket.disconnect();
    _socket.dispose();
    debugPrint('🔌 Fleet Viewer disconnected');
  }

  /**
   * Get all drivers
   */
  List<DriverLocation> get drivers => List.unmodifiable(_drivers);

  /**
   * Get driver count
   */
  int get driverCount => _drivers.length;

  /**
   * Get specific driver
   */
  DriverLocation? getDriver(String driverId) {
    try {
      return _drivers.firstWhere((d) => d.driverId == driverId);
    } catch (error) {
      return null;
    }
  }

  /**
   * Register listener for connection
   */
  void onConnected(Function() callback) {
    _onConnected.add(callback);
  }

  /**
   * Register listener for disconnection
   */
  void onDisconnected(Function() callback) {
    _onDisconnected.add(callback);
  }

  /**
   * Register listener for errors
   */
  void onError(Function(String) callback) {
    _onError.add(callback);
  }

  /**
   * Register listener for drivers update
   */
  void onDriversUpdate(Function(List<DriverLocation>) callback) {
    _onDriversUpdate.add(callback);
  }

  /**
   * Register listener for single location update
   */
  void onLocationUpdate(Function(DriverLocation) callback) {
    _onLocationUpdate.add(callback);
  }

  /**
   * Register listener for driver offline
   */
  void onDriverOffline(Function(String) callback) {
    _onDriverOffline.add(callback);
  }

  /**
   * Notify connected
   * @private
   */
  void _notifyConnected() {
    for (var callback in _onConnected) {
      callback();
    }
  }

  /**
   * Notify disconnected
   * @private
   */
  void _notifyDisconnected() {
    for (var callback in _onDisconnected) {
      callback();
    }
  }

  /**
   * Notify error
   * @private
   */
  void _notifyError(String error) {
    for (var callback in _onError) {
      callback(error);
    }
  }

  /**
   * Notify drivers update
   * @private
   */
  void _notifyDriversUpdate(List<DriverLocation> drivers) {
    for (var callback in _onDriversUpdate) {
      callback(drivers);
    }
  }

  /**
   * Notify single location update
   * @private
   */
  void _notifyLocationUpdate(DriverLocation driver) {
    for (var callback in _onLocationUpdate) {
      callback(driver);
    }
  }

  /**
   * Notify driver offline
   * @private
   */
  void _notifyDriverOffline(String driverId) {
    for (var callback in _onDriverOffline) {
      callback(driverId);
    }
  }

  /**
   * Check connection status
   */
  bool get isConnected => _connected;
}

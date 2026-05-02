/**
 * Fleet Socket Service - Socket.IO Communication
 * Handles WebSocket connection to backend for real-time location sharing
 */

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:async';

class FleetSocketService {
  final String backendUrl;
  late IO.Socket _socket;

  bool _connected = false;

  // Callbacks
  final List<Function()> _onConnected = [];
  final List<Function()> _onDisconnected = [];
  final List<Function(String)> _onError = [];
  final List<Function(dynamic)> _onDriversUpdate = [];

  FleetSocketService({required this.backendUrl});

  /**
   * Connect to Socket.IO server
   * First tests HTTP connectivity, then establishes Socket.IO connection
   */
  Future<void> connect() async {
    try {
      debugPrint('🔌 Socket.IO connecting to $backendUrl');
      debugPrint('   URL: $backendUrl');

      // First, verify HTTP connectivity to backend
      debugPrint('📡 Testing HTTP connectivity...');
      try {
        final healthUrl = '$backendUrl/health';
        debugPrint('   Testing: $healthUrl');

        // Use simple HTTP test
        // This will fail if backend is unreachable
        final response =
            await http.get(Uri.parse(healthUrl)).timeout(Duration(seconds: 5));

        if (response.statusCode == 200) {
          debugPrint('✅ HTTP connectivity OK (200 $healthUrl)');
        } else {
          debugPrint('⚠️ HTTP returned ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('⚠️ HTTP test failed: $e');
        debugPrint('   Backend may not be reachable at $backendUrl');
      }

      debugPrint('📡 Creating Socket.IO connection...');

      // Create socket - use simpler options
      _socket = IO.io(
        backendUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );

      debugPrint('✅ Socket object created');

      // Setup listeners BEFORE connecting
      _setupSocketListeners();
      debugPrint('✅ Listeners configured');

      // Use a completer with explicit connection tracking
      final connectionCompleter = Completer<void>();
      bool connectionEstablished = false;

      // Listen for successful connection
      final connectionListener = (_) {
        if (!connectionEstablished) {
          connectionEstablished = true;
          debugPrint('✅ onConnect callback fired!');
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete();
          }
        }
      };
      _socket.onConnect(connectionListener);

      // Timeout handler
      final timeoutTimer = Timer(Duration(seconds: 20), () {
        if (!connectionCompleter.isCompleted) {
          debugPrint('⏱️ Connection timeout (20 seconds)');
          debugPrint(
              '   Socket state: connected=${_socket.connected}, id=${_socket.id}');
          connectionCompleter.completeError(
            TimeoutException(
              'Socket.IO connection timeout after 20 seconds',
              Duration(seconds: 20),
            ),
          );
        }
      });

      // Status logging
      int checkNum = 0;
      final statusTimer = Timer.periodic(Duration(seconds: 1), (_) {
        checkNum++;
        debugPrint(
          '   [${checkNum}s] Socket: connected=${_socket.connected}, '
          'disconnected=${_socket.disconnected}, id=${_socket.id}',
        );
      });

      debugPrint('🚀 Initiating socket.connect()...');
      _socket.connect();

      // Wait for connection
      await connectionCompleter.future;

      // Cleanup timers
      timeoutTimer.cancel();
      statusTimer.cancel();

      debugPrint('✅ Socket.IO connection established: ${_socket.id}');
    } catch (error) {
      debugPrint('❌ Connection failed: $error');
      debugPrint(
        '   Final state: connected=${_socket.connected}, '
        'id=${_socket.id}',
      );

      _notifyError('Connection failed: $error');

      try {
        _socket.disconnect();
      } catch (e) {
        debugPrint('⚠️ Error during disconnect: $e');
      }

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
      debugPrint('✅ [SOCKET] Connected event fired');
      debugPrint('✅ [SOCKET] Socket ID: ${_socket.id}');
      _notifyConnected();
    });

    _socket.onDisconnect((_) {
      _connected = false;
      debugPrint('❌ [SOCKET] Disconnected event fired');
      _notifyDisconnected();
    });

    _socket.on('connectionAck', (data) {
      debugPrint('📌 [SOCKET] Connection acknowledged: $data');
    });

    _socket.on('driversUpdate', (data) {
      debugPrint('📡 [SOCKET] Received drivers update');
      _notifyDriversUpdate(data);
    });

    _socket.on('error', (data) {
      debugPrint('⚠️ [SOCKET] Socket error event: $data');
      _notifyError('Socket error: $data');
    });

    _socket.onConnectError((data) {
      debugPrint('⚠️ [SOCKET] Connection error event: $data');
      _notifyError('Connection error: $data');
    });

    _socket.onError((data) {
      debugPrint('⚠️ [SOCKET] Socket onError event: $data');
      _notifyError('Socket error: $data');
    });

    // Additional diagnostic listeners
    _socket.onReconnect((_) {
      debugPrint('🔄 [SOCKET] Reconnected');
      _connected = true;
      _notifyConnected();
    });

    _socket.onReconnectError((data) {
      debugPrint('⚠️ [SOCKET] Reconnection error: $data');
    });
  }

  /**
   * Send driver location to backend
   */
  void sendLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required String ambulanceId,
    required String driverName,
    String? ambulanceNumber,
    String? telephone,
  }) {
    if (!_connected) {
      debugPrint(
          '⚠️ [SOCKET] Not connected (_connected=$_connected), skipping location send');
      return;
    }

    try {
      debugPrint('📤 [SOCKET] Sending location for driver $driverId');
      debugPrint('   Coords: ($latitude, $longitude)');

      _socket.emit('updateLocation', {
        'driverId': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'ambulanceId': ambulanceId,
        'driverName': driverName,
        'ambulanceNumber': ambulanceNumber,
        'telephone': telephone,
      });

      debugPrint('✅ [SOCKET] Location emitted successfully');
    } catch (error) {
      debugPrint('❌ [SOCKET] Error sending location: $error');
    }
  }

  /**
   * Disconnect from Socket.IO
   */
  Future<void> disconnect() async {
    _connected = false;
    _socket.disconnect();
    _socket.dispose();
    debugPrint('🔌 Socket.IO disconnected');
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
  void onDriversUpdate(Function(dynamic) callback) {
    _onDriversUpdate.add(callback);
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
  void _notifyDriversUpdate(dynamic data) {
    for (var callback in _onDriversUpdate) {
      callback(data);
    }
  }

  /**
   * Check connection status
   */
  bool get isConnected => _connected;
}

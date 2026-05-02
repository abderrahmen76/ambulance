import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import 'api_client.dart';

class LocationRequestService {
  static final LocationRequestService _instance = LocationRequestService._internal();
  static const String _processedPrefix = 'processed_location_request_';
  static const Duration _dedupeTtl = Duration(minutes: 10);

  final ApiClient _apiClient = ApiClient();

  factory LocationRequestService() {
    return _instance;
  }

  LocationRequestService._internal();

  static LocationRequestService get instance => _instance;

  Future<void> ensureBackgroundReady() async {
    debugPrint('[LocationRequestService] ensureBackgroundReady start');
    try {
      await Firebase.initializeApp();
      debugPrint('[LocationRequestService] Firebase initialized in background context');
    } catch (_) {
      debugPrint('[LocationRequestService] Firebase already initialized');
    }

    try {
      Supabase.instance.client;
      debugPrint('[LocationRequestService] Supabase already initialized');
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.anonKey,
      );
      debugPrint('[LocationRequestService] Supabase initialized in background context');
    }
  }

  Future<void> handleLocationRequest(Map<String, dynamic> data) async {
    debugPrint('[LocationRequestService] handleLocationRequest called with data: $data');
    final requestId = _extractRequestId(data);
    final missionId = _extractMissionId(data);
    debugPrint(
        '[LocationRequestService] extracted identifiers: requestId=$requestId missionId=$missionId');

    if (requestId.isEmpty || missionId.isEmpty) {
      debugPrint(
          '[LocationRequestService] Skipping LOCATION_REQUEST with missing ids: $data');
      return;
    }

    if (await _alreadyProcessed(requestId)) {
      debugPrint(
          '[LocationRequestService] Duplicate LOCATION_REQUEST blocked for request $requestId');
      return;
    }

    final user = await _restoreCachedUser();
    debugPrint('[LocationRequestService] restored cached user: $user');
    if (user == null) {
      debugPrint(
          '[LocationRequestService] No cached user available, cannot answer request $requestId');
      return;
    }

    final ambulanceId = await _resolveAmbulanceIdForDriver(user['id']?.toString() ?? '');
    debugPrint('[LocationRequestService] resolved ambulanceId: $ambulanceId');
    if (ambulanceId == null || ambulanceId.isEmpty) {
      debugPrint(
          '[LocationRequestService] No ambulance found for driver ${user['id']}');
      return;
    }

    final permissionGranted = await _ensureLocationPermission();
    debugPrint('[LocationRequestService] location permission result: $permissionGranted');
    if (!permissionGranted) {
      debugPrint(
          '[LocationRequestService] Location permission denied for request $requestId');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
    debugPrint('[LocationRequestService] current position acquired: '
        'lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}');

    final payload = {
      'request_id': requestId,
      'mission_id': int.tryParse(missionId) ?? missionId,
      'ambulance_id': ambulanceId,
      'driver_user_id': user['id'],
      'provider_tenant_id': user['tenantId'] ?? user['tenant_id'],
      'latitude': position.latitude,
      'longitude': position.longitude,
      'client_sent_at': DateTime.now().toIso8601String(),
    };
    debugPrint('[LocationRequestService] snapshot payload: $payload');

    await _apiClient.post(
      SupabaseConfig.ambulanceLocationSnapshotsTable,
      payload,
    );

    await _markProcessed(requestId);
    debugPrint(
        '[LocationRequestService] Submitted one-shot location snapshot for request $requestId');
  }

  String _extractRequestId(Map<String, dynamic> data) {
    final direct = data['request_id']?.toString() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final nested = data['data'];
    if (nested is String && nested.isNotEmpty) {
      try {
        final parsed = jsonDecode(nested) as Map<String, dynamic>;
        return parsed['request_id']?.toString() ?? '';
      } catch (_) {
        return '';
      }
    }

    return '';
  }

  String _extractMissionId(Map<String, dynamic> data) {
    final direct = data['mission_id']?.toString() ?? data['missionId']?.toString() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final nested = data['data'];
    if (nested is String && nested.isNotEmpty) {
      try {
        final parsed = jsonDecode(nested) as Map<String, dynamic>;
        return parsed['mission_id']?.toString() ?? parsed['missionId']?.toString() ?? '';
      } catch (_) {
        return '';
      }
    }

    return '';
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[LocationRequestService] location services enabled: $serviceEnabled');
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    debugPrint('[LocationRequestService] initial permission: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[LocationRequestService] permission after request: $permission');
    }

    return permission == LocationPermission.always
        || permission == LocationPermission.whileInUse;
  }

  Future<Map<String, dynamic>?> _restoreCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('cached_user');
    debugPrint('[LocationRequestService] raw cached_user present: ${rawUser != null && rawUser.isNotEmpty}');
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawUser) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveAmbulanceIdForDriver(String driverUserId) async {
    debugPrint('[LocationRequestService] resolving ambulance for driver: $driverUserId');
    if (driverUserId.isEmpty) {
      return null;
    }

    final ambulances = await _apiClient.get(
      SupabaseConfig.ambulancesTable,
      filters: {
        'current_driver_id': 'eq.$driverUserId',
      },
      limit: 1,
    );
    debugPrint('[LocationRequestService] ambulance lookup response: $ambulances');

    if (ambulances.isEmpty) {
      return null;
    }

    return ambulances.first['id']?.toString();
  }

  Future<bool> _alreadyProcessed(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedAt = prefs.getString('$_processedPrefix$requestId');
    debugPrint(
        '[LocationRequestService] dedupe lookup: requestId=$requestId storedAt=$storedAt');
    if (storedAt == null || storedAt.isEmpty) {
      return false;
    }

    final timestamp = DateTime.tryParse(storedAt);
    if (timestamp == null) {
      return false;
    }

    return DateTime.now().difference(timestamp) < _dedupeTtl;
  }

  Future<void> _markProcessed(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_processedPrefix$requestId',
      DateTime.now().toIso8601String(),
    );
    debugPrint('[LocationRequestService] request marked processed: $requestId');
  }
}

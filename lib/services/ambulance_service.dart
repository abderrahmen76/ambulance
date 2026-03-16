import '../config/constants.dart';
import '../models/ambulance_model.dart';
import 'api_client.dart';

/// Ambulance Service
/// Handles fetching ambulance data for the current driver
/// Optimized for minimal queries and fast response
class AmbulanceService {
  static final AmbulanceService _instance = AmbulanceService._internal();
  final ApiClient _apiClient = ApiClient();

  // Cache ambulance data (improves performance on home screen)
  Ambulance? _cachedAmbulance;
  String? _cachedUserId;

  factory AmbulanceService() {
    return _instance;
  }

  AmbulanceService._internal();

  /// Get ambulance assigned to current driver
  /// Returns Ambulance if found, null if no ambulance assigned
  Future<Ambulance?> getAmbulanceForDriver(String driverId) async {
    try {
      // Check cache first (improves performance)
      if (_cachedAmbulance != null && _cachedUserId == driverId) {
        return _cachedAmbulance;
      }

      // Fetch ambulance where current_driver_id = driverId
      final ambulances = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {
          'current_driver_id': 'eq.$driverId',
        },
      );

      if (ambulances.isEmpty) {
        _cachedAmbulance = null;
        _cachedUserId = driverId;
        return null;
      }

      // Return the first ambulance (typically only one per driver)
      final ambulance = Ambulance.fromJson(ambulances.first);
      _cachedAmbulance = ambulance;
      _cachedUserId = driverId;
      return ambulance;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all ambulances (admin view)
  Future<List<Ambulance>> getAllAmbulances() async {
    try {
      final ambulances = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
      );

      return ambulances.map((json) => Ambulance.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update ambulance current location/status
  Future<void> updateAmbulanceStatus({
    required String ambulanceId,
    required String? currentDestination,
    required double? kilometrage,
  }) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId',
        {
          if (currentDestination != null)
            'current_destination': currentDestination,
          if (kilometrage != null) 'kilometrage': kilometrage,
        },
      );

      // Invalidate cache
      _cachedAmbulance = null;
      _cachedUserId = null;
    } catch (e) {
      rethrow;
    }
  }

  /// Clear cache (for testing or when driver changes)
  void clearCache() {
    _cachedAmbulance = null;
    _cachedUserId = null;
  }
}

import '../config/constants.dart';
import '../models/maintenance_record_model.dart';
import 'api_client.dart';

/// Maintenance Service
/// Handles fetching maintenance record data
class MaintenanceService {
  static final MaintenanceService _instance = MaintenanceService._internal();
  final ApiClient _apiClient = ApiClient();

  factory MaintenanceService() {
    return _instance;
  }

  MaintenanceService._internal();

  /// Get maintenance records for ambulance
  Future<List<MaintenanceRecord>> getMaintenanceRecords(
    String ambulanceId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final records = await _apiClient.get(
        SupabaseConfig.maintenanceRecordsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
        },
        orderBy: 'date.desc',
        limit: limit,
        offset: offset,
      );

      return records.map((json) => MaintenanceRecord.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get maintenance record by ID
  Future<MaintenanceRecord?> getMaintenanceRecord(String recordId) async {
    try {
      final records = await _apiClient.get(
        SupabaseConfig.maintenanceRecordsTable,
        filters: {
          'id': 'eq.$recordId',
        },
      );

      if (records.isEmpty) {
        return null;
      }

      return MaintenanceRecord.fromJson(records.first);
    } catch (e) {
      rethrow;
    }
  }

  /// Add new maintenance record with form data
  Future<void> addMaintenanceRecord(
      Map<String, dynamic> maintenanceData) async {
    try {
      print(
          '[MaintenanceService] addMaintenanceRecord() called with data: $maintenanceData');

      // Extract kilometrage for later UPDATE (workaround for column-level permissions)
      final kilometrage = maintenanceData['kilometrage'];
      final ambulanceId = maintenanceData['ambulance_id'];

      // ⚠️ WORKAROUND: Remove kilometrage from INSERT (column permission issue)
      // We'll UPDATE it separately after the record is created
      maintenanceData.remove('kilometrage');

      print(
          '[MaintenanceService] 🔍 REMOVED kilometrage from INSERT, will UPDATE separately');

      // Step 1: POST maintenance record WITHOUT kilometrage (this works)
      final response = await _apiClient.post(
        SupabaseConfig.maintenanceRecordsTable,
        maintenanceData,
      );

      print(
          '[MaintenanceService] addMaintenanceRecord() POST response: $response');

      // Step 2: Now UPDATE the same record to add kilometrage (UPDATE has different permissions)
      if (kilometrage != null && response.isNotEmpty) {
        try {
          final recordId = response['id'];
          print(
              '[MaintenanceService] 🔄 UPDATING record $recordId with kilometrage: $kilometrage');

          final patchEndpoint =
              '${SupabaseConfig.maintenanceRecordsTable}?id=eq.$recordId';
          await _apiClient.patch(
            patchEndpoint,
            {'kilometrage': kilometrage},
          );

          print(
              '[MaintenanceService] ✅ Updated maintenance record $recordId kilometrage to $kilometrage');
        } catch (e) {
          print(
              '[MaintenanceService] Warning: Failed to update kilometrage: $e');
          // Don't rethrow - record was already created
        }
      }

      // Step 3: Update ambulance kilometrage if provided
      if (kilometrage != null && ambulanceId != null) {
        try {
          final endpoint =
              '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId';
          await _apiClient.patch(
            endpoint,
            {'kilometrage': kilometrage},
          );
          print(
              '[MaintenanceService] Updated ambulance $ambulanceId kilometrage to $kilometrage');
        } catch (e) {
          print(
              '[MaintenanceService] Warning: Failed to update ambulance kilometrage: $e');
          // Don't rethrow - maintenance record was already added
        }
      }
    } catch (e) {
      print('[MaintenanceService] addMaintenanceRecord() ERROR: $e');
      rethrow;
    }
  }

  /// Add new maintenance record (legacy method with named parameters)
  Future<void> addMaintenanceRecordLegacy({
    required String ambulanceId,
    required String maintenanceType,
    required double cost,
    required String mechanicName,
    required String description,
  }) async {
    try {
      await _apiClient.post(SupabaseConfig.maintenanceRecordsTable, {
        'ambulance_id': ambulanceId,
        'maintenance_type': maintenanceType,
        'price_per_piece': cost,
        'mechanic_name': mechanicName,
        'description': description,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get upcoming maintenance based on kilometrage
  Future<List<Map<String, dynamic>>> getUpcomingMaintenance(
    String ambulanceId,
    double currentKilometrage,
  ) async {
    try {
      // Fetch maintenance types and their schedules
      // This would typically come from a maintenance_schedule table
      final maintenanceSchedules = await _apiClient.get(
        'maintenance_schedules',
        filters: {
          'is_active': 'eq.true',
        },
      );

      final upcomingList = <Map<String, dynamic>>[];

      for (final schedule in maintenanceSchedules) {
        final intervalKm = schedule['interval_km'] ?? 0;
        final nextServiceKm = currentKilometrage + intervalKm;

        // If service is due within next 1000km, add to upcoming
        if (nextServiceKm - currentKilometrage <= 1000) {
          upcomingList.add({
            'type': schedule['maintenance_type'],
            'dueAtKm': nextServiceKm,
            'urgency': nextServiceKm - currentKilometrage <= 100
                ? 'urgent'
                : nextServiceKm - currentKilometrage <= 500
                    ? 'soon'
                    : 'normal',
          });
        }
      }

      return upcomingList;
    } catch (e) {
      rethrow;
    }
  }
}

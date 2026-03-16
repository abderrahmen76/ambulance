import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/mission_model.dart';
import 'api_client.dart';

/// Mission Service
/// Handles fetching mission data for the driver
class MissionService {
  static final MissionService _instance = MissionService._internal();
  final ApiClient _apiClient = ApiClient();

  factory MissionService() {
    return _instance;
  }

  MissionService._internal();

  /// Get available missions (not yet assigned)
  Future<List<Mission>> getAvailableMissions() async {
    try {
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'status': 'eq.pending',
        },
      );

      return missions.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get active missions for current driver
  Future<List<Mission>> getActiveMissions(String ambulanceId) async {
    try {
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
          'status': 'eq.active',
        },
      );

      return missions.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all missions for ambulance
  Future<List<Mission>> getMissionsForAmbulance(String ambulanceId) async {
    try {
      debugPrint('[MissionService] Fetching all missions for ambulance: $ambulanceId');
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
        },
      );

      debugPrint('[MissionService] Fetched ${missions.length} missions');
      return missions.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MissionService] ERROR fetching missions: $e');
      rethrow;
    }
  }

  /// Accept a mission with driver name
  Future<void> acceptMission(
    String missionId,
    String ambulanceId,
    String driverName,
  ) async {
    try {
      print('[MissionService] Accepting mission $missionId');
      print('[MissionService] Driver: $driverName');
      print('[MissionService] Ambulance: $ambulanceId');
      
      // Format start_time as HH:MM:SS for time type column
      final now = DateTime.now();
      final startTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {
          'status': 'active',
          'ambulance_id': ambulanceId,
          'driver_name': driverName,
          'start_time': startTime,
        },
      );
      
      print('[MissionService] Mission accepted successfully');
    } catch (e) {
      print('[MissionService] ERROR accepting mission: ${e.toString()}');
      rethrow;
    }
  }

  /// Update mission status
  Future<void> updateMissionStatus(String missionId, String status) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {'status': status},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update a specific mission field
  Future<void> updateMissionField(String missionId, String fieldName, dynamic value) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {fieldName: value},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new pending mission
  Future<Mission> createMission({
    required String fromLocation,
    required String toLocation,
    required String priority,
    String? patientFirstName,
    String? patientLastName,
    String? patientPhone,
    String? infirmierName,
    String? missionPrice,
    String? notes,
    String? missionDate,
  }) async {
    try {
      // Generate mission number
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';
      final randomPart = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
      final missionNumber = 'MISS-$timestamp-$randomPart';

      // Use current time if not provided
      final finalMissionDate = missionDate ?? now.toIso8601String();

      final missionData = {
        'mission_number': missionNumber,
        'mission_date': finalMissionDate,
        'from_location': fromLocation,
        'to_location': toLocation,
        'priority': priority,
        'status': 'pending',
        'patient_first_name': patientFirstName,
        'patient_last_name': patientLastName,
        'patient_phone': patientPhone,
        'infirmier_name': infirmierName,
        'mission_price': missionPrice,
        'notes': notes,
      };

      final response = await _apiClient.post(
        SupabaseConfig.missionsTable,
        missionData,
      );

      debugPrint('[MissionService] Mission created: $missionNumber');
      return Mission.fromJson(response);
    } catch (e) {
      debugPrint('[MissionService] ERROR creating mission: $e');
      rethrow;
    }
  }
}

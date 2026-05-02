import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import '../config/constants.dart';
import '../models/mission_model.dart';
import 'api_client.dart';
import 'jwt_helper.dart';
import 'mission_private_service.dart';
import 'session_security_service.dart';

/// Mission Service
/// Handles fetching mission data for the driver
class MissionService {
  static final MissionService _instance = MissionService._internal();
  final ApiClient _apiClient = ApiClient();
  final MissionPrivateService _missionPrivateService = MissionPrivateService();
  final SessionSecurityService _sessionSecurityService =
      SessionSecurityService();

  // Track HTTP requests for deduplication
  final Map<String, DateTime> _notificationRequests = {};
  static const int _REQUEST_DEDUPE_WINDOW_MS = 5000; // 5 second window

  factory MissionService() {
    return _instance;
  }

  MissionService._internal();

  Map<String, String> _buildFunctionHeaders() {
    throw UnimplementedError(
      'Use _buildFunctionHeadersAsync for secure mission function calls.',
    );
  }

  Future<Map<String, String>> _buildFunctionHeadersAsync() {
    return _sessionSecurityService.buildFunctionHeaders();
  }

  Mission _mergeMissionWithPrivatePayload(
    Mission mission,
    Map<String, dynamic> payload,
  ) {
    final contact = payload['contact'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['contact'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final medical = payload['medical'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['medical'] as Map<String, dynamic>)
        : <String, dynamic>{};

    if (contact.isEmpty && medical.isEmpty) {
      return mission;
    }

    final mergedJson = mission.toJson();

    if (contact.isNotEmpty) {
      mergedJson['patient_name'] =
          contact['patient_name'] ?? mergedJson['patient_name'];
      mergedJson['patient_first_name'] =
          contact['patient_first_name'] ?? mergedJson['patient_first_name'];
      mergedJson['patient_last_name'] =
          contact['patient_last_name'] ?? mergedJson['patient_last_name'];
      mergedJson['patient_phone'] =
          contact['patient_phone'] ?? mergedJson['patient_phone'];
      mergedJson['patient_age'] =
          contact['patient_age'] ?? mergedJson['patient_age'];
      mergedJson['pickup_address'] =
          contact['pickup_address'] ?? mergedJson['pickup_address'];
      mergedJson['destination_address'] =
          contact['destination_address'] ?? mergedJson['destination_address'];
      mergedJson['pickup_lat'] = contact['pickup_lat'] ?? mergedJson['pickup_lat'];
      mergedJson['pickup_lng'] = contact['pickup_lng'] ?? mergedJson['pickup_lng'];
      mergedJson['destination_lat'] =
          contact['destination_lat'] ?? mergedJson['destination_lat'];
      mergedJson['destination_lng'] =
          contact['destination_lng'] ?? mergedJson['destination_lng'];
    }

    if (medical.isNotEmpty) {
      mergedJson['report_type'] = medical['report_type'] ?? mergedJson['report_type'];
      mergedJson['fractures_injuries'] =
          medical['fractures_injuries'] ?? mergedJson['fractures_injuries'];
      mergedJson['report_filled_at'] =
          medical['report_filled_at'] ?? mergedJson['report_filled_at'];
      mergedJson['medical_history'] =
          medical['medical_history'] ?? mergedJson['medical_history'];
      mergedJson['vital_signs'] = medical['vital_signs'] ?? mergedJson['vital_signs'];
      mergedJson['patient_needs'] =
          medical['patient_needs'] ?? mergedJson['patient_needs'];
      mergedJson['notes'] = medical['clinical_notes'] ?? mergedJson['notes'];
    }

    return Mission.fromJson(mergedJson);
  }

  Future<List<Mission>> _buildMissionListWithPrivateData(
    List<dynamic> missionRows,
  ) async {
    final enrichedMissions = await _attachClinicNames(missionRows);
    final missions = enrichedMissions.map((json) => Mission.fromJson(json)).toList();

    if (missions.isEmpty) {
      return missions;
    }

    try {
      final privateByMissionId = await _missionPrivateService.getManyMissionPrivateData(
        missions.map((mission) => mission.id),
      );

      return missions
          .map(
            (mission) => _mergeMissionWithPrivatePayload(
              mission,
              privateByMissionId[mission.id] ?? const <String, dynamic>{},
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[MissionService] Warning: private mission payload merge failed, falling back to base mission rows: $e',
      );
      return missions;
    }
  }

  Future<String?> _getCurrentTenantId() async {
    try {
      return await JWTHelper.getTenantId();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getMissionReservationContext(
      String missionId) async {
    final missions = await _apiClient.get(
      SupabaseConfig.missionsTable,
      filters: {
        'id': 'eq.$missionId',
      },
      limit: 1,
    );

    if (missions.isEmpty) {
      return null;
    }

    return missions.first as Map<String, dynamic>;
  }

  String _formatTimeOfDay(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  Future<void> _syncAmbulanceReservation({
    required String ambulanceId,
    required String missionId,
    required bool reserve,
  }) async {
    final payload = <String, dynamic>{
      'status': reserve ? 'busy' : 'available',
      'current_mission_id': reserve ? missionId : null,
    };

    print('[MissionService] 🚑 Syncing ambulance reservation');
    print('   ambulanceId: $ambulanceId');
    print('   missionId: $missionId');
    print('   reserve: $reserve');
    print('   ambulancePayload: $payload');

    await _apiClient.patch(
      '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId',
      payload,
    );
  }

  Future<List<String>> _getLinkedClinicTenantIds(String providerTenantId) async {
    try {
      final rows = await _apiClient.get(
        '/rest/v1/clinic_providers',
        filters: {
          'provider_tenant_id': 'eq.$providerTenantId',
        },
        limit: 200,
      );

      debugPrint(
          '[MissionService] Loaded ${rows.length} clinic-provider link(s) for provider tenant $providerTenantId');

      final clinicIds = rows
          .map((row) => row['clinic_tenant_id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      debugPrint(
          '[MissionService] Linked clinic tenant ids for provider $providerTenantId: $clinicIds');

      return clinicIds;
    } catch (e) {
      debugPrint(
          '[MissionService] Warning: could not load linked clinics for provider $providerTenantId: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getLinkedClinicsForCurrentProvider() async {
    try {
      await _sessionSecurityService.ensureFreshSession();
      await _sessionSecurityService.assertCurrentDeviceSessionActive();

      final response = await Supabase.instance.client.functions.invoke(
        'secure_reference_data',
        headers: await _buildFunctionHeadersAsync(),
        body: {
          'action': 'list_clinics',
        },
      );

      final payload = Map<String, dynamic>.from(
        response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
      );
      final rows = List<Map<String, dynamic>>.from(
        (payload['items'] as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map)),
      );

      final clinics = rows
          .map((row) {
            final tenantId = row['tenant_id']?.toString() ?? '';
            final tenantName = row['name']?.toString().trim() ?? tenantId;
            return {
              'tenant_id': tenantId,
              'name': tenantName.isEmpty ? tenantId : tenantName,
            };
          })
          .where((clinic) => (clinic['tenant_id'] ?? '').isNotEmpty)
          .toList()
        ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      debugPrint(
        '[MissionService] Loaded ${clinics.length} clinic tenant(s) directly from tenants table',
      );
      return clinics;
    } catch (e) {
      debugPrint(
        '[MissionService] getLinkedClinicsForCurrentProvider fallback warning: $e',
      );
      return [];
    }
  }

  Future<void> sendTechnicalSheetToClinic({
    required Mission mission,
    required String clinicTenantId,
    required String clinicName,
  }) async {
    await _sessionSecurityService.ensureFreshSession();
    await _sessionSecurityService.assertCurrentDeviceSessionActive(
      forceRefresh: true,
    );

    final providerTenantId = await _getCurrentTenantId();
    final latestMission = await getMissionById(mission.id);
    final mergedRequirements = <String, dynamic>{
      ...?latestMission?.requirements,
      ...?mission.requirements,
      'technicalSheetRecipientClinicId': clinicTenantId,
      'technicalSheetRecipientClinicName': clinicName,
      'technicalSheetSentAt': DateTime.now().toIso8601String(),
      'technicalSheetSentByProviderTenantId': providerTenantId,
      'technicalSheetShared': true,
    };

    await updateMissionField(
      mission.id,
      'requirements',
      mergedRequirements,
    );
  }

  Future<List<Map<String, dynamic>>> _attachClinicNames(
      List<dynamic> missionRows) async {
    final typedRows = missionRows
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final clinicTenantIds = typedRows
        .map((row) => row['clinic_tenant_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    debugPrint(
        '[MissionService] _attachClinicNames: mission_count=${typedRows.length}');
    debugPrint(
        '[MissionService] _attachClinicNames: clinic_tenant_ids=$clinicTenantIds');

    if (clinicTenantIds.isEmpty) {
      debugPrint(
          '[MissionService] _attachClinicNames: no clinic tenant ids found');
      return typedRows;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_reference_data',
        headers: await _buildFunctionHeadersAsync(),
        body: {
          'action': 'get_tenant_names',
          'tenant_ids': clinicTenantIds,
        },
      );

      final payload = Map<String, dynamic>.from(
        response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
      );
      final clinicRows = List<Map<String, dynamic>>.from(
        (payload['items'] as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map)),
      );

      final clinicNameById = <String, String>{};
      for (final row in clinicRows) {
        final tenantId = row['tenant_id']?.toString() ?? '';
        final tenantName = row['name']?.toString().trim() ?? '';
        if (tenantId.isNotEmpty && tenantName.isNotEmpty) {
          clinicNameById[tenantId] = tenantName;
        }
      }

      return typedRows.map((row) {
        final clinicTenantId = row['clinic_tenant_id']?.toString() ?? '';
        if (clinicTenantId.isEmpty) {
          return row;
        }

        return {
          ...row,
          'clinic_name': clinicNameById[clinicTenantId] ?? row['clinic_name'],
        };
      }).toList();
    } catch (secureLookupError) {
      debugPrint(
          '[MissionService] Warning: secure clinic lookup failed: $secureLookupError');
    }

      try {
          final clinicRows = await _apiClient.get(
            '/rest/v1/tenants',
            filters: {
            'id': 'in.(${clinicTenantIds.join(',')})',
          },
          limit: clinicTenantIds.length,
        );

        debugPrint('[MissionService] apiClient tenant rows=$clinicRows');

        final clinicNameById = <String, String>{};
        for (final row in clinicRows) {
          final tenantId = row['id']?.toString() ?? '';
          final tenantName = row['name']?.toString().trim() ?? '';
          if (tenantId.isNotEmpty && tenantName.isNotEmpty) {
            clinicNameById[tenantId] = tenantName;
            debugPrint(
                '[MissionService] apiClient mapped: $tenantId -> $tenantName');
          }
        }

        final enrichedRows = typedRows.map((row) {
          final clinicTenantId = row['clinic_tenant_id']?.toString() ?? '';
          if (clinicTenantId.isEmpty) {
            return row;
          }

        return {
            ...row,
            'clinic_name': clinicNameById[clinicTenantId] ?? row['clinic_name'],
            };
          }).toList();

        for (final row in enrichedRows) {
          final missionId = row['id']?.toString() ?? '';
          final clinicTenantId = row['clinic_tenant_id']?.toString() ?? '';
          if (clinicTenantId.isNotEmpty) {
            debugPrint(
                '[MissionService] apiClient enriched mission=$missionId clinic_tenant_id=$clinicTenantId clinic_name=${row['clinic_name']}');
          }
        }

        return enrichedRows;
        } catch (e) {
        debugPrint('[MissionService] Warning: REST clinic lookup failed: $e');
        }

        try {
        final supabase = Supabase.instance.client;
        final clinicRows = await supabase
            .from('tenants')
              .select('id,name')
              .inFilter('id', clinicTenantIds);

          debugPrint('[MissionService] supabase tenant rows=$clinicRows');

          final clinicNameById = <String, String>{};
          for (final row in clinicRows) {
            final tenantId = row['id']?.toString() ?? '';
            final tenantName = row['name']?.toString().trim() ?? '';
            if (tenantId.isNotEmpty && tenantName.isNotEmpty) {
              clinicNameById[tenantId] = tenantName;
              debugPrint(
                  '[MissionService] supabase mapped: $tenantId -> $tenantName');
            }
          }

          final enrichedRows = typedRows.map((row) {
            final clinicTenantId = row['clinic_tenant_id']?.toString() ?? '';
            if (clinicTenantId.isEmpty) {
              return row;
            }

          return {
              ...row,
              'clinic_name': clinicNameById[clinicTenantId] ?? row['clinic_name'],
            };
          }).toList();

          for (final row in enrichedRows) {
            final missionId = row['id']?.toString() ?? '';
            final clinicTenantId = row['clinic_tenant_id']?.toString() ?? '';
            if (clinicTenantId.isNotEmpty) {
              debugPrint(
                  '[MissionService] supabase enriched mission=$missionId clinic_tenant_id=$clinicTenantId clinic_name=${row['clinic_name']}');
            }
          }

          return enrichedRows;
        } catch (fallbackError) {
          debugPrint(
              '[MissionService] Warning: Supabase clinic lookup failed: $fallbackError');
        return typedRows;
      }
    }

  /// Get available missions (not yet assigned)
  Future<List<Mission>> getAvailableMissions(String ambulanceId) async {
    try {
      final tenantId = await _getCurrentTenantId();
      final filters = <String, dynamic>{
        'status': 'in.(pending,requested)',
      };

      if (tenantId != null && tenantId.isNotEmpty) {
        debugPrint(
            '[MissionService] Building available missions scope for provider tenant $tenantId');
        final orParts = <String>[
          'broadcast_ambulance_ids.cs.{$ambulanceId}',
          'assigned_ambulance_id.eq.$ambulanceId',
          'ambulance_id.eq.$ambulanceId',
          'tenant_id.eq.$tenantId',
          'assigned_company_id.eq.$tenantId',
          'selected_provider_tenant_id.eq.$tenantId',
          'broadcast_provider_ids.cs.{$tenantId}',
        ];

        filters['or'] = '(${orParts.join(',')})';
        debugPrint(
            '[MissionService] Available missions OR filter for tenant $tenantId: ${filters['or']}');
      } else {
        debugPrint(
            '[MissionService] No provider tenant id found while loading available missions');
        filters['or'] =
            '(broadcast_ambulance_ids.cs.{$ambulanceId},assigned_ambulance_id.eq.$ambulanceId,ambulance_id.eq.$ambulanceId)';
      }

      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: filters,
        orderBy: 'mission_date.desc',
        limit: 100,
      );

      return _buildMissionListWithPrivateData(missions);
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
          'or':
              '(ambulance_id.eq.$ambulanceId,assigned_ambulance_id.eq.$ambulanceId)',
          'status': 'eq.active',
        },
        orderBy: 'mission_date.desc',
        limit: 100,
      );

      return _buildMissionListWithPrivateData(missions);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all missions for ambulance
  Future<List<Mission>> getMissionsForAmbulance(String ambulanceId) async {
    try {
      debugPrint(
          '[MissionService] Fetching all missions for ambulance: $ambulanceId');
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'or':
              '(ambulance_id.eq.$ambulanceId,assigned_ambulance_id.eq.$ambulanceId)',
        },
        orderBy: 'mission_date.desc',
        limit: 200,
      );

      debugPrint('[MissionService] Fetched ${missions.length} missions');
      return _buildMissionListWithPrivateData(missions);
    } catch (e) {
      debugPrint('[MissionService] ERROR fetching missions: $e');
      rethrow;
    }
  }

  /// Get a single mission by ID
  Future<Mission?> getMissionById(String missionId) async {
    try {
      debugPrint('[MissionService] Fetching mission: $missionId');
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'id': 'eq.$missionId',
        },
      );

      if (missions.isNotEmpty) {
        debugPrint('[MissionService] Mission found');
        final mission = Mission.fromJson(missions.first);
        try {
          final privatePayload =
              await _missionPrivateService.getMissionPrivateData(missionId);
          return _mergeMissionWithPrivatePayload(mission, privatePayload);
        } catch (e) {
          debugPrint(
            '[MissionService] Warning: could not merge private mission payload for mission $missionId: $e',
          );
          return mission;
        }
      }
      debugPrint('[MissionService] Mission not found');
      return null;
    } catch (e) {
      debugPrint('[MissionService] ERROR fetching mission: $e');
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
      print('═══════════════════════════════════════════════════');
      print('[MissionService] ACCEPTING MISSION - STEP BY STEP');
      print('═══════════════════════════════════════════════════');
      print('[MissionService] 1️⃣ Parameters received:');
      print('   - Mission ID: $missionId (length: ${missionId.length})');
      print('   - Ambulance ID: $ambulanceId (length: ${ambulanceId.length})');
      print('   - Driver Name: $driverName');

      // Validate parameters
      if (missionId.isEmpty) {
        throw Exception('Mission ID cannot be empty');
      }
      if (ambulanceId.isEmpty) {
        throw Exception('Ambulance ID cannot be empty');
      }
      if (driverName.isEmpty) {
        throw Exception('Driver name cannot be empty');
      }

      // Format start_time as HH:MM:SS for time type column
      final now = DateTime.now();
      final startTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final tenantId = await _getCurrentTenantId();
      print('[MissionService] 2️⃣ Start time formatted: $startTime');
      print('[MissionService] 2️⃣ Provider tenant id resolved: $tenantId');

      final updatePayload = <String, dynamic>{
        'status': 'active',
        'ambulance_id': ambulanceId,
        'assigned_ambulance_id': ambulanceId,
        'driver_name': driverName,
        'dispatch_phase': 'accepted',
        'accepted_at': now.toIso8601String(),
        'start_time': startTime,
      };

      if (tenantId != null && tenantId.isNotEmpty) {
        updatePayload['assigned_company_id'] = tenantId;
        updatePayload['selected_provider_tenant_id'] = tenantId;
      }

      print('[MissionService] 3️⃣ Update payload:');
      print('   $updatePayload');

      final endpoint = '${SupabaseConfig.missionsTable}?id=eq.$missionId';
      print('[MissionService] 4️⃣ Calling PATCH endpoint: $endpoint');

        final response = await _apiClient.patch(endpoint, updatePayload);

      print('[MissionService] 5️⃣ PATCH response received:');
      print('   Type: ${response.runtimeType}');
      print('   Content: $response');

      // Verify the update - fetch mission to confirm status changed
      print('[MissionService] 5️⃣ VERIFICATION - Fetching updated mission...');
      final missions = await _apiClient.get(
        SupabaseConfig.missionsTable,
        filters: {
          'id': 'eq.$missionId',
        },
      );

      if (missions.isEmpty) {
        throw Exception('Mission not found after update (ID: $missionId)');
      }

      final updatedMission = missions.first;
      final updatedStatus = updatedMission['status'];
      final updatedAmbulanceId = updatedMission['ambulance_id'];
      final updatedDriverName = updatedMission['driver_name'];

      print('[MissionService] ✅ Mission after update:');
      print('   - Status: $updatedStatus (expected: active)');
      print('   - Ambulance ID: $updatedAmbulanceId (expected: $ambulanceId)');
      print('   - Driver Name: $updatedDriverName (expected: $driverName)');

        if (updatedStatus != 'active') {
          throw Exception(
            'Mission status not updated! Current status: $updatedStatus (expected: active). This indicates an RLS policy may be blocking the update.');
        }

        await _syncAmbulanceReservation(
          ambulanceId: ambulanceId,
          missionId: missionId,
          reserve: true,
        );

        print('[MissionService] ✅ Mission accepted successfully');
      print('═══════════════════════════════════════════════════');

      // Send mission assigned notification (non-blocking)
      print('[MissionService] 6️⃣ Sending mission assigned notification...');
      try {
        await _notifyMissionAssigned(missionId, driverName);
        print('[MissionService] ✅ Notification sent');
      } catch (notifError) {
        print('[MissionService] ⚠️ Warning - notification failed: $notifError');
        // Don't fail the mission acceptance if notification fails
      }
    } catch (e) {
      print('═══════════════════════════════════════════════════');
      print('[MissionService] ❌ ERROR accepting mission');
      print('═══════════════════════════════════════════════════');
      print('[MissionService] Error type: ${e.runtimeType}');
      print('[MissionService] Error message: ${e.toString()}');
      if (e is Exception) {
        print('[MissionService] Exception: $e');
      }
      print('═══════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Update mission status
  Future<void> updateMissionStatus(String missionId, String status) async {
    try {
      print('\n🔔 [MissionService] updateMissionStatus called');
      print('   missionId: $missionId');
      print('   newStatus: $status');

      final payload = <String, dynamic>{};

      final now = DateTime.now();

      switch (status) {
        case 'active':
          payload['status'] = 'active';
          payload['dispatch_phase'] = 'en_route';
          break;
        case 'arrived':
          payload['status'] = 'active';
          payload['dispatch_phase'] = 'arrived';
          break;
        case 'completed':
          payload['status'] = 'completed';
          payload['dispatch_phase'] = 'completed';
          break;
        case 'cancelled':
          payload['status'] = 'cancelled';
          payload['dispatch_phase'] = 'cancelled';
          break;
        default:
          payload['status'] = status;
      }

      print('   deviceNow: ${now.toIso8601String()}');
      print('   deviceTimezoneOffset: ${now.timeZoneOffset}');
      print('   payload: $payload');
      print(
          '   endpoint: ${SupabaseConfig.missionsTable}?id=eq.$missionId');

      final missionContext = await _getMissionReservationContext(missionId);
      final reservedAmbulanceId =
          missionContext?['assigned_ambulance_id']?.toString() ??
              missionContext?['ambulance_id']?.toString();

      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        payload,
      );

      if (status == 'completed') {
        _sessionSecurityService.clearSensitiveAccessWindow();
      }

      if (status == 'completed') {
        final updatedMission = await _getMissionReservationContext(missionId);
        final updatedAtRaw = updatedMission?['updated_at']?.toString();
        final completionSource = updatedAtRaw != null && updatedAtRaw.isNotEmpty
            ? DateTime.tryParse(updatedAtRaw)?.toLocal()
            : now;

        final completionTime = _formatTimeOfDay(completionSource ?? now);
        print('   serverUpdatedAt: $updatedAtRaw');
        print('   derivedCompletionTime: $completionTime');

        await _apiClient.patch(
          '${SupabaseConfig.missionsTable}?id=eq.$missionId',
          {
            'end_time': completionTime,
          },
        );
      }

      if (reservedAmbulanceId != null && reservedAmbulanceId.isNotEmpty) {
        final shouldReserve = status == 'active' || status == 'arrived';
        final shouldRelease = status == 'completed' || status == 'cancelled';

        if (shouldReserve || shouldRelease) {
          await _syncAmbulanceReservation(
            ambulanceId: reservedAmbulanceId,
            missionId: missionId,
            reserve: shouldReserve,
          );
        }
      }

      print('   ✅ Mission status updated in database');

      // Send mission status update notification (fire and forget)
      print('   🚀 QUEUING BACKGROUND NOTIFICATION for status change');
      unawaited(
        _notifyMissionStatusUpdate(missionId, status).catchError((e) {
          print(
              '❌ [MissionService] BACKGROUND ERROR in status notification: $e');
          print('   Stack trace: ${StackTrace.current}');
        }),
      );
      print('   ✅ Status update complete, notification queued in background\n');
    } catch (e) {
      print('❌ [MissionService] ERROR in updateMissionStatus: $e');
      rethrow;
    }
  }

  /// Update a specific mission field
  Future<void> updateMissionField(
      String missionId, String fieldName, dynamic value) async {
    try {
      const privateContactFields = <String>{
        'patient_name',
        'patient_first_name',
        'patient_last_name',
        'patient_phone',
        'patient_age',
        'pickup_address',
        'destination_address',
        'pickup_lat',
        'pickup_lng',
        'destination_lat',
        'destination_lng',
      };

      if (privateContactFields.contains(fieldName)) {
        await _sessionSecurityService.ensureFreshSession();
        await _sessionSecurityService.assertCurrentDeviceSessionActive(
          forceRefresh: true,
        );
        await Supabase.instance.client.functions.invoke(
          'secure_mission_phi',
          headers: await _buildFunctionHeadersAsync(),
          body: {
            'action': 'upsert_contact',
            'mission_id': missionId,
            'contact': {
              fieldName: value,
            },
          },
        );
      }

      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {fieldName: value},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Map priority from UI format to database format
  /// UI uses: normal, urgent, urgence
  /// Database expects: empty/null for normal, 'urgent' for high priority
  String? _mapPriority(String uiPriority) {
    final priority = uiPriority.toLowerCase().trim();
    // Pass through all priority values directly
    // Supabase CHECK constraint should allow:
    // normal, urgent, urgen, IRM, scanner, coro, alerte thrombolyse,
    // transfert, dialyse, deces, scintigraphie, oxygenotherapie
    if (priority.isEmpty) {
      return null; // NULL for empty priority
    }
    return priority;
  }

  /// Create a new pending mission
  Future<Mission> createMission({
    required String fromLocation,
    required String toLocation,
    required String priority,
    String? motifTransport,
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
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';
      final randomPart =
          (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
      final missionNumber = 'MISS-$timestamp-$randomPart';

      // Use current time if not provided
      final finalMissionDate = missionDate ?? now.toIso8601String();
      final mappedPriority = _mapPriority(priority);

      // Convert empty strings to default/null for optional fields
      // mission_price has NOT NULL constraint, so use "0" as default
      final finalMissionPrice =
          missionPrice?.isEmpty ?? true ? "0" : missionPrice;
      final finalPatientFirstName =
          patientFirstName?.isEmpty ?? true ? null : patientFirstName;
      final finalPatientLastName =
          patientLastName?.isEmpty ?? true ? null : patientLastName;
      final finalPatientPhone =
          patientPhone?.isEmpty ?? true ? null : patientPhone;
      final finalInfirmierName =
          infirmierName?.isEmpty ?? true ? null : infirmierName;
      final finalNotes = notes?.isEmpty ?? true ? null : notes;
      final finalMotifTransport =
          motifTransport?.isEmpty ?? true ? null : motifTransport;

      final missionData = {
        'mission_number': missionNumber,
        'mission_date': finalMissionDate,
        'from_location': fromLocation,
        'to_location': toLocation,
        'status': 'pending',
        'infirmier_name': finalInfirmierName,
        'mission_price': finalMissionPrice,
        'notes': finalNotes,
        'fractures_injuries': finalMotifTransport,
      };

      // Only include priority if it's not null
      if (mappedPriority != null) {
        missionData['priority'] = mappedPriority;
      }

      final response = await _apiClient.post(
        SupabaseConfig.missionsTable,
        missionData,
      );

      print('[MissionService] Mission created: $missionNumber');
      final baseMission = Mission.fromJson(response);
      Mission mission = baseMission;

      if (finalPatientFirstName != null ||
          finalPatientLastName != null ||
          finalPatientPhone != null) {
        try {
          final privatePayload = await Supabase.instance.client.functions.invoke(
            'secure_mission_phi',
            headers: await _buildFunctionHeadersAsync(),
            body: {
              'action': 'upsert_contact',
              'mission_id': baseMission.id,
              'contact': {
                'patient_first_name': finalPatientFirstName,
                'patient_last_name': finalPatientLastName,
                'patient_name': [
                  finalPatientFirstName,
                  finalPatientLastName,
                ].whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).join(' '),
                'patient_phone': finalPatientPhone,
                'pickup_address': fromLocation,
                'destination_address': toLocation,
              },
            },
          );

          final privateData = Map<String, dynamic>.from(
            privatePayload.data as Map<String, dynamic>? ??
                const <String, dynamic>{},
          );
          mission = _mergeMissionWithPrivatePayload(baseMission, privateData);
        } catch (e) {
          debugPrint(
            '[MissionService] Warning: mission contact details were not saved to private storage for mission ${baseMission.id}: $e',
          );
        }
      }

      // Send notification to all users (fire and forget with error handling)
      // This allows mission to be returned immediately while notification sends in background
      print(
          '[MissionService] 🚀 QUEUING BACKGROUND NOTIFICATION for $missionNumber');
      unawaited(
        _notifyAllUsersMissionCreated(
          missionNumber: missionNumber,
          patientName: '$patientFirstName $patientLastName'.trim(),
          priority: priority,
          fromLocation: fromLocation,
          toLocation: toLocation,
        ).catchError((e) {
          print('❌ [MissionService] BACKGROUND ERROR in notification: $e');
          print('   Stack trace: ${StackTrace.current}');
        }),
      );

      print(
          '[MissionService] ✅ Mission creation complete, notification queued in background');

      return mission;
    } catch (e) {
      print('[MissionService] ERROR creating mission: $e');
      rethrow;
    }
  }

  /// Send notification to all users about a new mission
  Future<void> _notifyAllUsersMissionCreated({
    required String missionNumber,
    required String patientName,
    required String priority,
    required String fromLocation,
    required String toLocation,
  }) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch;

      print('═══════════════════════════════════════════════════');
      print(
          '🔥 [MissionService] _notifyAllUsersMissionCreated CALLED [#$requestId]');
      print('   Mission: $missionNumber');

      // Validate backend URL
      final backendUrl = SupabaseConfig.notificationBackendUrl;
      print('   Backend URL: $backendUrl');
      if (backendUrl == null || backendUrl.isEmpty) {
        print('❌ BACKEND URL IS NULL OR EMPTY! Cannot send notification');
        print('═══════════════════════════════════════════════════');
        return;
      }
      print('✅ Backend URL is valid');
      print('═══════════════════════════════════════════════════');

      // Check if we're sending a duplicate notification for the same mission
      final lastRequest = _notificationRequests[missionNumber];
      if (lastRequest != null) {
        final timeSinceLastRequest =
            DateTime.now().difference(lastRequest).inMilliseconds;
        if (timeSinceLastRequest < _REQUEST_DEDUPE_WINDOW_MS) {
          print('═══════════════════════════════════════════════════');
          print('⚠️  [MissionService] DUPLICATE NOTIFICATION BLOCKED!');
          print('Mission: $missionNumber');
          print('Last sent: ${timeSinceLastRequest}ms ago');
          print('🚫 BLOCKING TO PREVENT DUPLICATE HTTP REQUEST');
          print('═══════════════════════════════════════════════════');
          return;
        }
      }

      // Record this notification request
      _notificationRequests[missionNumber] = DateTime.now();

      final priorityEmoji = priority == 'high' ? '🚨' : '📍';
      final notificationUrl = '$backendUrl/send-notification-all';

      print('═══════════════════════════════════════════════════');
      print('📢 SENDING MISSION NOTIFICATION [REQUEST #$requestId]');
      print('Backend URL: $backendUrl');
      print('Notification URL: $notificationUrl');
      print('Mission: $missionNumber');
      print('Priority: $priority');
      print('Patient details redacted from logs');
      print('Mission route details redacted from logs');
      print('═══════════════════════════════════════════════════');

      final payload = {
        'title': '$priorityEmoji Nouvelle Mission: $missionNumber',
        'body': '$patientName - $fromLocation → $toLocation',
        'missionNumber': missionNumber,
        'priority': priority,
        'requestId': requestId,
        'data': {
          'type': 'mission_created',
          'missionNumber': missionNumber,
          'priority': priority,
          'requestId': requestId.toString(),
        },
      };

      print('Payload prepared (fields redacted)');

      final response = await http
          .post(
        Uri.parse(notificationUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print(
              '❌ [MissionService] Notification request TIMEOUT after 30 seconds [REQUEST #$requestId]');
          throw Exception('Notification request timeout');
        },
      );

      print(
          'Response Status Code: ${response.statusCode} [REQUEST #$requestId]');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print(
            '✅ [MissionService] Mission notification sent successfully [REQUEST #$requestId]');
        print('Response: ${response.body}');
      } else {
        print(
            '❌ [MissionService] Failed to send notification [REQUEST #$requestId]');
        print('Status: ${response.statusCode}');
        print('Error: ${response.body}');
      }
    } catch (e) {
      print('═══════════════════════════════════════════════════');
      print('❌ [MissionService] ERROR sending notification: $e');
      print('═══════════════════════════════════════════════════');
      // Don't fail mission creation if notification fails
    }
  }

  /// Send mission assigned notification (when mission is accepted)
  Future<void> _notifyMissionAssigned(
    String missionId,
    String driverName,
  ) async {
    try {
      final backendUrl = SupabaseConfig.notificationBackendUrl;
      final notificationUrl = '$backendUrl/send-notification-all';

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📢 SENDING MISSION ASSIGNED NOTIFICATION');
      debugPrint('Mission ID: $missionId');
      debugPrint('Driver: $driverName');
      debugPrint('═══════════════════════════════════════════════════');

      final payload = {
        'title': '✅ Mission Acceptée',
        'body': 'Le chauffeur $driverName a accepté la mission',
        'missionId': missionId,
        'data': {
          'type': 'mission_assigned',
          'missionId': missionId,
          'driverName': driverName,
        },
      };

      debugPrint('Payload prepared for mission-assigned notification');

      final response = await http
          .post(
        Uri.parse(notificationUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint(
              '❌ [MissionService] Mission assigned notification TIMEOUT');
          throw Exception('Notification request timeout');
        },
      );

      if (response.statusCode == 200) {
        debugPrint(
            '✅ [MissionService] Mission assigned notification sent successfully');
      } else {
        debugPrint(
            '❌ [MissionService] Failed to send mission assigned notification');
      }
    } catch (e) {
      debugPrint(
          '❌ [MissionService] ERROR sending mission assigned notification: $e');
      // Don't fail if notification fails
    }
  }

  /// Send mission status update notification
  Future<void> _notifyMissionStatusUpdate(
    String missionId,
    String newStatus,
  ) async {
    try {
      print('\n🔥 [MissionService] _notifyMissionStatusUpdate CALLED');
      print('   missionId: $missionId');
      print('   newStatus: $newStatus');

      final backendUrl = SupabaseConfig.notificationBackendUrl;
      final notificationUrl = '$backendUrl/send-notification-all';

      // Determine title and emoji based on status
      String title;
      String body;
      String statusEmoji;

      switch (newStatus) {
        case 'completed':
          statusEmoji = '🏁';
          title = '$statusEmoji Mission Complétée';
          body = 'La mission $missionId a été complétée avec succès';
          break;
        case 'cancelled':
          statusEmoji = '❌';
          title = '$statusEmoji Mission Annulée';
          body = 'La mission $missionId a été annulée';
          break;
        default:
          statusEmoji = 'ℹ️';
          title = '$statusEmoji Mise à Jour de Mission';
          body = 'La mission $missionId a été mise à jour';
      }

      print('═══════════════════════════════════════════════════');
      print('📢 SENDING MISSION STATUS UPDATE NOTIFICATION');
      print('   Mission ID: $missionId');
      print('   New Status: $newStatus');
      print('   Title: $title');
      print('═══════════════════════════════════════════════════');

      final payload = {
        'title': title,
        'body': body,
        'missionId': missionId,
        'data': {
          'type': 'mission_status_update',
          'missionId': missionId,
          'status': newStatus,
        },
      };

      print('   Payload prepared for status update notification');

      final response = await http
          .post(
        Uri.parse(notificationUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint(
              '❌ [MissionService] Mission status update notification TIMEOUT');
          throw Exception('Notification request timeout');
        },
      );

      if (response.statusCode == 200) {
        debugPrint(
            '✅ [MissionService] Mission status update notification sent successfully');
      } else {
        debugPrint(
            '❌ [MissionService] Failed to send status update notification');
      }
    } catch (e) {
      debugPrint(
          '❌ [MissionService] ERROR sending status update notification: $e');
      // Don't fail if notification fails
    }
  }
}




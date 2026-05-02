import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mission_model.dart';
import 'session_security_service.dart';

class MissionPrivateService {
  final SessionSecurityService _sessionSecurityService =
      SessionSecurityService();

  Future<Map<String, Map<String, dynamic>>> getManyMissionPrivateData(
    Iterable<String> missionIds,
  ) async {
    await _sessionSecurityService.ensureFreshSession();
    await _sessionSecurityService.assertCurrentDeviceSessionActive();

    final normalizedIds = missionIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }

    final response = await Supabase.instance.client.functions.invoke(
      'secure_mission_phi',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'get_many_private',
        'mission_ids': normalizedIds,
      },
    );

    final payload = Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

    final items = payload['items'] is List
        ? List<Map<String, dynamic>>.from(
            (payload['items'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : const <Map<String, dynamic>>[];

    final result = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final missionId = item['mission_id']?.toString();
      if (missionId == null || missionId.isEmpty) {
        continue;
      }
      result[missionId] = item;
    }

    return result;
  }

  Future<Map<String, dynamic>> getMissionPrivateData(String missionId) async {
    await _sessionSecurityService.ensureFreshSession();
    await _sessionSecurityService.assertCurrentDeviceSessionActive();

    final response = await Supabase.instance.client.functions.invoke(
      'secure_mission_phi',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'get_private',
        'mission_id': missionId,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> saveTechnicalSheet({
    required Mission mission,
    required String? patientName,
    required String? patientFirstName,
    required String? patientLastName,
    required int? patientAge,
    required String? reportType,
    required String? fracturesInjuries,
    required Map<String, dynamic> vitalSigns,
    required List<String> medicalHistory,
    required dynamic patientNeeds,
    String? clinicalNotes,
  }) async {
    await _sessionSecurityService.ensureFreshSession();
    await _sessionSecurityService.assertCurrentDeviceSessionActive(
      forceRefresh: true,
    );

    final response = await Supabase.instance.client.functions.invoke(
      'secure_mission_phi',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'save_technical_sheet',
        'mission_id': mission.id,
        'contact': {
          'patient_name': patientName,
          'patient_first_name': patientFirstName,
          'patient_last_name': patientLastName,
          'patient_phone': mission.patientPhone,
          'patient_age': patientAge,
          'pickup_address': mission.pickupAddress,
          'destination_address': mission.destinationAddress,
          'pickup_lat': mission.pickupLat,
          'pickup_lng': mission.pickupLng,
          'destination_lat': mission.destinationLat,
          'destination_lng': mission.destinationLng,
        },
        'medical': {
          'report_type': reportType,
          'fractures_injuries': fracturesInjuries,
          'report_filled_at': DateTime.now().toIso8601String(),
          'vital_signs': vitalSigns,
          'medical_history': medicalHistory,
          'patient_needs': patientNeeds,
          'clinical_notes': clinicalNotes,
        },
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }
}

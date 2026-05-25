import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/ambulance_model.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import 'app_memory_cache_service.dart';
import 'realtime_event_bus_service.dart';

class AppRealtimeService {
  AppRealtimeService._();

  static final AppRealtimeService instance = AppRealtimeService._();

  RealtimeChannel? _missionChannel;
  RealtimeChannel? _ambulanceChannel;
  String? _tenantId;

  void startForUser(User user) {
    final tenantId = user.tenantId?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      debugPrint('[AppRealtimeService] skipped: user has no tenant_id');
      return;
    }

    if (_tenantId == tenantId &&
        _missionChannel != null &&
        _ambulanceChannel != null) {
      debugPrint('[AppRealtimeService] already running for tenant=$tenantId');
      return;
    }

    stop();
    _tenantId = tenantId;

    final client = Supabase.instance.client;

    _missionChannel = client
        .channel('tenant:$tenantId:missions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'missions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) => _handleMissionChange(payload, tenantId),
        )
        .subscribe((status, [_]) {
      debugPrint('[AppRealtimeService] missions status=$status');
    });

    _ambulanceChannel = client
        .channel('tenant:$tenantId:ambulances')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ambulances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) => _handleAmbulanceChange(payload, tenantId),
        )
        .subscribe((status, [_]) {
      debugPrint('[AppRealtimeService] ambulances status=$status');
    });

    debugPrint('[AppRealtimeService] started for tenant=$tenantId');
  }

  void stop() {
    final client = Supabase.instance.client;
    final missionChannel = _missionChannel;
    final ambulanceChannel = _ambulanceChannel;

    if (missionChannel != null) {
      unawaited(client.removeChannel(missionChannel));
    }
    if (ambulanceChannel != null) {
      unawaited(client.removeChannel(ambulanceChannel));
    }

    _missionChannel = null;
    _ambulanceChannel = null;
    _tenantId = null;
  }

  void _handleMissionChange(PostgresChangePayload payload, String tenantId) {
    try {
      MissionListCache.instance.clear();
      final eventType = payload.eventType;

      if (eventType == PostgresChangeEvent.delete) {
        final deletedId = _recordId(payload.oldRecord);
        if (deletedId != null) {
          MissionPhiMemoryCache.single.remove(deletedId);
          RealtimeEventBusService.instance.emit(
            RealtimeAppEvent.missionDeleted(deletedId),
          );
        }
        return;
      }

      final row = Map<String, dynamic>.from(payload.newRecord);
      if (!_missionBelongsToTenant(row, tenantId)) return;

      final mission = _missionFromOperationalRow(row);
      MissionPhiMemoryCache.single.remove(mission.id);

      if (eventType == PostgresChangeEvent.insert) {
        RealtimeEventBusService.instance.emit(
          RealtimeAppEvent.missionInserted(mission),
        );
      } else {
        RealtimeEventBusService.instance.emit(
          RealtimeAppEvent.missionUpdated(mission),
        );
      }
    } catch (e) {
      debugPrint('[AppRealtimeService] mission change ignored: $e');
    }
  }

  void _handleAmbulanceChange(PostgresChangePayload payload, String tenantId) {
    try {
      AmbulanceCache.list.clear();

      if (payload.eventType == PostgresChangeEvent.delete) {
        final deletedId = _recordId(payload.oldRecord);
        if (deletedId != null) {
          AmbulanceCache.byId.remove(deletedId);
        }
        return;
      }

      final row = Map<String, dynamic>.from(payload.newRecord);
      if ((row['tenant_id']?.toString() ?? '') != tenantId) return;

      final ambulance = Ambulance.fromJson(row);
      AmbulanceCache.byId.remove(ambulance.id);
      RealtimeEventBusService.instance.emit(
        RealtimeAppEvent.ambulanceUpdated(ambulance),
      );
    } catch (e) {
      debugPrint('[AppRealtimeService] ambulance change ignored: $e');
    }
  }

  Mission _missionFromOperationalRow(Map<String, dynamic> row) {
    final operationalRow = Map<String, dynamic>.from(row);
    const privateColumns = [
      'patient_name',
      'patient_phone',
      'patient_first_name',
      'patient_last_name',
      'patient_age',
      'medical_history',
      'vital_signs',
      'patient_needs',
      'medications',
      'fractures_injuries',
      'patient_signature',
    ];
    for (final column in privateColumns) {
      operationalRow[column] = null;
    }
    return Mission.fromJson(operationalRow);
  }

  bool _missionBelongsToTenant(Map<String, dynamic> row, String tenantId) {
    if (row['tenant_id']?.toString() == tenantId) return true;
    if (row['assigned_company_id']?.toString() == tenantId) return true;
    if (row['selected_provider_tenant_id']?.toString() == tenantId) return true;
    return _stringList(row['broadcast_provider_ids']).contains(tenantId);
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  String? _recordId(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    return id == null || id.isEmpty ? null : id;
  }
}

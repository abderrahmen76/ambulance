import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackingPresenceService {
  static final TrackingPresenceService _instance =
      TrackingPresenceService._internal();

  factory TrackingPresenceService() => _instance;

  TrackingPresenceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  String? _deviceId;
  TrackingShift? _activeShift;
  TrackingClaim? _activeClaim;

  static const _deviceIdKey = 'tracking_device_id';
  static const _heartbeatInterval = Duration(seconds: 20);
  static const _staleAfter = Duration(minutes: 2);

  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return existing;
    }

    final generated =
        'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_deviceIdKey, generated);
    _deviceId = generated;
    return generated;
  }

  TrackingShift? get activeShift => _activeShift;
  TrackingClaim? get activeClaim => _activeClaim;

  Future<void> loadCurrentState(String userId) async {
    final deviceId = await getDeviceId();

    final shiftRows = await _supabase
        .from('driver_shifts')
        .select()
        .eq('device_id', deviceId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1);

    final shifts = List<Map<String, dynamic>>.from(shiftRows);
    _activeShift =
        shifts.isEmpty ? null : TrackingShift.fromJson(shifts.first);

    final claimRows = await _supabase
        .from('ambulance_tracking_sessions')
        .select()
        .eq('device_id', deviceId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1);

    final claims = List<Map<String, dynamic>>.from(claimRows);
    _activeClaim =
        claims.isEmpty ? null : TrackingClaim.fromJson(claims.first);

    if (_activeShift != null || _activeClaim != null) {
      _startHeartbeat();
    }
  }

  Future<TrackingShift> startShift({
    required String userId,
    required String tenantId,
    required String driverName,
    String shiftSource = 'manual',
    String? scheduleId,
  }) async {
    final deviceId = await getDeviceId();

    final existingRows = await _supabase
        .from('driver_shifts')
        .select()
        .eq('device_id', deviceId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1);

    final existing = List<Map<String, dynamic>>.from(existingRows);
    if (existing.isNotEmpty) {
      _activeShift = TrackingShift.fromJson(existing.first);
      _startHeartbeat();
      return _activeShift!;
    }

    final insertRows = await _supabase
        .from('driver_shifts')
        .insert({
          'user_id': userId,
          'tenant_id': tenantId,
          'driver_name': driverName,
          'device_id': deviceId,
          'status': 'active',
          'shift_source': shiftSource,
          'schedule_id': scheduleId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .limit(1);

    _activeShift = TrackingShift.fromJson(
      List<Map<String, dynamic>>.from(insertRows).first,
    );
    _startHeartbeat();
    return _activeShift!;
  }

  Future<void> endShift({required String userId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final deviceId = await getDeviceId();
    if (_activeClaim != null) {
      await releaseClaim(nowIso: now);
    }

    await _supabase
        .from('driver_shifts')
        .update({
          'status': 'ended',
          'ended_at': now,
          'last_heartbeat_at': now,
        })
        .eq('device_id', deviceId)
        .eq('status', 'active');

    _activeShift = null;
    _stopHeartbeatIfIdle();
  }

  Future<TrackingClaimResult> claimAmbulance({
    required String userId,
    required String tenantId,
    required String driverName,
    required String ambulanceId,
    required String ambulanceNumber,
    bool forceTakeover = false,
  }) async {
    final deviceId = await getDeviceId();
    final shift = _activeShift ??
        await startShift(
          userId: userId,
          tenantId: tenantId,
          driverName: driverName,
        );

    final existingRows = await _supabase
        .from('ambulance_tracking_sessions')
        .select()
        .eq('ambulance_id', ambulanceId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1);

    final existingList = List<Map<String, dynamic>>.from(existingRows);
    final now = DateTime.now().toUtc();

    if (existingList.isNotEmpty) {
      final existing = TrackingClaim.fromJson(existingList.first);
      final stale = now.difference(existing.lastHeartbeatAt) > _staleAfter;

      final sameOwner = existing.deviceId == deviceId;

      if (!sameOwner && !stale && !forceTakeover) {
        return TrackingClaimResult.conflict(existing);
      }

      await _supabase
          .from('ambulance_tracking_sessions')
          .update({
            'status': stale ? 'stale' : 'transferred',
            'ended_at': now.toIso8601String(),
            'last_heartbeat_at': now.toIso8601String(),
          })
          .eq('id', existing.id);
    }

    await _supabase
        .from('ambulance_tracking_sessions')
        .update({
          'status': 'ended',
          'ended_at': now.toIso8601String(),
          'last_heartbeat_at': now.toIso8601String(),
        })
        .eq('device_id', deviceId)
        .eq('status', 'active');

    final insertRows = await _supabase
        .from('ambulance_tracking_sessions')
        .insert({
          'shift_id': shift.id,
          'ambulance_id': ambulanceId,
          'ambulance_number': ambulanceNumber,
          'user_id': userId,
          'tenant_id': tenantId,
          'driver_name': driverName,
          'device_id': deviceId,
          'status': 'active',
          'started_at': now.toIso8601String(),
          'last_heartbeat_at': now.toIso8601String(),
        })
        .select()
        .limit(1);

    _activeClaim = TrackingClaim.fromJson(
      List<Map<String, dynamic>>.from(insertRows).first,
    );
    _startHeartbeat();
    return TrackingClaimResult.granted(_activeClaim!);
  }

  Future<void> releaseClaim({String? nowIso}) async {
    final effectiveNow = nowIso ?? DateTime.now().toUtc().toIso8601String();

    if (_activeClaim != null) {
      await _supabase
          .from('ambulance_tracking_sessions')
          .update({
            'status': 'ended',
            'ended_at': effectiveNow,
            'last_heartbeat_at': effectiveNow,
          })
          .eq('id', _activeClaim!.id);
    }

    _activeClaim = null;
    _stopHeartbeatIfIdle();
  }

  Future<void> sendHeartbeat() async {
    final now = DateTime.now().toUtc().toIso8601String();

    if (_activeShift != null) {
      await _supabase
          .from('driver_shifts')
          .update({'last_heartbeat_at': now}).eq('id', _activeShift!.id);
    }

    if (_activeClaim != null) {
      await _supabase
          .from('ambulance_tracking_sessions')
          .update({'last_heartbeat_at': now}).eq('id', _activeClaim!.id);
      _activeClaim = _activeClaim!.copyWith(
        lastHeartbeatAt: DateTime.parse(now),
      );
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        await sendHeartbeat();
      } catch (e) {
        debugPrint('[TrackingPresence] heartbeat failed: $e');
      }
    });
  }

  void _stopHeartbeatIfIdle() {
    if (_activeShift == null && _activeClaim == null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  Future<List<TrackingShift>> fetchActiveShiftsForTenant(String tenantId) async {
    final rows = await _supabase
        .from('driver_shifts')
        .select()
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .order('started_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(TrackingShift.fromJson)
        .toList();
  }

  Future<List<TrackingClaim>> fetchActiveClaimsForTenant(String tenantId) async {
    final rows = await _supabase
        .from('ambulance_tracking_sessions')
        .select()
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .order('started_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(TrackingClaim.fromJson)
        .toList();
  }

  Future<void> managerEndShift(String shiftId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _supabase
        .from('driver_shifts')
        .update({
          'status': 'ended',
          'ended_at': now,
          'last_heartbeat_at': now,
        })
        .eq('id', shiftId);

    await _supabase
        .from('ambulance_tracking_sessions')
        .update({
          'status': 'revoked',
          'ended_at': now,
          'last_heartbeat_at': now,
        })
        .eq('shift_id', shiftId)
        .eq('status', 'active');
  }

  Future<void> managerEndClaim(String claimId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _supabase
        .from('ambulance_tracking_sessions')
        .update({
          'status': 'revoked',
          'ended_at': now,
          'last_heartbeat_at': now,
        })
        .eq('id', claimId)
        .eq('status', 'active');
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}

class TrackingShift {
  TrackingShift({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.driverName,
    required this.deviceId,
    required this.status,
    required this.startedAt,
    required this.lastHeartbeatAt,
    required this.shiftSource,
    this.endedAt,
    this.scheduleId,
  });

  final String id;
  final String userId;
  final String tenantId;
  final String driverName;
  final String deviceId;
  final String status;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;
  final String shiftSource;
  final DateTime? endedAt;
  final String? scheduleId;

  factory TrackingShift.fromJson(Map<String, dynamic> json) {
    return TrackingShift(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      driverName: (json['driver_name'] ?? '').toString(),
      deviceId: (json['device_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      shiftSource: (json['shift_source'] ?? 'manual').toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      lastHeartbeatAt:
          DateTime.tryParse((json['last_heartbeat_at'] ?? '').toString()) ??
              DateTime.now(),
      scheduleId: json['schedule_id']?.toString(),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.tryParse(json['ended_at'].toString()),
    );
  }
}

class TrackingClaim {
  TrackingClaim({
    required this.id,
    required this.shiftId,
    required this.ambulanceId,
    required this.ambulanceNumber,
    required this.userId,
    required this.tenantId,
    required this.driverName,
    required this.deviceId,
    required this.status,
    required this.startedAt,
    required this.lastHeartbeatAt,
    this.endedAt,
  });

  final String id;
  final String shiftId;
  final String ambulanceId;
  final String ambulanceNumber;
  final String userId;
  final String tenantId;
  final String driverName;
  final String deviceId;
  final String status;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;
  final DateTime? endedAt;

  factory TrackingClaim.fromJson(Map<String, dynamic> json) {
    return TrackingClaim(
      id: (json['id'] ?? '').toString(),
      shiftId: (json['shift_id'] ?? '').toString(),
      ambulanceId: (json['ambulance_id'] ?? '').toString(),
      ambulanceNumber:
          (json['ambulance_number'] ?? 'Ambulance').toString(),
      userId: (json['user_id'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      driverName: (json['driver_name'] ?? '').toString(),
      deviceId: (json['device_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      lastHeartbeatAt:
          DateTime.tryParse((json['last_heartbeat_at'] ?? '').toString()) ??
              DateTime.now(),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.tryParse(json['ended_at'].toString()),
    );
  }

  TrackingClaim copyWith({
    DateTime? lastHeartbeatAt,
    bool? isOnline,
  }) {
    return TrackingClaim(
      id: id,
      shiftId: shiftId,
      ambulanceId: ambulanceId,
      ambulanceNumber: ambulanceNumber,
      userId: userId,
      tenantId: tenantId,
      driverName: driverName,
      deviceId: deviceId,
      status: status,
      startedAt: startedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      endedAt: endedAt,
    );
  }
}

class TrackingClaimResult {
  TrackingClaimResult._({
    required this.granted,
    this.claim,
    this.conflictingClaim,
  });

  final bool granted;
  final TrackingClaim? claim;
  final TrackingClaim? conflictingClaim;

  factory TrackingClaimResult.granted(TrackingClaim claim) =>
      TrackingClaimResult._(granted: true, claim: claim);

  factory TrackingClaimResult.conflict(TrackingClaim conflictingClaim) =>
      TrackingClaimResult._(
        granted: false,
        conflictingClaim: conflictingClaim,
      );
}

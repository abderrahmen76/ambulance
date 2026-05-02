import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

import '../models/user_model.dart';

class ShiftScheduleService {
  ShiftScheduleService._internal();

  static final ShiftScheduleService _instance = ShiftScheduleService._internal();

  factory ShiftScheduleService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<DriverShiftSchedule>> fetchTenantSchedules(String tenantId) async {
    final rows = await _supabase
        .from('driver_shift_schedules')
        .select()
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(DriverShiftSchedule.fromJson)
        .toList();
  }

  Future<List<DriverShiftSchedule>> fetchDriverSchedules({
    required String tenantId,
    required String driverUserId,
  }) async {
    debugPrint(
      '[ShiftScheduleService] fetchDriverSchedules tenant=$tenantId driver=$driverUserId',
    );
    final rows = await _supabase
        .from('driver_shift_schedules')
        .select()
        .eq('tenant_id', tenantId)
        .eq('driver_user_id', driverUserId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final schedules = List<Map<String, dynamic>>.from(rows)
        .map(DriverShiftSchedule.fromJson)
        .toList();
    debugPrint(
      '[ShiftScheduleService] fetchDriverSchedules found=${schedules.length}',
    );
    return schedules;
  }

  Future<DriverShiftSchedule> createSchedule({
    required String tenantId,
    required User driver,
    required String createdBy,
    required ShiftRecurrence recurrence,
    required String shiftLabel,
    required DateTime startsOn,
    DateTime? endsOn,
    int? weekday,
    required String startTime,
    required String endTime,
    bool autoStartTracking = true,
  }) async {
    final insertRows = await _supabase
        .from('driver_shift_schedules')
        .insert({
          'tenant_id': tenantId,
          'driver_user_id': driver.id,
          'driver_name': driver.name,
          'recurrence_type': recurrence.name,
          'weekday': recurrence == ShiftRecurrence.weekly ? weekday : null,
          'shift_label': shiftLabel,
          'starts_on': _dateOnly(startsOn),
          'ends_on': endsOn == null ? null : _dateOnly(endsOn),
          'start_time': startTime,
          'end_time': endTime,
          'auto_start_tracking': autoStartTracking,
          'is_active': true,
          'created_by': createdBy,
        })
        .select()
        .limit(1);

    return DriverShiftSchedule.fromJson(
      List<Map<String, dynamic>>.from(insertRows).first,
    );
  }

  Future<DriverShiftSchedule> updateSchedule({
    required String scheduleId,
    required String shiftLabel,
    required ShiftRecurrence recurrence,
    required DateTime startsOn,
    DateTime? endsOn,
    int? weekday,
    required String startTime,
    required String endTime,
    required bool autoStartTracking,
    required bool isActive,
  }) async {
    final rows = await _supabase
        .from('driver_shift_schedules')
        .update({
          'shift_label': shiftLabel,
          'recurrence_type': recurrence.name,
          'weekday': recurrence == ShiftRecurrence.weekly ? weekday : null,
          'starts_on': _dateOnly(startsOn),
          'ends_on': endsOn == null ? null : _dateOnly(endsOn),
          'start_time': startTime,
          'end_time': endTime,
          'auto_start_tracking': autoStartTracking,
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', scheduleId)
        .select()
        .limit(1);

    return DriverShiftSchedule.fromJson(
      List<Map<String, dynamic>>.from(rows).first,
    );
  }

  Future<void> deactivateSchedule(String scheduleId) async {
    await _supabase.from('driver_shift_schedules').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', scheduleId);
  }

  DriverShiftSchedule? findActiveSchedule(
    List<DriverShiftSchedule> schedules,
    DateTime moment,
  ) {
    for (final schedule in schedules) {
      if (schedule.isActiveAt(moment)) {
        return schedule;
      }
    }
    return null;
  }

  DriverShiftSchedule? findNextSchedule(
    List<DriverShiftSchedule> schedules,
    DateTime moment,
  ) {
    DriverShiftSchedule? best;
    var bestDeltaMinutes = 1 << 30;

    for (final schedule in schedules) {
      if (!schedule.isActive) continue;
      final delta = schedule.minutesUntilNextStart(moment);
      if (delta == null) continue;
      if (delta < bestDeltaMinutes) {
        bestDeltaMinutes = delta;
        best = schedule;
      }
    }

    return best;
  }

  List<DriverShiftSchedule> schedulesForDate(
    List<DriverShiftSchedule> schedules,
    DateTime date,
  ) {
    return schedules.where((schedule) => schedule.appliesOn(date)).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  List<ShiftConflict> buildConflicts(
    List<DriverShiftSchedule> schedules,
    DateTime date,
  ) {
    final visible = schedulesForDate(schedules, date);
    final conflicts = <ShiftConflict>[];
    final byDriver = <String, List<DriverShiftSchedule>>{};

    for (final schedule in visible) {
      byDriver.putIfAbsent(schedule.driverUserId, () => []).add(schedule);
    }

    for (final entry in byDriver.entries) {
      final sorted = [...entry.value]
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      for (var i = 0; i < sorted.length - 1; i++) {
        final current = sorted[i];
        final next = sorted[i + 1];
        if (_overlaps(current, next)) {
          conflicts.add(
            ShiftConflict(
              driverUserId: current.driverUserId,
              driverName: current.driverName,
              first: current,
              second: next,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  bool _overlaps(DriverShiftSchedule first, DriverShiftSchedule second) {
    final firstEnd = first.endMinutes <= first.startMinutes
        ? first.endMinutes + (24 * 60)
        : first.endMinutes;
    final secondStart = second.startMinutes;
    return secondStart < firstEnd;
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}

enum ShiftRecurrence { daily, weekly }

class DriverShiftSchedule {
  DriverShiftSchedule({
    required this.id,
    required this.tenantId,
    required this.driverUserId,
    required this.driverName,
    required this.recurrenceType,
    required this.shiftLabel,
    required this.startsOn,
    required this.startTime,
    required this.endTime,
    required this.autoStartTracking,
    required this.isActive,
    required this.createdAt,
    this.weekday,
    this.endsOn,
  });

  final String id;
  final String tenantId;
  final String driverUserId;
  final String driverName;
  final ShiftRecurrence recurrenceType;
  final int? weekday;
  final String shiftLabel;
  final DateTime startsOn;
  final DateTime? endsOn;
  final String startTime;
  final String endTime;
  final bool autoStartTracking;
  final bool isActive;
  final DateTime createdAt;

  int get startMinutes => _toMinutes(startTime);
  int get endMinutes => _toMinutes(endTime);

  bool appliesOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(startsOn.year, startsOn.month, startsOn.day);
    final endDay = endsOn == null
        ? null
        : DateTime(endsOn!.year, endsOn!.month, endsOn!.day);

    if (day.isBefore(startDay)) {
      return false;
    }
    if (endDay != null && day.isAfter(endDay)) {
      return false;
    }

    if (recurrenceType == ShiftRecurrence.daily) {
      return true;
    }

    return weekday == date.weekday;
  }

  bool isActiveAt(DateTime moment) {
    if (!isActive || !appliesOn(moment)) {
      return false;
    }

    final minutesNow = (moment.hour * 60) + moment.minute;

    if (endMinutes > startMinutes) {
      return minutesNow >= startMinutes && minutesNow < endMinutes;
    }

    return minutesNow >= startMinutes || minutesNow < endMinutes;
  }

  String get timeRangeLabel => '$startTime - $endTime';

  int? minutesUntilNextStart(DateTime moment) {
    final today = DateTime(moment.year, moment.month, moment.day);
    for (var offset = 0; offset < 14; offset++) {
      final day = today.add(Duration(days: offset));
      if (!appliesOn(day)) {
        continue;
      }

      final start = DateTime(
        day.year,
        day.month,
        day.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );
      final delta = start.difference(moment).inMinutes;
      if (delta >= 0) {
        return delta;
      }
    }
    return null;
  }

  factory DriverShiftSchedule.fromJson(Map<String, dynamic> json) {
    return DriverShiftSchedule(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenant_id'] ?? '').toString(),
      driverUserId: (json['driver_user_id'] ?? '').toString(),
      driverName: (json['driver_name'] ?? 'Driver').toString(),
      recurrenceType:
          (json['recurrence_type'] ?? 'daily').toString() == 'weekly'
              ? ShiftRecurrence.weekly
              : ShiftRecurrence.daily,
      weekday: json['weekday'] == null
          ? null
          : int.tryParse(json['weekday'].toString()),
      shiftLabel: (json['shift_label'] ?? 'Shift').toString(),
      startsOn: DateTime.tryParse((json['starts_on'] ?? '').toString()) ??
          DateTime.now(),
      endsOn: json['ends_on'] == null
          ? null
          : DateTime.tryParse(json['ends_on'].toString()),
      startTime: (json['start_time'] ?? '08:00').toString(),
      endTime: (json['end_time'] ?? '16:00').toString(),
      autoStartTracking: json['auto_start_tracking'] == true,
      isActive: json['is_active'] != false,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static int _toMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      return 0;
    }
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return (hours * 60) + minutes;
  }
}

class ShiftConflict {
  ShiftConflict({
    required this.driverUserId,
    required this.driverName,
    required this.first,
    required this.second,
  });

  final String driverUserId;
  final String driverName;
  final DriverShiftSchedule first;
  final DriverShiftSchedule second;

  String get message =>
      '$driverName has overlapping shifts: ${first.timeRangeLabel} and ${second.timeRangeLabel}.';
}

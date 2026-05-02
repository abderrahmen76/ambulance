import 'package:flutter/foundation.dart';

import '../models/ambulance_model.dart';
import '../models/user_model.dart';
import 'fleet_tracking/background_location_service.dart';
import 'fleet_tracking/fleet_tracking_service.dart';
import 'shift_schedule_service.dart';
import 'tracking_presence_service.dart';

class ScheduledShiftRuntimeService {
  ScheduledShiftRuntimeService._internal();

  static final ScheduledShiftRuntimeService _instance =
      ScheduledShiftRuntimeService._internal();

  factory ScheduledShiftRuntimeService() => _instance;

  final TrackingPresenceService _presenceService = TrackingPresenceService();
  final ShiftScheduleService _scheduleService = ShiftScheduleService();
  final FleetTrackingService _trackingService = FleetTrackingService();

  Future<DriverShiftSchedule?> syncForDriver({
    required User user,
    required Ambulance? ambulance,
    required String backendUrl,
  }) async {
    final tenantId = user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return null;
    }

    await _presenceService.loadCurrentState(user.id);
    final schedules = await _scheduleService.fetchDriverSchedules(
      tenantId: tenantId,
      driverUserId: user.id,
    );
    final schedule = _scheduleService.findActiveSchedule(
      schedules,
      DateTime.now(),
    );
    final activeShift = _presenceService.activeShift;

    debugPrint(
      '[ScheduledShiftRuntime] syncForDriver user=${user.id} '
      'tenant=${user.tenantId} ambulance=${ambulance?.ambulanceNumber} '
      'activeSchedule=${schedule?.id} activeShift=${activeShift?.id}',
    );

    if (schedule == null) {
      if (activeShift != null && activeShift.shiftSource == 'scheduled') {
        debugPrint(
          '[ScheduledShiftRuntime] ending scheduled shift ${activeShift.id} '
          'because no active schedule window is running',
        );
        await _presenceService.endShift(userId: user.id);
        await _trackingService.stopTracking();
        if (await BackgroundLocationService.isServiceRunning()) {
          await BackgroundLocationService.stopBackgroundService();
        }
      }
      return null;
    }

    if (activeShift == null ||
        (activeShift.shiftSource == 'scheduled' &&
            activeShift.scheduleId != schedule.id)) {
      if (activeShift != null && activeShift.shiftSource == 'scheduled') {
        debugPrint(
          '[ScheduledShiftRuntime] replacing scheduled shift ${activeShift.id} '
          'with schedule ${schedule.id}',
        );
        await _presenceService.endShift(userId: user.id);
      }

      debugPrint(
        '[ScheduledShiftRuntime] starting scheduled shift for '
        '${user.name} using schedule ${schedule.id}',
      );
      await _presenceService.startShift(
        userId: user.id,
        tenantId: tenantId,
        driverName: user.name,
        shiftSource: 'scheduled',
        scheduleId: schedule.id,
      );
    }

    if (schedule.autoStartTracking && ambulance != null) {
      debugPrint(
        '[ScheduledShiftRuntime] auto-claiming ${ambulance.ambulanceNumber} '
        'for active schedule ${schedule.id}',
      );
      final result = await _presenceService.claimAmbulance(
        userId: user.id,
        tenantId: tenantId,
        driverName: user.name,
        ambulanceId: ambulance.id,
        ambulanceNumber: ambulance.ambulanceNumber,
      );

      if (result.granted) {
        debugPrint(
          '[ScheduledShiftRuntime] claim granted for ${ambulance.ambulanceNumber}, '
          'starting live tracking',
        );
        debugPrint(
          '[ScheduledShiftRuntime] tracker state before reset: '
          'isTracking=${_trackingService.isTracking} isConnected=${_trackingService.isConnected}',
        );
        if (!_trackingService.isConnected) {
          await _trackingService.hardResetRuntime();
        }
        debugPrint(
          '[ScheduledShiftRuntime] calling initialize for ambulance=${ambulance.id} '
          'driver=${user.id}',
        );
        await _trackingService.initialize(
          driverId: user.id,
          ambulanceId: ambulance.id,
          driverName: user.name,
          backendUrl: backendUrl,
          ambulanceNumber: ambulance.ambulanceNumber,
          ambulanceTelephone: ambulance.telephone,
        );
        debugPrint(
          '[ScheduledShiftRuntime] initialize completed; '
          'isTracking=${_trackingService.isTracking} isConnected=${_trackingService.isConnected}',
        );
        debugPrint('[ScheduledShiftRuntime] calling startTracking...');
        await _trackingService.startTracking();
        debugPrint(
          '[ScheduledShiftRuntime] startTracking completed; '
          'isTracking=${_trackingService.isTracking} isConnected=${_trackingService.isConnected}',
        );
        await BackgroundLocationService.initializeService();
        await BackgroundLocationService.startBackgroundService(
          driverId: user.id,
          ambulanceId: ambulance.id,
          driverName: user.name,
          backendUrl: backendUrl,
          ambulanceNumber: ambulance.ambulanceNumber,
          ambulanceTelephone: ambulance.telephone,
        );
        debugPrint('[ScheduledShiftRuntime] background service start requested');
      } else if (result.conflictingClaim != null) {
        debugPrint(
          '[ScheduledShiftRuntime] claim conflict for ${ambulance.ambulanceNumber}: ${result.conflictingClaim!.driverName}',
        );
      } else {
        debugPrint('[ScheduledShiftRuntime] claim returned no grant and no conflict');
      }
    } else if (ambulance == null) {
      debugPrint(
        '[ScheduledShiftRuntime] schedule is active but no ambulance is currently selected/linked',
      );
    }

    return schedule;
  }
}

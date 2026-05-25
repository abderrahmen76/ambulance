import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ambulance_model.dart';
import '../models/user_model.dart';
import 'ambulance_service.dart';
import 'company_staff_service.dart';
import 'custom_clinic_service.dart';
import 'maintenance_rule_service.dart';
import 'mission_service.dart';
import 'performance_log_service.dart';
import 'pdf_service.dart';

class DashboardPreloadService {
  static final DashboardPreloadService _instance =
      DashboardPreloadService._internal();

  final MissionService _missionService = MissionService();
  final AmbulanceService _ambulanceService = AmbulanceService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  final CustomClinicService _customClinicService = CustomClinicService();
  final MaintenanceRuleService _maintenanceRuleService =
      MaintenanceRuleService();

  bool _isPreloading = false;

  factory DashboardPreloadService() => _instance;

  DashboardPreloadService._internal();

  void preloadAfterAuth(User user) {
    if (_isPreloading) return;
    _isPreloading = true;

    unawaited(_preloadAfterAuth(user).whenComplete(() {
      _isPreloading = false;
    }));
  }

  Future<void> _preloadAfterAuth(User user) async {
    final role = user.role?.trim().toLowerCase() ?? '';
    if (role == 'admin') return;

    // Let the dashboard shell render before background cache warming starts.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final trace = PerformanceLog.start(
      'post-login preload',
      meta: {'role': role, 'tenant': user.tenantId ?? ''},
    );

    try {
      if (role == 'manager' || role == 'owner') {
        await _preloadManagerOwner(user, trace);
      } else {
        await _preloadDriver(user, trace);
      }
      trace.end(meta: {'status': 'ok'});
    } catch (e) {
      debugPrint('[DashboardPreloadService] preload warning: $e');
      trace.end(meta: {'status': 'warning', 'error': e.runtimeType});
    }
  }

  Future<void> _preloadManagerOwner(User user, PerfTrace trace) async {
    final tenantId = user.tenantId ?? '';

    // Critical dashboard data first. These calls warm MissionListCache and
    // AmbulanceCache for the visible dashboard plus the next likely tabs.
    await Future.wait([
      _warm('critical missions', _missionService.getAllMissionsOperational),
      _warm('critical ambulances', _ambulanceService.getAllAmbulances),
    ]);
    trace.checkpoint('critical_dashboard_warmed');

    final backgroundTasks = <Future<void>>[
      _warm('missions tab', _missionService.getAllMissionsOperational),
      _warm('ambulances tab', _ambulanceService.getAllAmbulances),
      _warm(
        'custom clinics sfax',
        () => _customClinicService.getClinicsByCity('Sfax'),
      ),
    ];

    if (tenantId.isNotEmpty) {
      backgroundTasks.addAll([
        _warm(
          'settings staff',
          () => _companyStaffService.getCompanyStaff(tenantId),
        ),
        _warm(
          'settings drivers',
          () => _companyStaffService.getCompanyDrivers(tenantId),
        ),
        _warm(
          'maintenance rules',
          () => _maintenanceRuleService.getRules(tenantId),
        ),
        _warm(
          'tenant header',
          () => PdfService.preloadTenantHeader(tenantId),
        ),
      ]);
    }

    await Future.wait(backgroundTasks);
    trace.checkpoint('next_tabs_prefetched');
  }

  Future<void> _preloadDriver(User user, PerfTrace trace) async {
    final tenantId = user.tenantId ?? '';
    final ambulance = await _safeValue<Ambulance?>(
      'driver ambulance',
      () => _ambulanceService.getAmbulanceForDriver(
        user.id,
        tenantId: tenantId.isEmpty ? null : tenantId,
      ),
    );
    trace.checkpoint('critical_dashboard_warmed');

    final ambulanceId = ambulance?.id;
    final tasks = <Future<void>>[
      _warm(
        'custom clinics sfax',
        () => _customClinicService.getClinicsByCity('Sfax'),
      ),
    ];

    if (ambulanceId != null && ambulanceId.isNotEmpty) {
      tasks.addAll([
        _warm(
          'driver available missions',
          () => _missionService.getAvailableMissions(ambulanceId),
        ),
        _warm(
          'driver active missions',
          () => _missionService.getActiveMissions(ambulanceId),
        ),
        _warm(
          'driver ambulance missions',
          () => _missionService.getMissionsForAmbulance(ambulanceId),
        ),
      ]);
    }

    if (tenantId.isNotEmpty) {
      tasks.addAll([
        _warm(
          'driver settings staff',
          () => _companyStaffService.getCompanyStaff(tenantId),
        ),
        _warm(
          'driver tenant header',
          () => PdfService.preloadTenantHeader(tenantId),
        ),
      ]);
    }

    await Future.wait(tasks);
    trace.checkpoint('next_tabs_prefetched');
  }

  Future<void> _warm<T>(String label, Future<T> Function() action) async {
    await _safeValue<T>(label, action);
  }

  Future<T?> _safeValue<T>(String label, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('[DashboardPreloadService] $label skipped: $e');
      return null;
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ambulance_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../services/api_client.dart';
import '../services/fleet_tracking/background_location_service.dart';
import '../services/fleet_tracking/fleet_tracking_service.dart';
import '../services/shift_schedule_service.dart';
import '../services/tracking_presence_service.dart';

class DriverTrackingScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;
  final String ambulanceNumber;

  const DriverTrackingScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
    required this.ambulanceNumber,
  }) : super(key: key);

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen>
    with WidgetsBindingObserver {
  static const _backendUrl = 'https://ambulance-backend-1-n6wd.onrender.com';

  final FleetTrackingService _trackingService = FleetTrackingService();
  final TrackingPresenceService _presenceService = TrackingPresenceService();
  final ShiftScheduleService _scheduleService = ShiftScheduleService();
  final ApiClient _apiClient = ApiClient();

  bool _isTracking = false;
  bool _isConnected = false;
  bool _backgroundServiceActive = false;
  bool _isBusy = true;
  String? _error;
  Position? _currentPosition;
  String? _currentPlaceName;
  int _updateCount = 0;
  DriverShiftSchedule? _activeSchedule;
  DriverShiftSchedule? _nextSchedule;
  List<DriverShiftSchedule> _driverSchedules = [];
  Timer? _scheduleSyncTimer;

  bool get _isScheduleLocked =>
      _presenceService.activeShift?.shiftSource == 'scheduled' &&
      _activeSchedule != null;

  List<Ambulance> _tenantAmbulances = [];
  String? _selectedAmbulanceId;
  String? _selectedAmbulanceNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupTrackingListeners();
    _bootstrap();
    _startScheduleSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncScheduledShift();
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _isBusy = true);
    try {
      await _presenceService.loadCurrentState(widget.user.id);
      await _loadTenantAmbulances();
      await _loadDriverSchedules();
      await _checkBackgroundService();

      final activeClaim = _presenceService.activeClaim;
      if (activeClaim != null) {
        _selectedAmbulanceId = activeClaim.ambulanceId;
        _selectedAmbulanceNumber = activeClaim.ambulanceNumber;
        await _ensureTrackingForClaim(
          ambulanceId: activeClaim.ambulanceId,
          ambulanceNumber: activeClaim.ambulanceNumber,
        );
      } else {
        _selectedAmbulanceId = widget.ambulanceId;
        _selectedAmbulanceNumber = widget.ambulanceNumber;
      }

      await _syncScheduledShift();
      _syncTrackingState();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _loadTenantAmbulances() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      _tenantAmbulances = [
        Ambulance(
          id: widget.ambulanceId,
          ambulanceNumber: widget.ambulanceNumber,
        ),
      ];
      return;
    }

    final rows = await _apiClient.get(
      SupabaseConfig.ambulancesTable,
      filters: {
        'tenant_id': 'eq.$tenantId',
      },
    );

    final ambulances = rows
        .map((row) => Ambulance.fromJson(row))
        .where((ambulance) => ambulance.id.isNotEmpty)
        .toList();

    if (ambulances.isEmpty) {
      _tenantAmbulances = [
        Ambulance(
          id: widget.ambulanceId,
          ambulanceNumber: widget.ambulanceNumber,
        ),
      ];
      return;
    }

    _tenantAmbulances = ambulances;
  }

  Future<void> _loadDriverSchedules() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      _driverSchedules = [];
      _activeSchedule = null;
      return;
    }

    final schedules = await _scheduleService.fetchDriverSchedules(
      tenantId: tenantId,
      driverUserId: widget.user.id,
    );
    _driverSchedules = schedules;
    _activeSchedule = _scheduleService.findActiveSchedule(
      schedules,
      DateTime.now(),
    );
    _nextSchedule = _scheduleService.findNextSchedule(
      schedules,
      DateTime.now(),
    );
    debugPrint(
      '[DriverTracking] loaded schedules count=${schedules.length} '
      'active=${_activeSchedule?.id} next=${_nextSchedule?.id} '
      'now=${DateTime.now()}',
    );
  }

  Future<void> _ensureTrackingForClaim({
    required String ambulanceId,
    required String ambulanceNumber,
    bool autoEnableBackground = false,
  }) async {
    await _trackingService.initialize(
      driverId: widget.user.id,
      ambulanceId: ambulanceId,
      driverName: widget.user.name,
      backendUrl: _backendUrl,
    );

    if (!_trackingService.isTracking) {
      await _trackingService.startTracking();
    }

    if (_backgroundServiceActive || autoEnableBackground) {
      final selectedAmbulance = _tenantAmbulances.cast<Ambulance?>().firstWhere(
            (item) => item?.id == ambulanceId,
            orElse: () => null,
          );
      await BackgroundLocationService.initializeService();
      await BackgroundLocationService.startBackgroundService(
        driverId: widget.user.id,
        ambulanceId: ambulanceId,
        driverName: widget.user.name,
        backendUrl: _backendUrl,
        ambulanceNumber: ambulanceNumber,
        ambulanceTelephone: selectedAmbulance?.telephone,
      );
      _backgroundServiceActive = true;
    }

    _selectedAmbulanceId = ambulanceId;
    _selectedAmbulanceNumber = ambulanceNumber;
    _syncTrackingState();
  }

  Future<void> _syncScheduledShift() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return;
    }

    try {
      await _loadDriverSchedules();
      final schedule = _scheduleService.findActiveSchedule(
        _driverSchedules,
        DateTime.now(),
      );
      _activeSchedule = schedule;
      _nextSchedule = _scheduleService.findNextSchedule(
        _driverSchedules,
        DateTime.now(),
      );

      final activeShift = _presenceService.activeShift;
      debugPrint(
        '[DriverTracking] syncSchedule now=${DateTime.now()} '
        'activeSchedule=${schedule?.id} nextSchedule=${_nextSchedule?.id} '
        'activeShift=${activeShift?.id} selectedAmbulance=$_selectedAmbulanceNumber',
      );

      if (schedule != null) {
        if (activeShift == null ||
            (activeShift.shiftSource == 'scheduled' &&
                activeShift.scheduleId != schedule.id)) {
          if (activeShift != null && activeShift.shiftSource == 'scheduled') {
            await _presenceService.endShift(userId: widget.user.id);
          }

          await _presenceService.startShift(
            userId: widget.user.id,
            tenantId: tenantId,
            driverName: widget.user.name,
            shiftSource: 'scheduled',
            scheduleId: schedule.id,
          );
        }

        if (schedule.autoStartTracking &&
            (_selectedAmbulanceId ?? '').isNotEmpty &&
            (_selectedAmbulanceNumber ?? '').isNotEmpty) {
          final result = await _presenceService.claimAmbulance(
            userId: widget.user.id,
            tenantId: tenantId,
            driverName: widget.user.name,
            ambulanceId: _selectedAmbulanceId!,
            ambulanceNumber: _selectedAmbulanceNumber!,
          );

          if (result.granted) {
            await _ensureTrackingForClaim(
              ambulanceId: _selectedAmbulanceId!,
              ambulanceNumber: _selectedAmbulanceNumber!,
              autoEnableBackground: true,
            );
          }
        }
      } else if (activeShift != null && activeShift.shiftSource == 'scheduled') {
        await _presenceService.endShift(userId: widget.user.id);
        await _trackingService.stopTracking();
        if (_backgroundServiceActive) {
          await BackgroundLocationService.stopBackgroundService();
          _backgroundServiceActive = false;
        }
      }

      if (mounted) {
        setState(() {});
      }
      _syncTrackingState();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Schedule sync failed: $error');
    }
  }

  void _startScheduleSyncTimer() {
    _scheduleSyncTimer?.cancel();
    _scheduleSyncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _syncScheduledShift(),
    );
  }

  String? _nextScheduleLabel() {
    final schedule = _nextSchedule;
    if (schedule == null) return null;
    final minutes = schedule.minutesUntilNextStart(DateTime.now());
    final nextStart = minutes == null
        ? null
        : DateTime.now().add(Duration(minutes: minutes));
    if (nextStart == null) {
      return '${schedule.shiftLabel} starts at ${schedule.startTime}';
    }
    final formattedDate =
        '${nextStart.day.toString().padLeft(2, '0')}/${nextStart.month.toString().padLeft(2, '0')}';
    final formattedTime =
        '${nextStart.hour.toString().padLeft(2, '0')}:${nextStart.minute.toString().padLeft(2, '0')}';
    return '${schedule.shiftLabel} starts on $formattedDate at $formattedTime';
  }

  void _syncTrackingState() {
    if (!mounted) return;
    setState(() {
      _isTracking = _trackingService.isTracking;
      _isConnected = _trackingService.isConnected;
      _updateCount = _trackingService.updateCount;
    });
  }

  void _setupTrackingListeners() {
    _trackingService.onLocationUpdated((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _updateCount = _trackingService.updateCount;
      });
      _getPlaceName(position.latitude, position.longitude);
    });

    _trackingService.onConnected(() {
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _error = null;
      });
    });

    _trackingService.onDisconnected(() {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
    });

    _trackingService.onError((error) {
      if (!mounted) return;
      setState(() => _error = error);
    });
  }

  Future<void> _checkBackgroundService() async {
    final isRunning = await BackgroundLocationService.isServiceRunning();
    if (mounted) {
      setState(() {
        _backgroundServiceActive = isRunning;
      });
    }
  }

  Future<void> _getPlaceName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty || !mounted) return;

      final place = placemarks.first;
      final label = [place.street, place.locality, place.country]
          .where((value) => value != null && value.isNotEmpty)
          .join(', ');
      setState(() {
        _currentPlaceName = label.isEmpty ? null : label;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _currentPlaceName = null);
      }
    }
  }

  Future<void> _startShift() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      _showSnack('Aucun tenant détecté pour ce compte.', Colors.red);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _presenceService.startShift(
        userId: widget.user.id,
        tenantId: tenantId,
        driverName: widget.user.name,
      );

      // Auto-claim the currently assigned/default ambulance so the driver
      // does not have to perform a second manual step in the normal case.
      if ((_selectedAmbulanceId ?? '').isNotEmpty &&
          (_selectedAmbulanceNumber ?? '').isNotEmpty) {
        final result = await _presenceService.claimAmbulance(
          userId: widget.user.id,
          tenantId: tenantId,
          driverName: widget.user.name,
          ambulanceId: _selectedAmbulanceId!,
          ambulanceNumber: _selectedAmbulanceNumber!,
        );

        if (result.granted) {
          await _ensureTrackingForClaim(
            ambulanceId: _selectedAmbulanceId!,
            ambulanceNumber: _selectedAmbulanceNumber!,
          );
          _showSnack(
            'Shift started. ${_selectedAmbulanceNumber!} claimed automatically.',
            Colors.green,
          );
        } else if (result.conflictingClaim != null) {
          _showSnack(
            'Shift started. ${_selectedAmbulanceNumber!} is already tracked by ${result.conflictingClaim!.driverName}.',
            Colors.orange,
          );
        } else {
          _showSnack('Shift started.', Colors.green);
        }
      } else {
        _showSnack('Shift started.', Colors.green);
      }
    } catch (error) {
      _showSnack('Unable to start shift: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _endShift() async {
    setState(() => _isBusy = true);
    try {
      await _presenceService.endShift(userId: widget.user.id);
      await _trackingService.stopTracking();
      if (_backgroundServiceActive) {
        await BackgroundLocationService.stopBackgroundService();
      }
      _syncTrackingState();
      _showSnack('Shift ended and tracking released.', Colors.orange);
    } catch (error) {
      _showSnack('Unable to end shift: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _claimSelectedAmbulance({bool forceTakeover = false}) async {
    final tenantId = widget.user.tenantId;
    final ambulanceId = _selectedAmbulanceId;
    final ambulanceNumber = _selectedAmbulanceNumber;

    if (tenantId == null ||
        tenantId.isEmpty ||
        ambulanceId == null ||
        ambulanceId.isEmpty ||
        ambulanceNumber == null ||
        ambulanceNumber.isEmpty) {
      _showSnack('Please select an ambulance first.', Colors.red);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final result = await _presenceService.claimAmbulance(
        userId: widget.user.id,
        tenantId: tenantId,
        driverName: widget.user.name,
        ambulanceId: ambulanceId,
        ambulanceNumber: ambulanceNumber,
        forceTakeover: forceTakeover,
      );

      if (!result.granted && result.conflictingClaim != null) {
        final shouldTakeOver =
            await _showTakeoverDialog(result.conflictingClaim!);
        if (shouldTakeOver == true) {
          if (!mounted) return;
          setState(() => _isBusy = false);
          await _claimSelectedAmbulance(forceTakeover: true);
          return;
        }
        return;
      }

      await _ensureTrackingForClaim(
        ambulanceId: ambulanceId,
        ambulanceNumber: ambulanceNumber,
      );
      _showSnack('Tracking claimed for $ambulanceNumber.', Colors.green);
    } catch (error) {
      _showSnack('Unable to claim ambulance: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _releaseClaim() async {
    setState(() => _isBusy = true);
    try {
      await _presenceService.releaseClaim();
      await _trackingService.stopTracking();
      if (_backgroundServiceActive) {
        await BackgroundLocationService.stopBackgroundService();
      }
      _syncTrackingState();
      _showSnack('Ambulance released.', Colors.orange);
    } catch (error) {
      _showSnack('Unable to release ambulance: $error', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _toggleBackgroundService() async {
    if (_presenceService.activeClaim == null) {
      _showSnack(
        'Claim an ambulance first. Background tracking follows the active claim.',
        Colors.orange,
      );
      return;
    }

    if (_backgroundServiceActive) {
      await BackgroundLocationService.stopBackgroundService();
      if (mounted) {
        setState(() => _backgroundServiceActive = false);
      }
      _showSnack('Background tracking disabled.', Colors.orange);
      return;
    }

    await BackgroundLocationService.initializeService();
    await BackgroundLocationService.startBackgroundService(
        driverId: widget.user.id,
        ambulanceId: _presenceService.activeClaim!.ambulanceId,
        driverName: widget.user.name,
        backendUrl: _backendUrl,
        ambulanceNumber: _presenceService.activeClaim!.ambulanceNumber,
        ambulanceTelephone: _tenantAmbulances
            .cast<Ambulance?>()
            .firstWhere(
              (item) => item?.id == _presenceService.activeClaim!.ambulanceId,
              orElse: () => null,
            )
            ?.telephone,
      );
    if (mounted) {
      setState(() => _backgroundServiceActive = true);
    }
    _showSnack('Background tracking enabled.', Colors.green);
  }

  Future<bool?> _showTakeoverDialog(TrackingClaim claim) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take over tracking?'),
        content: Text(
          '${claim.ambulanceNumber} is currently held by ${claim.driverName}.\n'
          'Last heartbeat: ${claim.lastHeartbeatAt.toLocal()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take over'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Ambulance? _findAmbulance(String? ambulanceId) {
    for (final ambulance in _tenantAmbulances) {
      if (ambulance.id == ambulanceId) {
        return ambulance;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeShift = _presenceService.activeShift;
    final activeClaim = _presenceService.activeClaim;
    final currentAmbulance = _findAmbulance(
      activeClaim?.ambulanceId ?? _selectedAmbulanceId,
    );

    if (_isBusy) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shift & Tracking',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildOverviewCard(activeShift, activeClaim),
          const SizedBox(height: 16),
          _buildLinkedAmbulanceCard(currentAmbulance, activeClaim),
          const SizedBox(height: 16),
          if (_currentPosition != null) _buildLocationCard(),
          if (_currentPosition != null) const SizedBox(height: 16),
          if (_error != null) _buildErrorCard(),
          if (_error != null) const SizedBox(height: 16),
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    TrackingShift? activeShift,
    TrackingClaim? activeClaim,
  ) {
    final shiftStarted = activeShift?.startedAt.toLocal();
    final lastBeat = activeClaim?.lastHeartbeatAt.toLocal() ??
        activeShift?.lastHeartbeatAt.toLocal();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatusChip(
                  label: activeShift != null ? 'SHIFT ACTIVE' : 'OFF SHIFT',
                  color: activeShift != null ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusChip(
                  label: _isConnected ? 'LIVE LINK' : 'DISCONNECTED',
                  color: _isConnected ? Colors.blue : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activeClaim != null
                ? 'Primary tracker: ${activeClaim.ambulanceNumber}'
                : 'No ambulance claimed yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            shiftStarted != null
                ? 'Shift started ${shiftStarted.toString().split('.').first}'
                : 'Manager schedules can start this shift automatically when the planned time begins.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (activeShift == null && _activeSchedule == null && _nextSchedule != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next schedule: ${_nextScheduleLabel()!}',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_activeSchedule != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active schedule: ${_activeSchedule!.shiftLabel} (${_activeSchedule!.timeRangeLabel})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tracking is managed automatically while this schedule is active.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
          if (lastBeat != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last heartbeat: ${lastBeat.toString().split('.').first}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _driverSchedules.isNotEmpty
                          ? () async {
                              await _syncScheduledShift();
                              if (!mounted) return;
                              if (_activeSchedule == null) {
                                final nextLabel = _nextScheduleLabel();
                                _showSnack(
                                  nextLabel == null
                                      ? 'No active shift right now.'
                                      : 'No active shift right now. $nextLabel.',
                                  Colors.orange,
                                );
                              } else {
                                _showSnack(
                                  'Scheduled shift synced.',
                                  Colors.green,
                                );
                              }
                            }
                          : (activeShift == null ? _startShift : null),
                  icon: Icon(
                    _driverSchedules.isNotEmpty
                        ? Icons.sync
                        : Icons.play_circle_fill,
                  ),
                  label: Text(
                    _driverSchedules.isNotEmpty ? 'Sync Schedule' : 'Start Shift',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScheduleLocked
                      ? null
                      : (activeShift != null ? _endShift : null),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_isScheduleLocked ? 'Scheduled' : 'End Shift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAmbulanceCard(
    Ambulance? currentAmbulance,
    TrackingClaim? activeClaim,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linked ambulance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live GPS is sent for the ambulance currently linked to this driver account.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (currentAmbulance != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentAmbulance.ambulanceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${currentAmbulance.telephone ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    activeClaim != null
                        ? 'Tracking is currently active for this ambulance.'
                        : 'This ambulance will be tracked automatically when the shift starts.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: const Text(
                'No ambulance is linked to this driver account yet. Go back and link or switch the ambulance from the dashboard first.',
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'To change ambulance, first liberate the current ambulance from the dashboard, then choose another one there.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final position = _currentPosition!;
    final displayLocation = _currentPlaceName ??
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest published location',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(displayLocation),
          const SizedBox(height: 6),
          Text(
            'Accuracy ${position.accuracy.toStringAsFixed(1)} m',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(
        _error!,
        style: TextStyle(color: Colors.red.shade800),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final deviceClaim = _presenceService.activeClaim;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracker stats',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Updates', '$_updateCount'),
              _buildStatItem(
                'Claim',
                deviceClaim?.ambulanceNumber ?? 'None',
              ),
              _buildStatItem(
                'Status',
                _isTracking ? 'Live' : 'Idle',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

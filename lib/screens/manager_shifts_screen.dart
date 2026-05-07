import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/company_staff_service.dart';
import '../services/shift_schedule_service.dart';
import '../services/tracking_presence_service.dart';

class ManagerShiftsScreenContent extends StatefulWidget {
  final User user;

  const ManagerShiftsScreenContent({Key? key, required this.user})
    : super(key: key);

  @override
  State<ManagerShiftsScreenContent> createState() =>
      _ManagerShiftsScreenContentState();
}

class _ManagerShiftsScreenContentState
    extends State<ManagerShiftsScreenContent> {
  final TrackingPresenceService _presenceService = TrackingPresenceService();
  final ShiftScheduleService _scheduleService = ShiftScheduleService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();

  bool _isLoading = true;
  bool _dayMode = true;
  DateTime _selectedDate = DateTime.now();
  List<TrackingShift> _liveShifts = [];
  List<TrackingClaim> _liveClaims = [];
  List<DriverShiftSchedule> _schedules = [];
  List<User> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _liveShifts = [];
        _liveClaims = [];
        _schedules = [];
        _drivers = [];
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _presenceService.fetchActiveShiftsForTenant(tenantId),
        _presenceService.fetchActiveClaimsForTenant(tenantId),
        _scheduleService.fetchTenantSchedules(tenantId),
        _companyStaffService.getCompanyDrivers(tenantId),
      ]);

      if (!mounted) return;
      setState(() {
        _liveShifts = results[0] as List<TrackingShift>;
        _liveClaims = results[1] as List<TrackingClaim>;
        _schedules = results[2] as List<DriverShiftSchedule>;
        _drivers = results[3] as List<User>;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les gardes : $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _endShift(TrackingShift shift) async {
    try {
      await _presenceService.managerEndShift(shift.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garde terminée avec succès.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de terminer la garde : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<DriverShiftSchedule> get _selectedDaySchedules =>
      _scheduleService.schedulesForDate(_schedules, _selectedDate);

  List<ShiftConflict> get _selectedConflicts =>
      _scheduleService.buildConflicts(_schedules, _selectedDate);

  Future<void> _showAssignShiftDialog({
    DriverShiftSchedule? existingSchedule,
  }) async {
    if (_drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun compte conducteur disponible pour cette société.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    User selectedDriver = existingSchedule == null
        ? _drivers.first
        : _drivers.firstWhere(
            (driver) => driver.id == existingSchedule.driverUserId,
            orElse: () => _drivers.first,
          );

    ShiftRecurrence recurrence =
        existingSchedule?.recurrenceType ?? ShiftRecurrence.daily;
    String scheduleType =
        existingSchedule?.scheduleType ?? DriverShiftSchedule.typeShift;
    int selectedWeekday = existingSchedule?.weekday ?? _selectedDate.weekday;
    DateTime startsOn =
        existingSchedule?.startsOn ??
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime? endsOn = existingSchedule?.endsOn;
    TimeOfDay startTime =
        _parseTimeOfDay(existingSchedule?.startTime) ??
        const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime =
        _parseTimeOfDay(existingSchedule?.endTime) ??
        const TimeOfDay(hour: 16, minute: 0);
    final labelController = TextEditingController(
      text: existingSchedule?.shiftLabel ?? 'Jour',
    );
    final reasonController = TextEditingController(
      text: existingSchedule?.absenceReason ?? '',
    );
    bool autoTracking = existingSchedule?.autoStartTracking ?? true;
    bool updateAll = true;
    bool isSaving = false;

    void applyTemplate(String label, TimeOfDay start, TimeOfDay end) {
      labelController.text = label;
      startTime = start;
      endTime = end;
    }

    void applyScheduleType(String type) {
      scheduleType = type;
      if (type == DriverShiftSchedule.typeShift) {
        if (labelController.text.trim().isEmpty ||
            labelController.text.trim() == 'Repos' ||
            labelController.text.trim() == 'Weekend' ||
            labelController.text.trim() == 'Congé' ||
            labelController.text.trim() == 'Maladie') {
          labelController.text = 'Jour';
        }
        autoTracking = existingSchedule?.autoStartTracking ?? true;
      } else {
        labelController.text = _scheduleTypeLabel(type);
        autoTracking = false;
        startTime = const TimeOfDay(hour: 0, minute: 0);
        endTime = const TimeOfDay(hour: 23, minute: 59);
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isWorkingShift =
                scheduleType == DriverShiftSchedule.typeShift;

            Future<void> pickDate({
              required DateTime initialDate,
              required ValueChanged<DateTime> onPicked,
              DateTime? firstDate,
            }) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate:
                    firstDate ??
                    DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null) {
                setDialogState(() => onPicked(picked));
              }
            }

            Future<void> pickTime({
              required TimeOfDay initialTime,
              required ValueChanged<TimeOfDay> onPicked,
            }) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );
              if (picked != null) {
                setDialogState(() => onPicked(picked));
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFFFBEAEA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existingSchedule == null
                            ? 'Affecter une garde'
                            : 'Modifier la garde',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24324A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dialogLabel('Conducteur'),
                      const SizedBox(height: 6),
                      _dialogShell(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDriver.id,
                            isExpanded: true,
                            items: _drivers
                                .map(
                                  (driver) => DropdownMenuItem(
                                    value: driver.id,
                                    child: Text(driver.name),
                                  ),
                                )
                                .toList(),
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setDialogState(() {
                                      selectedDriver = _drivers.firstWhere(
                                        (driver) => driver.id == value,
                                      );
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _dialogLabel('Type de planning'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _scheduleTypeChip(
                            label: 'Garde',
                            selected:
                                scheduleType == DriverShiftSchedule.typeShift,
                            onTap: () => setDialogState(
                              () => applyScheduleType(
                                DriverShiftSchedule.typeShift,
                              ),
                            ),
                          ),
                          _scheduleTypeChip(
                            label: 'Repos',
                            selected:
                                scheduleType == DriverShiftSchedule.typeRest,
                            onTap: () => setDialogState(
                              () => applyScheduleType(
                                DriverShiftSchedule.typeRest,
                              ),
                            ),
                          ),
                          _scheduleTypeChip(
                            label: 'Weekend',
                            selected:
                                scheduleType == DriverShiftSchedule.typeWeekend,
                            onTap: () => setDialogState(
                              () => applyScheduleType(
                                DriverShiftSchedule.typeWeekend,
                              ),
                            ),
                          ),
                          _scheduleTypeChip(
                            label: 'Congé',
                            selected:
                                scheduleType == DriverShiftSchedule.typeLeave,
                            onTap: () => setDialogState(
                              () => applyScheduleType(
                                DriverShiftSchedule.typeLeave,
                              ),
                            ),
                          ),
                          _scheduleTypeChip(
                            label: 'Maladie',
                            selected:
                                scheduleType ==
                                DriverShiftSchedule.typeSickLeave,
                            onTap: () => setDialogState(
                              () => applyScheduleType(
                                DriverShiftSchedule.typeSickLeave,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _dialogLabel('Nom de la garde'),
                      const SizedBox(height: 6),
                      _dialogShell(
                        child: TextField(
                          controller: labelController,
                          enabled: !isSaving,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Jour',
                          ),
                        ),
                      ),
                      if (!isWorkingShift) ...[
                        const SizedBox(height: 10),
                        _dialogLabel('Motif (optionnel)'),
                        const SizedBox(height: 6),
                        _dialogShell(
                          child: TextField(
                            controller: reasonController,
                            enabled: !isSaving,
                            decoration: const InputDecoration.collapsed(
                              hintText: 'Ex : congé annuel, repos...',
                            ),
                          ),
                        ),
                      ],
                      if (isWorkingShift) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _presetChip(
                              label: 'Jour',
                              onTap: () => setDialogState(
                                () => applyTemplate(
                                  'Jour',
                                  const TimeOfDay(hour: 8, minute: 0),
                                  const TimeOfDay(hour: 16, minute: 0),
                                ),
                              ),
                            ),
                            _presetChip(
                              label: 'Soir',
                              onTap: () => setDialogState(
                                () => applyTemplate(
                                  'Soir',
                                  const TimeOfDay(hour: 10, minute: 0),
                                  const TimeOfDay(hour: 18, minute: 0),
                                ),
                              ),
                            ),
                            _presetChip(
                              label: 'Nuit',
                              onTap: () => setDialogState(
                                () => applyTemplate(
                                  'Nuit',
                                  const TimeOfDay(hour: 16, minute: 0),
                                  const TimeOfDay(hour: 3, minute: 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6D8D8),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA46A6A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _segmentButton(
                                label: 'Quotidien',
                                selected: recurrence == ShiftRecurrence.daily,
                                onTap: () => setDialogState(
                                  () => recurrence = ShiftRecurrence.daily,
                                ),
                              ),
                              _segmentButton(
                                label: 'Hebdomadaire',
                                selected: recurrence == ShiftRecurrence.weekly,
                                onTap: () => setDialogState(
                                  () => recurrence = ShiftRecurrence.weekly,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dialogLabel('Débute le'),
                      const SizedBox(height: 6),
                      _tapShell(
                        label: _formatShortDate(startsOn),
                        onTap: isSaving
                            ? null
                            : () => pickDate(
                                initialDate: startsOn,
                                onPicked: (picked) => startsOn = picked,
                              ),
                      ),
                      const SizedBox(height: 10),
                      _dialogLabel('Se termine le (optionnel)'),
                      const SizedBox(height: 6),
                      _tapShell(
                        label: endsOn == null
                            ? 'Aucune date de fin'
                            : _formatShortDate(endsOn!),
                        onTap: isSaving
                            ? null
                            : () => pickDate(
                                initialDate: endsOn ?? startsOn,
                                firstDate: startsOn,
                                onPicked: (picked) => endsOn = picked,
                              ),
                      ),
                      if (recurrence == ShiftRecurrence.weekly) ...[
                        const SizedBox(height: 10),
                        _dialogLabel('Jour de la semaine'),
                        const SizedBox(height: 6),
                        _dialogShell(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedWeekday,
                              isExpanded: true,
                              items: List.generate(
                                7,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(_weekdayLabel(index + 1)),
                                ),
                              ),
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(
                                        () => selectedWeekday = value,
                                      );
                                    },
                            ),
                          ),
                        ),
                      ],
                      if (isWorkingShift) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dialogLabel('Heure de début'),
                                  const SizedBox(height: 6),
                                  _tapShell(
                                    label: _formatTimeOfDay(startTime),
                                    onTap: isSaving
                                        ? null
                                        : () => pickTime(
                                            initialTime: startTime,
                                            onPicked: (picked) =>
                                                startTime = picked,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dialogLabel('Heure de fin'),
                                  const SizedBox(height: 6),
                                  _tapShell(
                                    label: _formatTimeOfDay(endTime),
                                    onTap: isSaving
                                        ? null
                                        : () => pickTime(
                                            initialTime: endTime,
                                            onPicked: (picked) =>
                                                endTime = picked,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Démarrer le suivi automatiquement',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B4B4B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Démarre automatiquement le GPS de l’ambulance sélectionnée quand cette garde devient active.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: autoTracking,
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(
                                        () => autoTracking = value,
                                      );
                                    },
                              activeColor: const Color(0xFFA65C56),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        Text(
                          'Cette entrée bloque la journée du conducteur sans démarrer le suivi GPS.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (existingSchedule != null) ...[
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: updateAll,
                          onChanged: isSaving
                              ? null
                              : (value) => setDialogState(
                                  () => updateAll = value ?? true,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Modifier toute la série'),
                          subtitle: const Text(
                            'Appliquer la modification à toute la garde récurrente.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final tenantId = widget.user.tenantId;
                                    if (tenantId == null ||
                                        tenantId.isEmpty ||
                                        labelController.text.trim().isEmpty) {
                                      return;
                                    }
                                    final effectiveLabel = labelController.text
                                        .trim();
                                    final effectiveReason =
                                        reasonController.text.trim().isEmpty
                                        ? null
                                        : reasonController.text.trim();
                                    final effectiveStartTime = isWorkingShift
                                        ? _formatTimeOfDay(startTime)
                                        : '00:00';
                                    final effectiveEndTime = isWorkingShift
                                        ? _formatTimeOfDay(endTime)
                                        : '23:59';
                                    final effectiveAutoTracking =
                                        isWorkingShift && autoTracking;

                                    setDialogState(() => isSaving = true);
                                    try {
                                      if (existingSchedule == null) {
                                        await _scheduleService.createSchedule(
                                          tenantId: tenantId,
                                          driver: selectedDriver,
                                          createdBy: widget.user.id,
                                          recurrence: recurrence,
                                          shiftLabel: effectiveLabel,
                                          scheduleType: scheduleType,
                                          absenceReason: effectiveReason,
                                          startsOn: startsOn,
                                          endsOn: endsOn,
                                          weekday:
                                              recurrence ==
                                                  ShiftRecurrence.weekly
                                              ? selectedWeekday
                                              : null,
                                          startTime: effectiveStartTime,
                                          endTime: effectiveEndTime,
                                          autoStartTracking:
                                              effectiveAutoTracking,
                                        );
                                      } else if (updateAll) {
                                        await _scheduleService.updateSchedule(
                                          scheduleId: existingSchedule.id,
                                          shiftLabel: effectiveLabel,
                                          scheduleType: scheduleType,
                                          absenceReason: effectiveReason,
                                          recurrence: recurrence,
                                          startsOn: startsOn,
                                          endsOn: endsOn,
                                          weekday:
                                              recurrence ==
                                                  ShiftRecurrence.weekly
                                              ? selectedWeekday
                                              : null,
                                          startTime: effectiveStartTime,
                                          endTime: effectiveEndTime,
                                          autoStartTracking:
                                              effectiveAutoTracking,
                                          isActive: true,
                                        );
                                      }

                                      if (!mounted) return;
                                      Navigator.of(dialogContext).pop();
                                      await _loadData();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Garde enregistrée.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (error) {
                                      if (!mounted) return;
                                      setDialogState(() => isSaving = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Impossible d’enregistrer la garde : $error',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA65C56),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignShiftDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Affecter une garde',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _buildTopControls(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    label: 'Actives',
                    value: '${_liveShifts.length}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: 'En attente',
                    value: '${_pendingCount()}',
                    color: const Color(0xFFE27D60),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: 'Conflits',
                    value: '${_selectedConflicts.length}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _dayMode ? _buildDayTimeline() : _buildWeekList(),
            if (_selectedConflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildConflictCard(_selectedConflicts.first),
            ],
            const SizedBox(height: 18),
            _buildLiveOverviewCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF4)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _modeTab(
                  label: 'Jour',
                  selected: _dayMode,
                  onTap: () => setState(() => _dayMode = true),
                ),
                _modeTab(
                  label: 'Semaine',
                  selected: !_dayMode,
                  onTap: () => setState(() => _dayMode = false),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        Duration(days: _dayMode ? 1 : 7),
                      );
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    _dayMode
                        ? _formatLongDate(_selectedDate)
                        : 'Semaine du ${_formatShortDate(_weekStart(_selectedDate))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        Duration(days: _dayMode ? 1 : 7),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0F2F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTimeline() {
    final schedules = _selectedDaySchedules;
    if (schedules.isEmpty) {
      return _emptyCard('Aucune garde prévue pour cette journée.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAF0F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.only(left: 88, right: 16),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
            ),
            child: Row(
              children: _timelineHours().map((hour) {
                return Expanded(
                  child: Text(
                    hour,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          ...schedules.map(_buildTimelineRow),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(DriverShiftSchedule schedule) {
    final color = _scheduleColor(schedule);
    final conflict = _selectedConflicts.any(
      (item) => item.first.id == schedule.id || item.second.id == schedule.id,
    );
    final leftFraction = schedule.isWorkingShift
        ? schedule.startMinutes / (24 * 60)
        : 0.0;
    var duration = schedule.endMinutes - schedule.startMinutes;
    if (duration <= 0) {
      duration += 24 * 60;
    }
    final widthFraction = schedule.isWorkingShift
        ? (duration / (24 * 60)).clamp(0.14, 0.9)
        : 0.98;

    return Container(
      height: 92,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initials(schedule.driverName),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  schedule.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF31435B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final left = constraints.maxWidth * leftFraction;
                final width = constraints.maxWidth * widthFraction;
                return Stack(
                  children: [
                    Positioned(
                      left: left.clamp(0.0, constraints.maxWidth - 120),
                      top: 15,
                      child: GestureDetector(
                        onTap: () =>
                            _showAssignShiftDialog(existingSchedule: schedule),
                        child: Container(
                          width: width.clamp(120.0, constraints.maxWidth - 8),
                          height: 62,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    schedule.displayTimeRangeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      height: 1.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    conflict
                                        ? 'Conflit'
                                        : schedule.isWorkingShift
                                        ? 'Confirmée'
                                        : schedule.scheduleTypeLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (conflict)
                                Positioned(
                                  left: -14,
                                  top: 15,
                                  child: Container(
                                    width: 5,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE85B5B),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekList() {
    final start = _weekStart(_selectedDate);
    return Column(
      children: List.generate(7, (index) {
        final day = start.add(Duration(days: index));
        final schedules = _scheduleService.schedulesForDate(_schedules, day);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEAF0F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatShortDate(day),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              if (schedules.isEmpty)
                Text(
                  'Aucune garde prévue',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...schedules.map(
                  (schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.driverName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(schedule.displayLabel),
                        const SizedBox(width: 12),
                        Text(
                          schedule.displayTimeRangeLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildConflictCard(ShiftConflict conflict) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3C6C6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred, color: Colors.red, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conflit de planning détecté',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _conflictMessage(conflict),
                  style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAF0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suivi en direct',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF24324A),
            ),
          ),
          const SizedBox(height: 12),
          if (_liveShifts.isEmpty)
            Text(
              'Aucun conducteur n’est actuellement en garde active.',
              style: TextStyle(color: Colors.grey.shade700),
            )
          else
            ..._liveShifts.take(3).map((shift) {
              final claim = _liveClaims.where(
                (item) => item.shiftId == shift.id,
              );
              final activeClaim = claim.isEmpty ? null : claim.first;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        _initials(shift.driverName),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.driverName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeClaim == null
                                ? 'En garde, aucune ambulance attribuée'
                                : 'Suivi de ${activeClaim.ambulanceNumber}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _endShift(shift),
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _dialogShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _tapShell({required String label, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _presetChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE7B8B8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _scheduleTypeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFFE8E8),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFE7B8B8),
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : const Color(0xFF4B4B4B),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE8E8) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Color(0xFF7C6F6F)),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAF0F6)),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
    );
  }

  int _pendingCount() {
    return _selectedDaySchedules.where((schedule) {
      return schedule.isWorkingShift && !schedule.isActiveAt(DateTime.now());
    }).length;
  }

  List<String> _timelineHours() {
    return const [
      '08:00',
      '10:00',
      '12:00',
      '14:00',
      '16:00',
      '18:00',
      '20:00',
      '22:00',
    ];
  }

  Color _scheduleColor(DriverShiftSchedule schedule) {
    switch (schedule.scheduleType) {
      case DriverShiftSchedule.typeRest:
        return const Color(0xFF64748B);
      case DriverShiftSchedule.typeWeekend:
        return const Color(0xFF2563EB);
      case DriverShiftSchedule.typeLeave:
        return const Color(0xFF16A34A);
      case DriverShiftSchedule.typeSickLeave:
        return const Color(0xFFDC2626);
    }
    final label = schedule.shiftLabel.toLowerCase();
    if (label.contains('night') || label.contains('nuit')) {
      return const Color(0xFF41295A);
    }
    if (label.contains('evening') || label.contains('soir')) {
      return const Color(0xFFE27D60);
    }
    return AppColors.primary;
  }

  String _scheduleTypeLabel(String type) {
    switch (type) {
      case DriverShiftSchedule.typeRest:
        return 'Repos';
      case DriverShiftSchedule.typeWeekend:
        return 'Weekend';
      case DriverShiftSchedule.typeLeave:
        return 'Congé';
      case DriverShiftSchedule.typeSickLeave:
        return 'Maladie';
      default:
        return 'Jour';
    }
  }

  DateTime _weekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lundi';
      case DateTime.tuesday:
        return 'Mardi';
      case DateTime.wednesday:
        return 'Mercredi';
      case DateTime.thursday:
        return 'Jeudi';
      case DateTime.friday:
        return 'Vendredi';
      case DateTime.saturday:
        return 'Samedi';
      default:
        return 'Dimanche';
    }
  }

  String _monthLabel(int month) {
    switch (month) {
      case DateTime.january:
        return 'janv.';
      case DateTime.february:
        return 'févr.';
      case DateTime.march:
        return 'mars';
      case DateTime.april:
        return 'avr.';
      case DateTime.may:
        return 'mai';
      case DateTime.june:
        return 'juin';
      case DateTime.july:
        return 'juil.';
      case DateTime.august:
        return 'août';
      case DateTime.september:
        return 'sept.';
      case DateTime.october:
        return 'oct.';
      case DateTime.november:
        return 'nov.';
      default:
        return 'déc.';
    }
  }

  String _formatShortDate(DateTime date) =>
      '${_weekdayLabel(date.weekday).substring(0, 3)}, ${date.day} ${_monthLabel(date.month)}';

  String _formatLongDate(DateTime date) =>
      '${_weekdayLabel(date.weekday)}, ${date.day} ${_monthLabel(date.month)}';

  String _conflictMessage(ShiftConflict conflict) {
    return '${conflict.driverName} a des gardes qui se chevauchent : '
        '${conflict.first.timeRangeLabel} et ${conflict.second.timeRangeLabel}.';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

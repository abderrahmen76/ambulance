import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../services/company_staff_service.dart';
import '../services/mission_service.dart';
import '../services/pdf_service.dart';
import '../services/realtime_event_bus_service.dart';
import '../utils/responsive.dart';
import '../widgets/clinic_dropdown_field.dart';
import '../widgets/patient_request_summary_card.dart';
import 'mission_technical_sheet_screen.dart';

class ActiveMissionsScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;

  const ActiveMissionsScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
  }) : super(key: key);

  @override
  State<ActiveMissionsScreen> createState() => _ActiveMissionsScreenState();
}

class _ActiveMissionsScreenState extends State<ActiveMissionsScreen> {
  final MissionService _missionService = MissionService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'pending'; // pending, active, completed
  bool _hasActiveMission = false;
  List<User> _companyStaff = [];
  List<Mission> _cachedMissions = [];
  StreamSubscription<RealtimeAppEvent>? _realtimeSubscription;

  Future<void> _checkActiveMission({bool forceRefresh = false}) async {
    try {
      final activeMissions = await _missionService.getActiveMissions(
        widget.ambulanceId,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _hasActiveMission = activeMissions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking active missions: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _realtimeSubscription =
        RealtimeEventBusService.instance.stream.listen(_handleRealtimeEvent);
    _loadMissions();
    _checkActiveMission();
    _loadCompanyStaff();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanyStaff() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return;
    }

    try {
      final staff = await _companyStaffService.getCompanyStaff(tenantId);
      if (!mounted) return;
      setState(() {
        _companyStaff = staff
            .where((member) => member.id != widget.user.id)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading company staff: $e');
    }
  }

  void _loadMissions({bool forceRefresh = false}) {
    if (mounted) {
      setState(() {
        // For pending missions, use getAvailableMissions() to fetch all pending missions
        // For active/completed, use getMissionsForAmbulance() to fetch missions assigned to this ambulance
        if (_selectedStatus == 'pending') {
          _allMissionsFuture = _missionService.getAvailableMissions(
            widget.ambulanceId,
            forceRefresh: forceRefresh,
          );
        } else {
          _allMissionsFuture = _missionService.getMissionsForAmbulance(
            widget.ambulanceId,
            forceRefresh: forceRefresh,
          );
        }
      });
    }
  }

  void _handleRealtimeEvent(RealtimeAppEvent event) {
    if (!mounted) return;
    if (event.type == RealtimeEventType.missionRefreshRequested) {
      _loadMissions(forceRefresh: true);
      _checkActiveMission(forceRefresh: true);
      return;
    }
    if (_cachedMissions.isEmpty) return;
    if (event.type == RealtimeEventType.ambulanceUpdated) return;

    final updated = List<Mission>.from(_cachedMissions);

    if (event.type == RealtimeEventType.missionDeleted) {
      final missionId = event.recordId;
      if (missionId == null) return;
      updated.removeWhere((mission) => mission.id == missionId);
    } else {
      final mission = event.mission;
      if (mission == null) return;
      final index = updated.indexWhere((item) => item.id == mission.id);
      final shouldInclude = _missionBelongsInCurrentDriverList(mission);

      if (index == -1 && shouldInclude) {
        updated.insert(0, mission);
      } else if (index != -1 && shouldInclude) {
        updated[index] = mission;
      } else if (index != -1) {
        updated.removeAt(index);
      }
    }

    _cachedMissions = updated;
    final eventMission = event.mission;
    final eventIsActiveForAmbulance = eventMission != null &&
        eventMission.status == 'active' &&
        (eventMission.ambulanceId == widget.ambulanceId ||
            eventMission.assignedAmbulanceId == widget.ambulanceId);

    setState(() {
      _hasActiveMission =
          updated.any((mission) => mission.status == 'active') ||
              eventIsActiveForAmbulance;
      _allMissionsFuture = Future.value(List<Mission>.from(_cachedMissions));
    });
  }

  bool _missionBelongsInCurrentDriverList(Mission mission) {
    final tenantId = widget.user.tenantId;
    final sameTenant = tenantId != null &&
        tenantId.isNotEmpty &&
        (mission.tenantId == tenantId ||
            mission.assignedCompanyId == tenantId ||
            mission.selectedProviderTenantId == tenantId);
    final assignedToAmbulance = mission.ambulanceId == widget.ambulanceId ||
        mission.assignedAmbulanceId == widget.ambulanceId;

    if (_selectedStatus == 'pending') {
      return mission.status == 'pending' && (sameTenant || assignedToAmbulance);
    }

    return mission.status == _selectedStatus && assignedToAmbulance;
  }

  Future<Mission> _hydrateMissionForPhi(Mission mission) async {
    try {
      return await _missionService.hydrateMissionWithPrivateData(mission);
    } catch (e) {
      debugPrint(
        '[ActiveMissionsScreen] Warning: could not hydrate private mission data for ${mission.id}: $e',
      );
      return mission;
    }
  }

  Future<void> _openClinicMissionNavigation(Mission mission) async {
    final isPickupReached = mission.dispatchPhase == 'en_route';
    final launchUrlString = _buildClinicMissionNavigationUrl(
      mission,
      isPickupReached,
    );

    if (launchUrlString == null || launchUrlString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune URL de navigation disponible pour cette mission',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(launchUrlString);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _buildClinicMissionNavigationUrl(
    Mission mission,
    bool isPickupReached,
  ) {
    if (isPickupReached) {
      if (_hasCoordinates(mission.pickupLat, mission.pickupLng) &&
          _hasCoordinates(mission.destinationLat, mission.destinationLng)) {
        return 'https://www.google.com/maps/dir/?api=1'
            '&origin=${mission.pickupLat},${mission.pickupLng}'
            '&destination=${mission.destinationLat},${mission.destinationLng}'
            '&travelmode=driving';
      }

      return mission.destinationGoogleMapsUrl ??
          _buildSearchUrl(mission.destinationAddress);
    }

    if (_hasCoordinates(mission.pickupLat, mission.pickupLng)) {
      return 'https://www.google.com/maps/dir/?api=1'
          '&destination=${mission.pickupLat},${mission.pickupLng}'
          '&travelmode=driving';
    }

    return mission.pickupGoogleMapsUrl ??
        _buildSearchUrl(mission.pickupAddress);
  }

  bool _canOpenClinicMissionNavigation(Mission mission) {
    final isPickupReached = mission.dispatchPhase == 'en_route';
    final launchUrlString = _buildClinicMissionNavigationUrl(
      mission,
      isPickupReached,
    );
    return launchUrlString != null && launchUrlString.isNotEmpty;
  }

  bool _hasCoordinates(String? lat, String? lng) {
    return (lat != null && lat.isNotEmpty) && (lng != null && lng.isNotEmpty);
  }

  String? _buildSearchUrl(String? address) {
    if (address == null || address.trim().isEmpty) {
      return null;
    }
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}';
  }

  Future<void> _markArrivedAtPickup(Mission mission) async {
    try {
      await _missionService.updateMissionStatus(mission.id, 'active');
      _loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrivée au point de prise en charge enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Status Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildStatusTab('En Attente', 'pending'),
                const SizedBox(width: 8),
                _buildStatusTab('Actif', 'active'),
                const SizedBox(width: 8),
                _buildStatusTab('Complétée', 'completed'),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          // Missions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                _loadMissions(forceRefresh: true);
                _checkActiveMission(forceRefresh: true);
                return _allMissionsFuture;
              },
              child: FutureBuilder<List<Mission>>(
                future: _allMissionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('Mission loading error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[300],
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erreur lors du chargement des missions',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.red[600]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allMissions = snapshot.data ?? [];
                  _cachedMissions = allMissions;
                  // For pending missions, all missions are already pending (filtered by query)
                  // For active/completed, need to filter again
                  var filteredMissions = (_selectedStatus == 'pending')
                      ? allMissions
                      : allMissions
                            .where(
                              (mission) => mission.status == _selectedStatus,
                            )
                            .toList();

                  // Sort all missions by newest first
                  filteredMissions.sort((a, b) {
                    try {
                      final dateA = DateTime.parse(
                        a.missionDate ?? '1970-01-01',
                      );
                      final dateB = DateTime.parse(
                        b.missionDate ?? '1970-01-01',
                      );
                      return dateB.compareTo(
                        dateA,
                      ); // Descending order (newest first)
                    } catch (e) {
                      return 0;
                    }
                  });

                  if (filteredMissions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedStatus == 'active'
                                ? Icons.assignment_turned_in
                                : _selectedStatus == 'completed'
                                ? Icons.check_circle
                                : Icons.schedule,
                            color: Colors.grey[400],
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune mission ${_selectedStatus == 'active'
                                ? 'active'
                                : _selectedStatus == 'completed'
                                ? 'complétée'
                                : 'en attente'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildMissionsList(
                    context,
                    filteredMissions,
                    _selectedStatus == 'pending',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedStatus == status) return;
          setState(() {
            _selectedStatus = status;
          });
          _loadMissions(forceRefresh: true);
          _checkActiveMission(forceRefresh: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionsList(
    BuildContext context,
    List<Mission> missions,
    bool isPending,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      child: Column(
        children: missions.asMap().entries.map((entry) {
          final mission = entry.value;
          final isActive = _selectedStatus == 'active';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMissionCardCompact(
              context,
              mission,
              isActive,
              isPending,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissionCardCompact(
    BuildContext context,
    Mission mission,
    bool isActive,
    bool isPending,
  ) {
    final isPriority = (mission.priority ?? '').toUpperCase() == 'CRITICAL';
    final clinicName = mission.clinicName?.trim();
    final clinicLabel = (clinicName != null && clinicName.isNotEmpty)
        ? clinicName
        : 'Mission clinique';
    final isGuestPatientMission = mission.isGuestPatientMission;
    final isClinicMission =
        mission.clinicTenantId != null && mission.clinicTenantId!.isNotEmpty;
    final accentColor = isClinicMission
        ? const Color(0xFF7C3AED)
        : (isGuestPatientMission ? const Color(0xFF0F766E) : AppColors.primary);

    return Container(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      decoration: BoxDecoration(
        color: isClinicMission ? const Color(0xFFF8F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(
          context.responsive.radiusLarge.topLeft.x,
        ),
        border: Border.all(
          color: isClinicMission ? const Color(0xFFD8B4FE) : Colors.grey[200]!,
          width: isClinicMission ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isClinicMission ? const Color(0xFF7C3AED) : Colors.black)
                .withOpacity(isClinicMission ? 0.10 : 0.05),
            blurRadius: isClinicMission ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isClinicMission) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MISSION CLINIQUE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clinicLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isGuestPatientMission) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MISSION PATIENT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mission.requestedCompanyName ?? 'Najda / Patient App',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION #${mission.missionNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isClinicMission) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital,
                            size: 15,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              clinicLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isGuestPatientMission &&
                        mission.requestedAmbulanceNumber != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 15,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Preferee pour ${mission.requestedAmbulanceNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      mission.missionDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isClinicMission
                            ? const Color(0xFF6D28D9)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPriority
                      ? Colors.orange
                      : (isClinicMission
                            ? accentColor
                            : (isGuestPatientMission
                                  ? const Color(0xFF0F766E)
                                  : Colors.blue)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPriority
                      ? 'CRITICAL'
                      : (isClinicMission
                            ? 'CLINIC'
                            : (isGuestPatientMission
                                  ? 'PATIENT APP'
                                  : 'NORMAL')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Icon(Icons.location_on, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.pickupDisplayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.toLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (mission.hasPatientRequestDetails) ...[
            const SizedBox(height: 12),
            PatientRequestSummaryCard(
              mission: mission,
              dense: !isActive,
              accentColor: accentColor,
            ),
          ],
          const SizedBox(height: 12),

          // Patient and Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Infirmier',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    mission.infirmierName ?? 'Non assigné',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (isActive)
                ElevatedButton.icon(
                  onPressed: !kIsWeb
                      ? () async {
                          final hydratedMission = await _hydrateMissionForPhi(
                            mission,
                          );
                          final patientPhone =
                              hydratedMission.patientPhone?.trim();
                          if (patientPhone == null || patientPhone.isEmpty) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Aucun numero patient disponible',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          await _makePhoneCall(patientPhone);
                        }
                      : null,
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Appeler Patient'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment Status
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isClinicMission
                  ? const Color(0xFFF3E8FF)
                  : (isGuestPatientMission
                        ? const Color(0xFFF0FDFA)
                        : Colors.grey[50]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paiement: ${mission.isPaid == true ? 'PAYÉ' : 'NON PAYÉ'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mission.isPaid == true ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  mission.paymentType ?? 'Non spécifié',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          if (mission.hasMissionPhoto) ...[
            const SizedBox(height: 12),
            _buildMissionPhotoPreview(mission),
          ],

          // Action Buttons (for active and pending missions)
          if (isActive || isPending) ...[
            const SizedBox(height: 12),
            // Accept button (only for pending missions)
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _hasActiveMission
                      ? null
                      : () => _showAcceptMissionDialog(context, mission),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text(
                    _hasActiveMission ? 'Mission en cours' : 'Accepter',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasActiveMission
                        ? Colors.grey[400]
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            // Edit button - full width (only for active missions)
            if (isActive) ...[
              if (isClinicMission || isGuestPatientMission) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _canOpenClinicMissionNavigation(mission)
                        ? () => _openClinicMissionNavigation(mission)
                        : null,
                    icon: const Icon(Icons.navigation, size: 16),
                    label: Text(
                      mission.dispatchPhase == 'en_route'
                          ? 'Trajet vers destination'
                          : 'Trajet vers patient',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (mission.dispatchPhase != 'en_route') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _markArrivedAtPickup(mission),
                      icon: const Icon(Icons.flag, size: 16),
                      label: const Text('Arrivé au pickup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              if (isPending) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final hydratedMission = await _hydrateMissionForPhi(
                      mission,
                    );
                    if (!mounted) return;
                    _showEditMissionDataDialog(context, hydratedMission);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier les Données'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showActionConfirmation(
                        context,
                        'COMPLETE',
                        'completed',
                        mission,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Compléter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showActionConfirmation(
                        context,
                        'CANCEL',
                        'cancelled',
                        mission,
                      ),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Annuler'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MissionTechnicalSheetScreen(mission: mission),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('Détails'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Print and Invoice buttons - only for active/completed missions, not pending
            if (!isPending &&
                mission.reportType != null &&
                mission.reportType!.isNotEmpty &&
                mission.reportType != 'not_filled') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateMissionPDF(context, mission),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateInvoice(context, mission),
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('Facture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateInvoice(context, mission),
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('Facture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          // Imprimer and Facture buttons for completed missions
          if (!isActive && !isPending) ...[
            const SizedBox(height: 8),
            if (mission.reportType != null &&
                mission.reportType!.isNotEmpty &&
                mission.reportType != 'not_filled') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateMissionPDF(context, mission),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateInvoice(context, mission),
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('Facture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateInvoice(context, mission),
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('Facture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<String?> _getMissionPhotoSignedUrl(Mission mission) async {
    final bucket = mission.missionPhotoBucket;
    final path = mission.missionPhotoPath;
    if (bucket == null || path == null) {
      return null;
    }

    try {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
    } catch (error) {
      debugPrint('[ActiveMissions] failed to sign mission photo url: $error');
      return null;
    }
  }

  Widget _buildMissionPhotoPreview(Mission mission) {
    return FutureBuilder<String?>(
      future: _getMissionPhotoSignedUrl(mission),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final imageUrl = snapshot.data;
        if (imageUrl == null || imageUrl.isEmpty) {
          return const SizedBox.shrink();
        }

        return InkWell(
          onTap: () => _showMissionPhotoDialog(context, mission, imageUrl),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 84,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84,
                      height: 72,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo jointe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Touchez pour agrandir la photo du patient.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_full_rounded, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMissionPhotoDialog(
    BuildContext context,
    Mission mission,
    String imageUrl,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photo mission #${mission.missionNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Impossible de charger la photo.'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptMissionDialog(BuildContext context, Mission mission) {
    final driverNameController = TextEditingController(text: widget.user.name);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool isAccepting = false;
    final selectedTeammateIds = <String>{};

    void updateDriverNames() {
      final teammateNames = _companyStaff
          .where((member) => selectedTeammateIds.contains(member.id))
          .map((member) => member.name)
          .toList();
      driverNameController.text = <String>[
        widget.user.name,
        ...teammateNames,
      ].join(', ');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Accepter la Mission'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mission: #${mission.missionNumber}'),
                  const SizedBox(height: 12),
                  Text('De: ${mission.pickupDisplayLabel}'),
                  if (mission.isGuestPatientMission &&
                      mission.requestedAmbulanceNumber != null) ...[
                    const SizedBox(height: 8),
                    Text('Preferee pour: ${mission.requestedAmbulanceNumber}'),
                  ],
                  const SizedBox(height: 8),
                  Text('Vers: ${mission.toLocation}'),
                  if (mission.hasMissionPhoto) ...[
                    const SizedBox(height: 14),
                    _buildMissionPhotoPreview(mission),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: driverNameController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Nom du chauffeur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_companyStaff.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ajouter d\'autres utilisateurs de la société',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _companyStaff
                          .map(
                            (member) => FilterChip(
                              label: Text(member.name),
                              selected: selectedTeammateIds.contains(member.id),
                              onSelected: isAccepting
                                  ? null
                                  : (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedTeammateIds.add(member.id);
                                        } else {
                                          selectedTeammateIds.remove(member.id);
                                        }
                                        updateDriverNames();
                                      });
                                    },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAccepting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isAccepting
                    ? null
                    : () async {
                        if (driverNameController.text.isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez entrer le nom du chauffeur',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isAccepting = true);
                        Navigator.of(dialogContext).pop();

                        try {
                          // Show loading message
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✋ Acceptation de la mission en cours...',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          print(
                            '🟠 [ActiveMissions] Mission acceptance started',
                          );
                          print(
                            '🟠 [ActiveMissions] Mission ID: ${mission.id}',
                          );
                          print(
                            '🟠 [ActiveMissions] Mission Number: ${mission.missionNumber}',
                          );
                          print(
                            '🟠 [ActiveMissions] Ambulance ID passed: ${widget.ambulanceId}',
                          );
                          print(
                            '🟠 [ActiveMissions] Driver Name: ${driverNameController.text}',
                          );

                          // Accept mission (update status to 'active')
                          await _missionService.acceptMission(
                            mission.id,
                            widget.ambulanceId,
                            driverNameController.text,
                          );

                          print(
                            '🟠 [ActiveMissions] ✅ Mission accepted successfully',
                          );

                          // Add delay to ensure backend sync before reload
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          // Reload missions after successful update
                          if (mounted) {
                            print('🟠 [ActiveMissions] Reloading missions...');
                            _loadMissions();
                          }

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Mission #${mission.missionNumber} acceptée! Bienvenue ${driverNameController.text}',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          print(
                            '🔴 [ActiveMissions] ERROR accepting mission: ${e.toString()}',
                          );
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '❌ Erreur lors de l\'acceptation: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAccepting ? Colors.grey : null,
                ),
                child: isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Accepter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showActionConfirmation(
    BuildContext context,
    String action,
    String newStatus,
    Mission mission,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Confirmer l\'Action'),
            content: Text('Êtes-vous sûr de vouloir ${action.toLowerCase()}?'),
            actions: [
              TextButton(
                onPressed: isProcessing
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        Navigator.pop(dialogContext);

                        try {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('⏳ ${action} en cours...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          await _missionService.updateMissionStatus(
                            mission.id,
                            newStatus,
                          );

                          // Add delay to ensure backend sync before reload
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          // Reload missions after successful update
                          if (mounted) {
                            _loadMissions();
                          }

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('✅ ${action} réussie!'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('❌ Erreur: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProcessing ? Colors.grey : null,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lancer l\'appel téléphonique: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(
    BuildContext context,
    String title,
    String initialValue,
    String fieldKey,
    Mission mission,
  ) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Modifier $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Entrez $title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _updateMissionField(mission, fieldKey, controller.text);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMissionField(
    Mission mission,
    String fieldKey,
    String newValue,
  ) async {
    try {
      await _missionService.updateMissionField(mission.id, fieldKey, newValue);

      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mis à jour avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePaymentStatus(Mission mission) async {
    try {
      final newStatus = !(mission.isPaid ?? false);
      await _missionService.updateMissionField(
        mission.id,
        'is_paid',
        newStatus,
      );

      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut du paiement mis à jour en ${newStatus ? 'PAYÉ' : 'NON PAYÉ'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPaymentStatusDialog(BuildContext context, Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le Statut de Paiement'),
        content: const Text('Sélectionner le statut de paiement:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentStatus(mission, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Marquer comme PAYÉ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentStatus(mission, false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Marquer comme NON PAYÉ'),
          ),
        ],
      ),
    );
  }

  void _showPaymentTypeDialog(BuildContext context, Mission mission) {
    final guaranteeController = TextEditingController(
      text: mission.guarantee ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String selectedType = mission.paymentType ?? 'cash';

            return AlertDialog(
              title: const Text('Modifier le Type de Paiement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choisir comment le patient paiera:'),
                    const SizedBox(height: 16),
                    // Payment type options
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('💵 cash'),
                            value: 'cash',
                            groupValue: selectedType,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value != null) {
                                  selectedType = value;
                                }
                              });
                            },
                          ),
                          const Divider(height: 0),
                          RadioListTile<String>(
                            title: const Text('📋 Sur Compte'),
                            value: 'charge',
                            groupValue: selectedType,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value != null) {
                                  selectedType = value;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Guarantee field - show when "Sur Compte" is selected
                    if (selectedType == 'charge') ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        '🔐 Garantie (Obligatoire)',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: guaranteeController,
                        decoration: InputDecoration(
                          hintText:
                              'ex: Carte d\'identité, Fiche paroissiale, Contrat...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.orange[50],
                        ),
                        maxLines: 2,
                        autofocus: true,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    guaranteeController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedType.isEmpty
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _updatePaymentTypeWithGuarantee(
                            mission,
                            selectedType,
                            selectedType == 'charge'
                                ? guaranteeController.text
                                : '',
                          );
                          guaranteeController.dispose();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('✅ Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updatePaymentStatus(Mission mission, bool isPaid) async {
    try {
      await _missionService.updateMissionField(
        mission.id,
        'payment_status',
        isPaid,
      );

      // Reload missions after successful update
      _loadMissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut du paiement mis à jour en ${isPaid ? 'PAYÉ' : 'NON PAYÉ'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentTypeWithGuarantee(
    Mission mission,
    String paymentType,
    String guarantee,
  ) async {
    try {
      // Update payment type
      await _missionService.updateMissionField(
        mission.id,
        'payment_type',
        paymentType,
      );

      // Update guarantee if "Sur Compte" is selected
      if (paymentType == 'charge' && guarantee.isNotEmpty) {
        await _missionService.updateMissionField(
          mission.id,
          'guarantee',
          guarantee,
        );
      }

      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentType == 'cash'
                  ? '✅ Type de paiement: Liquide'
                  : '✅ Type de paiement: Sur Compte${guarantee.isNotEmpty ? ' (Garantie: $guarantee)' : ''}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentType(Mission mission, String paymentType) async {
    try {
      await _missionService.updateMissionField(
        mission.id,
        'payment_type',
        paymentType,
      );

      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Type de paiement mis à jour en $paymentType'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMissionPDF(
    BuildContext context,
    Mission mission,
  ) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération du PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final hydratedMission = await _hydrateMissionForPhi(mission);

      // Generate and download PDF
      await PdfService.generateMissionReportPdf(hydratedMission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF généré avec succès!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ActiveMissionsScreen] PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la génération du PDF: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generateInvoice(BuildContext context, Mission mission) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération de la facture...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final hydratedMission = await _hydrateMissionForPhi(mission);

      // Generate and download invoice PDF
      await PdfService.generateInvoicePdf(hydratedMission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facture générée avec succès!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ActiveMissionsScreen] Invoice generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la génération de la facture: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showEditMissionDataDialog(BuildContext context, Mission mission) {
    final formKey = GlobalKey<FormState>();
    final fromLocationManualCtrl = TextEditingController(
      text: mission.fromLocation,
    );
    final toLocationManualCtrl = TextEditingController(
      text: mission.toLocation,
    );
    final patientNameCtrl = TextEditingController(
      text: mission.patientName ?? '',
    );
    final patientPhoneCtrl = TextEditingController(
      text: mission.patientPhone ?? '',
    );
    final infirmierNameCtrl = TextEditingController(
      text: mission.infirmierName ?? '',
    );
    final notesCtrl = TextEditingController(text: mission.notes ?? '');
    final tarifCtrl = TextEditingController(text: mission.missionPrice ?? '');
    final guaranteeCtrl = TextEditingController(text: mission.guarantee ?? '');

    String selectedFromLocationType = 'domicile'; // domicile or clinic
    String selectedFromClinic = '';
    String selectedFromCity = 'Sfax';

    String selectedToLocationType = 'domicile'; // domicile or clinic
    String selectedToClinic = '';
    String selectedToCity = 'Sfax';

    String selectedPaymentType =
        mission.paymentType ?? 'cash'; // 'cash' or 'charge'
    bool selectedIsPaid = mission.isPaid ?? false;
    bool isLoading = false;

    // Cities list (Tunisia and Libya)
    const cities = [
      'Sfax',
      'Tunis',
      'Sousse',
      'Kairouan',
      'Gabès',
      'Gafsa',
      'Jendouba',
      'Kasserine',
      'Kebili',
      'Tozeur',
      'Mdenine',
      'Bizerte',
      'Ariana',
      'Ben Arous',
      'Manouba',
      'Nabeul',
      'Hammamet',
      'Monastir',
      'Mahdia',
      'Tripoli',
      'Benghazi',
      'Misrata',
      'Tarhuna',
      'Derna',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier les Données de la Mission'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From Location
                  const Text(
                    'Lieu de Départ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Type selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Domicile'),
                          selected: selectedFromLocationType == 'domicile',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                () => selectedFromLocationType = 'domicile',
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Clinique'),
                          selected: selectedFromLocationType == 'clinic',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                () => selectedFromLocationType = 'clinic',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedFromLocationType == 'clinic') ...[
                    // City dropdown
                    DropdownButton<String>(
                      value: selectedFromCity,
                      items: cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedFromCity = value ?? 'Sfax';
                          selectedFromClinic = '';
                        });
                      },
                      isExpanded: true,
                    ),
                    const SizedBox(height: 8),
                    // Clinic dropdown
                    ClinicDropdownField(
                      value: selectedFromClinic,
                      selectedCity: selectedFromCity,
                      onChanged: (value) {
                        setDialogState(() => selectedFromClinic = value ?? '');
                      },
                    ),
                  ] else
                    TextFormField(
                      controller: fromLocationManualCtrl,
                      decoration: InputDecoration(
                        hintText: 'Lieu de départ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      enabled: !isLoading,
                    ),
                  const SizedBox(height: 16),

                  // To Location
                  const Text(
                    'Lieu de Destination',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Type selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Domicile'),
                          selected: selectedToLocationType == 'domicile',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                () => selectedToLocationType = 'domicile',
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Clinique'),
                          selected: selectedToLocationType == 'clinic',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                () => selectedToLocationType = 'clinic',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedToLocationType == 'clinic') ...[
                    // City dropdown
                    DropdownButton<String>(
                      value: selectedToCity,
                      items: cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedToCity = value ?? 'Sfax';
                          selectedToClinic = '';
                        });
                      },
                      isExpanded: true,
                    ),
                    const SizedBox(height: 8),
                    // Clinic dropdown
                    ClinicDropdownField(
                      value: selectedToClinic,
                      selectedCity: selectedToCity,
                      onChanged: (value) {
                        setDialogState(() => selectedToClinic = value ?? '');
                      },
                    ),
                  ] else
                    TextFormField(
                      controller: toLocationManualCtrl,
                      decoration: InputDecoration(
                        hintText: 'Lieu de destination',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      enabled: !isLoading,
                    ),
                  const SizedBox(height: 16),

                  // Patient Name
                  const Text(
                    'Nom du Patient',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: patientNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nom complet du patient',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Patient Phone
                  const Text(
                    'Téléphone du Patient',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: patientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Numéro de téléphone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Infirmier Name
                  const Text(
                    'Infirmier/Médecin',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: infirmierNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nom de l\'infirmier',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  const Text(
                    'Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Notes supplémentaires',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Payment Type
                  const Text(
                    'Type de Paiement',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedPaymentType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Liquide')),
                      DropdownMenuItem(
                        value: 'charge',
                        child: Text('Sur Compte'),
                      ),
                    ],
                    onChanged: !isLoading
                        ? (value) {
                            if (value != null) {
                              setDialogState(() => selectedPaymentType = value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Guarantee field - show when "Sur Compte" is selected
                  if (selectedPaymentType == 'charge') ...[
                    const Text(
                      '🔐 Garantie (Obligatoire)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: guaranteeCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'ex: Carte d\'identité, Fiche paroissiale, Contrat...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.orange[50],
                      ),
                      maxLines: 2,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Tarif
                  const Text(
                    'Tarif',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: tarifCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Montant en dinars',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Statut du Paiement
                  Row(
                    children: [
                      Checkbox(
                        value: selectedIsPaid,
                        onChanged: !isLoading
                            ? (value) {
                                setDialogState(
                                  () => selectedIsPaid = value ?? false,
                                );
                              }
                            : null,
                      ),
                      const Text(
                        'Mission Payée',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Note: Les données de la fiche technique ne peuvent pas être modifiées via ce formulaire. Utilisez l\'onglet "Détails" pour la fiche technique.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setDialogState(() => isLoading = true);

                        // Determine final locations based on selected type
                        String finalFromLocation =
                            selectedFromLocationType == 'clinic'
                            ? selectedFromClinic
                            : fromLocationManualCtrl.text;
                        String finalToLocation =
                            selectedToLocationType == 'clinic'
                            ? selectedToClinic
                            : toLocationManualCtrl.text;

                        await _saveMissionEdits(
                          mission,
                          finalFromLocation,
                          finalToLocation,
                          patientNameCtrl.text,
                          patientPhoneCtrl.text,
                          infirmierNameCtrl.text,
                          notesCtrl.text,
                          selectedPaymentType,
                          tarifCtrl.text,
                          selectedIsPaid,
                          guaranteeCtrl.text,
                        );
                        if (mounted) {
                          Navigator.pop(dialogContext);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Save all mission edits to the database
  Future<void> _saveMissionEdits(
    Mission mission,
    String fromLocation,
    String toLocation,
    String patientName,
    String patientPhone,
    String infirmierName,
    String notes,
    String paymentType,
    String missionPrice,
    bool isPaid,
    String guarantee,
  ) async {
    try {
      final normalizedFromLocation = fromLocation.trim();
      final normalizedToLocation = toLocation.trim();
      final normalizedPatientName = patientName.trim();
      final normalizedPatientPhone = patientPhone.trim();
      final patientNameParts = normalizedPatientName
          .split(RegExp(r'\s+'))
          .where((part) => part.trim().isNotEmpty)
          .toList();
      final normalizedPatientFirstName = patientNameParts.isNotEmpty
          ? patientNameParts.first
          : null;
      final normalizedPatientLastName = patientNameParts.length > 1
          ? patientNameParts.skip(1).join(' ')
          : null;
      final normalizedInfirmierName = infirmierName.trim();
      final normalizedNotes = notes.trim();
      final normalizedGuarantee = guarantee.trim();
      final normalizedMissionPriceInput = missionPrice.trim().replaceAll(
        ',',
        '.',
      );
      final normalizedMissionPrice = normalizedMissionPriceInput.isEmpty
          ? 0
          : (num.tryParse(normalizedMissionPriceInput) ?? 0);

      // Update all fields
      await _missionService.updateMissionField(
        mission.id,
        'from_location',
        normalizedFromLocation,
      );
      await _missionService.updateMissionField(
        mission.id,
        'pickup_address',
        normalizedFromLocation,
      );
      await _missionService.updateMissionField(
        mission.id,
        'to_location',
        normalizedToLocation,
      );
      await _missionService.updateMissionField(
        mission.id,
        'destination_address',
        normalizedToLocation,
      );
      await _missionService.updateMissionField(
        mission.id,
        'patient_name',
        normalizedPatientName,
      );
      await _missionService.updateMissionField(
        mission.id,
        'patient_first_name',
        normalizedPatientFirstName,
      );
      await _missionService.updateMissionField(
        mission.id,
        'patient_last_name',
        normalizedPatientLastName,
      );
      await _missionService.updateMissionField(
        mission.id,
        'patient_phone',
        normalizedPatientPhone,
      );
      await _missionService.updateMissionField(
        mission.id,
        'infirmier_name',
        normalizedInfirmierName,
      );
      await _missionService.updateMissionField(
        mission.id,
        'notes',
        normalizedNotes,
      );
      await _missionService.updateMissionField(
        mission.id,
        'payment_type',
        paymentType,
      );
      await _missionService.updateMissionField(
        mission.id,
        'mission_price',
        normalizedMissionPrice,
      );
      await _missionService.updateMissionField(
        mission.id,
        'payment_status',
        isPaid,
      );

      // Update guarantee if "Sur Compte" is selected
      if (paymentType == 'charge' && normalizedGuarantee.isNotEmpty) {
        await _missionService.updateMissionField(
          mission.id,
          'guarantee',
          normalizedGuarantee,
        );
      } else if (paymentType != 'charge') {
        await _missionService.updateMissionField(mission.id, 'guarantee', null);
      }

      // Reload missions
      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission mise à jour avec succès!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ActiveMissionsScreen] Error saving mission edits: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

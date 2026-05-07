import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive.dart';
import '../config/constants.dart';
import '../models/ambulance_model.dart';
import '../models/fuel_card_model.dart';
import '../models/maintenance_record_model.dart';
import '../models/maintenance_rule_model.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../services/ambulance_service.dart';
import '../services/fuel_card_service.dart';
import '../services/maintenance_rule_service.dart';
import '../services/maintenance_service.dart';
import '../services/mission_service.dart';
import '../services/auth_service.dart';
import '../services/company_staff_service.dart';
import '../services/notification_service.dart';
import '../services/scheduled_shift_runtime_service.dart';
import '../widgets/clinic_dropdown_field.dart';
import '../widgets/patient_request_summary_card.dart';
import 'add_fuel_card_screen.dart';
import 'refuel_fuel_card_screen.dart';
import 'add_maintenance_screen.dart';
import 'active_missions_screen.dart';
import 'equipment_rental_screen.dart';
import 'notifications_list_screen.dart';
import 'driver_tracking_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _MaintenanceForecastStatus {
  final String label;
  final Color color;
  final int priority;
  final String? maintenanceType;
  final double? dueKm;
  final DateTime? dueDate;
  final double? remainingKm;

  const _MaintenanceForecastStatus({
    required this.label,
    required this.color,
    required this.priority,
    this.maintenanceType,
    this.dueKm,
    this.dueDate,
    this.remainingKm,
  });

  const _MaintenanceForecastStatus.ok()
    : label = 'OK',
      color = Colors.green,
      priority = 0,
      maintenanceType = null,
      dueKm = null,
      dueDate = null,
      remainingKm = null;
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AmbulanceService _ambulanceService = AmbulanceService();
  final MissionService _missionService = MissionService();
  final FuelCardService _fuelCardService = FuelCardService();
  final MaintenanceService _maintenanceService = MaintenanceService();
  final MaintenanceRuleService _maintenanceRuleService =
      MaintenanceRuleService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  final ScheduledShiftRuntimeService _scheduledShiftRuntimeService =
      ScheduledShiftRuntimeService();

  static const _trackingBackendUrl =
      'https://ambulance-backend-1-n6wd.onrender.com';

  late Future<Map<String, dynamic>> _dashboardData;
  int _selectedTabIndex = 0;
  bool _isAmbulanceActionInProgress = false;
  List<User> _companyStaff = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardData = _loadDashboardData();
    _loadCompanyStaff();

    // Set up notification tap handler
    NotificationService.instance.onNotificationTapped =
        (Map<String, dynamic> data) {
          final String? type = data['type'];
          debugPrint('[DashboardScreen] Notification tapped - type: $type');

          // Navigate to missions tab when mission notification is tapped
          if (type == 'mission_created' ||
              type == 'mission_assigned' ||
              type == 'MISSION_BROADCAST') {
            if (mounted) {
              setState(() {
                _selectedTabIndex = 1; // Switch to Missions tab
              });
            }
          }
        };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh dashboard data when app comes back to foreground
      if (mounted) {
        setState(() {
          _dashboardData = _loadDashboardData();
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      // Clear ambulance cache to fetch fresh data
      _ambulanceService.clearCache();

      // Fetch ambulance
      final ambulance = await _ambulanceService.getAmbulanceForDriver(
        widget.user.id!,
        tenantId: widget.user.tenantId,
      );

      // Fetch missions if we have an ambulance
      List<Mission> availableMissions = [];
      List<Mission> activeMissions = [];
      List<FuelCard> fuelHistory = [];
      List<MaintenanceRecord> maintenanceRecords = [];
      List<MaintenanceRule> maintenanceRules = [];
      List<Ambulance> availableAmbulances = [];

      if (ambulance != null) {
        try {
          await _scheduledShiftRuntimeService.syncForDriver(
            user: widget.user,
            ambulance: ambulance,
            backendUrl: _trackingBackendUrl,
          );
        } catch (_) {}

        final ambulanceId = ambulance.id!;
        final missions = await _missionService.getAvailableMissions(
          ambulanceId,
        );
        availableMissions = missions;

        // Fetch active missions
        activeMissions = await _missionService.getActiveMissions(ambulanceId);

        // Fetch fuel history
        fuelHistory = await _fuelCardService.getFuelCardHistory(ambulanceId);

        // Fetch maintenance records
        maintenanceRecords = await _maintenanceService.getMaintenanceRecords(
          ambulanceId,
        );
      }

      if (widget.user.tenantId != null && widget.user.tenantId!.isNotEmpty) {
        maintenanceRules = await _maintenanceRuleService.getRules(
          widget.user.tenantId!,
        );
        availableAmbulances = await _ambulanceService
            .getAvailableAmbulancesForDriver(
              driverId: widget.user.id,
              tenantId: widget.user.tenantId!,
            );
      }

      return {
        'ambulance': ambulance,
        'missions': availableMissions,
        'activeMissions': activeMissions,
        'fuelHistory': fuelHistory,
        'maintenanceRecords': maintenanceRecords,
        'maintenanceRules': maintenanceRules,
        'availableAmbulances': availableAmbulances,
      };
    } catch (e) {
      rethrow;
    }
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
      debugPrint('Error loading company staff for dashboard: $e');
    }
  }

  Future<void> _refreshDashboardData() async {
    if (!mounted) return;
    setState(() {
      _dashboardData = _loadDashboardData();
    });
  }

  Future<void> _linkAmbulance(Ambulance ambulance) async {
    if (widget.user.tenantId == null || widget.user.tenantId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun tenant associé à ce conducteur.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isAmbulanceActionInProgress = true);
    try {
      await _ambulanceService.assignAmbulanceToDriver(
        ambulanceId: ambulance.id,
        driverId: widget.user.id,
        tenantId: widget.user.tenantId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ambulance ${ambulance.ambulanceNumber} liée avec succès.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _refreshDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAmbulanceActionInProgress = false);
      }
    }
  }

  Future<void> _releaseAmbulance(Ambulance ambulance) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Libérer l\'ambulance'),
            content: Text(
              'Voulez-vous vraiment libérer ${ambulance.ambulanceNumber} pour pouvoir choisir une autre ambulance ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Libérer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() => _isAmbulanceActionInProgress = true);
    try {
      await _ambulanceService.releaseAmbulanceFromDriver(
        ambulanceId: ambulance.id,
        driverId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ambulance ${ambulance.ambulanceNumber} libérée avec succès.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _refreshDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAmbulanceActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildCustomAppBar(context),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Erreur lors du chargement du tableau de bord',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _dashboardData = _loadDashboardData();
                        });
                      }
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final ambulance = data['ambulance'] as Ambulance?;
          final missions = (data['missions'] ?? []) as List<Mission>;
          final activeMissions =
              (data['activeMissions'] ?? []) as List<Mission>;
          final fuelHistory = (data['fuelHistory'] ?? []) as List<FuelCard>;
          final maintenanceRecords =
              (data['maintenanceRecords'] ?? []) as List<MaintenanceRecord>;
          final maintenanceRules =
              (data['maintenanceRules'] ?? []) as List<MaintenanceRule>;
          final availableAmbulances =
              (data['availableAmbulances'] ?? []) as List<Ambulance>;

          // Show different screen based on selected tab
          Widget tabContent;
          switch (_selectedTabIndex) {
            case 0:
              // Dashboard tab
              tabContent = ambulance == null
                  ? _buildAmbulanceSelectionState(context, availableAmbulances)
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(
                        context.responsive.paddingValueLarge,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAmbulanceHeader(
                            context,
                            ambulance,
                            onRelease: _isAmbulanceActionInProgress
                                ? null
                                : () => _releaseAmbulance(ambulance),
                          ),
                          const SizedBox(height: 24),

                          // Available Missions Section
                          _buildMissionsSection(
                            context,
                            missions,
                            activeMissions.isNotEmpty,
                          ),
                          const SizedBox(height: 24),

                          // Quick Info Cards
                          _buildQuickInfoCards(context, ambulance),
                          const SizedBox(height: 24),

                          // Fuel Card History
                          if (fuelHistory.isNotEmpty) ...[
                            _buildFuelHistorySection(
                              context,
                              fuelHistory,
                              ambulance.id!,
                              ambulance.ambulanceNumber,
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            _buildEmptyFuelCardSection(
                              context,
                              ambulance.id!,
                              ambulance.ambulanceNumber,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Maintenance Records
                          _buildMaintenanceSection(
                            context,
                            maintenanceRecords,
                            ambulance,
                            maintenanceRules,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
              break;
            case 1:
              // Missions tab
              if (ambulance == null) {
                tabContent = _buildAmbulanceSelectionState(
                  context,
                  availableAmbulances,
                );
              } else {
                tabContent = ActiveMissionsScreen(
                  user: widget.user,
                  ambulanceId: ambulance.id!,
                );
              }
              break;
            case 2:
              // Equipment Rental tab
              if (ambulance == null) {
                tabContent = _buildAmbulanceSelectionState(
                  context,
                  availableAmbulances,
                );
              } else {
                tabContent = EquipmentRentalScreen(
                  ambulance: ambulance,
                  user: widget.user,
                );
              }
              break;
            case 3:
              // Driver Tracking tab
              if (ambulance == null) {
                tabContent = _buildAmbulanceSelectionState(
                  context,
                  availableAmbulances,
                );
              } else {
                tabContent = DriverTrackingScreen(
                  user: widget.user,
                  ambulanceId: ambulance.id!,
                  ambulanceNumber: ambulance.ambulanceNumber ?? 'N/A',
                );
              }
              break;
            default:
              tabContent = const Center(child: Text('Unknown Tab'));
          }

          return tabContent;
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  /// Custom AppBar with ambulance info and profile
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Ambulance info
              Expanded(
                child: Row(
                  children: [
                    // Red asterisk icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          '*',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ambulance number
                    FutureBuilder(
                      future: _dashboardData,
                      builder: (context, snapshot) {
                        final ambulanceNumber =
                            (snapshot.data?['ambulance'] as Ambulance?)
                                ?.ambulanceNumber ??
                            'Choisir';
                        return Text(
                          ambulanceNumber,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Right side: Icons
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationsListScreen(),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  // Logout button
                  IconButton(
                    icon: const Icon(Icons.logout),
                    color: AppColors.primary,
                    tooltip: 'Déconnexion',
                    onPressed: _logout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbulanceHeader(
    BuildContext context,
    Ambulance ambulance, {
    VoidCallback? onRelease,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID Ambulance',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  Text(
                    ambulance.ambulanceNumber ?? 'N/A',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'En ligne',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ambulance.telephone != null)
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  ambulance.telephone!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isAmbulanceActionInProgress ? null : onRelease,
              icon: _isAmbulanceActionInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_off),
              label: const Text('Libérer cette ambulance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceSelectionState(
    BuildContext context,
    List<Ambulance> availableAmbulances,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choisissez une ambulance pour continuer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Votre compte conducteur n\'est pas encore lié à une ambulance. Sélectionnez une ambulance disponible ci-dessous.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (availableAmbulances.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                'Aucune ambulance disponible pour le moment. Demandez à votre manager de libérer ou d\'assigner une ambulance.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...availableAmbulances.map(
              (availableAmbulance) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              availableAmbulance.ambulanceNumber,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              availableAmbulance.telephone?.isNotEmpty == true
                                  ? availableAmbulance.telephone!
                                  : 'Téléphone non renseigné',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isAmbulanceActionInProgress
                            ? null
                            : () => _linkAmbulance(availableAmbulance),
                        child: _isAmbulanceActionInProgress
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Choisir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMissionsSection(
    BuildContext context,
    List<Mission> missions,
    bool hasActiveMission,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Missions Disponibles',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _showAddMissionDialog(context),
              icon: const Icon(Icons.add_circle, size: 28),
              color: AppColors.primary,
              tooltip: 'Ajouter une mission en attente',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (missions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Text(
                'Aucune mission disponible',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(missions.length, (index) {
                final reversedMissions = missions.reversed.toList();
                final mission = reversedMissions[index];
                final priorityLower = (mission.priority ?? '').toLowerCase();
                final isHighPriority =
                    priorityLower == 'urgent' || priorityLower == 'emergency';
                final clinicName = mission.clinicName?.trim();
                final clinicLabel =
                    (clinicName != null && clinicName.isNotEmpty)
                    ? clinicName
                    : 'Mission clinique';
                final isClinicMission =
                    mission.clinicTenantId != null &&
                    mission.clinicTenantId!.isNotEmpty;
                final isGuestPatientMission = mission.isGuestPatientMission;
                final preferredAmbulanceNumber =
                    mission.requestedAmbulanceNumber;
                final accentColor = isClinicMission
                    ? const Color(0xFF7C3AED)
                    : (isGuestPatientMission
                          ? const Color(0xFF0F766E)
                          : AppColors.primary);

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == missions.length - 1 ? 0 : 12,
                  ),
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isClinicMission
                          ? const Color(0xFFF8F5FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isClinicMission
                            ? const Color(0xFFD8B4FE)
                            : (isGuestPatientMission
                                  ? const Color(0xFF2DD4BF)
                                  : (isHighPriority
                                        ? Colors.orange
                                        : Colors.grey[200]!)),
                        width:
                            isClinicMission ||
                                isHighPriority ||
                                isGuestPatientMission
                            ? 2
                            : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isClinicMission ? accentColor : Colors.black)
                              .withOpacity(isClinicMission ? 0.12 : 0.05),
                          blurRadius: isClinicMission ? 10 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isClinicMission) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(12),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        mission.requestedCompanyName ??
                                            'Najda / Patient App',
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
                        if (!isClinicMission) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isGuestPatientMission
                                  ? const Color(0xFFCCFBF1)
                                  : (isHighPriority
                                        ? Colors.orange[100]
                                        : Colors.blue[100]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isGuestPatientMission
                                  ? 'DEMANDE PATIENT'
                                  : (isHighPriority
                                        ? 'PRIORITE HAUTE'
                                        : 'PRIORITE MOYENNE'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isGuestPatientMission
                                        ? const Color(0xFF0F766E)
                                        : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          'Mission #${mission.missionNumber}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isClinicMission
                                    ? accentColor
                                    : Colors.grey[600],
                              ),
                        ),
                        if (isGuestPatientMission &&
                            preferredAmbulanceNumber != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF99F6E4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 16,
                                  color: Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Plus Proche : $preferredAmbulanceNumber',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF0F766E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'De',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    mission.pickupDisplayLabel,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vers',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    mission.toLocation ?? 'Aucune localisation',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (mission.hasPatientRequestDetails) ...[
                          const SizedBox(height: 10),
                          PatientRequestSummaryCard(
                            mission: mission,
                            dense: true,
                            accentColor: accentColor,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: hasActiveMission
                                ? null
                                : () {
                                    _showDriverNameDialog(context, mission);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasActiveMission
                                  ? Colors.grey[400]
                                  : accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              hasActiveMission
                                  ? 'Mission en cours'
                                  : 'Accepter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickInfoCards(BuildContext context, Ambulance ambulance) {
    final nextServiceKm =
        (ambulance.kilometrage ?? 0) + 2470; // Example: 2470 km to next service

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Informations Rapides sur l\'Ambulance',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.build),
                color: Colors.orange,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informations de maintenance ouvertes'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TELEPHONE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ambulance.telephone ?? 'N/A',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KILOMETRAGE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ambulance.kilometrage ?? 0} km',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Position Actuelle',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Carte complète à venir'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
              },
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Carte complète'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            color: Colors.grey[100],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Localisation de l\'Ambulance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alger, Algérie',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chargement de la carte...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFuelCardSection(
    BuildContext context,
    String ambulanceId,
    String ambulanceName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fuel Card History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddFuelCardScreen(
                          user: widget.user,
                          ambulanceId: ambulanceId,
                          ambulanceName: ambulanceName,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() {
                          _dashboardData = _loadDashboardData();
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RefuelFuelCardScreen(
                          user: widget.user,
                          ambulanceId: ambulanceId,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() {
                          _dashboardData = _loadDashboardData();
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.local_gas_station, size: 18),
                  label: const Text('Recharger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.local_gas_station,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucune transaction enregistrée',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFuelHistorySection(
    BuildContext context,
    List<FuelCard> fuelCards,
    String ambulanceId,
    String ambulanceName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fuel Card History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddFuelCardScreen(
                          user: widget.user,
                          ambulanceId: ambulanceId,
                          ambulanceName: ambulanceName,
                        ),
                      ),
                    ).then((_) {
                      // Refresh dashboard data when returning from form
                      if (mounted) {
                        setState(() {
                          _dashboardData = _loadDashboardData();
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RefuelFuelCardScreen(
                          user: widget.user,
                          ambulanceId: ambulanceId,
                        ),
                      ),
                    ).then((_) {
                      // Refresh dashboard data when returning from form
                      if (mounted) {
                        setState(() {
                          _dashboardData = _loadDashboardData();
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.local_gas_station, size: 18),
                  label: const Text('Recharger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
            ],
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Ambulancier',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Solde payé',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Soldes Restant',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Kilométrage',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fuelCards
                    .where((card) => card.driverName.toLowerCase() != 'refill')
                    .take(5)
                    .length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey[150], height: 1),
                itemBuilder: (context, index) {
                  final filteredCards = fuelCards
                      .where(
                        (card) => card.driverName.toLowerCase() != 'refill',
                      )
                      .toList();
                  final card = filteredCards[index];
                  final isEven = index.isEven;

                  // Calculate solde restant by summing all refills and subtracting consumptions up to this point
                  double calculatedBalance = 0.0;
                  for (final entry in fuelCards) {
                    if (entry.driverName.toLowerCase() == 'refill') {
                      calculatedBalance += entry.soldesPaid;
                    } else {
                      calculatedBalance -= entry.soldesPaid;
                    }
                    if (entry.id == card.id) break; // Stop at current card
                  }

                  return Container(
                    color: isEven ? Colors.grey[50] : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            (card.date ?? '').split('T')[0].isEmpty
                                ? 'N/A'
                                : (card.date ?? '').split('T')[0],
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            card.driverName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${card.soldesPaid} TND',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${calculatedBalance.toStringAsFixed(2)} TND',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: calculatedBalance >= 0
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            card.kilometrage != null
                                ? '${card.kilometrage!.toStringAsFixed(1)} km'
                                : '-',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceSection(
    BuildContext context,
    List<MaintenanceRecord> records,
    Ambulance ambulance,
    List<MaintenanceRule> rules,
  ) {
    final currentKm = ambulance.kilometrage ?? 0;
    final forecastStatus = _getFleetMaintenanceForecastStatus(
      records,
      rules,
      currentKm,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Enregistrements de Maintenance',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMaintenanceScreen(
                      user: widget.user,
                      ambulanceId: ambulance.id!,
                      ambulanceName: ambulance.ambulanceNumber,
                    ),
                  ),
                ).then((_) {
                  // Refresh dashboard data when returning from form
                  if (mounted) {
                    setState(() {
                      _dashboardData = _loadDashboardData();
                    });
                  }
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMaintenanceForecastCard(context, forecastStatus, currentKm),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
            ],
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Type',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Driver',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Mécanicien',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Coût',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  // Sort records by date in descending order (newest first)
                  final sortedRecords = List<MaintenanceRecord>.from(records)
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return SizedBox(
                    height: 300,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: sortedRecords.map((record) {
                          final maintenanceType =
                              record.maintenanceType ?? 'Service';
                          final driverName = record.driverName ?? '-';
                          final mechanicName = record.mechanicName ?? 'Unknown';
                          final cost = record.pricePerPiece ?? 0;
                          final forecastStatus = _getMaintenanceForecastStatus(
                            record,
                            rules,
                            currentKm,
                          );
                          final statusColor = _getMaintenanceStatusColor(
                            maintenanceType,
                          );

                          return GestureDetector(
                            onTap: () => _showMaintenanceDetailsDialog(
                              record,
                              ambulance,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                                color: Colors.grey[50],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        maintenanceType,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      driverName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      mechanicName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      cost > 0
                                          ? '$cost TND • ${forecastStatus.label}'
                                          : forecastStatus.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: forecastStatus.color,
                                          ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show driver name input dialog
  void _showDriverNameDialog(BuildContext context, Mission mission) {
    final TextEditingController driverNameController = TextEditingController(
      text: widget.user.name,
    );
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
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Accepter la Mission'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mission #${mission.missionNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Chauffeur responsable'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: driverNameController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Nom du chauffeur',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Veuillez entrer votre nom';
                      }
                      return null;
                    },
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Veuillez entrer votre nom'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isAccepting = true);

                          // First close the dialog IMMEDIATELY
                          Navigator.pop(dialogContext);

                          // After dialog is closed, do all async work WITHOUT using context
                          try {
                            print('[Dashboard] Mission acceptance started');
                            print('[Dashboard] Mission ID: ${mission.id}');
                            print(
                              '[Dashboard] Mission Number: ${mission.missionNumber}',
                            );

                            // Get ambulance ID from loaded data
                            final data = await _loadDashboardData();
                            final ambulance = data['ambulance'] as Ambulance?;

                            print(
                              '[Dashboard] Ambulance loaded: ${ambulance?.id}',
                            );

                            if (ambulance == null) {
                              print('[Dashboard] ERROR: No ambulance found');
                              return;
                            }

                            print('[Dashboard] Calling acceptMission with:');
                            print('   - Mission ID: ${mission.id}');
                            print('   - Ambulance ID: ${ambulance.id}');
                            print(
                              '   - Driver Name: ${driverNameController.text}',
                            );

                            // Accept mission
                            await _missionService.acceptMission(
                              mission.id!,
                              ambulance.id!,
                              driverNameController.text,
                            );

                            print('[Dashboard] Mission accepted successfully');

                            // Add delay to ensure backend sync before reload
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );

                            if (mounted) {
                              // Reload dashboard data immediately
                              setState(() {
                                _dashboardData = _loadDashboardData();
                                _selectedTabIndex = 1; // Switch to Missions tab
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Mission #${mission.missionNumber} acceptée ! Bienvenue ${driverNameController.text}',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            print(
                              '[Dashboard] ERROR accepting mission: ${e.toString()}',
                            );
                            print('[Dashboard] Stack trace: $e');

                            // Show error only if widget is still mounted and context is valid
                            if (mounted) {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (contextError) {
                                print(
                                  '[Dashboard] Could not show error message: $contextError',
                                );
                                // Context is no longer valid, just log the error
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepting
                        ? Colors.grey
                        : AppColors.primary,
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
        );
      },
    );
  }

  void _showAddMissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddMissionDialog(
          missionService: _missionService,
          parentContext: context,
          onMissionCreated: () {
            Navigator.pop(dialogContext);
            // Refresh dashboard data
            if (mounted) {
              setState(() {
                _dashboardData = _loadDashboardData();
              });
            }
          },
        );
      },
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: isMobile
          ? _buildCompactBottomNav() // Icons only for mobile
          : _buildFullBottomNav(), // Labels for tablet/desktop
    );
  }

  /// Compact mobile navigation - icons only
  Widget _buildCompactBottomNav() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedTabIndex,
      type: BottomNavigationBarType.shifting,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Tableau',
          tooltip: 'Tableau de Bord',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Missions',
          tooltip: 'Missions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'Équipement',
          tooltip: 'Équipement',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'Suivi',
          tooltip: 'Suivi Driver',
        ),
      ],
      onTap: (index) {
        if (mounted) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 0) {
              _dashboardData = _loadDashboardData();
            }
          });
        }
      },
    );
  }

  /// Full bottom navigation with labels
  Widget _buildFullBottomNav() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedTabIndex,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'TABLEAU DE BORD',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'MISSIONS',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'ÉQUIPEMENT',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'SUIVI'),
      ],
      onTap: (index) {
        if (mounted) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 0) {
              _dashboardData = _loadDashboardData();
            }
          });
        }
      },
    );
  }

  Color _getMaintenanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'terminé':
      case 'completed':
      case 'vidange':
      case 'oil change':
      case 'brake pad replacement':
        return Colors.green;
      case 'urgent':
      case 'engine oil change':
        return Colors.red;
      case 'pending':
      case 'en attente':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  _MaintenanceForecastStatus _getFleetMaintenanceForecastStatus(
    List<MaintenanceRecord> records,
    List<MaintenanceRule> rules,
    double currentKm,
  ) {
    var status = const _MaintenanceForecastStatus.ok();
    final latestByType = <String, MaintenanceRecord>{};
    final sortedRecords = List<MaintenanceRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final record in sortedRecords) {
      final typeKey = _maintenanceRuleService.normalizeMaintenanceType(
        record.maintenanceType,
      );
      final current = latestByType[typeKey];
      if (current == null || _isNewerMaintenanceRecord(record, current)) {
        latestByType[typeKey] = record;
      }
    }

    for (final record in latestByType.values) {
      final recordStatus = _getMaintenanceForecastStatus(
        record,
        rules,
        currentKm,
      );
      if (_isNearerMaintenanceStatus(recordStatus, status)) {
        status = recordStatus;
      }
    }
    return status;
  }

  bool _isNewerMaintenanceRecord(
    MaintenanceRecord candidate,
    MaintenanceRecord current,
  ) {
    final candidateCreated = DateTime.tryParse(
      candidate.createdAt ?? candidate.updatedAt ?? '',
    );
    final currentCreated = DateTime.tryParse(
      current.createdAt ?? current.updatedAt ?? '',
    );
    if (candidateCreated != null && currentCreated != null) {
      final comparison = candidateCreated.compareTo(currentCreated);
      if (comparison != 0) return comparison > 0;
    }

    final candidateDate = DateTime.tryParse(candidate.date);
    final currentDate = DateTime.tryParse(current.date);
    if (candidateDate != null && currentDate != null) {
      final comparison = candidateDate.compareTo(currentDate);
      if (comparison != 0) return comparison > 0;
    }

    final candidateKm = candidate.kilometrage ?? candidate.nextDueKm ?? 0;
    final currentKm = current.kilometrage ?? current.nextDueKm ?? 0;
    if (candidateKm != currentKm) return candidateKm > currentKm;

    return candidate.id.compareTo(current.id) > 0;
  }

  bool _isNearerMaintenanceStatus(
    _MaintenanceForecastStatus candidate,
    _MaintenanceForecastStatus current,
  ) {
    if (current.maintenanceType == null) return true;
    if (candidate.maintenanceType == null) return false;

    if (candidate.priority != current.priority) {
      return candidate.priority > current.priority;
    }

    final candidateRemaining = candidate.remainingKm;
    final currentRemaining = current.remainingKm;
    if (candidateRemaining != null && currentRemaining != null) {
      return candidateRemaining.abs() < currentRemaining.abs();
    }
    if (candidate.dueKm != null && current.dueKm != null) {
      return candidate.dueKm! < current.dueKm!;
    }
    if (candidate.dueDate != null && current.dueDate != null) {
      return candidate.dueDate!.isBefore(current.dueDate!);
    }
    return false;
  }

  _MaintenanceForecastStatus _getMaintenanceForecastStatus(
    MaintenanceRecord record,
    List<MaintenanceRule> rules,
    double currentKm,
  ) {
    var priority = 0;
    var label = 'OK';
    var color = Colors.green;

    final rule = _findMaintenanceRule(record.maintenanceType, rules);
    final nextDueKm =
        record.nextDueKm ??
        (rule?.enabled == true && rule?.intervalKm != null
            ? (record.kilometrage ?? 0) + rule!.intervalKm!
            : null);
    final remainingKm = nextDueKm != null ? nextDueKm - currentKm : null;
    if (nextDueKm != null) {
      final warningKm = record.warningBeforeKm ?? rule?.warningBeforeKm ?? 0;
      if (currentKm >= nextDueKm) {
        priority = 2;
        label = 'En retard';
        color = Colors.red;
      } else if (warningKm > 0 && currentKm >= nextDueKm - warningKm) {
        priority = 1;
        label = 'Bientôt';
        color = Colors.orange;
      }
    }

    final ruleNextDueDate =
        rule?.enabled == true &&
            rule?.intervalDays != null &&
            DateTime.tryParse(record.date) != null
        ? DateTime.tryParse(
            record.date,
          )!.add(Duration(days: rule!.intervalDays!))
        : null;
    final nextDueDate =
        DateTime.tryParse(record.nextDueDate ?? '') ?? ruleNextDueDate;
    if (nextDueDate != null) {
      final warningDays =
          record.warningBeforeDays ?? rule?.warningBeforeDays ?? 0;
      final now = DateTime.now();
      if (now.isAfter(nextDueDate) || _isSameDay(now, nextDueDate)) {
        priority = 2;
        label = 'En retard';
        color = Colors.red;
      } else if (priority < 2 &&
          warningDays > 0 &&
          now.isAfter(nextDueDate.subtract(Duration(days: warningDays)))) {
        priority = 1;
        label = 'Bientôt';
        color = Colors.orange;
      }
    }

    return _MaintenanceForecastStatus(
      label: label,
      color: color,
      priority: priority,
      maintenanceType: _formatMaintenanceType(record.maintenanceType),
      dueKm: nextDueKm,
      dueDate: nextDueDate,
      remainingKm: remainingKm,
    );
  }

  String _formatMaintenanceType(String type) {
    const labels = {
      'oil change': 'Vidange',
      'brake pad replacement': 'Plaquettes de Frein',
      'spark plugs': 'Bougies',
      'tires': 'Pneus',
      'brake fluid': 'Liquide de Frein',
      'urgent': 'Urgent',
    };
    final normalized = _maintenanceRuleService.normalizeMaintenanceType(type);
    return labels[normalized] ?? type;
  }

  MaintenanceRule? _findMaintenanceRule(
    String maintenanceType,
    List<MaintenanceRule> rules,
  ) {
    final typeKey = _maintenanceRuleService.normalizeMaintenanceType(
      maintenanceType,
    );
    for (final rule in rules) {
      if (_maintenanceRuleService.normalizeMaintenanceType(
            rule.maintenanceType,
          ) ==
          typeKey) {
        return rule;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMaintenanceForecastCard(
    BuildContext context,
    _MaintenanceForecastStatus status,
    double currentKm,
  ) {
    final targetLabel = status.dueKm != null
        ? '${status.dueKm!.toStringAsFixed(0)} km'
        : status.dueDate != null
        ? '${status.dueDate!.day.toString().padLeft(2, '0')}/${status.dueDate!.month.toString().padLeft(2, '0')}/${status.dueDate!.year}'
        : '${currentKm.toStringAsFixed(0)} km';
    final typeLabel = status.maintenanceType == null
        ? ''
        : '${status.maintenanceType} ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.build_circle_outlined, color: status.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Prévision entretien: $typeLabel${status.label} • $targetLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDetailsDialog(
    MaintenanceRecord record,
    Ambulance ambulance,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails de l\'Entretien'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date:', record.date),
              const SizedBox(height: 12),
              _buildDetailRow('Type d\'Entretien:', record.maintenanceType),
              const SizedBox(height: 12),
              _buildDetailRow('Description:', record.maintenanceDescription),
              const SizedBox(height: 12),
              _buildDetailRow('Mécanicien:', record.mechanicName ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Coût:',
                record.pricePerPiece != null
                    ? '${record.pricePerPiece!.toStringAsFixed(2)} TND'
                    : '-',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Notes:',
                record.notes?.isEmpty ?? true ? '-' : record.notes!,
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Chauffeur:', record.driverName ?? '-'),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Kilométrage:',
                record.kilometrage != null
                    ? '${record.kilometrage!.toStringAsFixed(2)} km'
                    : '-',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Perform logout and clear persistent session
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}

class AddMissionDialog extends StatefulWidget {
  final MissionService missionService;
  final BuildContext parentContext;
  final VoidCallback onMissionCreated;

  const AddMissionDialog({
    Key? key,
    required this.missionService,
    required this.parentContext,
    required this.onMissionCreated,
  }) : super(key: key);

  @override
  State<AddMissionDialog> createState() => _AddMissionDialogState();
}

class _AddMissionDialogState extends State<AddMissionDialog> {
  late GlobalKey<FormState> _formKey;
  late TextEditingController patientNameController;
  late TextEditingController patientPhoneController;
  late TextEditingController infirmierController;
  late TextEditingController tarifController;
  late TextEditingController notesController;
  late TextEditingController fromLocationManualController;
  late TextEditingController toLocationManualController;
  late TextEditingController customPriorityController;

  String selectedPriority = 'normal';
  String selectedFromLocationType = 'domicile';
  String selectedToLocationType = 'domicile';
  String selectedFromClinic = '';
  String selectedToClinic = '';
  String selectedFromCity = 'Sfax';
  String selectedToCity = 'Sfax';
  bool isLoading = false;
  List<String> customPriorityOptions = [];

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    patientNameController = TextEditingController();
    patientPhoneController = TextEditingController();
    infirmierController = TextEditingController();
    tarifController = TextEditingController();
    notesController = TextEditingController();
    fromLocationManualController = TextEditingController();
    toLocationManualController = TextEditingController();
    customPriorityController = TextEditingController();
    selectedFromClinic = LocationData.clinicsSfax[0];
    selectedToClinic = LocationData.clinicsSfax[0];
    _loadCustomPriorities();
  }

  Future<void> _loadCustomPriorities() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('custom_priorities') ?? [];
    setState(() {
      customPriorityOptions = saved;
    });
  }

  Future<void> _saveCustomPriority(String priority) async {
    if (priority.isEmpty || customPriorityOptions.contains(priority)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    customPriorityOptions.add(priority);
    await prefs.setStringList('custom_priorities', customPriorityOptions);
  }

  @override
  void dispose() {
    patientNameController.dispose();
    patientPhoneController.dispose();
    infirmierController.dispose();
    tarifController.dispose();
    notesController.dispose();
    fromLocationManualController.dispose();
    toLocationManualController.dispose();
    customPriorityController.dispose();
    super.dispose();
  }

  String _getFromLocation() {
    if (selectedFromLocationType == 'domicile') {
      return fromLocationManualController.text.isNotEmpty
          ? fromLocationManualController.text
          : 'domicile';
    } else {
      // If clinic type is selected but no clinic chosen, return empty
      return selectedFromClinic;
    }
  }

  String _getToLocation() {
    if (selectedToLocationType == 'domicile') {
      return toLocationManualController.text.isNotEmpty
          ? toLocationManualController.text
          : 'domicile';
    } else {
      // If clinic type is selected but no clinic chosen, return empty
      return selectedToClinic;
    }
  }

  Future<void> _createMission() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      // Get the actual priority to use
      String finalPriority = selectedPriority;
      if (selectedPriority == 'autre') {
        finalPriority = customPriorityController.text.trim();
        // Save custom priority for future use
        await _saveCustomPriority(finalPriority);
      }

      final medicine = await widget.missionService.createMission(
        fromLocation: _getFromLocation(),
        toLocation: _getToLocation(),
        priority: finalPriority,
        patientFirstName: patientNameController.text.split(' ').first,
        patientLastName: patientNameController.text.split(' ').length > 1
            ? patientNameController.text.split(' ').last
            : '',
        patientPhone: patientPhoneController.text,
        infirmierName: infirmierController.text,
        missionPrice: tarifController.text,
        notes: notesController.text,
      );

      if (mounted) {
        // MissionService already sends notifications, so no need to send again here
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Mission ${medicine.missionNumber} créée avec succès',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onMissionCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Error creating mission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ajouter une Mission en Attente',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date and Time
                Text(
                  'Date et Heure',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateTime.now().toString().split('.')[0],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                Text('Priorité', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: LocationData.priorityOptions.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(
                        LocationData.getPriorityDisplayName(priority),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPriority = value;
                        if (value != 'autre') {
                          customPriorityController.clear();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Custom priority input (visible only when "autre" is selected)
                if (selectedPriority == 'autre') ...[
                  Text(
                    'Veuillez entrer votre priorité personnalisée',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: customPriorityController,
                    decoration: InputDecoration(
                      hintText: 'ex: suivi post-opératoire',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Veuillez entrer une priorité';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Show previously used custom priorities
                  if (customPriorityOptions.isNotEmpty) ...[
                    Text(
                      'Priorités personnalisées récentes',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: customPriorityOptions.map((option) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              customPriorityController.text = option;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                            ),
                            child: Text(
                              option,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 16),

                // Lieu de Départ
                Text(
                  'Lieu de Départ',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _buildLocationSection(
                  'From',
                  selectedFromLocationType,
                  (value) => setState(() => selectedFromLocationType = value!),
                  fromLocationManualController,
                  selectedFromClinic,
                  (value) => setState(() => selectedFromClinic = value!),
                  selectedFromCity,
                  (value) {
                    setState(() {
                      selectedFromCity = value!;
                      selectedFromClinic = ''; // Reset clinic when city changes
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Lieu de Destination
                Text(
                  'Lieu de Destination',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _buildLocationSection(
                  'To',
                  selectedToLocationType,
                  (value) => setState(() => selectedToLocationType = value!),
                  toLocationManualController,
                  selectedToClinic,
                  (value) => setState(() => selectedToClinic = value!),
                  selectedToCity,
                  (value) {
                    setState(() {
                      selectedToCity = value!;
                      selectedToClinic = ''; // Reset clinic when city changes
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Patient Name
                Text(
                  'Nom du Patient',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: patientNameController,
                  decoration: InputDecoration(
                    hintText: 'Nom complet',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Patient Phone
                Text(
                  'Téléphone du Patient',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: patientPhoneController,
                  decoration: InputDecoration(
                    hintText: 'Numéro de téléphone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Infirmier/Médecin
                Text(
                  'Infirmier/Médecin',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: infirmierController,
                  decoration: InputDecoration(
                    hintText: 'Nom',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarif
                Text('Tarif', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: tarifController,
                  decoration: InputDecoration(
                    hintText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Notes
                Text('Notes', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'Additional notes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: isLoading ? null : _createMission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection(
    String label,
    String locationType,
    Function(String?) onLocationTypeChange,
    TextEditingController manualController,
    String selectedClinic,
    Function(String) onClinicChange,
    String selectedCity,
    Function(String) onCityChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(label: Text('Domicile'), value: 'domicile'),
                  ButtonSegment(label: Text('clinique'), value: 'chu'),
                ],
                selected: <String>{locationType},
                onSelectionChanged: (Set<String> newSelection) {
                  onLocationTypeChange(newSelection.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (locationType == 'domicile')
          TextFormField(
            controller: manualController,
            decoration: InputDecoration(
              hintText: 'Entrez la localisation manuellement',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sélectionner la Ville',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedCity,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  ...LocationData.citiesTunisia.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  const DropdownMenuItem(
                    value: 'libya',
                    child: Text('--- Libya ---'),
                  ),
                  ...LocationData.citiesLibya.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                ],
                onChanged: (value) {
                  if (value != null && value != 'libya') {
                    onCityChange(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Sélectionner la Clinique/Hôpital',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              ClinicDropdownField(
                value: selectedCity == 'Sfax'
                    ? selectedClinic
                    : LocationData.clinicsSfax[0],
                selectedCity: selectedCity,
                onChanged: (value) {
                  onClinicChange(value);
                },
              ),
            ],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/ambulance_model.dart';
import '../models/fuel_card_model.dart';
import '../models/maintenance_record_model.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../services/ambulance_service.dart';
import '../services/fuel_card_service.dart';
import '../services/maintenance_service.dart';
import '../services/mission_service.dart';
import 'add_fuel_card_screen.dart';
import 'add_maintenance_screen.dart';
import 'active_missions_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AmbulanceService _ambulanceService = AmbulanceService();
  final MissionService _missionService = MissionService();
  final FuelCardService _fuelCardService = FuelCardService();
  final MaintenanceService _maintenanceService = MaintenanceService();

  late Future<Map<String, dynamic>> _dashboardData;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardData = _loadDashboardData();
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
      // Fetch ambulance
      final ambulance =
          await _ambulanceService.getAmbulanceForDriver(widget.user.id!);

      // Fetch missions if we have an ambulance
      List<Mission> availableMissions = [];
      List<Mission> activeMissions = [];
      List<FuelCard> fuelHistory = [];
      List<MaintenanceRecord> maintenanceRecords = [];

      if (ambulance != null) {
        final ambulanceId = ambulance.id!;
        final missions = await _missionService.getAvailableMissions();
        availableMissions = missions;

        // Fetch active missions
        activeMissions = await _missionService.getActiveMissions(ambulanceId);

        // Fetch fuel history
        fuelHistory = await _fuelCardService.getFuelCardHistory(ambulanceId);

        // Fetch maintenance records
        maintenanceRecords =
            await _maintenanceService.getMaintenanceRecords(ambulanceId);
      }

      return {
        'ambulance': ambulance,
        'missions': availableMissions,
        'activeMissions': activeMissions,
        'fuelHistory': fuelHistory,
        'maintenanceRecords': maintenanceRecords,
      };
    } catch (e) {
      rethrow;
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
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
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
          final activeMissions = (data['activeMissions'] ?? []) as List<Mission>;
          final fuelHistory = (data['fuelHistory'] ?? []) as List<FuelCard>;
          final maintenanceRecords =
              (data['maintenanceRecords'] ?? []) as List<MaintenanceRecord>;

          // Show different screen based on selected tab
          Widget tabContent;
          switch (_selectedTabIndex) {
            case 0:
              // Dashboard tab
              tabContent = SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ambulance Header
                    if (ambulance != null) ...[
                      _buildAmbulanceHeader(context, ambulance),
                      const SizedBox(height: 24),
                    ],

                    // Available Missions Section
                    _buildMissionsSection(context, missions, activeMissions.isNotEmpty),
                    const SizedBox(height: 24),

                    // Quick Info Cards
                    if (ambulance != null) ...[
                      _buildQuickInfoCards(context, ambulance),
                      const SizedBox(height: 24),
                    ],

                    // Current Position Map (Placeholder)
                    _buildMapSection(context),
                    const SizedBox(height: 24),

                    // Fuel Card History
                    if (fuelHistory.isNotEmpty && ambulance != null) ...[
                      _buildFuelHistorySection(context, fuelHistory, ambulance.id!),
                      const SizedBox(height: 24),
                    ] else if (ambulance != null) ...[
                      _buildEmptyFuelCardSection(context, ambulance.id!),
                      const SizedBox(height: 24),
                    ],

                    // Maintenance Records
                    if (maintenanceRecords.isNotEmpty && ambulance != null) ...[
                      _buildMaintenanceSection(context, maintenanceRecords, ambulance.id!),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              );
              break;
            case 1:
              // Missions tab
              if (ambulance == null) {
                tabContent = const Center(
                  child: Text('Aucune ambulance assignée'),
                );
              } else {
                tabContent = ActiveMissionsScreen(
                  user: widget.user,
                  ambulanceId: ambulance.id!,
                );
              }
              break;
            default:
              tabContent = const Center(
                child: Text('Unknown Tab'),
              );
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
                                'AMB-001';
                        return Text(
                          ambulanceNumber,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Aucune nouvelle notification'),
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

  Widget _buildAmbulanceHeader(BuildContext context, Ambulance ambulance) {
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
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
        ],
      ),
    );
  }

  Widget _buildMissionsSection(BuildContext context, List<Mission> missions, bool hasActiveMission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Missions Disponibles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
              ),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
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

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == missions.length - 1 ? 0 : 12,
                  ),
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isHighPriority ? Colors.orange : Colors.grey[200]!,
                        width: isHighPriority ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isHighPriority
                                ? Colors.orange[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isHighPriority
                                ? 'PRIORITE HAUTE'
                                : 'PRIORITE MOYENNE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mission #${mission.missionNumber}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: AppColors.primary),
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
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  Text(
                                    mission.fromLocation ?? 'Aucune localisation',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
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
                            Icon(Icons.location_on,
                                size: 16, color: Colors.green),
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
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  Text(
                                    mission.toLocation ?? 'Aucune localisation',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: hasActiveMission ? null : () {
                              _showDriverNameDialog(context, mission);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasActiveMission ? Colors.grey[400] : AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(hasActiveMission ? 'Mission en cours' : 'Accepter'),
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
              Row(
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
                  Text(
                    'Informations Rapides sur l\'Ambulance',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.build),
                color: Colors.orange,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informations de maintenance ouvertes')),
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
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROCHAIN SERVICE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'In ${nextServiceKm - (ambulance.kilometrage ?? 0)} km',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              label: const Text('Carte Complète'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
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

  Widget _buildEmptyFuelCardSection(BuildContext context, String ambulanceId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fuel Card History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFuelCardScreen(
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
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
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
                Icon(Icons.local_gas_station, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Aucune transaction enregistrée',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fuel Card History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFuelCardScreen(
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
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
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
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
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
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Montant',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Solde',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
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
                itemCount: fuelCards.take(5).length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey[150], height: 1),
                itemBuilder: (context, index) {
                  final card = fuelCards[index];
                  final isEven = index.isEven;
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${card.fuelAmount} L',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                    ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${card.balance} L',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
    String ambulanceId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enregistrements de Maintenance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMaintenanceScreen(
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
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
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
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
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
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Mécanicien',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Date',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Coût',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
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
                itemCount: records.take(5).length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey[150], height: 1),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final isEven = index.isEven;
                  final maintenanceType = record.maintenanceType ?? 'Service';
                  final mechanicName = record.mechanicName ?? 'Unknown';
                  final date = (record.date ?? '').split('T')[0].isEmpty
                      ? 'N/A'
                      : (record.date ?? '').split('T')[0];
                  final cost = record.pricePerPiece ?? 0;

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
                            maintenanceType,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
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
                            date,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$cost DA',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
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

  /// Show driver name input dialog
  void _showDriverNameDialog(BuildContext context, Mission mission) {
    final TextEditingController driverNameController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
              const Text('Veuillez entrer votre nom:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: driverNameController,
                decoration: InputDecoration(
                  hintText: 'Votre nom complet',
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (driverNameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez entrer votre nom'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Close dialog
                  Navigator.pop(dialogContext);

                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Acceptation de la mission...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  // Get ambulance ID from loaded data
                  final data = await _loadDashboardData();
                  final ambulance = data['ambulance'] as Ambulance?;

                  if (ambulance == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Aucune ambulance assignée'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Accept mission
                  await _missionService.acceptMission(
                    mission.id!,
                    ambulance.id!,
                    driverNameController.text,
                  );

                  print('[Dashboard] Mission accepted successfully');

                  if (mounted) {
                    // Reload dashboard data
                    setState(() {
                      _dashboardData = _loadDashboardData();
                      _selectedTabIndex = 1; // Switch to Missions tab
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mission #${mission.missionNumber} acceptée! Bienvenue ${driverNameController.text}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('[Dashboard] ERROR accepting mission: ${e.toString()}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Accepter'),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedTabIndex > 1 ? 1 : _selectedTabIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'TABLEAU DE BORD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'MISSIONS',
          ),
        ],
        onTap: (index) {
          if (mounted) {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
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
      // Perform logout and redirect to login
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

  String selectedPriority = 'normal';
  String selectedFromLocationType = 'domicile';
  String selectedToLocationType = 'domicile';
  String selectedFromClinic = '';
  String selectedToClinic = '';
  String selectedFromCity = 'Sfax';
  String selectedToCity = 'Sfax';
  bool isLoading = false;

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
    selectedFromClinic = LocationData.clinicsSfax[0];
    selectedToClinic = LocationData.clinicsSfax[0];
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
    super.dispose();
  }

  String _getFromLocation() {
    if (selectedFromLocationType == 'domicile') {
      return fromLocationManualController.text.isNotEmpty
          ? fromLocationManualController.text
          : 'domicile';
    } else {
      return selectedFromClinic;
    }
  }

  String _getToLocation() {
    if (selectedToLocationType == 'domicile') {
      return toLocationManualController.text.isNotEmpty
          ? toLocationManualController.text
          : 'domicile';
    } else {
      return selectedToClinic;
    }
  }

  Future<void> _createMission() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final medicine = await widget.missionService.createMission(
        fromLocation: _getFromLocation(),
        toLocation: _getToLocation(),
        priority: selectedPriority,
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
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Mission ${medicine.missionNumber} créée avec succès'),
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
                    Text(
                      'Ajouter une Mission en Attente',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
                Text(
                  'Priorité',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
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
                      child: Text(LocationData.getPriorityDisplayName(priority)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedPriority = value);
                    }
                  },
                ),
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
                  (value) => setState(() => selectedFromCity = value!),
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
                  (value) => setState(() => selectedToCity = value!),
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
                Text(
                  'Tarif',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
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
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
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
                      onPressed: isLoading ? null : () => Navigator.pop(context),
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
                  ButtonSegment(label: Text('CHU'), value: 'chu'),
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
              Text('Sélectionner la Ville', style: Theme.of(context).textTheme.labelSmall),
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
              Text('Sélectionner la Clinique/Hôpital',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedCity == 'Sfax'
                    ? selectedClinic
                    : LocationData.clinicsSfax[0],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: LocationData.clinicsSfax.map((clinic) {
                  return DropdownMenuItem(value: clinic, child: Text(clinic));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onClinicChange(value);
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../models/ambulance_model.dart';
import '../services/mission_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../utils/responsive.dart';
import '../widgets/clinic_dropdown_field.dart';
import '../widgets/manager_nav_drawer.dart';
import 'manager_missions_screen.dart';
import 'manager_ambulances_screen.dart';
import 'manager_equipment_rentals_screen.dart';
import 'manager_historique_screen.dart';
import 'manager_shifts_screen.dart';
import 'fleet_viewer_map_screen.dart';
import 'settings/manager_settings_screen_optimized.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final User user;

  const ManagerDashboardScreen({Key? key, required this.user})
    : super(key: key);

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient();
  final _missionService = MissionService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedNavIndex = 0;
  late final List<Widget>
  _screens; // 🔥 Created ONCE in initState, never recreated

  int totalMissions = 0;
  int activeMissions = 0;
  int completedMissions = 0;
  double totalRevenue = 0;
  int totalDrivers = 0;
  int totalAmbulances = 0;
  int freeAmbulances = 0; // Ambulances without active missions
  double missionsWeeklyChangePercent = 0;
  double completedWeeklyChangePercent = 0;
  double revenueWeeklyChangePercent = 0;
  List<Mission> missions = [];
  List<Ambulance> ambulances = [];

  String get _managerHeaderTitle {
    final name = widget.user.name.trim();
    return name.isNotEmpty ? name : 'Manager';
  }

  Future<List<dynamic>> _attachClinicNames(List<dynamic> missionRows) async {
    final clinicTenantIds = missionRows
        .map((row) => row['clinic_tenant_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (clinicTenantIds.isEmpty) {
      return missionRows;
    }

    try {
      final apiClient = ApiClient();
      final tenantRows = await apiClient.get(
        '/rest/v1/tenants',
        filters: {'id': 'in.(${clinicTenantIds.join(',')})'},
      );

      final clinicNames = <String, String>{};
      for (final tenant in tenantRows) {
        final id = tenant['id']?.toString();
        final name = tenant['name']?.toString();
        if (id != null && name != null && name.isNotEmpty) {
          clinicNames[id] = name;
        }
      }

      return missionRows.map((row) {
        final copy = Map<String, dynamic>.from(row as Map);
        final clinicTenantId = copy['clinic_tenant_id']?.toString();
        if (clinicTenantId != null && clinicNames.containsKey(clinicTenantId)) {
          copy['clinic_name'] = clinicNames[clinicTenantId];
        }
        return copy;
      }).toList();
    } catch (e) {
      debugPrint('[ManagerDashboard] Failed to attach clinic names: $e');
      return missionRows;
    }
  }

  @override
  void initState() {
    super.initState();
    print('[DEBUG] ManagerDashboard initState() called');
    WidgetsBinding.instance.addObserver(this);

    // 🔥 CREATE NESTED CONTENT SCREENS ONCE - NOT IN BUILD()
    // Store only the content widgets to persist them
    // Dashboard is built dynamically so it rebuilds with fresh data when state changes
    _screens = [
      Container(), // Placeholder - dashboard built dynamically in _buildContent()
      ManagerMissionsScreenContent(user: widget.user), // Tab 1: Missions
      ManagerAmbulancesScreenContent(
        user: widget.user,
      ), // Tab 2: Fleet/Ambulances
      ManagerEquipmentRentalScreenContent(
        user: widget.user,
      ), // Tab 3: Equipment Rentals
      ManagerHistoriqueScreenContent(user: widget.user), // Tab 4: Historique
      ManagerShiftsScreenContent(user: widget.user), // Tab 5: Shifts
      FleetViewerMapScreen(user: widget.user), // Tab 6: Live Fleet Tracking
      ManagerSettingsScreenOptimized(user: widget.user), // Tab 7: Settings
    ];
    print(
      '[DEBUG] ManagerDashboard: _screens created with ${_screens.length} widgets',
    );

    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[DEBUG] App resumed - lifecycle event detected');
      debugPrint(
        '[ManagerDashboardScreen] App resumed, reloading dashboard...',
      );
      _loadDashboardData();
      // Dashboard content will trigger nested widget lifecycle events
      // No need to force rebuild - keep widgets alive with IndexedStack
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      print('🔄 Manager Dashboard: Starting data load...');
      print('[DEBUG] Current _selectedNavIndex: $_selectedNavIndex');
      print('[DEBUG] totalMissions before load: $totalMissions');
      final apiClient = ApiClient();

      print('📥 Fetching missions...');
      final missionData = await apiClient.get(SupabaseConfig.missionsTable);
      final enrichedMissionData = await _attachClinicNames(missionData);
      print('✅ Missions fetched: ${missionData.length} records');

      print('📥 Fetching ambulances...');
      final ambulanceData = await apiClient.get(SupabaseConfig.ambulancesTable);
      print('✅ Ambulances fetched: ${ambulanceData.length} records');

      // Parse missions with error handling
      print('🔄 Parsing missions...');
      List<Mission> missionList = [];
      for (int i = 0; i < enrichedMissionData.length; i++) {
        try {
          final mission = Mission.fromJson(enrichedMissionData[i]);
          missionList.add(mission);
        } catch (e) {
          print('❌ Error parsing mission $i: $e');
          print('   Data: ${enrichedMissionData[i]}');
        }
      }
      print('✅ Parsed ${missionList.length} missions successfully');

      // Parse ambulances with error handling
      print('🔄 Parsing ambulances...');
      List<Ambulance> ambulanceList = [];
      for (int i = 0; i < ambulanceData.length; i++) {
        try {
          final ambulance = Ambulance.fromJson(ambulanceData[i]);
          ambulanceList.add(ambulance);
        } catch (e) {
          print('❌ Error parsing ambulance $i: $e');
          print('   Data: ${ambulanceData[i]}');
        }
      }
      print('✅ Parsed ${ambulanceList.length} ambulances successfully');

      if (mounted) {
        // Calculate today's date
        final now = DateTime.now();

        // Filter for today's missions
        final todayMissions = missionList.where((m) {
          try {
            final missionDate = DateTime.parse(m.missionDate);
            return missionDate.year == now.year &&
                missionDate.month == now.month &&
                missionDate.day == now.day;
          } catch (e) {
            return false;
          }
        }).toList();

        // Calculate revenue from completed missions (sum actual prices)
        final completedMissionsList = missionList
            .where((m) => m.status == 'completed')
            .toList();
        double calculatedRevenue = 0.0;
        for (var mission in completedMissionsList) {
          try {
            final price = double.tryParse(mission.missionPrice ?? '0') ?? 0.0;
            calculatedRevenue += price;
          } catch (e) {
            print('Error parsing mission price: $e');
          }
        }

        // Calculate free ambulances based on active missions
        final activeMissionsWithAmbulance = missionList
            .where(
              (m) =>
                  (m.status == 'active' || m.status == 'pending') &&
                  m.ambulanceId.isNotEmpty,
            )
            .toList();

        final occupiedAmbulanceIds = <String>{};
        for (var mission in activeMissionsWithAmbulance) {
          if (mission.ambulanceId.isNotEmpty) {
            occupiedAmbulanceIds.add(mission.ambulanceId);
          }
        }

        final freeAmbList = ambulanceList
            .where((a) => !occupiedAmbulanceIds.contains(a.id))
            .toList();

        // Debug free ambulances
        debugPrint('🚑 Ambulance Status:');
        for (var amb in ambulanceList) {
          final isOccupied = occupiedAmbulanceIds.contains(amb.id);
          debugPrint(
            '   - ${amb.ambulanceNumber}: ${isOccupied ? 'BUSY' : 'FREE'}',
          );
        }
        debugPrint(
          '   - Active missions with ambulance: ${activeMissionsWithAmbulance.length}',
        );
        debugPrint('   - Occupied ambulances: ${occupiedAmbulanceIds.length}');
        debugPrint(
          '   - Free ambulances: ${freeAmbList.length}/${ambulanceList.length}',
        );

        // Calculate weekly percentage changes
        // THIS WEEK: missions from last 7 days
        final thisWeekMissions = missionList.where((m) {
          try {
            final missionDate = DateTime.parse(m.missionDate);
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final isThisWeek = missionDate.isAfter(weekAgo);
            if (isThisWeek) {
              debugPrint(
                '  ✓ Mission ${m.missionNumber}: ${m.missionDate} (THIS WEEK)',
              );
            }
            return isThisWeek;
          } catch (e) {
            debugPrint('  ✗ Error parsing ${m.missionDate}: $e');
            return false;
          }
        }).toList();

        // THIS WEEK: completed missions from last 7 days
        final thisWeekCompleted = thisWeekMissions
            .where((m) => m.status == 'completed')
            .toList();

        // LAST WEEK: missions from 14 days ago to 7 days ago
        final lastWeekMissions = missionList.where((m) {
          try {
            final missionDate = DateTime.parse(m.missionDate);
            final twoWeeksAgo = DateTime.now().subtract(
              const Duration(days: 14),
            );
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            return missionDate.isAfter(twoWeeksAgo) &&
                missionDate.isBefore(weekAgo);
          } catch (e) {
            return false;
          }
        }).toList();

        // LAST WEEK: completed missions from 14 days ago to 7 days ago
        final lastWeekCompleted = lastWeekMissions
            .where((m) => m.status == 'completed')
            .toList();

        // Calculate trending percentages - compare THIS WEEK vs LAST WEEK
        double completedPercent = lastWeekCompleted.isNotEmpty
            ? ((thisWeekCompleted.length - lastWeekCompleted.length) /
                  lastWeekCompleted.length *
                  100)
            : 0.0;
        double revenuePercent = completedPercent;

        double missionsPercent =
            0; // Since MISSIONS TOTALES won't show percentage

        print('📊 Dashboard stats:');
        print('   - Total missions (ALL): ${missionList.length}');
        print(
          '   - Active missions: ${missionList.where((m) => m.status == 'pending' || m.status == 'accepted').length}',
        );
        print('   - Completed (this week): ${thisWeekCompleted.length}');
        print('   - Last week completed: ${lastWeekCompleted.length}');
        print(
          '   - Free ambulances: ${freeAmbList.length}/${ambulanceList.length}',
        );
        print(
          '   - Weekly change (completed): ${completedPercent.toStringAsFixed(1)}%',
        );
        print('   - Todays missions: ${todayMissions.length}');
        print('   - Ambulances: ${ambulanceList.length}');

        print('[DEBUG] About to call setState()...');
        print('[DEBUG] totalMissions = ${missionList.length}');
        print('[DEBUG] totalAmbulances = ${ambulanceList.length}');

        setState(() {
          print('[DEBUG] Inside setState(), updating state variables');
          missions = missionList;
          ambulances = ambulanceList;
          totalMissions = missionList.length; // ALL missions (not filtered)
          activeMissions = missionList
              .where((m) => m.status == 'pending' || m.status == 'accepted')
              .length;
          completedMissions = thisWeekCompleted.length; // This week's completed
          // Calculate this week's revenue from actual mission prices
          double thisWeekRevenue = 0.0;
          for (var mission in thisWeekCompleted) {
            try {
              final price = double.tryParse(mission.missionPrice ?? '0') ?? 0.0;
              thisWeekRevenue += price;
            } catch (e) {
              print('Error parsing mission price: $e');
            }
          }
          totalRevenue = thisWeekRevenue;
          totalAmbulances = ambulanceList.length;
          freeAmbulances = freeAmbList.length;
          missionsWeeklyChangePercent = missionsPercent;
          completedWeeklyChangePercent = completedPercent;
          revenueWeeklyChangePercent = revenuePercent;
          print(
            '[DEBUG] setState() completed - totalMissions is now $totalMissions',
          );
        });

        print('✅ Dashboard data loaded successfully');
      }
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      // Perform logout and clear persistent session
      await AuthService().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showCreateMissionDialog() {
    print('\n\n🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫');
    print('🟫 [_showCreateMissionDialog] ENTRY - DASHBOARD');
    print('🟫 Mission creation dialog opened from dashboard');
    print('🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫\n');

    final formKey = GlobalKey<FormState>();
    final patientNameController = TextEditingController();
    final patientPhoneController = TextEditingController();
    final infirmierController = TextEditingController();
    final tarifController = TextEditingController();
    final notesController = TextEditingController();

    String? generatedMissionNumber;
    String selectedPriority = 'normal';
    String selectedFromLocationType = 'clinic';
    String selectedFromClinic = LocationData.clinicsSfax.first;
    final fromLocationManualController = TextEditingController();

    String selectedToLocationType = 'clinic';
    String selectedToClinic = LocationData.clinicsSfax.first;
    final toLocationManualController = TextEditingController();

    _generateMissionNumber().then((number) {
      generatedMissionNumber = number;
    });

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Créer une Nouvelle Mission',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null)
                          setState(() => selectedPriority = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lieu de Départ',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildLocationSection(
                      'From',
                      selectedFromLocationType,
                      (value) =>
                          setState(() => selectedFromLocationType = value!),
                      fromLocationManualController,
                      selectedFromClinic,
                      (value) => setState(() => selectedFromClinic = value!),
                      'Sfax',
                      (value) {},
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lieu de Destination',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildLocationSection(
                      'To',
                      selectedToLocationType,
                      (value) =>
                          setState(() => selectedToLocationType = value!),
                      toLocationManualController,
                      selectedToClinic,
                      (value) => setState(() => selectedToClinic = value!),
                      'Sfax',
                      (value) {},
                    ),
                    const SizedBox(height: 16),
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
                    Text(
                      'Tarif',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: tarifController,
                      decoration: InputDecoration(
                        hintText: 'Montant',
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
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes supplémentaires',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              print(
                                '\n🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫',
                              );
                              print(
                                '🟫 [Dashboard Dialog] CRÉER BUTTON CLICKED',
                              );
                              print('🟫 Form validation: ✅ PASSED');
                              print(
                                '🟫 Dialog closing and calling _createMissionDirect()',
                              );
                              print(
                                '🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫\n',
                              );
                              Navigator.pop(context);
                              _createMissionDirect(
                                generatedMissionNumber ?? 'MISS-AUTO-001',
                                selectedFromLocationType == 'manual'
                                    ? fromLocationManualController.text
                                    : selectedFromClinic,
                                selectedToLocationType == 'manual'
                                    ? toLocationManualController.text
                                    : selectedToClinic,
                                selectedPriority,
                                patientNameController.text,
                                patientPhoneController.text,
                                infirmierController.text,
                                notesController.text,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Créer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _generateMissionNumber() async {
    try {
      final missionData = await _apiClient.get(SupabaseConfig.missionsTable);
      final missions = missionData
          .map((json) => Mission.fromJson(json))
          .toList();
      final now = DateTime.now();
      final datePrefix =
          now.year.toString() +
          now.month.toString().padLeft(2, '0') +
          now.day.toString().padLeft(2, '0') +
          now.hour.toString().padLeft(2, '0');
      final sameDateMissions = missions
          .where((m) => m.missionNumber.startsWith('MISS-$datePrefix'))
          .toList();
      int nextCounter = 0;
      if (sameDateMissions.isNotEmpty) {
        final lastNumber = sameDateMissions.last.missionNumber;
        final counterStr = lastNumber.split('-').last;
        nextCounter = int.parse(counterStr) + 1;
        if (nextCounter > 999) {
          final nextDate = now.add(const Duration(hours: 1));
          final newDatePrefix =
              nextDate.year.toString() +
              nextDate.month.toString().padLeft(2, '0') +
              nextDate.day.toString().padLeft(2, '0') +
              nextDate.hour.toString().padLeft(2, '0');
          return 'MISS-$newDatePrefix-000';
        }
      }
      return 'MISS-$datePrefix-${nextCounter.toString().padLeft(3, '0')}';
    } catch (e) {
      return 'MISS-AUTO-001';
    }
  }

  Widget _buildLocationSection(
    String type,
    String selectedType,
    Function(String?) onTypeChanged,
    TextEditingController manualController,
    String selectedClinic,
    Function(String?) onClinicChanged,
    String selectedCity,
    Function(String?) onCityChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Clinique'),
                selected: selectedType == 'clinic',
                onSelected: (selected) {
                  if (selected) onTypeChanged('clinic');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Manuel'),
                selected: selectedType == 'manual',
                onSelected: (selected) {
                  if (selected) onTypeChanged('manual');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedType == 'clinic')
          ClinicDropdownField(
            value: selectedClinic,
            selectedCity: selectedCity,
            onChanged: onClinicChanged,
          )
        else
          TextFormField(
            controller: manualController,
            decoration: InputDecoration(
              hintText: type == 'From'
                  ? 'Lieu de départ'
                  : 'Lieu de destination',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  /// Map priority from UI format to database format
  /// UI uses: normal, urgent, urgence
  /// Database expects: empty/null for normal, 'urgent' for high priority
  String? _mapPriority(String uiPriority) {
    final priority = uiPriority.toLowerCase().trim();
    // Pass through all priority values directly
    // Supabase CHECK constraint should allow:
    // normal, urgent, urgence, IRM, scanner, coro, alerte thrombolyse,
    // transfert, dialyse, deces, scintigraphie, oxygenotherapie
    if (priority.isEmpty) {
      return null; // NULL for empty priority
    }
    return priority;
  }

  Future<void> _createMissionDirect(
    String missionNumber,
    String fromLocation,
    String toLocation,
    String priority,
    String patientName,
    String patientPhone,
    String infirmierName,
    String notes,
  ) async {
    try {
      print('\n🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩');
      print('🟩 [_createMissionDirect] ENTRY - DASHBOARD MISSION CREATION');
      print('🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩');
      print('   📋 All parameters received:');
      print('      missionNumber: $missionNumber');
      print('      Patient: $patientName');
      print('      Priority: $priority');
      print('      Phone: $patientPhone');
      print('      Infirmier: $infirmierName');

      print('   🔀 Parsing patient name...');
      // Extract first and last name from patient name
      final nameParts = patientName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      print('      firstName: \"$firstName\"');
      print('      lastName: \"$lastName\"');

      print('   🔗 MissionService type: ${_missionService.runtimeType}');
      print('   🚀 CALLING _missionService.createMission()...');
      // Use MissionService to create mission (handles notifications with deduplication)
      await _missionService.createMission(
        fromLocation: fromLocation,
        toLocation: toLocation,
        priority: priority,
        patientFirstName: firstName,
        patientLastName: lastName,
        patientPhone: patientPhone,
        infirmierName: infirmierName,
        missionPrice: '0', // No price in dashboard creation - use 0
        notes: notes,
        missionDate: DateTime.now().toIso8601String(),
      );

      print('   ✅ _missionService.createMission() returned');
      print('   📊 Reloading dashboard...');

      if (mounted) {
        print('   ✅ Widget mounted - executing post-creation actions');
        _loadDashboardData();
        print('   ✅ _loadDashboardData() called');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        print('   ✅ SnackBar shown');
      } else {
        print('   ⚠️  Widget not mounted');
      }
      print('🟩 [_createMissionDirect] EXIT - SUCCESS\n');
    } catch (e) {
      print('   ❌ EXCEPTION in _createMissionDirect: $e');
      print('   🔗 Stack: ${StackTrace.current}');
      if (mounted) {
        print('   ⚠️  Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('🟩 [_createMissionDirect] EXIT - FAILED\n');
    }
  }

  void _showCreateAmbulanceDialog() {
    final formKey = GlobalKey<FormState>();
    final ambulanceNumberController = TextEditingController();
    final telephoneController = TextEditingController();
    final driverIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter une Nouvelle Ambulance'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ambulanceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro d\'Ambulance',
                    hintText: 'Ex: AMB-001',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telephoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverIdController,
                  decoration: const InputDecoration(
                    labelText: 'Chauffeur (ID)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext);
                _createAmbulanceDirect(
                  ambulanceNumberController.text,
                  telephoneController.text,
                  driverIdController.text,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAmbulanceDirect(
    String ambulanceNumber,
    String telephone,
    String driverId,
  ) async {
    try {
      final body = {'ambulance_number': ambulanceNumber};
      if (telephone.isNotEmpty) body['telephone'] = telephone;
      if (driverId.isNotEmpty) body['current_driver_id'] = driverId;

      await _apiClient.post(SupabaseConfig.ambulancesTable, body);

      if (mounted) {
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambulance ajoutée avec succès'),
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
    print(
      '[DEBUG] Dashboard build() called - _selectedNavIndex=$_selectedNavIndex, totalMissions=$totalMissions',
    );
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: ManagerNavDrawer(
        user: widget.user,
        selectedIndex: _selectedNavIndex,
        scaffoldState: _scaffoldKey,
        onNavItemTapped: (index) {
          setState(() {
            _selectedNavIndex = index;
            if (index == 0) {
              _loadDashboardData();
            }
          });
        },
        onLogout: _logout,
      ),
      body: Column(
        children: [
          // Header
          _buildHeader(),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive.paddingValueLarge,
        vertical: context.responsive.paddingValueMedium,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: context.responsive.radiusSmall,
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: context.responsive.spacingSmall),
                  Expanded(
                    child: Text(
                      _managerHeaderTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedNavIndex == 1)
                  ElevatedButton.icon(
                    onPressed: () => _showCreateMissionDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouvelle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.responsive.paddingValueSmall,
                        vertical: context.responsive.paddingValueSmall,
                      ),
                    ),
                  ),
                SizedBox(width: context.responsive.spacingSmall),
                // Hamburger menu button to open right sidebar
                IconButton(
                  icon: const Icon(Icons.menu),
                  color: AppColors.primary,
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    print(
      '[DEBUG] _buildContent() called - _selectedNavIndex=$_selectedNavIndex, totalMissions=$totalMissions',
    );
    // 🔥 Dashboard is built DYNAMICALLY so it gets fresh data on setState()
    // Other tabs persist in _screens to avoid recreation
    if (_selectedNavIndex == 0) {
      print('[DEBUG] Building DASHBOARD content (index 0)');
      print(
        '[DEBUG] Dashboard will show: $totalMissions missions, $totalAmbulances ambulances',
      );
      return _buildDashboardContent(); // Builds fresh every time state changes with new data
    }

    print('[DEBUG] Using persisted widget at index $_selectedNavIndex');
    return _screens[_selectedNavIndex]; // Directly return the persisted widget
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Aperçu du Gestionnaire',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.responsive.spacingXSmall),
          Text(
            'Surveillance des opérations en temps réel',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          SizedBox(height: context.responsive.spacingXLarge),

          // Stats cards grid - smaller version
          GridView.count(
            crossAxisCount: context.responsive.gridColumns2,
            crossAxisSpacing: context.responsive.spacingMedium,
            mainAxisSpacing: context.responsive.spacingMedium,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              _buildSmallStatCard(
                'MISSIONS TOTALES',
                totalMissions.toString(),
                '',
                true,
              ),
              _buildSmallStatCard(
                'MISSIONS COMPLÉTÉES / SEMAINE',
                completedMissions.toString(),
                completedWeeklyChangePercent > 0
                    ? '+${completedWeeklyChangePercent.toStringAsFixed(1)}%'
                    : '${completedWeeklyChangePercent.toStringAsFixed(1)}%',
                completedWeeklyChangePercent >= 0,
              ),
              _buildSmallStatCard(
                'REVENUS TOTAUX / SEMAINE',
                '${totalRevenue.toStringAsFixed(0)} TND',
                revenueWeeklyChangePercent > 0
                    ? '+${revenueWeeklyChangePercent.toStringAsFixed(1)}%'
                    : '${revenueWeeklyChangePercent.toStringAsFixed(1)}%',
                revenueWeeklyChangePercent >= 0,
              ),
              _buildSmallStatCard(
                'AMBULANCES LIBRES',
                freeAmbulances.toString(),
                '', // No percentage for ambulances
                true,
              ),
            ],
          ),
          SizedBox(height: context.responsive.spacingXLarge),

          // Live Fleet Map
          // Text(
          //   'Carte de la Flotte en Direct',
          //   style: Theme.of(context).textTheme.titleMedium?.copyWith(
          //         fontWeight: FontWeight.bold,
          //       ),
          // ),
          // SizedBox(height: context.responsive.spacingMedium),
          // _buildFleetMap(),
          // SizedBox(height: context.responsive.spacingXLarge),

          // Missions Aujourd'hui
          Text(
            'Missions Aujourd\'hui',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.responsive.spacingMedium),
          _buildTodayMissions(),
          SizedBox(height: context.responsive.spacingXLarge),

          // Active Fleet Status
          Text(
            'État de la Flotte Active',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.responsive.spacingMedium),
          _buildActiveFleetStatus(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String change,
    bool isPositive,
  ) {
    return Container(
      padding: EdgeInsets.all(context.responsive.paddingValueMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: context.responsive.radiusLarge,
        border: Border.all(color: Colors.grey[200]!),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.responsive.spacingSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    change,
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(
    String label,
    String value,
    String change,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (change.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFleetMap() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        children: [
          // Map placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Intégration carte en cours...',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Live update badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MISE À JOUR EN DIRECT',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMissions() {
    // Filter missions for today
    final now = DateTime.now();
    final todayMissions = missions.where((m) {
      try {
        final missionDate = DateTime.parse(m.missionDate);
        return missionDate.year == now.year &&
            missionDate.month == now.month &&
            missionDate.day == now.day;
      } catch (e) {
        return false;
      }
    }).toList();

    // Sort by newest first (descending order)
    todayMissions.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.missionDate);
        final dateB = DateTime.parse(b.missionDate);
        return dateB.compareTo(dateA); // Descending order
      } catch (e) {
        return 0;
      }
    });

    // Limit to first 5 missions
    final limitedMissions = todayMissions;

    if (limitedMissions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'Aucune mission aujourd\'hui',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      height: 300, // Set max height for internal scroll - shows ~5 missions
      child: ListView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            todayMissions.length, // Show ALL missions, user scrolls to see
        itemBuilder: (context, index) {
          final mission = todayMissions[index];
          final clinicName = mission.clinicName?.trim();
          final clinicLabel = (clinicName != null && clinicName.isNotEmpty)
              ? clinicName
              : 'Mission clinique';
          final isClinicMission =
              mission.clinicTenantId != null &&
              mission.clinicTenantId!.isNotEmpty;
          final statusColor = mission.status == 'completed'
              ? Colors.green
              : mission.status == 'accepted'
              ? Colors.orange
              : Colors.blue;

          return Container(
            decoration: BoxDecoration(
              color: isClinicMission
                  ? const Color(0xFFF8F5FF)
                  : Colors.transparent,
              border: index < todayMissions.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                  : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isClinicMission) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Clinique: $clinicLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        'Mission #${mission.missionNumber}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isClinicMission
                                  ? const Color(0xFF6D28D9)
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mission.fromLocation} → ${mission.toLocation}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    mission.status.replaceFirst(
                      mission.status[0],
                      mission.status[0].toUpperCase(),
                    ),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFleetStatus() {
    if (ambulances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'Aucune ambulance disponible',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      children: ambulances.take(3).map((ambulance) {
        // Find active mission for this ambulance
        final activeMission = missions
            .where(
              (m) =>
                  m.ambulanceId == ambulance.id &&
                  (m.status == 'active' || m.status == 'pending'),
            )
            .firstOrNull;

        final hasMission = activeMission != null;
        final statusColor = hasMission ? Colors.orange : Colors.green;
        final statusText = hasMission ? 'EN MISSION' : 'DISPONIBLE';
        final destination = hasMission
            ? activeMission!.toLocation
            : 'En attente';
        final icon = hasMission ? Icons.directions_car : Icons.check_circle;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left border color indicator
              Container(
                width: 4,
                height: 70,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ambulance.ambulanceNumber ?? 'N/A',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasMission
                          ? '📍 Vers: $destination'
                          : 'Prête à être dépêchée',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  hasMission ? '🚑' : '✓',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFleetStatusCard(
    String ambulanceId,
    String status,
    String detail,
    String location,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left border color indicator
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ambulanceId,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Detail
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                detail,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: isMobile
          ? _buildMobileBottomNav() // Icons only for mobile
          : _buildTabletBottomNav(), // Full labels for tablet/desktop
    );
  }

  /// Mobile navigation - icons only with tooltips
  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedNavIndex,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
          tooltip: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Missions',
          tooltip: 'Missions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping),
          label: 'Parc',
          tooltip: 'Parc/Ambulances',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'Équipements',
          tooltip: 'Équipements',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Historique',
          tooltip: 'Historique',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.badge),
          label: 'Gardes',
          tooltip: 'Gardes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Suivi',
          tooltip: 'Suivi en temps réel',
        ),
      ],
      onTap: (index) {
        print('[DEBUG] Tab tapped: index=$index (was $_selectedNavIndex)');
        setState(() {
          _selectedNavIndex = index;
          print('[DEBUG] Tab switched to index=$index');
        });
      },
    );
  }

  /// Tablet/Desktop navigation - full labels
  Widget _buildTabletBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedNavIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ACCUEIL'),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'MISSIONS',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping),
          label: 'PARC',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'ÉQUIPEMENTS',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'HISTORIQUE'),
        BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'GARDES'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'SUIVI'),
      ],
      onTap: (index) {
        print('[DEBUG] Tab tapped: index=$index (was $_selectedNavIndex)');
        setState(() {
          _selectedNavIndex = index;
          print('[DEBUG] Tab switched to index=$index');
        });
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';
import '../widgets/clinic_dropdown_field.dart';

class ManagerMissionsScreen extends StatefulWidget {
  final User user;

  const ManagerMissionsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerMissionsScreen> createState() => _ManagerMissionsScreenState();
}

class _ManagerMissionsScreenState extends State<ManagerMissionsScreen>
    with WidgetsBindingObserver {
  final MissionService _missionService = MissionService();
  final ApiClient _apiClient = ApiClient();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'active'; // active, completed, cancelled, historique
  String _selectedAmbulanceFilter = ''; // Filter for historique tab
  Map<String, String> _ambulanceCache = {}; // Cache ambulance numbers
  bool _isProcessingTabChange = false; // Debounce rapid tab clicks

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
      final tenantRows = await _apiClient.get(
        '/rest/v1/tenants',
        filters: {
          'id': 'in.(${clinicTenantIds.join(',')})',
        },
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
      debugPrint('[ManagerMissions] Failed to attach clinic names: $e');
      return missionRows;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ManagerMissionsScreen] App resumed, reloading missions...');
      _loadMissions();
    }
  }

  void _loadMissions() {
    if (mounted) {
      setState(() {
        _allMissionsFuture = _getAllMissions();
      });
    }
  }

  Future<List<Mission>> _getAllMissions() async {
    try {
      final missionData = await _apiClient.get(SupabaseConfig.missionsTable);
      final enrichedMissionData = await _attachClinicNames(missionData);
      _preloadAmbulanceNames(enrichedMissionData);
      return enrichedMissionData.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      print('Error loading missions: $e');
      rethrow;
    }
  }

  void _preloadAmbulanceNames(List<dynamic> missionData) {
    // Extract unique ambulance IDs
    final ambulanceIds = <String>{};
    for (var mission in missionData) {
      final ambId = mission['ambulance_id'];
      if (ambId != null) {
        ambulanceIds.add(ambId.toString());
      }
    }

    // Load ambulance data in background
    if (ambulanceIds.isNotEmpty) {
      _loadAmbulanceNames(ambulanceIds.toList());
    }
  }

  Future<void> _loadAmbulanceNames(List<String> ambulanceIds) async {
    try {
      final ambulanceData =
          await _apiClient.get(SupabaseConfig.ambulancesTable);
      for (var amb in ambulanceData) {
        final id = amb['id'].toString();
        final number = amb['ambulance_number'] as String?;
        if (number != null) {
          _ambulanceCache[id] = number;
        }
      }
    } catch (e) {
      print('Error loading ambulance names: $e');
    }
  }

  String _getAmbulanceName(String ambulanceId) {
    if (_ambulanceCache.containsKey(ambulanceId)) {
      return _ambulanceCache[ambulanceId]!;
    }
    // Fallback: use first 4 chars or whole ID if shorter
    final displayId = ambulanceId.length >= 4
        ? ambulanceId.substring(0, 4).toUpperCase()
        : ambulanceId.toUpperCase();
    return 'AMB-$displayId';
  }

  Future<String> _generateMissionNumber() async {
    print('📍 [_generateMissionNumber] ENTRY');
    try {
      print('   ⏰ Generating timestamp...');
      // Generate unique mission number: MISS-YYYYMMDDHH-RRRR (with random 4-digit suffix)
      final now = DateTime.now();
      final datePrefix = now.year.toString() +
          now.month.toString().padLeft(2, '0') +
          now.day.toString().padLeft(2, '0') +
          now.hour.toString().padLeft(2, '0');

      // Add 4-digit random number for uniqueness
      final random =
          (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');
      final missionNumber = 'MISS-$datePrefix-$random';
      print('   ✅ Generated mission number: $missionNumber');
      print('📍 [_generateMissionNumber] EXIT - returning: $missionNumber');
      return missionNumber;
    } catch (e) {
      print('   ❌ Error generating mission number: $e');
      print('📍 [_generateMissionNumber] EXIT - returning fallback');
      return 'MISS-AUTO-${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _logout() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header matching dashboard style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.primary,
                          onPressed: () => Navigator.pop(context),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gestion des Missions',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showCreateMissionDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nouvelle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          color: AppColors.primary,
                          tooltip: 'Notifications',
                          onPressed: () {
                            // TODO: Implement notifications
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          color: AppColors.primary,
                          tooltip: 'Déconnexion',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildStatusTab('Actif', 'active'),
                const SizedBox(width: 8),
                _buildStatusTab('Complètée', 'completed'),
                const SizedBox(width: 8),
                _buildStatusTab('Annulée', 'cancelled'),
                const SizedBox(width: 8),
                _buildStatusTab('Historique', 'historique'),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),

          // Historique Filter & Statistics
          if (_selectedStatus == 'historique')
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<List<Mission>>(
                future: _allMissionsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final historiqueMissions = snapshot.data!
                      .where((m) =>
                          m.status == 'completed' || m.status == 'cancelled')
                      .toList();

                  // Get unique ambulances
                  final ambulanceIds = <String>{};
                  for (var mission in historiqueMissions) {
                    final ambId = mission.ambulanceId ?? '';
                    if (ambId.isNotEmpty) {
                      ambulanceIds.add(ambId);
                    }
                  }

                  // Calculate statistics for selected ambulance
                  late List<Mission> ambMissions;
                  late Map<String, int> stats;

                  if (_selectedAmbulanceFilter.isEmpty) {
                    ambMissions = historiqueMissions;
                    stats = {'completed': 0, 'cancelled': 0};
                    for (var m in historiqueMissions) {
                      if (m.status == 'completed')
                        stats['completed'] = (stats['completed'] ?? 0) + 1;
                      if (m.status == 'cancelled')
                        stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
                    }
                  } else {
                    ambMissions = historiqueMissions
                        .where((m) => m.ambulanceId == _selectedAmbulanceFilter)
                        .toList();
                    stats = {'completed': 0, 'cancelled': 0};
                    for (var m in ambMissions) {
                      if (m.status == 'completed')
                        stats['completed'] = (stats['completed'] ?? 0) + 1;
                      if (m.status == 'cancelled')
                        stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
                    }
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ambulance Filter
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedAmbulanceFilter,
                              isExpanded: true,
                              hint: const Text('Filtrer par ambulance'),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Toutes les ambulances'),
                                ),
                                ...ambulanceIds.map((id) {
                                  final number = _getAmbulanceName(id);
                                  return DropdownMenuItem(
                                    value: id,
                                    child: Text(number),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                      () => _selectedAmbulanceFilter = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Statistics
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '${stats['completed'] ?? 0}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: Colors.green),
                                ),
                                const Text('Complétées'),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '${stats['cancelled'] ?? 0}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: Colors.red),
                                ),
                                const Text('Annulées'),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '${ambMissions.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: Colors.blue),
                                ),
                                const Text('Total'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Missions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                _loadMissions();
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allMissions = snapshot.data ?? [];
                  final filteredMissions = allMissions.where((mission) {
                    // Filter by status
                    bool statusMatch = false;
                    if (_selectedStatus == 'historique') {
                      statusMatch = mission.status == 'completed' ||
                          mission.status == 'cancelled';
                    } else {
                      statusMatch = mission.status == _selectedStatus;
                    }

                    // Filter by ambulance if set and in historique tab
                    if (_selectedStatus == 'historique' &&
                        _selectedAmbulanceFilter.isNotEmpty) {
                      return statusMatch &&
                          mission.ambulanceId == _selectedAmbulanceFilter;
                    }

                    return statusMatch;
                  }).toList()
                    ..sort((a, b) => DateTime.parse(b.missionDate)
                        .compareTo(DateTime.parse(a.missionDate)));

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
                                    : Icons.cancel,
                            color: Colors.grey[400],
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune mission ${_selectedStatus == 'active' ? 'active' : _selectedStatus == 'completed' ? 'complétée' : 'annulée'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildMissionsList(context, filteredMissions);
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
        onTap: () async {
          // Prevent rapid clicks from causing disposed widget errors
          if (_isProcessingTabChange || !mounted) return;

          _isProcessingTabChange = true;
          try {
            if (mounted) {
              setState(() {
                _selectedStatus = status;
              });
            }
            // Delay before allowing next click
            await Future.delayed(const Duration(milliseconds: 300));
          } finally {
            if (mounted) {
              _isProcessingTabChange = false;
            }
          }
        },
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: context.responsive.spacingMedium),
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

  Widget _buildMissionsList(BuildContext context, List<Mission> missions) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      child: Column(
        children: missions.asMap().entries.map((entry) {
          final mission = entry.value;
          final isActive = _selectedStatus == 'active';

          return Padding(
            padding: EdgeInsets.only(bottom: context.responsive.spacingLarge),
            child: _buildMissionCard(context, mission, isActive),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissionCard(
      BuildContext context, Mission mission, bool isActive) {
    final isPriority = (mission.priority ?? '').toUpperCase() == 'CRITICAL' ||
        (mission.priority ?? '').toUpperCase() == 'EMERGENCY';
    final clinicName = mission.clinicName?.trim();
    final clinicLabel = (clinicName != null && clinicName.isNotEmpty)
        ? clinicName
        : 'Mission clinique';
    final isClinicMission =
        mission.clinicTenantId != null && mission.clinicTenantId!.isNotEmpty;
    final accentColor =
        isClinicMission ? const Color(0xFF7C3AED) : AppColors.primary;

    return Container(
      padding: EdgeInsets.all(context.responsive.paddingValueLarge),
      decoration: BoxDecoration(
        color: isClinicMission ? const Color(0xFFF8F5FF) : Colors.white,
        borderRadius: context.responsive.radiusLarge,
        border: Border.all(
          color: isClinicMission
              ? const Color(0xFFD8B4FE)
              : Colors.grey[200]!,
          width: isClinicMission ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isClinicMission ? accentColor : Colors.black)
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
                  const Icon(Icons.local_hospital,
                      color: Colors.white, size: 18),
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
            SizedBox(height: context.responsive.spacingMedium),
          ],
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'MISSION #${mission.missionNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPriority
                        ? Colors.red
                        : (isClinicMission ? accentColor : Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPriority ? 'URGENT' : (isClinicMission ? 'CLINIC' : 'NORMAL'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.responsive.spacingMedium),

          // Locations
            Row(
              children: [
                Icon(Icons.location_on, color: accentColor, size: 18),
                SizedBox(width: context.responsive.spacingSmall),
                Expanded(
                  child: Text(
                  mission.fromLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: context.responsive.spacingSmall),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 18),
              SizedBox(width: context.responsive.spacingSmall),
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
          SizedBox(height: context.responsive.spacingMedium),

          // Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ambulance',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    _getAmbulanceName(mission.ambulanceId),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
            ],
          ),
          SizedBox(height: context.responsive.spacingMedium),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditMissionDialog(mission),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: context.responsive.spacingSmall,
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              SizedBox(width: context.responsive.spacingSmall),
              if (isActive)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusChangeDialog(mission),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mettre à jour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: context.responsive.spacingSmall,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteConfirmation(mission),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: context.responsive.spacingSmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Facture and Imprimer buttons for completed/cancelled missions
          if (!isActive) ...[
            SizedBox(height: context.responsive.spacingSmall),
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
                      padding: EdgeInsets.symmetric(
                        vertical: context.responsive.spacingSmall,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.responsive.spacingSmall),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generateInvoice(context, mission),
                    icon: const Icon(Icons.receipt, size: 16),
                    label: const Text('Facture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: context.responsive.spacingSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showCreateMissionDialog() {
    print('\n\n🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷');
    print('🔷 [_ManagerMissionsScreenState._showCreateMissionDialog] ENTRY');
    print('🔷 Screen 1: STANDALONE MISSIONS SCREEN');
    print('🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷🔷\n');

    final formKey = GlobalKey<FormState>();
    final patientNameController = TextEditingController();
    final patientPhoneController = TextEditingController();
    final infirmierController = TextEditingController();
    final tarifController = TextEditingController();
    final notesController = TextEditingController();

    String? generatedMissionNumber;
    String selectedPriority = 'normal';
    String selectedMotifTransport = LocationData.motifTransportOptions.first;
    String selectedFromLocationType = 'clinic';
    String selectedFromClinic = LocationData.clinicsSfax.first;
    String selectedFromCity = 'Sfax';
    final fromLocationManualController = TextEditingController();

    String selectedToLocationType = 'clinic';
    String selectedToClinic = LocationData.clinicsSfax.first;
    String selectedToCity = 'Sfax';
    final toLocationManualController = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: EdgeInsets.all(context.responsive.paddingValueLarge),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(context.responsive.paddingValueXLarge),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: context.responsive.spacingXLarge),

                    // Date and Time
                    Text(
                      'Date et Heure',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    Container(
                      padding:
                          EdgeInsets.all(context.responsive.paddingValueMedium),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: context.responsive.radiusSmall,
                      ),
                      child: Text(
                        DateTime.now().toString().split('.')[0],
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Priority
                    Text(
                      'Priorité',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                      items: LocationData.priorityOptions.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(
                              LocationData.getPriorityDisplayName(priority)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedPriority = value);
                        }
                      },
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Motif de Transport
                    Text(
                      'Motif de Transport',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    DropdownButtonFormField<String>(
                      value: selectedMotifTransport,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                      items: LocationData.motifTransportOptions.map((motif) {
                        return DropdownMenuItem(
                          value: motif,
                          child: Text(
                              LocationData.getMotifTransportDisplayName(motif)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedMotifTransport = value);
                        }
                      },
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Lieu de Départ
                    Text(
                      'Lieu de Départ',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    _buildLocationSection(
                      'From',
                      selectedFromLocationType,
                      (value) =>
                          setState(() => selectedFromLocationType = value!),
                      fromLocationManualController,
                      selectedFromClinic,
                      (value) => setState(() => selectedFromClinic = value!),
                      selectedFromCity,
                      (value) => setState(() => selectedFromCity = value!),
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Lieu de Destination
                    Text(
                      'Lieu de Destination',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    _buildLocationSection(
                      'To',
                      selectedToLocationType,
                      (value) =>
                          setState(() => selectedToLocationType = value!),
                      toLocationManualController,
                      selectedToClinic,
                      (value) => setState(() => selectedToClinic = value!),
                      selectedToCity,
                      (value) => setState(() => selectedToCity = value!),
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Patient Name
                    Text(
                      'Nom du Patient',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    TextFormField(
                      controller: patientNameController,
                      decoration: InputDecoration(
                        hintText: 'Nom complet',
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Patient Phone
                    Text(
                      'Téléphone du Patient',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    TextFormField(
                      controller: patientPhoneController,
                      decoration: InputDecoration(
                        hintText: 'Numéro de téléphone',
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Infirmier/Médecin
                    Text(
                      'Infirmier/Médecin',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    TextFormField(
                      controller: infirmierController,
                      decoration: InputDecoration(
                        hintText: 'Nom',
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Tarif
                    Text(
                      'Tarif',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    TextFormField(
                      controller: tarifController,
                      decoration: InputDecoration(
                        hintText: 'Montant',
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: context.responsive.spacingLarge),

                    // Notes
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: context.responsive.spacingSmall),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes supplémentaires',
                        border: OutlineInputBorder(
                          borderRadius: context.responsive.radiusSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsive.paddingValueMedium,
                          vertical: context.responsive.paddingValueMedium,
                        ),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: context.responsive.spacingXLarge),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed:
                              isLoading ? null : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState?.validate() ??
                                      false) {
                                    setState(() => isLoading = true);

                                    try {
                                      // Generate mission number FIRST, while dialog is open
                                      final missionNumber =
                                          await _generateMissionNumber();
                                      print(
                                          '✅ [Dialog] Generated mission number: $missionNumber');

                                      // NOW close the dialog
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }

                                      // THEN run the async mission creation
                                      print(
                                          '🚀 [Dialog] About to create mission...');
                                      await _createMissionComprehensive(
                                        missionNumber,
                                        _formatDate(DateTime.now()),
                                        selectedFromLocationType == 'manual'
                                            ? fromLocationManualController.text
                                            : selectedFromClinic,
                                        selectedToLocationType == 'manual'
                                            ? toLocationManualController.text
                                            : selectedToClinic,
                                        selectedPriority,
                                        selectedMotifTransport,
                                        patientNameController.text,
                                        patientPhoneController.text,
                                        infirmierController.text,
                                        tarifController.text,
                                        notesController.text,
                                      );
                                      print(
                                          '✅ [Dialog] Mission creation completed');
                                    } catch (e) {
                                      print('❌ [Dialog] Error: $e');
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => isLoading = false);
                                      }
                                    }
                                  }
                                },
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
                              : const Text('Créer'),
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
        // Type selector
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
            SizedBox(width: context.responsive.spacingSmall),
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
        SizedBox(height: context.responsive.spacingMedium),

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
              hintText:
                  type == 'From' ? 'Lieu de départ' : 'Lieu de destination',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _createMissionComprehensive(
    String missionNumber,
    String missionDate,
    String fromLocation,
    String toLocation,
    String priority,
    String motifTransport,
    String patientName,
    String patientPhone,
    String infirmierName,
    String tarif,
    String notes,
  ) async {
    try {
      print('\n🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥');
      print('🟥 [_createMissionComprehensive] ENTRY');
      print('🟥 SCREEN 1 - STANDALONE MISSION CREATION');
      print('🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥');
      print('   📋 All parameters received:');
      print('      missionNumber: $missionNumber');
      print('      missionDate: $missionDate');
      print('      Patient: $patientName');
      print('      Priority: $priority');
      print('      Motif Transport: $motifTransport');
      print('      Phone: $patientPhone');
      print('      Infirmier: $infirmierName');
      print('      Tarif: $tarif');

      print('   🔀 Parsing patient name...');
      // Extract first and last name from patient name
      final nameParts = patientName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      print('      firstName: \"$firstName\"');
      print('      lastName: \"$lastName\"');

      print('   🔗 MissionService type: ${_missionService.runtimeType}');
      print('   🚀 CALLING _missionService.createMission()...');
      // Use MissionService to create mission (handles notifications automatically with deduplication)
      await _missionService.createMission(
        fromLocation: fromLocation,
        toLocation: toLocation,
        priority: priority,
        motifTransport: motifTransport,
        patientFirstName: firstName,
        patientLastName: lastName,
        patientPhone: patientPhone,
        infirmierName: infirmierName,
        missionPrice: tarif,
        notes: notes,
        missionDate: missionDate,
      );

      print('   ✅ _missionService.createMission() returned');
      print('   📊 Reloading missions...');

      if (mounted) {
        print('   ✅ Widget mounted - executing post-creation actions');
        _loadMissions();
        print('   ✅ _loadMissions() called');
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
      print('🟥 [_createMissionComprehensive] EXIT - SUCCESS\n');
    } catch (e) {
      print('   ❌ EXCEPTION in _createMissionComprehensive: $e');
      print('   🔗 Stack: ${StackTrace.current}');
      if (mounted) {
        print('   ⚠️  Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('🟥 [_createMissionComprehensive] EXIT - FAILED\n');
    }
  }

  void _showEditMissionDialog(Mission mission) {
    final formKey = GlobalKey<FormState>();
    final missionNumberCtrl =
        TextEditingController(text: mission.missionNumber);
    final dateCtrl = TextEditingController(text: mission.missionDate);
    final fromLocationCtrl = TextEditingController(text: mission.fromLocation);
    final toLocationCtrl = TextEditingController(text: mission.toLocation);
    final driverNameCtrl =
        TextEditingController(text: mission.driverName ?? '');
    final infirmierNameCtrl =
        TextEditingController(text: mission.infirmierName ?? '');
    String selectedPriority = mission.priority;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier la Mission'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: missionNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de Mission',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                SizedBox(height: context.responsive.spacingMedium),
                TextFormField(
                  controller: fromLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de Départ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: toLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: driverNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chauffeur',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: context.responsive.spacingMedium),
                TextFormField(
                  controller: infirmierNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Infirmier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priorité',
                    border: OutlineInputBorder(),
                  ),
                  items: LocationData.priorityOptions.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child:
                          Text(LocationData.getPriorityDisplayName(priority)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) selectedPriority = value;
                  },
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
                _updateMission(
                  mission,
                  missionNumberCtrl.text,
                  dateCtrl.text,
                  fromLocationCtrl.text,
                  toLocationCtrl.text,
                  driverNameCtrl.text,
                  infirmierNameCtrl.text,
                  selectedPriority,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMission(
    Mission mission,
    String missionNumber,
    String missionDate,
    String fromLocation,
    String toLocation,
    String driverName,
    String infirmierName,
    String priority,
  ) async {
    try {
      await _missionService.updateMissionField(
          mission.id, 'mission_number', missionNumber);
      await _missionService.updateMissionField(
          mission.id, 'mission_date', missionDate);
      await _missionService.updateMissionField(
          mission.id, 'from_location', fromLocation);
      await _missionService.updateMissionField(
          mission.id, 'to_location', toLocation);
      await _missionService.updateMissionField(
          mission.id, 'driver_name', driverName);
      await _missionService.updateMissionField(
          mission.id, 'infirmier_name', infirmierName);
      await _missionService.updateMissionField(
          mission.id, 'priority', priority);

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission mise à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusChangeDialog(Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le Statut'),
        content: const Text('Sélectionner le nouveau statut:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateStatus(mission, 'completed');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Complétée'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateStatus(mission, 'cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Annulée'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la Suppression'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer la mission #${mission.missionNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteMission(mission);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(Mission mission, String newStatus) async {
    try {
      print('\n🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄');
      print('🔄 [Manager] UPDATING MISSION STATUS');
      print('🔄 Mission ID: ${mission.id}');
      print('🔄 Mission Number: ${mission.missionNumber}');
      print('🔄 Current Status: ${mission.status}');
      print('🔄 New Status: $newStatus');
      print('🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄\n');

      print('   🔗 Calling _missionService.updateMissionStatus()...');
      await _missionService.updateMissionStatus(mission.id, newStatus);
      print('   ✅ MissionService returned successfully');

      if (mounted) {
        print('   📊 Reloading missions and showing success snackbar...');
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Statut mis à jour en ${newStatus == 'completed' ? 'Complétée' : 'Annulée'}'),
            backgroundColor: Colors.green,
          ),
        );
        print('   ✅ UI updated with new status\n');
      } else {
        print('   ⚠️  Widget not mounted - skipping UI updates\n');
      }
    } catch (e) {
      print('   ❌ EXCEPTION in _updateStatus: $e');
      print('   🔗 Stack: ${StackTrace.current}\n');
      if (mounted) {
        print('   ⚠️  Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send notification when manager creates a mission
  Future<void> _sendMissionNotification({
    required String missionNumber,
    required String patientName,
    required String priority,
    required String fromLocation,
    required String toLocation,
  }) async {
    // This method is deprecated - notifications are now handled by MissionService
    // which provides built-in deduplication. This method is kept for backward compatibility only.
    debugPrint(
        '[Manager Screen] ⚠️  _sendMissionNotification is deprecated - using MissionService instead');
  }

  Future<void> _deleteMission(Mission mission) async {
    try {
      await _apiClient.delete(
        SupabaseConfig.missionsTable,
        mission.id,
      );

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMissionPDF(
      BuildContext context, Mission mission) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération du PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await PdfService.generateMissionReportPdf(mission);

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
      debugPrint('[Manager] PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la génération du PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generateInvoice(BuildContext context, Mission mission) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération de la facture...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await PdfService.generateInvoicePdf(mission);

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
      debugPrint('[Manager] Invoice generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur lors de la génération de la facture: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Wrapper widget for embedding missions screen content in dashboard tabs
class ManagerMissionsScreenContent extends StatefulWidget {
  final User user;

  const ManagerMissionsScreenContent({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerMissionsScreenContent> createState() =>
      _ManagerMissionsScreenContentState();
}

class _ManagerMissionsScreenContentState
    extends State<ManagerMissionsScreenContent> with WidgetsBindingObserver {
  final MissionService _missionService = MissionService();
  final ApiClient _apiClient = ApiClient();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'active';
  String _selectedAmbulanceFilter = ''; // Filter for historique tab
  Map<String, String> _ambulanceCache = {};
  bool _isProcessingTabChange = false;

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
      final tenantRows = await _apiClient.get(
        '/rest/v1/tenants',
        filters: {
          'id': 'in.(${clinicTenantIds.join(',')})',
        },
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
      debugPrint('[ManagerMissionsContent] Failed to attach clinic names: $e');
      return missionRows;
    }
  }

  @override
  void initState() {
    super.initState();
    print('[DEBUG] ManagerMissionsScreenContent initState() called');
    WidgetsBinding.instance.addObserver(this);
    _loadMissions();
    print(
        '[DEBUG] ManagerMissionsScreenContent: _loadMissions() called in initState');

    // 🔥 CRITICAL FIX: Reload after widget is fully built
    // This prevents lifecycle event race conditions when widget is recreated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print(
            '[DEBUG] ManagerMissionsScreenContent: Post-frame callback fired');
        debugPrint(
            '[ManagerMissionsScreenContent] Post-frame callback: reloading missions');
        _loadMissions();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint(
          '[ManagerMissionsScreenContent] App resumed, reloading missions...');
      _loadMissions();
    }
  }

  void _loadMissions() {
    if (mounted) {
      setState(() {
        _allMissionsFuture = _getAllMissions();
      });
    }
  }

  Future<List<Mission>> _getAllMissions() async {
    try {
      final missionData = await _apiClient.get(SupabaseConfig.missionsTable);
      final enrichedMissionData = await _attachClinicNames(missionData);
      _preloadAmbulanceNames(enrichedMissionData);
      return enrichedMissionData.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      print('Error loading missions: $e');
      rethrow;
    }
  }

  void _preloadAmbulanceNames(List<dynamic> missionData) {
    final ambulanceIds = <String>{};
    for (var mission in missionData) {
      final ambId = mission['ambulance_id'];
      if (ambId != null) {
        ambulanceIds.add(ambId.toString());
      }
    }
    if (ambulanceIds.isNotEmpty) {
      _loadAmbulanceNames(ambulanceIds.toList());
    }
  }

  Future<void> _loadAmbulanceNames(List<String> ambulanceIds) async {
    try {
      final ambulanceData =
          await _apiClient.get(SupabaseConfig.ambulancesTable);
      for (var amb in ambulanceData) {
        final id = amb['id'].toString();
        final number = amb['ambulance_number'] as String?;
        if (number != null) {
          _ambulanceCache[id] = number;
        }
      }
    } catch (e) {
      print('Error loading ambulance names: $e');
    }
  }

  String _getAmbulanceName(String ambulanceId) {
    if (_ambulanceCache.containsKey(ambulanceId)) {
      return _ambulanceCache[ambulanceId]!;
    }
    final displayId = ambulanceId.length >= 4
        ? ambulanceId.substring(0, 4).toUpperCase()
        : ambulanceId.toUpperCase();
    return 'AMB-$displayId';
  }

  Future<String> _generateMissionNumber() async {
    try {
      // Generate unique mission number: MISS-YYYYMMDDHH-RRRR (with random 4-digit suffix)
      final now = DateTime.now();
      final datePrefix = now.year.toString() +
          now.month.toString().padLeft(2, '0') +
          now.day.toString().padLeft(2, '0') +
          now.hour.toString().padLeft(2, '0');

      // Add 4-digit random number for uniqueness
      final random =
          (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');
      final missionNumber = 'MISS-$datePrefix-$random';
      debugPrint('🔢 [SCREEN 2 - DASHBOARD] Generated: $missionNumber');
      return missionNumber;
    } catch (e) {
      debugPrint('Error generating mission number: $e');
      return 'MISS-AUTO-${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
  }

  void _showCreateMissionDialog() {
    print('\n\n🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶');
    print(
        '🔶 [_ManagerMissionsScreenContentState._showCreateMissionDialog] ENTRY');
    print('🔶 Screen 2: DASHBOARD EMBEDDED MISSIONS SCREEN');
    print('🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶🔶\n');

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

    print('   ✅ Controllers and variables initialized');
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    Text('Date et Heure',
                        style: Theme.of(context).textTheme.labelLarge),
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
                    Text('Priorité',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
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
                    Text('Lieu de Départ',
                        style: Theme.of(context).textTheme.labelLarge),
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
                        (value) {}),
                    const SizedBox(height: 16),
                    Text('Lieu de Destination',
                        style: Theme.of(context).textTheme.labelLarge),
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
                        (value) {}),
                    const SizedBox(height: 16),
                    Text('Nom du Patient',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: patientNameController,
                      decoration: InputDecoration(
                        hintText: 'Nom complet',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Téléphone du Patient',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: patientPhoneController,
                      decoration: InputDecoration(
                        hintText: 'Numéro de téléphone',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Text('Infirmier/Médecin',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: infirmierController,
                      decoration: InputDecoration(
                        hintText: 'Nom',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Tarif',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: tarifController,
                      decoration: InputDecoration(
                        hintText: 'Montant',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Text('Notes',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes supplémentaires',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
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
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              try {
                                // Generate mission number FIRST, while dialog is open
                                final missionNumber =
                                    await _generateMissionNumber();
                                print(
                                    '✅ [Dashboard Dialog] Generated mission number: $missionNumber');

                                // NOW close the dialog
                                if (mounted) {
                                  Navigator.pop(context);
                                }

                                // THEN run the async mission creation
                                print(
                                    '🚀 [Dashboard Dialog] About to create mission...');
                                await _createMissionWrapper(
                                  missionNumber,
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
                                  tarifController.text,
                                  notesController.text,
                                );
                                print(
                                    '✅ [Dashboard Dialog] Mission creation completed');
                              } catch (e) {
                                print('❌ [Dashboard Dialog] Error: $e');
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              }
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

  Future<void> _createMissionWrapper(
    String missionNumber,
    String fromLocation,
    String toLocation,
    String priority,
    String patientName,
    String patientPhone,
    String infirmierName,
    String tarif,
    String notes,
  ) async {
    try {
      print('\n🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧');
      print('🟧 [_createMissionWrapper] ENTRY');
      print('🟧 SCREEN 2 - DASHBOARD MISSION CREATION');
      print('🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧🟧');
      print('   📋 All parameters received:');
      print('      missionNumber: $missionNumber');
      print('      Patient: $patientName');
      print('      Priority: $priority');
      print('      Phone: $patientPhone');
      print('      Infirmier: $infirmierName');
      print('      Tarif: $tarif');

      print('   🔀 Parsing patient name...');
      // Extract first and last name from patient name
      final nameParts = patientName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      print('      firstName: \"$firstName\"');
      print('      lastName: \"$lastName\"');

      print('   🔗 MissionService type: ${_missionService.runtimeType}');
      print('   🚀 CALLING _missionService.createMission()...');
      // Use MissionService to create mission (handles notifications automatically with deduplication)
      await _missionService.createMission(
        fromLocation: fromLocation,
        toLocation: toLocation,
        priority: priority,
        patientFirstName: firstName,
        patientLastName: lastName,
        patientPhone: patientPhone,
        infirmierName: infirmierName,
        missionPrice: tarif,
        notes: notes,
        missionDate: DateTime.now().toIso8601String(),
      );

      print('   ✅ _missionService.createMission() returned');
      print('   📊 Reloading missions...');

      if (mounted) {
        print('   ✅ Widget mounted - executing post-creation actions');
        _loadMissions();
        print('   ✅ _loadMissions() called');
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
      print('🟧 [_createMissionWrapper] EXIT - SUCCESS\n');
    } catch (e) {
      print('   ❌ EXCEPTION in _createMissionWrapper: $e');
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
      print('🟧 [_createMissionWrapper] EXIT - FAILED\n');
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
              hintText:
                  type == 'From' ? 'Lieu de départ' : 'Lieu de destination',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  void _showEditMissionDialog(Mission mission) {
    final formKey = GlobalKey<FormState>();
    final missionNumberCtrl =
        TextEditingController(text: mission.missionNumber);
    final dateCtrl = TextEditingController(text: mission.missionDate);
    final fromLocationCtrl = TextEditingController(text: mission.fromLocation);
    final toLocationCtrl = TextEditingController(text: mission.toLocation);
    final infirmierNameCtrl =
        TextEditingController(text: mission.infirmierName ?? '');
    String selectedPriority = mission.priority;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier la Mission'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: missionNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de Mission',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fromLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de Départ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: toLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: infirmierNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Infirmier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priorité',
                    border: OutlineInputBorder(),
                  ),
                  items: LocationData.priorityOptions.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child:
                          Text(LocationData.getPriorityDisplayName(priority)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) selectedPriority = value;
                  },
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
                _updateMissionWrapper(
                  mission.id,
                  missionNumberCtrl.text,
                  fromLocationCtrl.text,
                  toLocationCtrl.text,
                  infirmierNameCtrl.text,
                  selectedPriority,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMissionWrapper(
    String missionId,
    String missionNumber,
    String fromLocation,
    String toLocation,
    String infirmierName,
    String priority,
  ) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {
          'mission_number': missionNumber,
          'from_location': fromLocation,
          'to_location': toLocation,
          'infirmier_name': infirmierName,
          'priority': priority,
        },
      );

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission mise à jour avec succès'),
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

  void _showStatusChangeDialog(Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le Statut'),
        content: const Text('Sélectionner le nouveau statut:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateMissionStatus(mission.id, 'completed');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Complétée'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateMissionStatus(mission.id, 'cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Annulée'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMissionStatus(String missionId, String newStatus) async {
    try {
      print('\n🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄');
      print('🔄 [Dashboard] UPDATING MISSION STATUS');
      print('🔄 Mission ID: $missionId');
      print('🔄 New Status: $newStatus');
      print('🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄🔄\n');

      print('   🔗 Calling _missionService.updateMissionStatus()...');
      await _missionService.updateMissionStatus(missionId, newStatus);
      print('   ✅ MissionService returned successfully');

      if (mounted) {
        print('   📊 Reloading missions and showing success snackbar...');
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut mis à jour en ${newStatus == 'completed' ? 'Complétée' : 'Annulée'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        print('   ✅ UI updated with new status\n');
      } else {
        print('   ⚠️  Widget not mounted - skipping UI updates\n');
      }
    } catch (e) {
      print('   ❌ EXCEPTION in _updateMissionStatus: $e');
      print('   🔗 Stack: ${StackTrace.current}\n');
      if (mounted) {
        print('   ⚠️  Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la Suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la mission #${mission.missionNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteMissionWrapper(mission.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMissionWrapper(String missionId) async {
    try {
      await _apiClient.delete(SupabaseConfig.missionsTable, missionId);

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission supprimée avec succès'),
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

  /// Send notification when manager creates a mission
  Future<void> _sendMissionNotification({
    required String missionNumber,
    required String patientName,
    required String priority,
    required String fromLocation,
    required String toLocation,
  }) async {
    // This method is deprecated - notifications are now handled by MissionService
    // which provides built-in deduplication. This method is kept for backward compatibility only.
    debugPrint(
        '[Dashboard Content] ⚠️  _sendMissionNotification is deprecated - using MissionService instead');
  }

  Future<void> _generateMissionPDF(
      BuildContext context, Mission mission) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération du PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await PdfService.generateMissionReportPdf(mission);

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
      debugPrint('[Dashboard] PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la génération du PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generateInvoice(BuildContext context, Mission mission) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération de la facture...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await PdfService.generateInvoicePdf(mission);

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
      debugPrint('[Dashboard] Invoice generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur lors de la génération de la facture: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status Filter Tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildStatusTab('Actif', 'active'),
              const SizedBox(width: 8),
              _buildStatusTab('Complètée', 'completed'),
              const SizedBox(width: 8),
              _buildStatusTab('Annulée', 'cancelled'),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[300]),

        // Missions List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              _loadMissions();
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                final allMissions = snapshot.data ?? [];
                final filteredMissions = allMissions
                    .where((mission) => mission.status == _selectedStatus)
                    .toList()
                  ..sort((a, b) => DateTime.parse(b.missionDate)
                      .compareTo(DateTime.parse(a.missionDate)));

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
                                  : Icons.cancel,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune mission ${_selectedStatus == 'active' ? 'active' : _selectedStatus == 'completed' ? 'complétée' : 'annulée'}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildMissionsList(context, filteredMissions);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTab(String label, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (_isProcessingTabChange || !mounted) return;

          _isProcessingTabChange = true;
          try {
            if (mounted) {
              setState(() {
                _selectedStatus = status;
              });
            }
            await Future.delayed(const Duration(milliseconds: 300));
          } finally {
            if (mounted) {
              _isProcessingTabChange = false;
            }
          }
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

  Widget _buildMissionsList(BuildContext context, List<Mission> missions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: missions.asMap().entries.map((entry) {
          final mission = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMissionCard(context, mission),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, Mission mission) {
    final isPriority = (mission.priority ?? '').toUpperCase() == 'CRITICAL' ||
        (mission.priority ?? '').toUpperCase() == 'EMERGENCY';
    final isActive = mission.status == 'active';
    final clinicName = mission.clinicName?.trim();
    final clinicLabel = (clinicName != null && clinicName.isNotEmpty)
        ? clinicName
        : 'Mission clinique';
    final isClinicMission =
        mission.clinicTenantId != null && mission.clinicTenantId!.isNotEmpty;
    final accentColor =
        isClinicMission ? const Color(0xFF7C3AED) : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClinicMission ? const Color(0xFFF8F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClinicMission
              ? const Color(0xFFD8B4FE)
              : Colors.grey[200]!,
          width: isClinicMission ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isClinicMission ? accentColor : Colors.black)
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
                  const Icon(Icons.local_hospital,
                      color: Colors.white, size: 18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'MISSION #${mission.missionNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPriority
                        ? Colors.red
                        : (isClinicMission ? accentColor : Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPriority ? 'URGENT' : (isClinicMission ? 'CLINIC' : 'NORMAL'),
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
            Row(
              children: [
                Icon(Icons.location_on, color: accentColor, size: 18),
                SizedBox(width: context.responsive.spacingSmall),
                Expanded(
                  child: Text(
                  mission.fromLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: context.responsive.spacingSmall),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 18),
              SizedBox(width: context.responsive.spacingSmall),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ambulance',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    _getAmbulanceName(mission.ambulanceId),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditMissionDialog(mission),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusChangeDialog(mission),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mettre à jour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteConfirmation(mission),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
          // Facture and Imprimer buttons for completed/cancelled missions
          if (!isActive) ...[
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
          ],
        ],
      ),
    );
  }
}

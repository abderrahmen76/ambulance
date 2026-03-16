import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../services/api_client.dart';
import '../config/constants.dart';

class ManagerMissionsScreen extends StatefulWidget {
  final User user;

  const ManagerMissionsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerMissionsScreen> createState() => _ManagerMissionsScreenState();
}

class _ManagerMissionsScreenState extends State<ManagerMissionsScreen> {
  final MissionService _missionService = MissionService();
  final ApiClient _apiClient = ApiClient();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'active'; // active, completed, cancelled
  Map<String, String> _ambulanceCache = {}; // Cache ambulance numbers
  bool _isProcessingTabChange = false; // Debounce rapid tab clicks

  @override
  void initState() {
    super.initState();
    _loadMissions();
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
      _preloadAmbulanceNames(missionData);
      return missionData.map((json) => Mission.fromJson(json)).toList();
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
    try {
      // Get all missions
      final missionData = await _apiClient.get(SupabaseConfig.missionsTable);
      final missions =
          missionData.map((json) => Mission.fromJson(json)).toList();

      // Get today's date in format YYYYMMDDHH
      final now = DateTime.now();
      final datePrefix = now.year.toString() +
          now.month.toString().padLeft(2, '0') +
          now.day.toString().padLeft(2, '0') +
          now.hour.toString().padLeft(2, '0');

      // Find missions with same date prefix
      final sameDateMissions = missions
          .where((m) => m.missionNumber.startsWith('MISS-$datePrefix'))
          .toList();

      int nextCounter = 0;
      if (sameDateMissions.isNotEmpty) {
        // Extract counter from last mission (format: MISS-YYYYMMDDHH-XXX)
        final lastNumber = sameDateMissions.last.missionNumber;
        final counterStr = lastNumber.split('-').last;
        nextCounter = int.parse(counterStr) + 1;

        // If counter reaches 1000, increment date
        if (nextCounter > 999) {
          final nextDate = now.add(const Duration(hours: 1));
          final newDatePrefix = nextDate.year.toString() +
              nextDate.month.toString().padLeft(2, '0') +
              nextDate.day.toString().padLeft(2, '0') +
              nextDate.hour.toString().padLeft(2, '0');
          return 'MISS-$newDatePrefix-000';
        }
      }

      return 'MISS-$datePrefix-${nextCounter.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating mission number: $e');
      return 'MISS-AUTO-001';
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
                  final filteredMissions = allMissions
                      .where((mission) => mission.status == _selectedStatus)
                      .toList();

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
          final isActive = _selectedStatus == 'active';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
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

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
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
                  const SizedBox(height: 4),
                  Text(
                    mission.missionDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPriority ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPriority ? 'URGENT' : 'NORMAL',
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
              Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

          // Action Buttons
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
        ],
      ),
    );
  }

  void _showCreateMissionDialog() {
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
    String selectedFromCity = 'Sfax';
    final fromLocationManualController = TextEditingController();

    String selectedToLocationType = 'clinic';
    String selectedToClinic = LocationData.clinicsSfax.first;
    String selectedToCity = 'Sfax';
    final toLocationManualController = TextEditingController();

    bool isLoading = false;

    // Generate mission number
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
                      (value) =>
                          setState(() => selectedFromLocationType = value!),
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
                      (value) =>
                          setState(() => selectedToLocationType = value!),
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

                    // Notes
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
                              : () {
                                  if (formKey.currentState?.validate() ??
                                      false) {
                                    Navigator.pop(context);
                                    _createMissionComprehensive(
                                      generatedMissionNumber ?? 'MISS-AUTO-001',
                                      _formatDate(DateTime.now()),
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
          DropdownButtonFormField<String>(
            value: selectedClinic,
            decoration: InputDecoration(
              labelText:
                  type == 'From' ? 'Sélectionner une clinique' : 'Destination',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: LocationData.clinicsSfax
                .map((clinic) => DropdownMenuItem(
                      value: clinic,
                      child: Text(clinic),
                    ))
                .toList(),
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
    String patientName,
    String patientPhone,
    String infirmierName,
    String tarif,
    String notes,
  ) async {
    try {
      await _apiClient.post(
        SupabaseConfig.missionsTable,
        {
          'mission_number': missionNumber,
          'mission_date': missionDate,
          'from_location': fromLocation,
          'to_location': toLocation,
          'infirmier_name': infirmierName,
          'patient_first_name': patientName,
          'patient_phone': patientPhone,
          'priority': priority,
          'status': 'active',
          'ambulance_id': '',
          'payment_type': 'tarif',
          'report_type': tarif,
          'fractures_injuries': notes,
        },
      );

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  controller: driverNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chauffeur',
                    border: OutlineInputBorder(),
                  ),
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
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normale')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Urgence')),
                  ],
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
      await _missionService.updateMissionStatus(mission.id, newStatus);

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Statut mis à jour en ${newStatus == 'completed' ? 'Complétée' : 'Annulée'}'),
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
    extends State<ManagerMissionsScreenContent> {
  final MissionService _missionService = MissionService();
  final ApiClient _apiClient = ApiClient();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'active';
  Map<String, String> _ambulanceCache = {};
  bool _isProcessingTabChange = false;

  @override
  void initState() {
    super.initState();
    _loadMissions();
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
      _preloadAmbulanceNames(missionData);
      return missionData.map((json) => Mission.fromJson(json)).toList();
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
      final missionData = await _apiClient.get(SupabaseConfig.missionsTable);
      final missions =
          missionData.map((json) => Mission.fromJson(json)).toList();

      final now = DateTime.now();
      final datePrefix = now.year.toString() +
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
          final newDatePrefix = nextDate.year.toString() +
              nextDate.month.toString().padLeft(2, '0') +
              nextDate.day.toString().padLeft(2, '0') +
              nextDate.hour.toString().padLeft(2, '0');
          return 'MISS-$newDatePrefix-000';
        }
      }

      return 'MISS-$datePrefix-${nextCounter.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating mission number: $e');
      return 'MISS-AUTO-001';
    }
  }

  void _showCreateMissionDialog() {
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

                    Text('Date et Heure', style: Theme.of(context).textTheme.labelLarge),
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

                    Text('Priorité', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: LocationData.priorityOptions.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => selectedPriority = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    Text('Lieu de Départ', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _buildLocationSection('From', selectedFromLocationType, (value) => setState(() => selectedFromLocationType = value!), fromLocationManualController, selectedFromClinic, (value) => setState(() => selectedFromClinic = value!), 'Sfax', (value) {}),
                    const SizedBox(height: 16),

                    Text('Lieu de Destination', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _buildLocationSection('To', selectedToLocationType, (value) => setState(() => selectedToLocationType = value!), toLocationManualController, selectedToClinic, (value) => setState(() => selectedToClinic = value!), 'Sfax', (value) {}),
                    const SizedBox(height: 16),

                    Text('Nom du Patient', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: patientNameController,
                      decoration: InputDecoration(
                        hintText: 'Nom complet',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Téléphone du Patient', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: patientPhoneController,
                      decoration: InputDecoration(
                        hintText: 'Numéro de téléphone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    Text('Infirmier/Médecin', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: infirmierController,
                      decoration: InputDecoration(
                        hintText: 'Nom',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Tarif', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: tarifController,
                      decoration: InputDecoration(
                        hintText: 'Montant',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    Text('Notes', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes supplémentaires',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                              Navigator.pop(context);
                              _createMissionWrapper(
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
                                tarifController.text,
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
      // Build request body, excluding empty strings and problematic fields
      final body = {
        'mission_number': missionNumber,
        'mission_date': DateTime.now().toString(),
        'from_location': fromLocation,
        'to_location': toLocation,
        'priority': priority,
        'status': 'active',
      };

      // Only add optional fields if they have values
      if (patientName.isNotEmpty) {
        body['patient_first_name'] = patientName;
      }
      if (patientPhone.isNotEmpty) {
        body['patient_phone'] = patientPhone;
      }
      if (infirmierName.isNotEmpty) {
        body['infirmier_name'] = infirmierName;
      }
      if (notes.isNotEmpty) {
        body['fractures_injuries'] = notes;
      }
      // Note: tarif is not sent to avoid database constraint violations

      await _apiClient.post(
        SupabaseConfig.missionsTable,
        body,
      );

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission créée avec succès'),
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
          DropdownButtonFormField<String>(
            value: selectedClinic,
            decoration: InputDecoration(
              labelText:
                  type == 'From' ? 'Sélectionner une clinique' : 'Destination',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: LocationData.clinicsSfax
                .map((clinic) => DropdownMenuItem(
                      value: clinic,
                      child: Text(clinic),
                    ))
                .toList(),
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
    final missionNumberCtrl = TextEditingController(text: mission.missionNumber);
    final dateCtrl = TextEditingController(text: mission.missionDate);
    final fromLocationCtrl = TextEditingController(text: mission.fromLocation);
    final toLocationCtrl = TextEditingController(text: mission.toLocation);
    final infirmierNameCtrl = TextEditingController(text: mission.infirmierName ?? '');
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
                  validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fromLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de Départ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: toLocationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
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
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normale')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                    DropdownMenuItem(value: 'emergency', child: Text('Urgence')),
                  ],
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
      await _apiClient.patch(
        '${SupabaseConfig.missionsTable}?id=eq.$missionId',
        {'status': newStatus},
      );

      if (mounted) {
        _loadMissions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut mis à jour en ${newStatus == 'completed' ? 'Complétée' : 'Annulée'}',
            ),
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
                    .toList();

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

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
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
                  const SizedBox(height: 4),
                  Text(
                    mission.missionDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPriority ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPriority ? 'URGENT' : 'NORMAL',
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
              Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

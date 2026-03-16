import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ambulance_model.dart';
import '../models/fuel_card_model.dart';
import '../models/maintenance_record_model.dart';
import '../models/mission_model.dart';
import '../services/ambulance_service.dart';
import '../services/api_client.dart';
import '../services/fuel_card_service.dart';
import '../services/maintenance_service.dart';
import '../services/ambulance_report_service.dart';
import '../config/constants.dart';
import './add_maintenance_screen.dart';
import './add_fuel_card_screen.dart';

class ManagerAmbulancesScreen extends StatefulWidget {
  final User user;

  const ManagerAmbulancesScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerAmbulancesScreen> createState() =>
      _ManagerAmbulancesScreenState();
}

class _ManagerAmbulancesScreenState extends State<ManagerAmbulancesScreen> {
  final _apiClient = ApiClient();
  late Future<List<Ambulance>> _ambulancesFuture;

  @override
  void initState() {
    super.initState();
    _ambulancesFuture = _getAllAmbulances();
  }

  Future<List<Ambulance>> _getAllAmbulances() async {
    try {
      final ambulances = await _apiClient.get(SupabaseConfig.ambulancesTable);
      return ambulances.map((json) => Ambulance.fromJson(json)).toList();
    } catch (e) {
      print('Error loading ambulances: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestion des Ambulances',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Ambulance>>(
            future: _ambulancesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Erreur: ${snapshot.error}'),
                );
              }

              final ambulances = snapshot.data ?? [];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('N° Ambulance')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Immatriculation')),
                      DataColumn(label: Text('État')),
                      DataColumn(label: Text('Chauffeur')),
                      DataColumn(label: Text('Missions')),
                      DataColumn(label: Text('Prochaine Maintenance')),
                    ],
                    rows: ambulances.map((ambulance) {
                      // Ambulance model doesn't have all fields, using available ones
                      final statusColor = Colors.blue;

                      return DataRow(
                        cells: [
                          DataCell(Text(ambulance.ambulanceNumber ?? '-')),
                          DataCell(Text('-')), // Type not available
                          DataCell(Text('-')), // License plate not available
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(ambulance.currentDriverId ?? '-')),
                          DataCell(
                            const Text(
                              '0',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            const Text('-'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'available':
        return Colors.green;
      case 'in_maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _translateStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'available':
        return 'Disponible';
      case 'in_maintenance':
        return 'En Maintenance';
      case 'inactive':
        return 'Inactive';
      default:
        return status ?? '-';
    }
  }
}

/// Wrapper widget for embedding ambulances screen content in dashboard tabs
class ManagerAmbulancesScreenContent extends StatefulWidget {
  final User user;

  const ManagerAmbulancesScreenContent({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerAmbulancesScreenContent> createState() =>
      _ManagerAmbulancesScreenContentState();
}

class _ManagerAmbulancesScreenContentState
    extends State<ManagerAmbulancesScreenContent> {
  final _apiClient = ApiClient();
  final _fuelCardService = FuelCardService();
  final _maintenanceService = MaintenanceService();
  late Future<List<Ambulance>> _ambulancesFuture;
  Ambulance? _selectedAmbulance;

  @override
  void initState() {
    super.initState();
    _ambulancesFuture = _getAllAmbulances();
  }

  Future<List<Ambulance>> _getAllAmbulances() async {
    try {
      final ambulances = await _apiClient.get(SupabaseConfig.ambulancesTable);
      return ambulances.map((json) => Ambulance.fromJson(json)).toList();
    } catch (e) {
      print('Error loading ambulances: $e');
      rethrow;
    }
  }

  Future<List<FuelCard>> _getFuelCards(String ambulanceId) async {
    try {
      final response = await _apiClient.get(
        '${SupabaseConfig.fuelCardsTable}?ambulance_id=eq.$ambulanceId',
      );
      return response.map((json) => FuelCard.fromJson(json)).toList();
    } catch (e) {
      print('Error loading fuel cards: $e');
      return [];
    }
  }

  Future<List<MaintenanceRecord>> _getMaintenanceRecords(
      String ambulanceId) async {
    try {
      final response = await _apiClient.get(
        '${SupabaseConfig.maintenanceRecordsTable}?ambulance_id=eq.$ambulanceId',
      );
      return response.map((json) => MaintenanceRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error loading maintenance records: $e');
      return [];
    }
  }

  Future<List<MaintenanceRecord>> _getAllMaintenanceRecords() async {
    try {
      final response =
          await _apiClient.get(SupabaseConfig.maintenanceRecordsTable);
      return response.map((json) => MaintenanceRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error loading all maintenance records: $e');
      return [];
    }
  }

  Future<List<Mission>> _getAllActiveMissions() async {
    try {
      final response = await _apiClient.get(
        '${SupabaseConfig.missionsTable}?status=eq.active',
      );
      return response.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      print('Error loading active missions: $e');
      return [];
    }
  }

  Future<List<Mission>> _getAllMissions() async {
    try {
      final response = await _apiClient.get(SupabaseConfig.missionsTable);
      return response.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      print('Error loading all missions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        _loadAmbulances();
        return _ambulancesFuture;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Ambulance>>(
          future: _ambulancesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            final ambulances = snapshot.data ?? [];

            // Get today's date as string
            final todayDate = DateTime.now().toString().split(' ')[0];

            return FutureBuilder<List<MaintenanceRecord>>(
              future: _getAllMaintenanceRecords(),
              builder: (context, maintenanceSnapshot) {
                final maintenanceRecords = maintenanceSnapshot.data ?? [];

                // Filter maintenance records for today
                final todaysMaintenance = maintenanceRecords
                    .where((record) => record.date.startsWith(todayDate))
                    .toList();

                return FutureBuilder<List<Mission>>(
                  future: _getAllActiveMissions(),
                  builder: (context, missionsSnapshot) {
                    final activeMissions = missionsSnapshot.data ?? [];

                    return FutureBuilder<List<Mission>>(
                      future: _getAllMissions(),
                      builder: (context, allMissionsSnapshot) {
                        final allMissions = allMissionsSnapshot.data ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fleet Stats Header
                            _buildFleetStats(
                                ambulances, todaysMaintenance, activeMissions),
                            const SizedBox(height: 24),

                            // Active Units Section
                            Text(
                              'UNITÉS ACTIVES',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (ambulances.isEmpty)
                              Center(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 32),
                                  child: Text(
                                    'Aucune ambulance disponible',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  ...ambulances.map((ambulance) {
                                    // Check if ambulance is in an active mission
                                    final isInDuty = activeMissions.any(
                                      (m) =>
                                          m.ambulanceId == ambulance.id &&
                                          m.ambulanceId.isNotEmpty,
                                    );

                                    final statusColor = isInDuty
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFA3E635);
                                    final statusText =
                                        isInDuty ? 'EN SERVICE' : 'DISPONIBLE';

                                    // Filter ALL missions (completed + active) for this ambulance (all time)
                                    final ambulanceMissionsTotal = allMissions
                                        .where((m) =>
                                            m.ambulanceId == ambulance.id &&
                                            m.ambulanceId.isNotEmpty)
                                        .toList();

                                    final completedMissionsTotal =
                                        ambulanceMissionsTotal
                                            .where(
                                                (m) => m.status == 'completed')
                                            .length;
                                    final totalMissionsCount =
                                        ambulanceMissionsTotal.length;

                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedAmbulance = ambulance),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _selectedAmbulance?.id ==
                                                    ambulance.id
                                                ? AppColors.primary
                                                : Colors.grey[200]!,
                                            width: _selectedAmbulance?.id ==
                                                    ambulance.id
                                                ? 2
                                                : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 50,
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.local_taxi,
                                                        color: Colors.grey[600],
                                                        size: 28,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          ambulance
                                                              .ambulanceNumber,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Ford Transit • 2022',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Accomplissement',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    Text(
                                                      '$completedMissionsTotal / $totalMissionsCount',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child:
                                                      LinearProgressIndicator(
                                                    value: totalMissionsCount >
                                                            0
                                                        ? completedMissionsTotal /
                                                            totalMissionsCount
                                                        : 0,
                                                    minHeight: 6,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.green[600]!,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Next Service',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    const Text(
                                                      '15 Oct',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      _showEditAmbulanceDialog(
                                                          ambulance),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.primary,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Gérer',
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),

                            // Selected Ambulance Details
                            if (_selectedAmbulance != null) ...[
                              const SizedBox(height: 24),
                              _buildAmbulanceDetails(_selectedAmbulance!),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFleetStats(List<Ambulance> ambulances,
      List<MaintenanceRecord> todaysMaintenance, List<Mission> activeMissions) {
    final available =
        ambulances.where((a) => (a.currentMissionId?.isEmpty ?? true)).length;

    // Count unique ambulances with active missions (ambulance_id not null)
    final inServiceAmbulanceIds = activeMissions
        .where((m) => m.ambulanceId != null && m.ambulanceId.isNotEmpty)
        .map((m) => m.ambulanceId)
        .toSet();
    final inService = inServiceAmbulanceIds.length;

    // Count unique ambulances that had maintenance added today
    final uniqueAmbulancesWithMaintenanceToday =
        todaysMaintenance.map((record) => record.ambulanceId).toSet().length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISPONIBLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  available.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EN SERVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  inService.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENTRETIEN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uniqueAmbulancesWithMaintenanceToday.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmbulanceDetails(Ambulance ambulance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                  Text(
                    'Unit Details: ${ambulance.ambulanceNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _exportAmbulanceReport(ambulance),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TELEPHONE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ambulance.telephone ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KILOMÉTRAGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '42,500 km',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'TENDANCE DES MISSIONS (7 JOURS)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildMissionsTrendChart(ambulance),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MAINTENANCE HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddMaintenanceDialog(ambulance),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<MaintenanceRecord>>(
                future: _getMaintenanceRecords(ambulance.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final maintenanceRecords = snapshot.data ?? [];

                  if (maintenanceRecords.isEmpty) {
                    return Text(
                      'Aucune maintenance enregistrée',
                      style: TextStyle(color: Colors.grey[600]),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: maintenanceRecords.take(3).map((record) {
                      final statusColor =
                          _getMaintenanceStatusColor(record.maintenanceType);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.maintenanceDescription,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    record.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                record.maintenanceType,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddMaintenanceDialog(ambulance),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Planifier l\'entretien'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildFuelCardsSection(ambulance),
      ],
    );
  }

  Widget _buildFuelCardsSection(Ambulance ambulance) {
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
              Text(
                'CARTES CARBURANT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddFuelCardDialog(ambulance),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<FuelCard>>(
            future: _getFuelCards(ambulance.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final fuelCards = snapshot.data ?? [];

              if (fuelCards.isEmpty) {
                return Text(
                  'Aucune carte carburant',
                  style: TextStyle(color: Colors.grey[600]),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fuelCards.map((card) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conducteur: ${card.driverName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Solde: ${card.balance} DA | Carburant: ${card.fuelAmount}L',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMissionsTrendChart(Ambulance ambulance) {
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      return now.subtract(Duration(days: 6 - index));
    });

    return FutureBuilder<List<Mission>>(
      future: _getAllMissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final missions = snapshot.data ?? [];
        final missionCounts = <int>[];

        // Count missions per day for this ambulance
        for (var date in last7Days) {
          final dayString = date.toString().split(' ')[0];
          final dayMissions = missions.where((m) {
            final statusLower = m.status.toLowerCase().trim();
            return m.ambulanceId == ambulance.id &&
                m.missionDate.startsWith(dayString) &&
                (statusLower == 'active' ||
                    statusLower == 'completed' ||
                    statusLower == 'canceled');
          }).length;
          missionCounts.add(dayMissions);
        }

        final max = missionCounts.isEmpty
            ? 1.0
            : (missionCounts.reduce((a, b) => a > b ? a : b).toDouble() + 2);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (index) {
            final height = (missionCounts[index] / max) * 80;
            return Column(
              children: [
                Container(
                  width: 16,
                  height: height,
                  decoration: BoxDecoration(
                    color: index == 6 ? Colors.blue[600] : Colors.blue[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  missionCounts[index].toString(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Color _getMaintenanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'terminé':
      case 'completed':
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

  void _showAddMaintenanceDialog(Ambulance ambulance) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddMaintenanceScreen(
          user: widget.user,
          ambulanceId: ambulance.id,
        ),
      ),
    )
        .then((_) {
      // Refresh data when user returns from the screen
      _loadAmbulances();
    });
  }

  void _showAddFuelCardDialog(Ambulance ambulance) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddFuelCardScreen(
          user: widget.user,
          ambulanceId: ambulance.id,
        ),
      ),
    )
        .then((_) {
      // Refresh data when user returns from the screen
      _loadAmbulances();
    });
  }

  void _showEditFuelCardDialog(FuelCard card) {
    final formKey = GlobalKey<FormState>();
    final driverNameController = TextEditingController(text: card.driverName);
    final balanceController =
        TextEditingController(text: card.balance.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Fuel Card'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: driverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Driver Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: balanceController,
                  decoration: const InputDecoration(
                    labelText: 'Balance (DA)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateFuelCard(
                card.id,
                driverNameController.text,
                double.tryParse(balanceController.text) ?? 0,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFuelCard(
    String cardId,
    String driverName,
    double balance,
  ) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.fuelCardsTable}?id=eq.$cardId',
        {
          'driver_name': driverName,
          'balance': balance,
        },
      );

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel card updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteFuelCard(String cardId) async {
    try {
      await _apiClient.delete(SupabaseConfig.fuelCardsTable, cardId);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel card deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _loadAmbulances() {
    if (mounted) {
      setState(() {
        _ambulancesFuture = _getAllAmbulances();
        _selectedAmbulance = null;
      });
    }
  }

  void _showEditAmbulanceDialog(Ambulance ambulance) {
    final formKey = GlobalKey<FormState>();
    final ambulanceNumberController =
        TextEditingController(text: ambulance.ambulanceNumber);
    final telephoneController =
        TextEditingController(text: ambulance.telephone ?? '');
    final driverIdController =
        TextEditingController(text: ambulance.currentDriverId ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier Ambulance'),
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
                _updateAmbulanceWrapper(
                  ambulance.id,
                  ambulanceNumberController.text,
                  telephoneController.text,
                  driverIdController.text,
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

  Future<void> _updateAmbulanceWrapper(
    String ambulanceId,
    String ambulanceNumber,
    String telephone,
    String driverId,
  ) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId',
        {
          'ambulance_number': ambulanceNumber,
          'telephone': telephone,
          'current_driver_id': driverId.isEmpty ? null : driverId,
        },
      );

      if (mounted) {
        _loadAmbulances();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambulance mise à jour avec succès'),
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

  Future<void> _exportAmbulanceReport(Ambulance ambulance) async {
    try {
      // Show loading dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Génération du rapport...'),
              ],
            ),
          ),
        ),
      );

      // Fetch required data
      final fuelCards = await _getFuelCards(ambulance.id);
      final maintenanceRecords = await _getMaintenanceRecords(ambulance.id);
      final missions = await _getAllMissions();
      final activeMissions = await _getAllActiveMissions();

      // Calculate stats
      final allAmbulances = await _getAllAmbulances();
      final available = allAmbulances
          .where((a) => (a.currentMissionId?.isEmpty ?? true))
          .length;
      final inServiceAmbulanceIds = activeMissions
          .where((m) => m.ambulanceId != null && m.ambulanceId.isNotEmpty)
          .map((m) => m.ambulanceId)
          .toSet();
      final inService = inServiceAmbulanceIds.length;
      final todaysMaint = maintenanceRecords
          .where(
              (r) => r.date.startsWith(DateTime.now().toString().split(' ')[0]))
          .toList();
      final uniqueMaintToday =
          todaysMaint.map((r) => r.ambulanceId).toSet().length;

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Generate and download PDF
      final reportService = AmbulanceReportService();
      await reportService.generateAndDownloadReport(
        ambulance: ambulance,
        fuelCards: fuelCards,
        maintenanceRecords: maintenanceRecords,
        missions: missions,
        availableCount: available,
        inServiceCount: inService,
        maintenanceCount: uniqueMaintToday,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Rapport pour ${ambulance.ambulanceNumber} généré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteAmbulanceConfirmation(Ambulance ambulance) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la Suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer l\'ambulance ${ambulance.ambulanceNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAmbulanceWrapper(ambulance.id);
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

  Future<void> _deleteAmbulanceWrapper(String ambulanceId) async {
    try {
      await _apiClient.delete(SupabaseConfig.ambulancesTable, ambulanceId);

      if (mounted) {
        _loadAmbulances();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambulance supprimée avec succès'),
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
                _createAmbulanceWrapper(
                  ambulanceNumberController.text,
                  telephoneController.text,
                  driverIdController.text,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAmbulanceWrapper(
    String ambulanceNumber,
    String telephone,
    String driverId,
  ) async {
    try {
      final body = {
        'ambulance_number': ambulanceNumber,
      };

      // Only add optional fields if they have values
      if (telephone.isNotEmpty) {
        body['telephone'] = telephone;
      }
      if (driverId.isNotEmpty) {
        body['current_driver_id'] = driverId;
      }

      await _apiClient.post(
        SupabaseConfig.ambulancesTable,
        body,
      );

      if (mounted) {
        _loadAmbulances();
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
}

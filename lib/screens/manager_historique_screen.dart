import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../models/ambulance_model.dart';
import '../services/api_client.dart';
import '../config/constants.dart';

class ManagerHistoriqueScreenContent extends StatefulWidget {
  final User user;

  const ManagerHistoriqueScreenContent({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerHistoriqueScreenContent> createState() =>
      _ManagerHistoriqueScreenContentState();
}

class _ManagerHistoriqueScreenContentState
    extends State<ManagerHistoriqueScreenContent> {
  final _apiClient = ApiClient();
  late Future<List<Mission>> _missionsFuture;
  late Future<List<Ambulance>> _ambulancesFuture;

  // Filter parameters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAmbulance;
  String? _selectedDriver;
  String? _selectedStatus;
  List<Ambulance> _ambulances = [];
  Set<String> _drivers = {};
  final List<String> _statuses = ['completed', 'active', 'canceled', 'pending'];

  @override
  void initState() {
    super.initState();
    _missionsFuture = _getAllMissions();
    _ambulancesFuture = _getAllAmbulances();
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    try {
      final ambulances = await _getAllAmbulances();
      setState(() {
        _ambulances = ambulances;
      });

      final missions = await _getAllMissions();
      final drivers = missions.map((m) => m.driverName ?? 'N/A').toSet();
      setState(() {
        _drivers = drivers;
      });
    } catch (e) {
      print('Error loading filter data: $e');
    }
  }

  Future<List<Mission>> _getAllMissions() async {
    try {
      final response = await _apiClient.get(SupabaseConfig.missionsTable);
      return response.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      print('Error loading missions: $e');
      return [];
    }
  }

  Future<List<Ambulance>> _getAllAmbulances() async {
    try {
      final response = await _apiClient.get(SupabaseConfig.ambulancesTable);
      return response.map((json) => Ambulance.fromJson(json)).toList();
    } catch (e) {
      print('Error loading ambulances: $e');
      return [];
    }
  }

  List<Mission> _filterMissions(List<Mission> missions) {
    return missions.where((mission) {
      try {
        final missionDate = DateTime.parse(mission.missionDate);

        // Filter by date range (inclusive on both ends)
        if (_startDate != null && missionDate.isBefore(_startDate!)) {
          return false;
        }
        // Include entire end date by checking against next day
        if (_endDate != null && missionDate.isAfter(_endDate!.add(Duration(days: 1)))) {
          return false;
        }

        // Filter by ambulance
        if (_selectedAmbulance != null &&
            mission.ambulanceId != _selectedAmbulance) {
          return false;
        }

        // Filter by driver
        if (_selectedDriver != null && mission.driverName != _selectedDriver) {
          return false;
        }

        // Filter by status
        if (_selectedStatus != null && mission.status != _selectedStatus) {
          return false;
        }

        return true;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'canceled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Complétée';
      case 'active':
        return 'Active';
      case 'canceled':
        return 'Annulée';
      case 'pending':
        return 'En attente';
      default:
        return status;
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _missionsFuture = _getAllMissions();
          _ambulancesFuture = _getAllAmbulances();
        });
        await _loadFilterData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Historique des Missions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Filters Section
            _buildFiltersSection(),
            const SizedBox(height: 20),

            // Missions List
            FutureBuilder<List<Mission>>(
              future: _missionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final allMissions = snapshot.data ?? [];
                final filteredMissions = _filterMissions(allMissions);

                if (filteredMissions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune mission trouvée',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Summary
                    _buildSummaryPanel(filteredMissions),
                    const SizedBox(height: 20),

                    // Missions List
                    ...filteredMissions.map((mission) {
                      return _buildMissionCard(mission);
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
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
          Text(
            'FILTRES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Date Range Filter
          GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                        color: _startDate != null
                            ? Colors.black
                            : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_startDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child:
                          Icon(Icons.clear, color: Colors.grey[400], size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ambulance Filter
          DropdownButtonFormField<String>(
            value: _selectedAmbulance,
            hint: const Text('Sélectionner une ambulance'),
            items: _ambulances
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.ambulanceNumber),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedAmbulance = value;
              });
            },
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: Icon(Icons.local_shipping,
                  color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Driver Filter
          DropdownButtonFormField<String>(
            value: _selectedDriver,
            hint: const Text('Sélectionner un ambulancier'),
            items: _drivers
                .map((driver) => DropdownMenuItem(
                      value: driver,
                      child: Text(driver),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedDriver = value;
              });
            },
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon:
                  Icon(Icons.person, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Status Filter
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            hint: const Text('Sélectionner un statut'),
            items: _statuses
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_translateStatus(status)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value;
              });
            },
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon:
                  Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ),
          ),

          // Clear Filters Button
          if (_startDate != null ||
              _selectedAmbulance != null ||
              _selectedDriver != null ||
              _selectedStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _selectedAmbulance = null;
                      _selectedDriver = null;
                      _selectedStatus = null;
                    });
                  },
                  child: const Text('Réinitialiser les filtres'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(List<Mission> missions) {
    final completed = missions.where((m) => m.status == 'completed').length;
    final active = missions.where((m) => m.status == 'active').length;
    final canceled = missions.where((m) => m.status == 'canceled').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStat('Total', missions.length.toString(), Colors.blue),
          _buildSummaryStat('Complétées', completed.toString(), Colors.green),
          _buildSummaryStat('Actives', active.toString(), Colors.orange),
          _buildSummaryStat('Annulées', canceled.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionCard(Mission mission) {
    final statusColor = _getStatusColor(mission.status);
    final statusText = _translateStatus(mission.status);
    final missionDate = DateTime.parse(mission.missionDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header row with mission number and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.missionNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(missionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location row
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${mission.fromLocation} → ${mission.toLocation}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildDetailItem(
                  'Ambulance', mission.ambulanceId, Icons.local_shipping),
              _buildDetailItem(
                  'Conducteur', mission.driverName ?? 'N/A', Icons.person),
              _buildDetailItem(
                  'Patient',
                  '${mission.patientFirstName ?? ''} ${mission.patientLastName ?? ''}'
                      .trim(),
                  Icons.person_outline),
              _buildDetailItem(
                  'Priorité', mission.priority ?? 'N/A', Icons.priority_high),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

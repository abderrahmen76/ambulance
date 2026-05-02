import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../models/ambulance_model.dart';
import '../services/api_client.dart';
import '../services/pdf_service.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';

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
    extends State<ManagerHistoriqueScreenContent> with WidgetsBindingObserver {
  final _apiClient = ApiClient();
  late Future<List<Mission>> _missionsFuture;
  late Future<List<Ambulance>> _ambulancesFuture;

  // Filter parameters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAmbulance;
  String? _selectedDriver;
  String? _selectedStatus;
  String? _selectedPaymentType;
  List<Ambulance> _ambulances = [];
  Set<String> _drivers = {};
  final List<String> _statuses = [
    'completed',
    'active',
    'cancelled',
    'pending'
  ];
  final List<String> _paymentTypes = ['cash', 'charge'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloadHistoriqueData();

    // 🔥 CRITICAL FIX: Reload after widget is fully built
    // This prevents lifecycle event race conditions when widget is recreated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint(
            '[ManagerHistoriqueScreenContent] Post-frame callback: reloading historique data');
        _reloadHistoriqueData();
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
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          '[ManagerHistoriqueScreen] App resumed, reloading historique...');
      _reloadHistoriqueData();
    }
  }

  void _reloadHistoriqueData() {
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
        if (_endDate != null &&
            missionDate.isAfter(_endDate!.add(Duration(days: 1)))) {
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

        // Filter by payment type
        if (_selectedPaymentType != null &&
            mission.paymentType != _selectedPaymentType) {
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
      case 'cancelled':
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
      case 'cancelled':
        return 'Annulée';
      case 'pending':
        return 'En attente';
      default:
        return status;
    }
  }

  String _getPaymentTypeLabel(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'charge':
        return 'Sur Dossier';
      default:
        return paymentType;
    }
  }

  IconData _getPaymentTypeIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'charge':
        return Icons.description;
      default:
        return Icons.payment;
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
    final responsive = context.responsive;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _missionsFuture = _getAllMissions();
          _ambulancesFuture = _getAllAmbulances();
        });
        await _loadFilterData();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: responsive.paddingLarge,
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
                  SizedBox(height: responsive.spacingLarge),

                  // Filters Section
                  _buildFiltersSection(),
                  SizedBox(height: responsive.spacingLarge),
                ],
              ),
            ),
          ),
          // Missions List
          FutureBuilder<List<Mission>>(
            future: _missionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverToBoxAdapter(
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(child: Text('Erreur: ${snapshot.error}')),
                );
              }

              final allMissions = snapshot.data ?? [];
              final filteredMissions = _filterMissions(allMissions);
              // Order by newest missionDate on top
              filteredMissions.sort((a, b) {
                final dateA =
                    DateTime.tryParse(a.missionDate) ?? DateTime(1970);
                final dateB =
                    DateTime.tryParse(b.missionDate) ?? DateTime(1970);
                return dateB.compareTo(dateA);
              });

              if (filteredMissions.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
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
                  ),
                );
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.responsive.spacingLarge),
                  child: Column(
                    children: [
                      // Summary
                      _buildSummaryPanel(filteredMissions, _selectedAmbulance),
                      const SizedBox(height: 20),

                      // Missions List
                      ...filteredMissions.map((mission) {
                        return _buildMissionCard(mission);
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    final responsive = context.responsive;
    return Container(
      padding: responsive.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: responsive.radiusLarge,
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
              fontSize: responsive.fontSizeSmall,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: responsive.spacingMedium),

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
                  SizedBox(width: context.responsive.spacingMedium),
                  Expanded(
                    child: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                        color: _startDate != null
                            ? Colors.black
                            : Colors.grey[600],
                        fontSize: context.responsive.fontSizeSmall,
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
          SizedBox(height: context.responsive.spacingMedium),

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
              contentPadding: EdgeInsets.symmetric(
                  horizontal: context.responsive.spacingMedium,
                  vertical: context.responsive.spacingSmall),
              border: OutlineInputBorder(
                  borderRadius: context.responsive.radiusMedium),
              prefixIcon: Icon(Icons.local_shipping,
                  color: AppColors.primary, size: 20),
            ),
          ),
          SizedBox(height: context.responsive.spacingMedium),

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
              contentPadding: EdgeInsets.symmetric(
                  horizontal: context.responsive.spacingMedium,
                  vertical: context.responsive.spacingSmall),
              border: OutlineInputBorder(
                  borderRadius: context.responsive.radiusMedium),
              prefixIcon:
                  Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ),
          ),
          SizedBox(height: context.responsive.spacingMedium),

          // Payment Type Filter
          DropdownButtonFormField<String>(
            value: _selectedPaymentType,
            hint: const Text('Mode de paiement'),
            items: _paymentTypes
                .map((paymentType) => DropdownMenuItem(
                      value: paymentType,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getPaymentTypeIcon(paymentType),
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getPaymentTypeLabel(paymentType),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentType = value;
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: context.responsive.spacingMedium,
                  vertical: context.responsive.spacingSmall),
              border: OutlineInputBorder(
                  borderRadius: context.responsive.radiusMedium),
              prefixIcon:
                  Icon(Icons.payment, color: AppColors.primary, size: 20),
            ),
          ),

          // Clear Filters Button
          if (_startDate != null ||
              _selectedAmbulance != null ||
              _selectedDriver != null ||
              _selectedStatus != null ||
              _selectedPaymentType != null)
            Padding(
              padding: EdgeInsets.only(top: context.responsive.spacingMedium),
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
                      _selectedPaymentType = null;
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

  Widget _buildSummaryPanel(
      List<Mission> missions, String? selectedAmbulanceId) {
    final responsive = context.responsive;
    final completed = missions.where((m) => m.status == 'completed').length;
    final active = missions.where((m) => m.status == 'active').length;
    final canceled = missions.where((m) => m.status == 'cancelled').length;

    // Get selected ambulance info if filtered
    String? selectedAmbulanceName;
    if (selectedAmbulanceId != null) {
      try {
        final ambulance = _ambulances.firstWhere(
          (a) => a.id == selectedAmbulanceId,
          orElse: () => Ambulance(
            id: '',
            ambulanceNumber: 'N/A',
          ),
        );
        selectedAmbulanceName = ambulance.ambulanceNumber;
      } catch (e) {
        selectedAmbulanceName = 'N/A';
      }
    }

    // Calculate performance metrics for selected ambulance
    double totalEarnings = 0;
    final completedMissions =
        missions.where((m) => m.status == 'completed').toList();
    for (var mission in completedMissions) {
      try {
        final price = double.tryParse(mission.missionPrice ?? '0') ?? 0;
        totalEarnings += price;
      } catch (e) {
        // Skip invalid prices
      }
    }
    final avgEarnings = completedMissions.isNotEmpty
        ? totalEarnings / completedMissions.length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ambulance filter header or general header
        Container(
          padding: responsive.paddingSmall,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                selectedAmbulanceName != null
                    ? Icons.local_shipping
                    : Icons.info,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: responsive.spacingSmall),
              Text(
                selectedAmbulanceName != null
                    ? 'Statistiques pour'
                    : 'Statistiques',
                style: TextStyle(
                  fontSize: responsive.fontSizeSmall,
                  color: Colors.grey[600],
                ),
              ),
              if (selectedAmbulanceName != null) ...[
                SizedBox(width: responsive.spacingSmall),
                Text(
                  selectedAmbulanceName,
                  style: TextStyle(
                    fontSize: responsive.fontSizeSmall,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                SizedBox(width: responsive.spacingSmall),
                Text(
                  'générales',
                  style: TextStyle(
                    fontSize: responsive.fontSizeSmall,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: responsive.spacingMedium),
        Container(
          padding: responsive.paddingMedium,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.primary.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: responsive.radiusLarge,
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(
                  'Total', missions.length.toString(), Colors.blue),
              _buildSummaryStat(
                  'Complétées', completed.toString(), Colors.green),
              _buildSummaryStat('Actives', active.toString(), Colors.orange),
              _buildSummaryStat('Annulées', canceled.toString(), Colors.red),
            ],
          ),
        ),
        // Performance/Earnings section - always visible
        SizedBox(height: responsive.spacingMedium),
        Container(
          padding: responsive.paddingMedium,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: responsive.radiusLarge,
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
                'PERFORMANCE',
                style: TextStyle(
                  fontSize: responsive.fontSizeSmall,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: responsive.spacingMedium),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: responsive.spacingMedium,
                mainAxisSpacing: responsive.spacingMedium,
                childAspectRatio: 1.2,
                children: [
                  _buildPerformanceStat(
                    'Revenus Total',
                    '${totalEarnings.toStringAsFixed(2)} DT',
                    Colors.green,
                    Icons.attach_money,
                    responsive,
                  ),
                  _buildPerformanceStat(
                    'Revenu Moyen',
                    '${avgEarnings.toStringAsFixed(2)} DT',
                    Colors.blue,
                    Icons.trending_up,
                    responsive,
                  ),
                  _buildPerformanceStat(
                    'Missions Complétées',
                    completedMissions.length.toString(),
                    Colors.green,
                    Icons.check_circle,
                    responsive,
                  ),
                  _buildPerformanceStat(
                    'Taux Complétude',
                    missions.isNotEmpty
                        ? '${((completedMissions.length / missions.length) * 100).toStringAsFixed(0)}%'
                        : 'N/A',
                    Colors.orange,
                    Icons.percent,
                    responsive,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceStat(
    String label,
    String value,
    Color color,
    IconData icon,
    var responsive,
  ) {
    return Container(
      padding: responsive.paddingSmall,
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: responsive.spacingSmall),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: responsive.spacingSmall),
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.fontSizeSmall,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    final responsive = context.responsive;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: responsive.fontSizeTitle,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: responsive.spacingSmall),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.fontSizeSmall,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionCard(Mission mission) {
    final responsive = context.responsive;
    final statusColor = _getStatusColor(mission.status);
    final statusText = _translateStatus(mission.status);
    final missionDate = DateTime.parse(mission.missionDate);

    // Minimized card: only mission number, date, status, and locations
    return InkWell(
      onTap: () => _showMissionDetailsDialog(mission),
      borderRadius: responsive.radiusLarge,
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.spacingMedium),
        padding: responsive.paddingMedium,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: responsive.radiusLarge,
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
                Text(
                  mission.missionNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
            const SizedBox(height: 6),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(missionDate),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }

  void _showMissionDetailsDialog(Mission mission) {
    final responsive = context.responsive;
    final statusColor = _getStatusColor(mission.status);
    final statusText = _translateStatus(mission.status);
    final missionDate = DateTime.parse(mission.missionDate);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Mission '),
                  Expanded(
                    child: Text(
                      mission.missionNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Date:  ${DateFormat('dd/MM/yyyy HH:mm').format(missionDate)}'),
                const SizedBox(height: 8),
                Text('Ambulance: ${mission.ambulanceId}'),
                Text('Conducteur: ${mission.driverName ?? 'N/A'}'),
                Text(
                    'Patient: ${(mission.patientFirstName ?? '') + ' ' + (mission.patientLastName ?? '')}'),
                Text('Priorité: ${mission.priority ?? 'N/A'}'),
                Text('De: ${mission.fromLocation}'),
                Text('À: ${mission.toLocation}'),
                if (mission.missionPrice != null)
                  Text('Prix: ${mission.missionPrice} DT'),
                if (mission.paymentType != null)
                  Text(
                      'Paiement: ${_getPaymentTypeLabel(mission.paymentType!)}'),
                if (mission.status != null) Text('Statut: $statusText'),
                // Add more fields as needed
              ],
            ),
          ),
          actions: [
            if (mission.status.toLowerCase() != 'pending') ...[
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Show loading
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Génération du PDF...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  try {
                    await PdfService.generateMissionReportPdf(mission);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF généré avec succès!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Erreur lors de la génération du PDF: \\${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Imprimer'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Show loading
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Génération de la facture...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  try {
                    await PdfService.generateInvoicePdf(mission);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Facture générée avec succès!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Erreur lors de la génération de la facture: \\${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Facture'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/company_staff_service.dart';
import '../services/maintenance_rule_service.dart';
import '../services/maintenance_service.dart';
import '../utils/responsive.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;
  final String? ambulanceName;

  const AddMaintenanceScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
    this.ambulanceName,
  }) : super(key: key);

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  late TextEditingController _dateController;
  late TextEditingController _descriptionController;
  late TextEditingController _nextServiceController;
  late TextEditingController _priceController;
  late TextEditingController _mechanicController;
  late TextEditingController _notesController;
  late TextEditingController _driverController;
  late TextEditingController _customMaintenanceTypeController;
  late TextEditingController _kilometrageController;

  String? _selectedMaintenanceType;

  // French display names
  final List<String> _maintenanceTypesFrench = [
    'Vidange',
    'Plaquettes de Frein',
    'Bougies',
    'Pneus',
    'Liquide de Frein',
    'Urgent',
    'Autre',
  ];

  // Mapping from French display names to English database values
  final Map<String, String> _maintenanceTypeMapping = {
    'Vidange': 'oil change',
    'Plaquettes de Frein': 'brake pad replacement',
    'Bougies': 'spark plugs',
    'Pneus': 'tires',
    'Liquide de Frein': 'brake fluid',
    'Urgent': 'urgent',
    'Autre': 'pending',
  };

  final _formKey = GlobalKey<FormState>();
  final MaintenanceService _maintenanceService = MaintenanceService();
  final MaintenanceRuleService _maintenanceRuleService =
      MaintenanceRuleService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  late String _ambulanceDisplayName;
  List<User> _companyStaff = [];
  final Set<String> _selectedTeammateIds = {};

  @override
  void initState() {
    super.initState();
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _dateController = TextEditingController(text: today);
    _descriptionController = TextEditingController();
    _nextServiceController = TextEditingController();
    _priceController = TextEditingController();
    _mechanicController = TextEditingController();
    _notesController = TextEditingController();
    _driverController = TextEditingController(text: widget.user.name);
    _customMaintenanceTypeController = TextEditingController();
    _kilometrageController = TextEditingController();
    _ambulanceDisplayName = widget.ambulanceName ?? widget.ambulanceId;
    _loadAmbulanceDisplayName();
    _loadCompanyStaff();
  }

  Future<void> _loadAmbulanceDisplayName() async {
    try {
      final rows = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {'id': 'eq.${widget.ambulanceId}'},
      );
      if (!mounted || rows.isEmpty) return;
      final number = (rows.first['ambulance_number'] ?? '').toString().trim();
      if (number.isNotEmpty) {
        setState(() => _ambulanceDisplayName = number);
      }
    } catch (e) {
      print('[AddMaintenance] Error loading ambulance name: $e');
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
      _updateDriverField();
    } catch (e) {
      print('[AddMaintenance] Error loading company staff: $e');
    }
  }

  void _toggleTeammate(User teammate, bool selected) {
    setState(() {
      if (selected) {
        _selectedTeammateIds.add(teammate.id);
      } else {
        _selectedTeammateIds.remove(teammate.id);
      }
      _updateDriverField();
    });
  }

  void _updateDriverField() {
    final teammateNames = _companyStaff
        .where((member) => _selectedTeammateIds.contains(member.id))
        .map((member) => member.name)
        .toList();
    final names = <String>[widget.user.name, ...teammateNames];
    _driverController.text = names.join(', ');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _nextServiceController.dispose();
    _priceController.dispose();
    _mechanicController.dispose();
    _notesController.dispose();
    _driverController.dispose();
    _customMaintenanceTypeController.dispose();
    _kilometrageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1095)), // +3 years
    );

    if (pickedDate != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      if (controller == _dateController) {
        _updateNextServiceDate();
      }
    }
  }

  Future<void> _updateNextServiceDate() async {
    final tenantId = widget.user.tenantId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        _selectedMaintenanceType == null) {
      _nextServiceController.clear();
      return;
    }

    try {
      final maintenanceType = _getDatabaseMaintenanceType();
      final rule = await _maintenanceRuleService.getRuleForType(
        tenantId,
        maintenanceType,
      );
      if (!mounted) return;

      if (rule == null || !rule.enabled || rule.intervalDays == null) {
        setState(() => _nextServiceController.clear());
        return;
      }

      final dateFormat = DateFormat('dd/MM/yyyy');
      final baseDate = dateFormat.parse(_dateController.text);
      final nextDate = baseDate.add(Duration(days: rule.intervalDays!));
      setState(() {
        _nextServiceController.text = dateFormat.format(nextDate);
      });
    } catch (e) {
      print('[AddMaintenance] Error loading maintenance rule: $e');
      if (mounted) {
        setState(() => _nextServiceController.clear());
      }
    }
  }

  String _getDatabaseMaintenanceType() {
    if (_selectedMaintenanceType == 'Autre') {
      final customType = _customMaintenanceTypeController.text.trim();
      return customType.isEmpty
          ? 'custom maintenance'
          : customType.toLowerCase();
    }
    return _maintenanceTypeMapping[_selectedMaintenanceType] ?? 'pending';
  }

  void _submitForm() async {
    print('[AddMaintenance] Submit button pressed');
    print('[AddMaintenance] Form valid: ${_formKey.currentState?.validate()}');

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      print('[AddMaintenance] Setting loading state to true');

      try {
        // Parse date back to ISO format for API
        final dateFormat = DateFormat('dd/MM/yyyy');
        final parsedDate = dateFormat.parse(_dateController.text);
        final isoDate = parsedDate.toIso8601String();

        print(
          '[AddMaintenance] Parsed date: ${_dateController.text} -> $isoDate',
        );

        final databaseMaintenanceType = _getDatabaseMaintenanceType();
        final tenantId = widget.user.tenantId;
        final rule = tenantId == null || tenantId.isEmpty
            ? null
            : await _maintenanceRuleService.getRuleForType(
                tenantId,
                databaseMaintenanceType,
              );

        if (_selectedMaintenanceType == 'Autre' &&
            tenantId != null &&
            tenantId.isNotEmpty) {
          await _maintenanceRuleService.ensureRuleForType(
            tenantId: tenantId,
            maintenanceType: databaseMaintenanceType,
          );
        }

        final currentKm = double.tryParse(_kilometrageController.text) ?? 0;
        final intervalKm = rule?.enabled == true ? rule?.intervalKm : null;
        final intervalDays = rule?.enabled == true ? rule?.intervalDays : null;
        final warningBeforeKm = rule?.enabled == true
            ? rule?.warningBeforeKm
            : null;
        final warningBeforeDays = rule?.enabled == true
            ? rule?.warningBeforeDays
            : null;
        final nextDueKm = intervalKm != null ? currentKm + intervalKm : null;
        final nextDueDate = intervalDays != null
            ? parsedDate.add(Duration(days: intervalDays))
            : null;

        // Prepare data for API
        final maintenanceData = {
          'ambulance_id': widget.ambulanceId,
          'date': isoDate,
          'maintenance_type': databaseMaintenanceType,
          'maintenance_description':
              _descriptionController.text, // Fixed field name
          'mechanic_name': _mechanicController.text,
          'price_per_piece': double.tryParse(_priceController.text) ?? 0,
          'notes': _notesController.text,
          'user_id': widget.user.id,
          'driver_name': _driverController.text,
          'kilometrage': currentKm,
          if (nextDueKm != null) 'next_due_km': nextDueKm,
          if (nextDueDate != null)
            'next_due_date': nextDueDate.toIso8601String(),
          if (intervalKm != null) 'interval_km': intervalKm,
          if (intervalDays != null) 'interval_days': intervalDays,
          if (warningBeforeKm != null) 'warning_before_km': warningBeforeKm,
          if (warningBeforeDays != null)
            'warning_before_days': warningBeforeDays,
        };

        print('[AddMaintenance] Form data prepared:');
        print(
          '[AddMaintenance] - Ambulance ID: ${maintenanceData['ambulance_id']}',
        );
        print('[AddMaintenance] - Date: ${maintenanceData['date']}');
        print(
          '[AddMaintenance] - Type: ${maintenanceData['maintenance_type']}',
        );
        print(
          '[AddMaintenance] - Description: ${maintenanceData['maintenance_description']}',
        );
        print(
          '[AddMaintenance] - Mechanic: ${maintenanceData['mechanic_name']}',
        );
        print(
          '[AddMaintenance] - Price: ${maintenanceData['price_per_piece']} TND',
        );
        print('[AddMaintenance] - User ID: ${maintenanceData['user_id']}');
        print(
          '[AddMaintenance] - Driver Name: ${maintenanceData['driver_name']}',
        );
        print('[AddMaintenance] - Notes: ${maintenanceData['notes']}');
        print(
          '[AddMaintenance] - Kilometrage: ${maintenanceData['kilometrage']}',
        );
        print(
          '[AddMaintenance] - Kilometrage Controller Text: "${_kilometrageController.text}" (empty: ${_kilometrageController.text.isEmpty})',
        );
        print(
          '[AddMaintenance] - Kilometrage parsed: ${double.tryParse(_kilometrageController.text)} (type: ${double.tryParse(_kilometrageController.text).runtimeType})',
        );

        // TODO: Call MaintenanceService to submit
        print('[AddMaintenance] Ready to submit to API');
        await _maintenanceService.addMaintenanceRecord(maintenanceData);

        print('[AddMaintenance] Navigating back');
        // Navigate back immediately (dashboard will auto-refresh and show data)
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('[AddMaintenance] ERROR: ${e.toString()}');
        print('[AddMaintenance] Stack trace: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
        print('[AddMaintenance] Setting loading state to false');
      }
    } else {
      print('[AddMaintenance] Form validation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouveau Dossier d\'Entretien'),
            Text(
              _ambulanceDisplayName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.responsive.paddingValueXLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date de l'entretien
              Text(
                'Date de l\'entretien',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(_dateController),
                decoration: InputDecoration(
                  hintText: 'dd/mm/yyyy',
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print('[AddMaintenance] Date validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Date requise' : null;
                },
              ),
              const SizedBox(height: 20),

              // Nom du Chauffeur
              Text(
                'Nom du Chauffeur',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Entrer le nom du chauffeur',
                  prefixIcon: Icon(Icons.person, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print('[AddMaintenance] Driver validator - value: "$value"');
                  return value?.isEmpty ?? true
                      ? 'Nom du chauffeur requis'
                      : null;
                },
              ),
              if (_companyStaff.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ajouter d\'autres ambulanciers',
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
                          selected: _selectedTeammateIds.contains(member.id),
                          onSelected: (selected) =>
                              _toggleTeammate(member, selected),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              // Type d'Entretien
              Text(
                'Type d\'Entretien',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMaintenanceType,
                items: _maintenanceTypesFrench.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMaintenanceType = value;
                  });
                  _updateNextServiceDate();
                },
                decoration: InputDecoration(
                  hintText: 'Sélectionner un type',
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print('[AddMaintenance] Type validator - value: "$value"');
                  return value?.isEmpty ?? true
                      ? 'Type d\'entretien requis'
                      : null;
                },
              ),
              const SizedBox(height: 20),

              // Custom Maintenance Type (only show when "Autre" is selected)
              if (_selectedMaintenanceType == 'Autre')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type d\'Entretien Personnalisé',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customMaintenanceTypeController,
                      onChanged: (_) => _updateNextServiceDate(),
                      decoration: InputDecoration(
                        hintText: 'Entrer le type d\'entretien personnalisé',
                        prefixIcon: Icon(Icons.edit, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        print(
                          '[AddMaintenance] Custom type validator - value: "$value"',
                        );
                        if (_selectedMaintenanceType == 'Autre') {
                          return value?.isEmpty ?? true
                              ? 'Type d\'entretien requis'
                              : null;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Nom du Mécanicien
              Text(
                'Nom du Mécanicien / Garage',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mechanicController,
                decoration: InputDecoration(
                  hintText: 'Entrer le nom du garage',
                  prefixIcon: Icon(Icons.build, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print(
                    '[AddMaintenance] Mechanic validator - value: "$value"',
                  );
                  return value?.isEmpty ?? true
                      ? 'Nom du mécanicien requis'
                      : null;
                },
              ),
              const SizedBox(height: 20),

              // Prix and Next Service in row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coût (TND)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            suffixText: 'TND',
                            suffixStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          validator: (value) {
                            print(
                              '[AddMaintenance] Price validator - value: "$value"',
                            );
                            // Allow empty (will default to 0)
                            if (value != null && value.isNotEmpty) {
                              final parsed = double.tryParse(value);
                              if (parsed == null) {
                                print('[AddMaintenance] Price parse failed');
                                return 'Coût invalide';
                              }
                            }
                            return null;
                          },
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
                          'Prochain entretien',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nextServiceController,
                          readOnly: true,
                          onTap: () => _selectDate(_nextServiceController),
                          decoration: InputDecoration(
                            hintText: 'mm/dd/yyyy',
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          validator: (value) {
                            print(
                              '[AddMaintenance] Next service validator - value: "$value"',
                            );
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Kilométrage
              Text(
                'Kilométrage Actuel (km)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _kilometrageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: 'km',
                  suffixStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.speed, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print(
                    '[AddMaintenance] Kilometrage validator - value: "$value"',
                  );
                  // Allow empty (will default to 0)
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null) {
                      print('[AddMaintenance] Kilometrage parse failed');
                      return 'Kilométrage invalide';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description du Travail
              Text(
                'Description du Travail Effectué',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Détails supplémentaires sur l\'intervention...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  print(
                    '[AddMaintenance] Description validator - value: "$value"',
                  );
                  return value?.isEmpty ?? true ? 'Description requise' : null;
                },
              ),
              const SizedBox(height: 20),

              // Notes
              Text(
                'Notes / Commentaires',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ajouter des notes supplémentaires...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.check),
                      const SizedBox(width: 8),
                      Text(
                        _isLoading
                            ? 'Enregistrement...'
                            : 'Enregistrer le dossier',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Annuler',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

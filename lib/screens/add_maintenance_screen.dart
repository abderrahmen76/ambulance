import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/company_staff_service.dart';
import '../services/maintenance_service.dart';
import '../utils/responsive.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;

  const AddMaintenanceScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
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
    'Autre'
  ];

  // Mapping from French display names to English database values
  final Map<String, String> _maintenanceTypeMapping = {
    'Vidange': 'oil change',
    'Plaquettes de Frein': 'brake pad replacement',
    'Bougies': 'oil change',
    'Pneus': 'brake pad replacement',
    'Liquide de Frein': 'brake pad replacement',
    'Urgent': 'urgent',
    'Autre': 'pending',
  };

  // Maintenance intervals (in days or km - for now using days)
  final Map<String, int> _maintenanceIntervals = {
    'Vidange': 180, // 6 months
    'Plaquettes de Frein': 365, // 1 year
    'Bougies': 365,
    'Pneus': 365,
    'Liquide de Frein': 365,
    'Urgent': 90,
    'Autre': 90,
  };

  final _formKey = GlobalKey<FormState>();
  final MaintenanceService _maintenanceService = MaintenanceService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  bool _isLoading = false;
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
    _driverController = TextEditingController(text: widget.user.name ?? '');
    _customMaintenanceTypeController = TextEditingController();
    _kilometrageController = TextEditingController();
    _loadCompanyStaff();
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
        _companyStaff = staff.where((member) => member.id != widget.user.id).toList();
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
    }
  }

  void _updateNextServiceDate() {
    if (_selectedMaintenanceType != null) {
      final days = _maintenanceIntervals[_selectedMaintenanceType!] ?? 90;
      final nextDate = DateTime.now().add(Duration(days: days));
      _nextServiceController.text = DateFormat('dd/MM/yyyy').format(nextDate);
    }
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
            '[AddMaintenance] Parsed date: ${_dateController.text} -> $isoDate');

        // Get the database value from the French display name or use custom type
        String databaseMaintenanceType = 'pending';
        if (_selectedMaintenanceType == 'Autre') {
          // Use the custom maintenance type entered by the user
          databaseMaintenanceType =
              _customMaintenanceTypeController.text.isEmpty
                  ? 'custom maintenance'
                  : _customMaintenanceTypeController.text.toLowerCase();
        } else {
          databaseMaintenanceType =
              _maintenanceTypeMapping[_selectedMaintenanceType] ?? 'pending';
        }

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
          'kilometrage': double.tryParse(_kilometrageController.text) ?? 0,
        };

        print('[AddMaintenance] Form data prepared:');
        print(
            '[AddMaintenance] - Ambulance ID: ${maintenanceData['ambulance_id']}');
        print('[AddMaintenance] - Date: ${maintenanceData['date']}');
        print(
            '[AddMaintenance] - Type: ${maintenanceData['maintenance_type']}');
        print(
            '[AddMaintenance] - Description: ${maintenanceData['maintenance_description']}');
        print(
            '[AddMaintenance] - Mechanic: ${maintenanceData['mechanic_name']}');
        print(
            '[AddMaintenance] - Price: ${maintenanceData['price_per_piece']} TND');
        print('[AddMaintenance] - User ID: ${maintenanceData['user_id']}');
        print(
            '[AddMaintenance] - Driver Name: ${maintenanceData['driver_name']}');
        print('[AddMaintenance] - Notes: ${maintenanceData['notes']}');
        print(
            '[AddMaintenance] - Kilometrage: ${maintenanceData['kilometrage']}');
        print(
            '[AddMaintenance] - Kilometrage Controller Text: "${_kilometrageController.text}" (empty: ${_kilometrageController.text.isEmpty})');
        print(
            '[AddMaintenance] - Kilometrage parsed: ${double.tryParse(_kilometrageController.text)} (type: ${double.tryParse(_kilometrageController.text).runtimeType})');

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
              widget.ambulanceId,
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
                  suffixIcon:
                      Icon(Icons.calendar_today, color: AppColors.primary),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMaintenanceType = value;
                    _updateNextServiceDate();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Sélectionner un type',
                  suffixIcon:
                      Icon(Icons.arrow_drop_down, color: AppColors.primary),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        print(
                            '[AddMaintenance] Custom type validator - value: "$value"');
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print(
                      '[AddMaintenance] Mechanic validator - value: "$value"');
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
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            print(
                                '[AddMaintenance] Price validator - value: "$value"');
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
                            suffixIcon: Icon(Icons.calendar_today,
                                color: AppColors.primary),
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
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            print(
                                '[AddMaintenance] Next service validator - value: "$value"');
                            return value?.isEmpty ?? true
                                ? 'Intervalle requis'
                                : null;
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print(
                      '[AddMaintenance] Kilometrage validator - value: "$value"');
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print(
                      '[AddMaintenance] Description validator - value: "$value"');
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

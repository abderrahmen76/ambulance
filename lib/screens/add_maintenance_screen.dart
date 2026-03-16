import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/maintenance_service.dart';

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

  String? _selectedMaintenanceType;

  final List<String> _maintenanceTypes = [
    'Vidange',
    'Roue',
    'Bougie',
    'Chaîne',
    'Filtre à Air',
    'Filtre à Huile',
    'Batterie',
    'Plaquettes de Frein',
    'Liquide de Frein',
    'Autre'
  ];

  // Maintenance intervals (in days or km - for now using days)
  final Map<String, int> _maintenanceIntervals = {
    'Vidange': 180, // 6 months
    'Roue': 365, // 1 year
    'Bougie': 365,
    'Chaîne': 180,
    'Filtre à Air': 180,
    'Filtre à Huile': 180,
    'Batterie': 730, // 2 years
    'Plaquettes de Frein': 365,
    'Liquide de Frein': 365,
    'Autre': 90,
  };

  final _formKey = GlobalKey<FormState>();
  final MaintenanceService _maintenanceService = MaintenanceService();
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _nextServiceController.dispose();
    _priceController.dispose();
    _mechanicController.dispose();
    _notesController.dispose();
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

        print('[AddMaintenance] Parsed date: ${_dateController.text} -> $isoDate');

        // Prepare data for API
        final maintenanceData = {
          'ambulance_id': widget.ambulanceId,
          'date': isoDate,
          'maintenance_type': _selectedMaintenanceType?.toLowerCase(), // Convert to lowercase for DB constraint
          'maintenance_description': _descriptionController.text, // Fixed field name
          'mechanic_name': _mechanicController.text,
          'price_per_piece': double.tryParse(_priceController.text) ?? 0,
          'notes': _notesController.text,
          'user_id': widget.user.id,
          'driver_name': widget.user.name,
        };

        print('[AddMaintenance] Form data prepared:');
        print('[AddMaintenance] - Ambulance ID: ${maintenanceData['ambulance_id']}');
        print('[AddMaintenance] - Date: ${maintenanceData['date']}');
        print('[AddMaintenance] - Type: ${maintenanceData['maintenance_type']}');
        print('[AddMaintenance] - Description: ${maintenanceData['maintenance_description']}');
        print('[AddMaintenance] - Mechanic: ${maintenanceData['mechanic_name']}');
        print('[AddMaintenance] - Price: ${maintenanceData['price_per_piece']} TND');
        print('[AddMaintenance] - User ID: ${maintenanceData['user_id']}');
        print('[AddMaintenance] - Driver Name: ${maintenanceData['driver_name']}');
        print('[AddMaintenance] - Notes: ${maintenanceData['notes']}');

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
        padding: const EdgeInsets.all(20),
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
                  suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print('[AddMaintenance] Date validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Date requise' : null;
                },
              ),
              const SizedBox(height: 20),

              // Type d'Entretien
              Text(
                'Type d\'Entretien',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMaintenanceType,
                items: _maintenanceTypes.map((type) {
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
                  suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print('[AddMaintenance] Type validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Type d\'entretien requis' : null;
                },
              ),
              const SizedBox(height: 20),

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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print('[AddMaintenance] Mechanic validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Nom du mécanicien requis' : null;
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            print('[AddMaintenance] Price validator - value: "$value"');
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
                            suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            print('[AddMaintenance] Next service validator - value: "$value"');
                            return value?.isEmpty ?? true ? 'Intervalle requis' : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print('[AddMaintenance] Description validator - value: "$value"');
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        _isLoading ? 'Enregistrement...' : 'Enregistrer le dossier',
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

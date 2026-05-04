import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/company_staff_service.dart';
import '../services/fuel_card_service.dart';
import '../utils/responsive.dart';

class AddFuelCardScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;
  final String? ambulanceName;

  const AddFuelCardScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
    this.ambulanceName,
  }) : super(key: key);

  @override
  State<AddFuelCardScreen> createState() => _AddFuelCardScreenState();
}

class _AddFuelCardScreenState extends State<AddFuelCardScreen> {
  late TextEditingController _dateController;
  late TextEditingController _driverController;
  late TextEditingController _soldesPaidController;
  late TextEditingController _notesController;
  late TextEditingController _kilometrageController;

  final _formKey = GlobalKey<FormState>();
  final FuelCardService _fuelCardService = FuelCardService();
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  double _currentBalance = 0.0;
  late String _ambulanceDisplayName;
  List<User> _companyStaff = [];
  final Set<String> _selectedTeammateIds = {};

  @override
  void initState() {
    super.initState();
    print('[AddFuelCard] Initializing form...');
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _dateController = TextEditingController(text: today);
    _driverController = TextEditingController(text: widget.user.name);
    _soldesPaidController = TextEditingController();
    _notesController = TextEditingController();
    _kilometrageController = TextEditingController();
    _ambulanceDisplayName = widget.ambulanceName ?? widget.ambulanceId;
    _loadAmbulanceDisplayName();
    _loadCurrentBalance();
    _loadCompanyStaff();
    print('[AddFuelCard] Form initialized');
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
      print('[AddFuelCard] Error loading ambulance name: $e');
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
      print('[AddFuelCard] Error loading company staff: $e');
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

  Future<void> _loadCurrentBalance() async {
    try {
      print('[AddFuelCard] Loading current balance...');
      final balance = await _fuelCardService.getCurrentCardBalance(
        widget.ambulanceId,
      );
      setState(() {
        _currentBalance = balance;
      });
      print('[AddFuelCard] Current balance: $_currentBalance TND');
    } catch (e) {
      print('[AddFuelCard] Error loading balance: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _driverController.dispose();
    _soldesPaidController.dispose();
    _notesController.dispose();
    _kilometrageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    }
  }

  void _submitForm() async {
    print('[AddFuelCard] Submit button pressed');
    print('[AddFuelCard] Form valid: ${_formKey.currentState?.validate()}');

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      print('[AddFuelCard] Setting loading state to true');

      try {
        // Parse date back to ISO format for API
        final dateFormat = DateFormat('dd/MM/yyyy');
        final parsedDate = dateFormat.parse(_dateController.text);
        final isoDate = parsedDate.toIso8601String();

        print('[AddFuelCard] Parsed date: ${_dateController.text} -> $isoDate');

        // Prepare data for API
        final fuelData = {
          'ambulance_id': widget.ambulanceId,
          'date': isoDate,
          'driver_name': _driverController.text,
          'soldes_paid': double.tryParse(_soldesPaidController.text) ?? 0,
          'notes': _notesController.text,
          'user_id': widget.user.id,
          'kilometrage': double.tryParse(_kilometrageController.text) ?? 0,
        };

        print('[AddFuelCard] Form data prepared:');
        print('[AddFuelCard] - Ambulance ID: ${fuelData['ambulance_id']}');
        print('[AddFuelCard] - Date: ${fuelData['date']}');
        print('[AddFuelCard] - Driver: ${fuelData['driver_name']}');
        print(
          '[AddFuelCard] - Soldes Paid (Consumed): ${fuelData['soldes_paid']} TND',
        );
        print('[AddFuelCard] - Kilometrage: ${fuelData['kilometrage']} km');
        print('[AddFuelCard] - Notes: ${fuelData['notes']}');

        // TODO: Call FuelCardService to submit
        print('[AddFuelCard] Ready to submit to API');
        await _fuelCardService.addFuelCard(fuelData);

        print('[AddFuelCard] Navigating back');
        // Navigate back immediately (dashboard will auto-refresh and show data)
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('[AddFuelCard] ERROR: ${e.toString()}');
        print('[AddFuelCard] Stack trace: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
        print('[AddFuelCard] Setting loading state to false');
      }
    } else {
      print('[AddFuelCard] Form validation failed');
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
        title: const Text('Nouvelle Carte Carburant'),
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
              // Vehicle info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Véhicule',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _ambulanceDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'EN SERVICE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date field
              Text(
                'Date de la transaction',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
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
                  print('[AddFuelCard] Date validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Date requise' : null;
                },
              ),
              const SizedBox(height: 20),

              // Driver name field
              Text(
                'Ambulancier',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Nom du conducteur',
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
                  print('[AddFuelCard] Driver validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Nom requis' : null;
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

              // Soldes Paid field
              Text(
                'Soldes (Payé) - TND',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _soldesPaidController,
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
                  if (value?.isEmpty ?? true) {
                    return 'Soldes payé requis';
                  }
                  if (double.tryParse(value!) == null) {
                    return 'Montant invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Solde Restant display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solde Actuel',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentBalance.toStringAsFixed(2)} TND',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.green[900],
                              ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Solde Restant',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_currentBalance - (double.tryParse(_soldesPaidController.text) ?? 0)).toStringAsFixed(2)} TND',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[900],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Kilometrage field
              Text(
                'Kilometrage (KM)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _kilometrageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.0',
                  suffixText: 'km',
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
                  if (value?.isEmpty ?? true) return null; // Optional field
                  if (double.tryParse(value!) == null) {
                    return 'Kilometrage invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Notes field
              Text(
                'Notes / Commentaires',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ajouter des notes...',
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
              const SizedBox(height: 32),

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
                        _isLoading ? 'Enregistrement...' : 'Enregistrer',
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

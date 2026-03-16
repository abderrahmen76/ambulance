import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/fuel_card_service.dart';

class AddFuelCardScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;

  const AddFuelCardScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
  }) : super(key: key);

  @override
  State<AddFuelCardScreen> createState() => _AddFuelCardScreenState();
}

class _AddFuelCardScreenState extends State<AddFuelCardScreen> {
  late TextEditingController _dateController;
  late TextEditingController _driverController;
  late TextEditingController _quantityController;
  late TextEditingController _amountController;
  late TextEditingController _cardNumberController;
  late TextEditingController _notesController;

  final _formKey = GlobalKey<FormState>();
  final FuelCardService _fuelCardService = FuelCardService();
  bool _isLoading = false;
  String _fullCardNumber = ''; // Store full card number internally

  @override
  void initState() {
    super.initState();
    print('[AddFuelCard] Initializing form...');
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _dateController = TextEditingController(text: today);
    _driverController = TextEditingController(); // Empty by default
    _quantityController = TextEditingController();
    _amountController = TextEditingController();
    _cardNumberController = TextEditingController();
    _fullCardNumber = '';
    _notesController = TextEditingController();
    print('[AddFuelCard] Form initialized');
  }

  String _maskCardNumberForDisplay(String digitsOnly) {
    // Format as **** **** **** XXXX - showing only last 4 digits
    if (digitsOnly.length < 16) return digitsOnly;
    
    String last4 = digitsOnly.substring(12);
    return '**** **** **** $last4';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _driverController.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    _cardNumberController.dispose();
    _notesController.dispose();
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
          'fuel_amount': double.tryParse(_quantityController.text) ?? 0,
          'balance': double.tryParse(_amountController.text) ?? 0,
          'card_number': _fullCardNumber,
          'notes': _notesController.text,
          'user_id': widget.user.id,
        };

        print('[AddFuelCard] Form data prepared:');
        print('[AddFuelCard] - Ambulance ID: ${fuelData['ambulance_id']}');
        print('[AddFuelCard] - Date: ${fuelData['date']}');
        print('[AddFuelCard] - Driver: ${fuelData['driver_name']}');
        print('[AddFuelCard] - Quantity: ${fuelData['fuel_amount']} L');
        print('[AddFuelCard] - Balance: ${fuelData['balance']} TND');
        print('[AddFuelCard] - Card (masked): ${_maskCardNumberForDisplay(_fullCardNumber)}');
        print('[AddFuelCard] - Card (full): $_fullCardNumber');
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
        padding: const EdgeInsets.all(20),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.ambulanceId,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print('[AddFuelCard] Driver validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Nom requis' : null;
                },
              ),
              const SizedBox(height: 20),

              // Quantity and Amount in row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantité (L)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            suffixText: 'L',
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
                            print('[AddFuelCard] Quantity validator - value: "$value"');
                            // Allow empty (will default to 0)
                            if (value != null && value.isNotEmpty) {
                              final parsed = double.tryParse(value);
                              if (parsed == null) {
                                print('[AddFuelCard] Quantity parse failed');
                                return 'Quantité invalide';
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
                          'Solde (TND)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amountController,
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
                            print('[AddFuelCard] Amount validator - value: "$value"');
                            // Allow empty (will default to 0)
                            if (value != null && value.isNotEmpty) {
                              final parsed = double.tryParse(value);
                              if (parsed == null) {
                                print('[AddFuelCard] Amount parse failed');
                                return 'Solde invalide';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card Number field
              Text(
                'Numero de Carte',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 16, // Only allow 16 digits
                decoration: InputDecoration(
                  hintText: 'Entrez les 16 chiffres',
                  counterText: '', // Hide the counter
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
                  final digitsOnly = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  print('[AddFuelCard] Card validation - input: $value, digits: $digitsOnly, length: ${digitsOnly.length}');
                  if (digitsOnly.isEmpty) {
                    return 'Numéro de carte requis';
                  }
                  if (digitsOnly.length < 16) {
                    return 'Numéro incomplet (${digitsOnly.length}/16 chiffres)';
                  }
                  // Store the verified full card number
                  _fullCardNumber = digitsOnly;
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/fuel_card_service.dart';
import '../utils/responsive.dart';

class RefuelFuelCardScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;
  final Map<String, dynamic>? ambulanceData;

  const RefuelFuelCardScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
    this.ambulanceData,
  }) : super(key: key);

  @override
  State<RefuelFuelCardScreen> createState() => _RefuelFuelCardScreenState();
}

class _RefuelFuelCardScreenState extends State<RefuelFuelCardScreen> {
  late TextEditingController _dateController;
  late TextEditingController _refillAmountController;

  final _formKey = GlobalKey<FormState>();
  final FuelCardService _fuelCardService = FuelCardService();
  bool _isLoading = false;
  double _currentCardBalance = 0.0;

  @override
  void initState() {
    super.initState();
    print('[RefuelFuelCard] Initializing refuel form...');
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _dateController = TextEditingController(text: today);
    _refillAmountController = TextEditingController();
    _loadCurrentBalance();
    print('[RefuelFuelCard] Form initialized');
  }

  Future<void> _loadCurrentBalance() async {
    try {
      print('[RefuelFuelCard] Loading current balance...');
      final balance =
          await _fuelCardService.getCurrentCardBalance(widget.ambulanceId);
      setState(() {
        _currentCardBalance = balance;
      });
      print('[RefuelFuelCard] Current balance: $_currentCardBalance TND');
    } catch (e) {
      print('[RefuelFuelCard] Error loading balance: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _refillAmountController.dispose();
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
    print('[RefuelFuelCard] Submit button pressed');
    print('[RefuelFuelCard] Form valid: ${_formKey.currentState?.validate()}');

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      print('[RefuelFuelCard] Setting loading state to true');

      try {
        // Parse date back to ISO format for API
        final dateFormat = DateFormat('dd/MM/yyyy');
        final parsedDate = dateFormat.parse(_dateController.text);
        final isoDate = parsedDate.toIso8601String();

        print(
            '[RefuelFuelCard] Parsed date: ${_dateController.text} -> $isoDate');

        // Prepare data for API
        final refillData = {
          'ambulance_id': widget.ambulanceId,
          'date': isoDate,
          'refill_amount': double.tryParse(_refillAmountController.text) ?? 0,
          'user_id': widget.user.id,
        };

        print('[RefuelFuelCard] Refill data prepared:');
        print('[RefuelFuelCard] - Ambulance ID: ${refillData['ambulance_id']}');
        print('[RefuelFuelCard] - Date: ${refillData['date']}');
        print(
            '[RefuelFuelCard] - Refill Amount: ${refillData['refill_amount']} TND');

        // Call FuelCardService to submit refill
        print('[RefuelFuelCard] Submitting refill to API');
        await _fuelCardService.refillFuelCard(refillData);

        print('[RefuelFuelCard] Refill successful, navigating back');
        // Navigate back immediately
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recharge effectuée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('[RefuelFuelCard] ERROR: ${e.toString()}');
        print('[RefuelFuelCard] Stack trace: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
        print('[RefuelFuelCard] Setting loading state to false');
      }
    } else {
      print('[RefuelFuelCard] Form validation failed');
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
        title: const Text('Recharger Carte Carburant'),
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
              // Current Balance Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solde Actuel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentCardBalance.toStringAsFixed(2)} TND',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[900],
                              ),
                        ),
                        Icon(
                          Icons.local_gas_station,
                          color: Colors.blue[600],
                          size: 32,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date field
              Text(
                'Date de Recharge',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
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
                  print('[RefuelFuelCard] Date validator - value: "$value"');
                  return value?.isEmpty ?? true ? 'Date requise' : null;
                },
              ),
              const SizedBox(height: 20),

              // Refill Amount field
              Text(
                'Montant à Recharger - TND',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _refillAmountController,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  print(
                      '[RefuelFuelCard] Refill amount validator - value: "$value"');
                  if (value?.isEmpty ?? true) {
                    return 'Montant de recharge requis';
                  }
                  if (double.tryParse(value!) == null) {
                    return 'Montant invalide';
                  }
                  final amount = double.parse(value!);
                  if (amount <= 0) {
                    return 'Le montant doit être supérieur à 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Preview new balance
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
                          'Nouveau Solde',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_currentCardBalance + (double.tryParse(_refillAmountController.text) ?? 0)).toStringAsFixed(2)} TND',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green[900],
                                  ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
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
                        const Icon(Icons.add_circle),
                      const SizedBox(width: 8),
                      Text(
                        _isLoading ? 'Rechargement...' : 'Recharger',
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ambulance_model.dart';
import '../models/equipment_rental_model.dart';
import '../models/user_model.dart';
import '../services/company_staff_service.dart';
import '../services/equipment_rental_service.dart';
import '../services/notification_app_service.dart';
import '../config/constants.dart';

// Base equipment types (fixed options)
const List<String> baseEquipmentTypes = ['Oxygéne', 'Autre'];

String _normalizeEquipmentTypeLabel(String value) => value.trim().toLowerCase();

bool _isOxygenEquipmentTypeLabel(String value) =>
    _normalizeEquipmentTypeLabel(value).contains('oxy');

bool _isPlaceholderEquipmentTypeLabel(String value) {
  final normalized = _normalizeEquipmentTypeLabel(value);
  return normalized == 'autre' || normalized == 'other';
}

String _canonicalEquipmentTypeLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (_isOxygenEquipmentTypeLabel(trimmed)) return 'Oxygene';
  return trimmed;
}

String _friendlyEquipmentError(Object error) {
  final raw = error.toString();
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^ApiException:\s*'), '');
  if (cleaned.toLowerCase().contains('stock insuffisant')) {
    return cleaned;
  }
  return 'Erreur: $cleaned';
}

List<String> _buildEquipmentTypeOptions({
  required List<String> stockTypes,
  required List<String> fallbackTypes,
}) {
  final sourceTypes = stockTypes.isNotEmpty ? stockTypes : fallbackTypes;
  final options =
      sourceTypes
          .map(_canonicalEquipmentTypeLabel)
          .where(
            (type) =>
                type.isNotEmpty && !_isPlaceholderEquipmentTypeLabel(type),
          )
          .toSet()
          .toList()
        ..sort();

  return [...options, 'Autre'];
}

class EquipmentRentalScreen extends StatefulWidget {
  final Ambulance ambulance;
  final User user;

  const EquipmentRentalScreen({
    Key? key,
    required this.ambulance,
    required this.user,
  }) : super(key: key);

  @override
  State<EquipmentRentalScreen> createState() => _EquipmentRentalScreenState();
}

class _EquipmentRentalScreenState extends State<EquipmentRentalScreen> {
  late EquipmentRentalService _rentalService;
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  List<EquipmentRental> _rentals = [];
  bool _isLoading = true;
  List<String> _allEquipmentTypes = [...baseEquipmentTypes];
  List<User> _companyStaff = [];

  String get _equipmentTypesPrefsKey {
    final tenantId = widget.user.tenantId?.trim();
    if (tenantId != null && tenantId.isNotEmpty) {
      return 'custom_equipment_types_$tenantId';
    }
    return 'custom_equipment_types_user_${widget.user.id}';
  }

  @override
  void initState() {
    super.initState();
    _rentalService = EquipmentRentalService();
    _loadCompanyStaff();
    _loadEquipmentTypesAndRentals();
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
    } catch (e) {
      debugPrint('Error loading company staff: $e');
    }
  }

  Future<void> _loadEquipmentTypesAndRentals() async {
    await _loadCustomEquipmentTypes();
    await _loadEquipmentRentals();
  }

  Future<void> _loadCustomEquipmentTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customTypes = prefs.getStringList(_equipmentTypesPrefsKey) ?? [];
      if (mounted) {
        setState(() {
          _allEquipmentTypes = [...baseEquipmentTypes, ...customTypes];
        });
      }
    } catch (e) {
      debugPrint('Error loading custom equipment types: $e');
    }
  }

  Future<void> _loadEquipmentRentals() async {
    try {
      final rentals = await _rentalService.getAmbulanceEquipmentRentals(
        widget.ambulance.id,
      );
      if (mounted) {
        setState(() {
          _rentals = rentals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddRentalDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AddEquipmentRentalDialog(
        ambulanceId: widget.ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: _companyStaff,
        onRentalAdded: (rental) async {
          Navigator.pop(dialogContext);

          // Save notification to database (backend will send FCM)
          await NotificationServiceApp.instance.saveNotification(
            title: '✅ Équipement Loué',
            body:
                '${widget.ambulance.ambulanceNumber} - ${rental.equipmentType} loué jusqu\'au ${rental.returnDate}',
            type: 'equipment_rented',
            data: {
              'equipment_type': rental.equipmentType,
              'rental_date': rental.rentDate,
              'return_date': rental.returnDate ?? '',
              'equipment_id': rental.id,
              'user_id': widget.user.id,
              'ambulance_id': widget.ambulance.id,
              'ambulance_name': widget.ambulance.ambulanceNumber,
            },
          );

          // Show local notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ ${rental.equipmentType} loué jusqu\'au ${rental.returnDate}',
                  style: const TextStyle(fontSize: 14),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Set loading state and refresh
          if (mounted) {
            setState(() => _isLoading = true);
            await _loadEquipmentTypesAndRentals();
          }
        },
      ),
    );
  }

  void _showReturnDialog(EquipmentRental rental) {
    final returnDateCtrl = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retourner Équipement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Équipement: ${rental.equipmentType}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: returnDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date de Retour',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  returnDateCtrl.text = picked.toString().split(' ')[0];
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _rentalService.markAsReturned(
                  rental.id,
                  returnDateCtrl.text,
                );
                if (mounted) {
                  Navigator.pop(dialogContext);

                  // Save notification to database (backend will send FCM)
                  await NotificationServiceApp.instance.saveNotification(
                    title: '✅ Équipement Retourné',
                    body:
                        '${widget.ambulance.ambulanceNumber} - ${rental.equipmentType} retourné le ${returnDateCtrl.text}',
                    type: 'equipment_returned',
                    data: {
                      'equipment_type': rental.equipmentType,
                      'equipment_id': rental.id,
                      'return_date': returnDateCtrl.text,
                      'user_id': widget.user.id,
                      'ambulance_id': widget.ambulance.id,
                      'ambulance_name': widget.ambulance.ambulanceNumber,
                    },
                  );

                  // Show local notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ ${rental.equipmentType} retourné le ${returnDateCtrl.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  _loadEquipmentRentals();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showEditRentalDialog(EquipmentRental rental) {
    final ambulancierCtrl = TextEditingController(text: rental.ambulancierName);
    final patientNameCtrl = TextEditingController(
      text: rental.patientName ?? '',
    );
    final patientAddressCtrl = TextEditingController(
      text: rental.patientAddress ?? '',
    );
    final costCtrl = TextEditingController(text: rental.cost.toString());
    final quantityCtrl = TextEditingController(
      text: rental.quantity.toString(),
    );
    final notesCtrl = TextEditingController(text: rental.notes ?? '');
    final returnDateCtrl = TextEditingController(
      text: rental.returnDate?.split(' ')[0] ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier Détails de Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Équipement: ${rental.equipmentType}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Ambulancier name
              TextFormField(
                controller: ambulancierCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'Ambulancier',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Patient name
              TextFormField(
                controller: patientNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Nom du patient',
                ),
              ),
              const SizedBox(height: 12),

              // Patient address
              TextFormField(
                controller: patientAddressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Adresse du Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Adresse complète du patient',
                ),
              ),
              const SizedBox(height: 12),

              // Return date
              TextFormField(
                controller: returnDateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date de Retour Prévue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: rental.returnDate != null
                        ? DateTime.parse(rental.returnDate!.split(' ')[0])
                        : DateTime.now(),
                    firstDate: DateTime.parse(rental.rentDate.split(' ')[0]),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    returnDateCtrl.text = picked.toString().split(' ')[0];
                  }
                },
              ),
              const SizedBox(height: 12),

              // Quantity
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '1',
                ),
              ),
              const SizedBox(height: 12),

              // Cost
              TextFormField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Coût (TND)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'État de l\'équipement, conditions spéciales, etc.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final quantity = int.tryParse(quantityCtrl.text.trim());
                if (quantity == null || quantity < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La quantité doit être au moins 1'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                // Update rental with all new values
                await _rentalService.updateEquipmentRental(
                  rentalId: rental.id,
                  ambulancierName: ambulancierCtrl.text,
                  patientName: patientNameCtrl.text.isEmpty
                      ? null
                      : patientNameCtrl.text,
                  patientAddress: patientAddressCtrl.text.isEmpty
                      ? null
                      : patientAddressCtrl.text,
                  returnDate: returnDateCtrl.text,
                  cost: double.tryParse(costCtrl.text) ?? rental.cost,
                  quantity: quantity,
                  notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                );

                if (mounted) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Détails mis à jour avec succès'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );

                  _loadEquipmentRentals();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Mettre à Jour'),
          ),
        ],
      ),
    );
  }

  void _showEditReturnDateDialog(EquipmentRental rental) {
    final returnDateCtrl = TextEditingController(
      text: rental.returnDate?.split(' ')[0] ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier Date de Retour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Équipement: ${rental.equipmentType}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: returnDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Nouvelle Date de Retour',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: rental.returnDate != null
                      ? DateTime.parse(rental.returnDate!.split(' ')[0])
                      : DateTime.now(),
                  firstDate: DateTime.parse(rental.rentDate.split(' ')[0]),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  returnDateCtrl.text = picked.toString().split(' ')[0];
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update the rental with new return date
                await _rentalService.updateReturnDate(
                  rental.id,
                  returnDateCtrl.text,
                );

                if (mounted) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Date de retour mise à jour le ${returnDateCtrl.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  _loadEquipmentRentals();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Mettre à Jour'),
          ),
        ],
      ),
    );
  }

  void _showSellDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => SellEquipmentDialog(
        ambulanceId: widget.ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: _companyStaff,
        onEquipmentSold: (sale) async {
          Navigator.pop(dialogContext);

          // Save notification to database (backend will send FCM)
          await NotificationServiceApp.instance.saveNotification(
            title: '💰 Équipement Vendu',
            body:
                '${widget.ambulance.ambulanceNumber} - ${sale.equipmentType} vendu: ${sale.cost.toStringAsFixed(2)} TND',
            type: 'equipment_sold',
            data: {
              'equipment_type': sale.equipmentType,
              'sale_date': sale.rentDate,
              'equipment_id': sale.id,
              'user_id': widget.user.id,
              'ambulance_id': widget.ambulance.id,
              'ambulance_name': widget.ambulance.ambulanceNumber,
            },
          );

          // Show local notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '💰 ${sale.equipmentType} vendu pour ${sale.cost.toStringAsFixed(2)} TND',
                  style: const TextStyle(fontSize: 14),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Set loading state and refresh
          if (mounted) {
            setState(() => _isLoading = true);
            await _loadEquipmentTypesAndRentals();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add and Sell buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddRentalDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter Équipement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSellDialog,
                  icon: const Icon(Icons.sell),
                  label: const Text('Vendre Équipement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rentals list or empty state
          if (_rentals.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cliquez sur "Ajouter Équipement" pour louer du matériel',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rentals.length,
              itemBuilder: (context, index) {
                final rental = _rentals[index];
                return _buildRentalCard(rental);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRentalCard(EquipmentRental rental) {
    final isReturned = rental.isReturned ?? false;
    final isSold = rental.transactionType == 'sale';
    final rentDateFormatted = rental.rentDate.split(' ')[0];
    final returnDateFormatted = rental.returnDate?.split(' ')[0] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equipment type status and edit button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.equipmentType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSold
                              ? Colors.orange[100]
                              : (isReturned
                                    ? Colors.grey[200]
                                    : Colors.green[100]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSold
                              ? 'Vendu'
                              : (isReturned ? 'Retourné' : 'En Location'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSold
                                ? Colors.orange[700]
                                : (isReturned
                                      ? Colors.grey[700]
                                      : Colors.green[700]),
                          ),
                        ),
                      ),
                      // Patient name
                      if (rental.patientName != null &&
                          rental.patientName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rental.patientName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Edit button
                GestureDetector(
                  onTap: () => _showEditRentalDialog(rental),
                  child: const Icon(
                    Icons.edit_note,
                    size: 24,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                // Cost
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Coût',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${rental.cost.toStringAsFixed(2)} TND',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ambulancier name
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ambulancier',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rental.ambulancierName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Patient address (if exists)
            if (rental.patientAddress != null &&
                rental.patientAddress!.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adresse du Patient',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rental.patientAddress!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Patient phone number (if exists)
            if (rental.patientPhoneNumber != null &&
                rental.patientPhoneNumber!.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Téléphone du Patient',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        rental.patientPhoneNumber!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date de Location',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rentDateFormatted,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date de Retour',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        returnDateFormatted,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isReturned ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Notes
            if (rental.notes != null && rental.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rental.notes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],

            // Action button
            if (!isReturned)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showReturnDialog(rental),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Retourner Équipement'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Dialog for adding new equipment rental
class AddEquipmentRentalDialog extends StatefulWidget {
  final String ambulanceId;
  final String userId;
  final User currentUser;
  final List<User> companyStaff;
  final EquipmentRentalService rentalService;
  final List<String> equipmentTypes;
  final Function(EquipmentRental) onRentalAdded;

  const AddEquipmentRentalDialog({
    Key? key,
    required this.ambulanceId,
    required this.userId,
    required this.currentUser,
    required this.companyStaff,
    required this.rentalService,
    required this.equipmentTypes,
    required this.onRentalAdded,
  }) : super(key: key);

  @override
  State<AddEquipmentRentalDialog> createState() =>
      _AddEquipmentRentalDialogState();
}

class _AddEquipmentRentalDialogState extends State<AddEquipmentRentalDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEquipment;
  String _customEquipment = '';
  late String _ambulancierName;
  String _patientName = '';
  String _patientAddress = '';
  String _patientPhoneNumber = '';
  late String _rentDate;
  late String _returnDate;
  double _cost = 0.0;
  String _notes = '';
  bool _isLoading = false;
  int _quantity = 1; // Quantity of items being rented
  List<String> _stockEquipmentTypes = [];
  Map<String, int> _inventoryByEquipmentType = {};
  bool _isRefreshingAvailableStock = false;

  late TextEditingController _rentDateController;
  late TextEditingController _returnDateController;
  late TextEditingController _quantityController;
  late TextEditingController _ambulancierController;
  final Set<String> _selectedTeammateIds = {};

  String get _equipmentTypesPrefsKey {
    final tenantId = widget.currentUser.tenantId?.trim();
    if (tenantId != null && tenantId.isNotEmpty) {
      return 'custom_equipment_types_$tenantId';
    }
    return 'custom_equipment_types_user_${widget.currentUser.id}';
  }

  @override
  void initState() {
    super.initState();
    _ambulancierName = widget.currentUser.name;
    // Initialize rent date to today
    _rentDate = DateTime.now().toString().split(' ')[0];
    // Initialize return date to 3 days later (for rentals)
    _returnDate = DateTime.now()
        .add(const Duration(days: 3))
        .toString()
        .split(' ')[0];
    _rentDateController = TextEditingController(text: _rentDate);
    _returnDateController = TextEditingController(text: _returnDate);
    _quantityController = TextEditingController(text: _quantity.toString());
    _ambulancierController = TextEditingController(text: _ambulancierName);
    _loadStockEquipmentTypes();
  }

  Future<void> _loadStockEquipmentTypes() async {
    try {
      final inventories = await widget.rentalService.getEquipmentInventories();
      if (!mounted) return;
      setState(() {
        _stockEquipmentTypes = inventories.keys.toList();
        _inventoryByEquipmentType = inventories;
      });
    } catch (e) {
      debugPrint('Error loading stock equipment types: $e');
    }
  }

  void _updateAmbulancierName() {
    final teammateNames = widget.companyStaff
        .where((member) => _selectedTeammateIds.contains(member.id))
        .map((member) => member.name)
        .toList();
    _ambulancierName = <String>[
      widget.currentUser.name,
      ...teammateNames,
    ].join(', ');
    _ambulancierController.text = _ambulancierName;
  }

  int _availableStockForSelection() {
    final selectedType = _selectedEquipment == 'Autre'
        ? _customEquipment
        : (_selectedEquipment ?? '');
    final canonicalType = _canonicalEquipmentTypeLabel(selectedType);
    if (canonicalType.isEmpty) return 0;
    return _inventoryByEquipmentType[canonicalType] ?? 0;
  }

  Future<void> _refreshAvailableStockForSelection() async {
    final selectedType = _selectedEquipment == 'Autre'
        ? _customEquipment
        : (_selectedEquipment ?? '');
    if (selectedType.trim().isEmpty) return;

    setState(() => _isRefreshingAvailableStock = true);
    try {
      final available = await widget.rentalService.getAvailableEquipmentQuantity(
        selectedType,
      );
      final canonicalType = _canonicalEquipmentTypeLabel(selectedType);
      if (!mounted || canonicalType.isEmpty) return;
      setState(() {
        _inventoryByEquipmentType[canonicalType] = available;
      });
    } catch (e) {
      debugPrint('Error refreshing available equipment stock: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAvailableStock = false);
      }
    }
  }

  @override
  void dispose() {
    _rentDateController.dispose();
    _returnDateController.dispose();
    _quantityController.dispose();
    _ambulancierController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomEquipmentType(String equipmentType) async {
    try {
      // Only save if it's a custom type (not in baseEquipmentTypes)
      if (!baseEquipmentTypes.contains(equipmentType)) {
        final prefs = await SharedPreferences.getInstance();
        final customTypes = prefs.getStringList(_equipmentTypesPrefsKey) ?? [];

        // Only add if not already in the list
        if (!customTypes.contains(equipmentType)) {
          customTypes.add(equipmentType);
          await prefs.setStringList(_equipmentTypesPrefsKey, customTypes);
          debugPrint('✅ Saved custom equipment type: $equipmentType');
        }
      }
    } catch (e) {
      debugPrint('Error saving custom equipment type: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final equipmentType = _selectedEquipment == 'Autre'
          ? _customEquipment
          : _selectedEquipment!;

      try {
        setState(() => _isLoading = true);

        // Save custom equipment type if needed
        await _saveCustomEquipmentType(equipmentType);

        final rental = await widget.rentalService.createEquipmentRental(
          ambulanceId: widget.ambulanceId,
          equipmentType: equipmentType,
          ambulancierName: _ambulancierName,
          rentDate: _rentDate,
          returnDate: _returnDate,
          cost: _cost,
          notes: _notes.isEmpty ? null : _notes,
          patientName: _patientName.isEmpty ? null : _patientName,
          patientAddress: _patientAddress.isEmpty ? null : _patientAddress,
          patientPhoneNumber: _patientPhoneNumber.isEmpty
              ? null
              : _patientPhoneNumber,
          quantity: _quantity,
        );

        if (mounted) {
          widget.onRentalAdded(rental);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyEquipmentError(e)),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentTypeOptions = _buildEquipmentTypeOptions(
      stockTypes: _stockEquipmentTypes,
      fallbackTypes: widget.equipmentTypes,
    );

    return AlertDialog(
      title: const Text('Ajouter Équipement en Location'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equipment selection
              DropdownButtonFormField<String>(
                value: _selectedEquipment,
                decoration: InputDecoration(
                  labelText: 'Type d\'Équipement',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: equipmentTypeOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: !_isLoading
                    ? (value) {
                        setState(() {
                          _selectedEquipment = value;
                        });
                        _refreshAvailableStockForSelection();
                      }
                    : null,
                validator: (value) =>
                    value == null ? 'Sélectionnez un équipement' : null,
              ),
              const SizedBox(height: 12),

              if (_inventoryByEquipmentType.isNotEmpty &&
                  _selectedEquipment != null &&
                  _selectedEquipment != 'Autre')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Stock disponible: ${_availableStockForSelection()}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                ),
              if (_isRefreshingAvailableStock)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              // Custom equipment if "Autre" selected
              if (_selectedEquipment == 'Autre')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    initialValue: _customEquipment,
                    decoration: InputDecoration(
                      labelText: 'Spécifiez l\'équipement',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    enabled: !_isLoading,
                    onChanged: (value) {
                      setState(() => _customEquipment = value);
                      _refreshAvailableStockForSelection();
                    },
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Entrez le type' : null,
                  ),
                ),

              // Ambulancier name
              TextFormField(
                controller: _ambulancierController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'Ambulancier',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez le nom du conducteur/staff',
                ),
                readOnly: true,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Entrez le nom de l\'ambulancier'
                    : null,
              ),
              if (widget.companyStaff.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.companyStaff
                      .map(
                        (member) => FilterChip(
                          label: Text(member.name),
                          selected: _selectedTeammateIds.contains(member.id),
                          onSelected: !_isLoading
                              ? (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTeammateIds.add(member.id);
                                    } else {
                                      _selectedTeammateIds.remove(member.id);
                                    }
                                    _updateAmbulancierName();
                                  });
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),

              // Patient name
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nom du Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez le nom du patient',
                ),
                enabled: !_isLoading,
                onChanged: (value) => setState(() => _patientName = value),
              ),
              const SizedBox(height: 12),

              // Patient address
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Adresse du Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez l\'adresse du patient',
                ),
                enabled: !_isLoading,
                maxLines: 2,
                onChanged: (value) => setState(() => _patientAddress = value),
              ),
              const SizedBox(height: 12),

              // Patient phone number
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Numéro Téléphone Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '+216 XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone),
                ),
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                onChanged: (value) =>
                    setState(() => _patientPhoneNumber = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date de Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_rentDate),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final formattedDate = picked.toString().split(' ')[0];
                    setState(() {
                      _rentDate = formattedDate;
                      _rentDateController.text = _rentDate;
                      // If return date is before new rent date, update it to be at least equal
                      if (_returnDate.compareTo(_rentDate) < 0) {
                        _returnDate = _rentDate;
                        _returnDateController.text = _returnDate;
                      }
                    });
                  }
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Sélectionnez une date' : null,
              ),
              const SizedBox(height: 12),

              // Return date
              TextFormField(
                controller: _returnDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date de Retour Prévue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_returnDate),
                    firstDate: DateTime.parse(_rentDate),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final formattedDate = picked.toString().split(' ')[0];
                    setState(() {
                      _returnDate = formattedDate;
                      _returnDateController.text = _returnDate;
                    });
                  }
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Sélectionnez une date';
                  }
                  if (_returnDate.compareTo(_rentDate) < 0) {
                    return 'La date de retour doit être après la date de location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '1',
                ),
                enabled: !_isLoading,
                onChanged: (value) =>
                    setState(() => _quantity = int.tryParse(value) ?? 1),
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  if (qty == null || qty < 1) {
                    return 'La quantité doit être au moins 1';
                  }
                  if (_inventoryByEquipmentType.isNotEmpty &&
                      qty > _availableStockForSelection()) {
                    return 'Stock insuffisant';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Cost
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Coût (TND)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                enabled: !_isLoading,
                onChanged: (value) =>
                    setState(() => _cost = double.tryParse(value) ?? 0.0),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Entrez un coût valide'
                    : null,
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'État de l\'équipement, conditions, etc.',
                ),
                enabled: !_isLoading,
                onChanged: (value) => setState(() => _notes = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}

// Dialog for selling equipment
class SellEquipmentDialog extends StatefulWidget {
  final String ambulanceId;
  final String userId;
  final User currentUser;
  final List<User> companyStaff;
  final EquipmentRentalService rentalService;
  final List<String> equipmentTypes;
  final Function(EquipmentRental) onEquipmentSold;

  const SellEquipmentDialog({
    Key? key,
    required this.ambulanceId,
    required this.userId,
    required this.currentUser,
    required this.companyStaff,
    required this.rentalService,
    required this.equipmentTypes,
    required this.onEquipmentSold,
  }) : super(key: key);

  @override
  State<SellEquipmentDialog> createState() => _SellEquipmentDialogState();
}

class _SellEquipmentDialogState extends State<SellEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEquipment;
  String _customEquipment = '';
  late String _ambulancierName;
  String _patientName = '';
  String _patientAddress = '';
  String _patientPhoneNumber = '';
  String _saleDate = DateTime.now().toString().split(' ')[0];
  double _cost = 0.0;
  String _notes = '';
  bool _isLoading = false;
  int _quantity = 1;
  List<String> _stockEquipmentTypes = [];
  Map<String, int> _inventoryByEquipmentType = {};
  bool _isRefreshingAvailableStock = false;

  late TextEditingController _saleDateController;
  late TextEditingController _quantityController;
  late TextEditingController _ambulancierController;
  final Set<String> _selectedTeammateIds = {};

  String get _equipmentTypesPrefsKey {
    final tenantId = widget.currentUser.tenantId?.trim();
    if (tenantId != null && tenantId.isNotEmpty) {
      return 'custom_equipment_types_$tenantId';
    }
    return 'custom_equipment_types_user_${widget.currentUser.id}';
  }

  @override
  void initState() {
    super.initState();
    _ambulancierName = widget.currentUser.name;
    _saleDateController = TextEditingController(text: _saleDate);
    _quantityController = TextEditingController(text: _quantity.toString());
    _ambulancierController = TextEditingController(text: _ambulancierName);
    _loadStockEquipmentTypes();
  }

  Future<void> _loadStockEquipmentTypes() async {
    try {
      final inventories = await widget.rentalService.getEquipmentInventories();
      if (!mounted) return;
      setState(() {
        _stockEquipmentTypes = inventories.keys.toList();
        _inventoryByEquipmentType = inventories;
      });
    } catch (e) {
      debugPrint('Error loading stock equipment types: $e');
    }
  }

  void _updateAmbulancierName() {
    final teammateNames = widget.companyStaff
        .where((member) => _selectedTeammateIds.contains(member.id))
        .map((member) => member.name)
        .toList();
    _ambulancierName = <String>[
      widget.currentUser.name,
      ...teammateNames,
    ].join(', ');
    _ambulancierController.text = _ambulancierName;
  }

  int _availableStockForSelection() {
    final selectedType = _selectedEquipment == 'Autre'
        ? _customEquipment
        : (_selectedEquipment ?? '');
    final canonicalType = _canonicalEquipmentTypeLabel(selectedType);
    if (canonicalType.isEmpty) return 0;
    return _inventoryByEquipmentType[canonicalType] ?? 0;
  }

  Future<void> _refreshAvailableStockForSelection() async {
    final selectedType = _selectedEquipment == 'Autre'
        ? _customEquipment
        : (_selectedEquipment ?? '');
    if (selectedType.trim().isEmpty) return;

    setState(() => _isRefreshingAvailableStock = true);
    try {
      final available = await widget.rentalService.getAvailableEquipmentQuantity(
        selectedType,
      );
      final canonicalType = _canonicalEquipmentTypeLabel(selectedType);
      if (!mounted || canonicalType.isEmpty) return;
      setState(() {
        _inventoryByEquipmentType[canonicalType] = available;
      });
    } catch (e) {
      debugPrint('Error refreshing available equipment stock: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAvailableStock = false);
      }
    }
  }

  @override
  void dispose() {
    _saleDateController.dispose();
    _quantityController.dispose();
    _ambulancierController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomEquipmentType(String equipmentType) async {
    try {
      if (!baseEquipmentTypes.contains(equipmentType)) {
        final prefs = await SharedPreferences.getInstance();
        final customTypes = prefs.getStringList(_equipmentTypesPrefsKey) ?? [];

        if (!customTypes.contains(equipmentType)) {
          customTypes.add(equipmentType);
          await prefs.setStringList(_equipmentTypesPrefsKey, customTypes);
          debugPrint('✅ Saved custom equipment type: $equipmentType');
        }
      }
    } catch (e) {
      debugPrint('Error saving custom equipment type: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final equipmentType = _selectedEquipment == 'Autre'
          ? _customEquipment
          : _selectedEquipment!;

      try {
        setState(() => _isLoading = true);

        // Save custom equipment type if needed
        await _saveCustomEquipmentType(equipmentType);

        final sale = await widget.rentalService.sellEquipment(
          ambulanceId: widget.ambulanceId,
          equipmentType: equipmentType,
          ambulancierName: _ambulancierName,
          saleDate: _saleDate,
          cost: _cost,
          notes: _notes.isEmpty ? null : _notes,
          patientName: _patientName.isEmpty ? null : _patientName,
          patientAddress: _patientAddress.isEmpty ? null : _patientAddress,
          patientPhoneNumber: _patientPhoneNumber.isEmpty
              ? null
              : _patientPhoneNumber,
          quantity: _quantity,
        );

        if (mounted) {
          widget.onEquipmentSold(sale);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyEquipmentError(e)),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentTypeOptions = _buildEquipmentTypeOptions(
      stockTypes: _stockEquipmentTypes,
      fallbackTypes: widget.equipmentTypes,
    );

    return AlertDialog(
      title: const Text('Vendre Équipement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equipment selection
              DropdownButtonFormField<String>(
                value: _selectedEquipment,
                decoration: InputDecoration(
                  labelText: 'Type d\'Équipement',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: equipmentTypeOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: !_isLoading
                    ? (value) {
                        setState(() {
                          _selectedEquipment = value;
                        });
                        _refreshAvailableStockForSelection();
                      }
                    : null,
                validator: (value) =>
                    value == null ? 'Sélectionnez un équipement' : null,
              ),
              if (_inventoryByEquipmentType.isNotEmpty &&
                  _selectedEquipment != null &&
                  _selectedEquipment != 'Autre')
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Stock disponible: ${_availableStockForSelection()}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                ),
              if (_isRefreshingAvailableStock)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 12),

              // Custom equipment if "Autre" selected
              if (_selectedEquipment == 'Autre')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    initialValue: _customEquipment,
                    decoration: InputDecoration(
                      labelText: 'Spécifiez l\'équipement',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    enabled: !_isLoading,
                    onChanged: (value) {
                      setState(() => _customEquipment = value);
                      _refreshAvailableStockForSelection();
                    },
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Entrez le type' : null,
                  ),
                ),

              // Ambulancier name
              TextFormField(
                controller: _ambulancierController,
                decoration: InputDecoration(
                  labelText: 'Nom du Vendeur',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez le nom du conducteur/staff',
                ),
                readOnly: true,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Entrez le nom du vendeur' : null,
              ),
              if (widget.companyStaff.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.companyStaff
                      .map(
                        (member) => FilterChip(
                          label: Text(member.name),
                          selected: _selectedTeammateIds.contains(member.id),
                          onSelected: !_isLoading
                              ? (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTeammateIds.add(member.id);
                                    } else {
                                      _selectedTeammateIds.remove(member.id);
                                    }
                                    _updateAmbulancierName();
                                  });
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),

              // Patient name
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nom du Client (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez le nom du client',
                ),
                enabled: !_isLoading,
                onChanged: (value) => setState(() => _patientName = value),
              ),
              const SizedBox(height: 12),

              // Patient address
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Adresse du Client (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Entrez l\'adresse du client',
                ),
                enabled: !_isLoading,
                maxLines: 2,
                onChanged: (value) => setState(() => _patientAddress = value),
              ),
              const SizedBox(height: 12),

              // Patient phone number
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Numéro Téléphone Client (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '+216 XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone),
                ),
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                onChanged: (value) =>
                    setState(() => _patientPhoneNumber = value),
              ),
              const SizedBox(height: 12),

              // Sale date
              TextFormField(
                controller: _saleDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date de Vente',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_saleDate),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final formattedDate = picked.toString().split(' ')[0];
                    setState(() {
                      _saleDate = formattedDate;
                      _saleDateController.text = _saleDate;
                    });
                  }
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Sélectionnez une date' : null,
              ),
              const SizedBox(height: 12),

              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '1',
                ),
                enabled: !_isLoading,
                onChanged: (value) =>
                    setState(() => _quantity = int.tryParse(value) ?? 1),
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  if (qty == null || qty < 1) {
                    return 'La quantité doit être au moins 1';
                  }
                  if (_inventoryByEquipmentType.isNotEmpty &&
                      qty > _availableStockForSelection()) {
                    return 'Stock insuffisant';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Cost
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Montant de Vente (TND)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                enabled: !_isLoading,
                onChanged: (value) =>
                    setState(() => _cost = double.tryParse(value) ?? 0.0),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Entrez un montant valide'
                    : null,
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Détails de la vente, conditions, etc.',
                ),
                enabled: !_isLoading,
                onChanged: (value) => setState(() => _notes = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Vendre'),
        ),
      ],
    );
  }
}

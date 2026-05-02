import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equipment_rental_model.dart';
import '../models/user_model.dart';
import '../services/equipment_rental_service.dart';
import '../services/api_client.dart';
import '../config/constants.dart';

// Base equipment types
const List<String> baseEquipmentTypes = [
  'Oxygéne',
  'Autre',
];

class ManagerEquipmentRentalsScreen extends StatefulWidget {
  final User user;

  const ManagerEquipmentRentalsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerEquipmentRentalsScreen> createState() =>
      _ManagerEquipmentRentalsScreenState();
}

class _ManagerEquipmentRentalsScreenState
    extends State<ManagerEquipmentRentalsScreen> {
  late EquipmentRentalService _rentalService;
  List<EquipmentRental> _allRentals = [];
  bool _isLoading = true;
  List<String> _allEquipmentTypes = [...baseEquipmentTypes];
  String _filterStatus = 'all'; // all, active, returned
  int _totalOxygenBottles = 0; // Total oxygen bottles in inventory

  @override
  void initState() {
    super.initState();
    _rentalService = EquipmentRentalService();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCustomEquipmentTypes();
    await _loadOxygenBottlesInventory();
    await _loadAllRentals();
  }

  Future<void> _loadOxygenBottlesInventory() async {
    try {
      final total = await _rentalService.getOxygenInventoryCount();
      if (mounted) {
        setState(() {
          _totalOxygenBottles = total;
        });
      }
    } catch (e) {
      debugPrint('Error loading oxygen bottles inventory: $e');
      if (mounted) {
        setState(() {
          _totalOxygenBottles = 0;
        });
      }
    }
  }

  Future<void> _setOxygenBottlesInventory(int quantity) async {
    try {
      // Get existing inventory record from Supabase
      await _rentalService.setOxygenInventoryCount(quantity);
      /*

      */
      /*
      if (mounted) {
          {
            'metadata': 'oxygen_inventory',
            'equipment_type': 'Oxygène (Inventaire)',
            'ambulance_id': null,
            'quantity': quantity,
            'rent_date': DateTime.now().toString().split(' ')[0],
            'is_returned': true,
            'cost': 0,
          },
        );
      }
      */

      if (mounted) {
        setState(() {
          _totalOxygenBottles = quantity;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventaire défini: $quantity bouteilles d\'oxygène'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSetInventoryDialog() {
    final inventoryCtrl =
        TextEditingController(text: _totalOxygenBottles.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Définir Inventaire Oxygène'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nombre total de bouteilles d\'oxygène en stock:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: inventoryCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre de bouteilles',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(inventoryCtrl.text) ?? 0;
              if (qty >= 0) {
                _setOxygenBottlesInventory(qty);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCustomEquipmentTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customTypes = prefs.getStringList('custom_equipment_types') ?? [];
      if (mounted) {
        setState(() {
          _allEquipmentTypes = [
            ...baseEquipmentTypes,
            ...customTypes,
          ];
        });
      }
    } catch (e) {
      debugPrint('Error loading custom equipment types: $e');
    }
  }

  Future<void> _loadAllRentals() async {
    try {
      final rentals = await _rentalService.getTenantEquipmentRentals();
      if (mounted) {
        setState(() {
          _allRentals = [...rentals];
          _allRentals.sort(
              (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
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

  List<EquipmentRental> _getFilteredRentals() {
    switch (_filterStatus) {
      case 'active':
        return _allRentals
            .where((r) =>
                r.isReturned == false &&
                !(r.returnDate != null &&
                    r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0]))
            .toList();
      case 'returned':
        return _allRentals
            .where((r) =>
                r.isReturned == true &&
                !(r.returnDate != null &&
                    r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0]))
            .toList();
      case 'sold':
        return _allRentals
            .where((r) =>
                r.returnDate != null &&
                r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0])
            .toList();
      default:
        return _allRentals;
    }
  }

  void _showEditRentalDialog(EquipmentRental rental) {
    final ambulancierCtrl =
        TextEditingController(text: rental.ambulancierName ?? '');
    final patientNameCtrl =
        TextEditingController(text: rental.patientName ?? '');
    final patientAddressCtrl =
        TextEditingController(text: rental.patientAddress ?? '');
    final patientPhoneCtrl =
        TextEditingController(text: rental.patientPhoneNumber ?? '');
    final costCtrl = TextEditingController(text: rental.cost.toString());
    final notesCtrl = TextEditingController(text: rental.notes ?? '');
    final returnDateCtrl =
        TextEditingController(text: rental.returnDate?.split(' ')[0] ?? '');

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
                'Ambulance: ${rental.ambulanceId}\nÉquipement: ${rental.equipmentType}',
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

              // Cost
              TextFormField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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

                  _loadAllRentals();
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
    final returnDateCtrl =
        TextEditingController(text: rental.returnDate?.split(' ')[0] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier Date de Retour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ambulance: ${rental.ambulanceId}\nÉquipement: ${rental.equipmentType}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
                await _rentalService.updateReturnDate(
                    rental.id, returnDateCtrl.text);

                if (mounted) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Date mise à jour: ${returnDateCtrl.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  _loadAllRentals();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredRentals = _getFilteredRentals();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Oxygen bottles inventory button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSetInventoryDialog,
              icon: const Icon(Icons.inventory_2),
              label: Text(
                'Inventaire Oxygène: $_totalOxygenBottles bouteilles',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Équipements en Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterButton('En Location', 'active'),
                const SizedBox(width: 8),
                _buildFilterButton('Retournés', 'returned'),
                const SizedBox(width: 8),
                _buildFilterButton('Vendus', 'sold'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Actives',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == false).length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Retournées',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == true).length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Performance Section
          _buildPerformancePanel(),
          const SizedBox(height: 20),

          // Rentals list or empty state
          if (filteredRentals.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterStatus == 'all'
                        ? 'Aucun équipement en location'
                        : 'Aucun équipement $_filterStatus',
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
              itemCount: filteredRentals.length,
              itemBuilder: (context, index) {
                final rental = filteredRentals[index];
                return _buildRentalCard(rental);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isActive = _filterStatus == value;
    return ElevatedButton(
      onPressed: () => setState(() => _filterStatus = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? AppColors.primary : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.grey[700],
        elevation: isActive ? 2 : 0,
      ),
      child: Text(label),
    );
  }

  Widget _buildRentalCard(EquipmentRental rental) {
    final isReturned = rental.isReturned ?? false;
    final isSold = rental.returnDate != null &&
        rental.returnDate!.split(' ')[0] == rental.rentDate.split(' ')[0];
    final rentDateFormatted = rental.rentDate.split(' ')[0];
    final returnDateFormatted = rental.returnDate?.split(' ')[0] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equipment type and status
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
                            horizontal: 8, vertical: 4),
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
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(rental),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ambulance and Ambulancier
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ambulance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rental.ambulanceId,
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
                        'Ambulancier',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rental.ambulancierName ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Patient info (name and address)
            if (rental.patientName != null ||
                rental.patientAddress != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rental.patientName != null &&
                      rental.patientName!.isNotEmpty) ...[
                    const Text(
                      'Patient',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rental.patientName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (rental.patientAddress != null &&
                      rental.patientAddress!.isNotEmpty) ...[
                    const Text(
                      'Adresse du Patient',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.redAccent),
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
                    const SizedBox(height: 8),
                  ],
                  if (rental.patientPhoneNumber != null &&
                      rental.patientPhoneNumber!.isNotEmpty) ...[
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(EquipmentRental rental) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir supprimer cette location?'),
            const SizedBox(height: 12),
            Text(
              'Équipement: ${rental.equipmentType}\nAmbulance: ${rental.ambulanceId}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
                await _rentalService.deleteRental(rental.id);

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Location supprimée'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  _loadAllRentals();
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformancePanel() {
    // Exclude inventory records (metadata field is not null)
    final rentalsOnly = _allRentals
        .where((r) => r.metadata == null || r.metadata!.isEmpty)
        .toList();

    final totalCost = rentalsOnly.fold<double>(0, (sum, r) => sum + r.cost);
    final soldCount = rentalsOnly
        .where((r) => r.transactionType == 'sale')
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final activeCount = rentalsOnly
        .where((r) => r.transactionType == 'rental' && r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final returnedCount = rentalsOnly
        .where((r) => r.transactionType == 'rental' && r.isReturned == true)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final averageCost =
        rentalsOnly.isNotEmpty ? totalCost / rentalsOnly.length : 0.0;

    // Calculate oxygen bottles rented and remaining
    final oxygenRented = rentalsOnly
        .where((r) =>
            (r.equipmentType.toLowerCase().contains('oxy')) &&
            r.transactionType == 'rental' &&
            r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final oxygenRemaining =
        _totalOxygenBottles > 0 ? _totalOxygenBottles - oxygenRented : 0;

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
            'PERFORMANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildPerformanceStat(
                'Revenu Total',
                '${totalCost.toStringAsFixed(2)} TND',
                Colors.green,
                Icons.monetization_on,
              ),
              _buildPerformanceStat(
                'Coût Moyen',
                '${averageCost.toStringAsFixed(2)} TND',
                Colors.blue,
                Icons.trending_up,
              ),
              _buildPerformanceStat(
                'En Location',
                activeCount.toString(),
                Colors.orange,
                Icons.local_shipping,
              ),
              _buildPerformanceStat(
                'Vendus',
                soldCount.toString(),
                Colors.orange,
                Icons.sell,
              ),
              _buildPerformanceStat(
                'Oxygène Loué',
                oxygenRented.toString(),
                Colors.red,
                Icons.local_fire_department,
              ),
              _buildPerformanceStat(
                'Oxygène Restant',
                oxygenRemaining.toString(),
                oxygenRemaining > 0 ? Colors.green : Colors.red,
                Icons.science,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Content class for dashboard integration
class ManagerEquipmentRentalScreenContent extends StatefulWidget {
  final User user;

  const ManagerEquipmentRentalScreenContent({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ManagerEquipmentRentalScreenContent> createState() =>
      _ManagerEquipmentRentalScreenContentState();
}

class _ManagerEquipmentRentalScreenContentState
    extends State<ManagerEquipmentRentalScreenContent>
    with WidgetsBindingObserver {
  late EquipmentRentalService _rentalService;
  late ApiClient _apiClient;
  List<EquipmentRental> _allRentals = [];
  bool _isLoading = true;
  List<String> _allEquipmentTypes = [...baseEquipmentTypes];
  String _filterStatus = 'all';
  int _totalOxygenBottles = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rentalService = EquipmentRentalService();
    _apiClient = ApiClient();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '[ManagerEquipmentRentalScreenContent] Post-frame callback: loading rentals');
      _loadData();
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
          '[ManagerEquipmentRentalScreenContent] App resumed, reloading rentals...');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await _loadCustomEquipmentTypes();
    await _loadAllRentals();
    await _loadOxygenBottlesInventory();
  }

  Future<void> _loadCustomEquipmentTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customTypes = prefs.getStringList('custom_equipment_types') ?? [];
      if (mounted) {
        setState(() {
          _allEquipmentTypes = [
            ...baseEquipmentTypes,
            ...customTypes,
          ];
        });
      }
    } catch (e) {
      debugPrint('Error loading custom equipment types: $e');
    }
  }

  Future<void> _loadAllRentals() async {
    try {
      final rentals = await _rentalService.getTenantEquipmentRentals();
      if (mounted) {
        setState(() {
          _allRentals = [...rentals];
          _allRentals.sort(
              (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading equipment rentals: $e');
    }
  }

  Future<void> _loadOxygenBottlesInventory() async {
    try {
      final total = await _rentalService.getOxygenInventoryCount();
      if (mounted) {
        setState(() {
          _totalOxygenBottles = total;
        });
      }
    } catch (e) {
      debugPrint('Error loading oxygen bottles inventory: $e');
      if (mounted) {
        setState(() {
          _totalOxygenBottles = 0;
        });
      }
    }
  }

  Future<void> _setOxygenBottlesInventory(int quantity) async {
    try {
      // Get existing inventory record from Supabase
      final response = await _apiClient.get(
        '${SupabaseConfig.equipmentRentalsTable}?metadata=eq.oxygen_inventory',
      );

      if (response.isNotEmpty) {
        // Update existing
        final recordId = response.first['id'];
        await _apiClient.patch(
          '${SupabaseConfig.equipmentRentalsTable}?id=eq.$recordId',
          {'quantity': quantity},
        );
      } else {
        // Create new inventory record
        await _apiClient.post(
          SupabaseConfig.equipmentRentalsTable,
          {
            'metadata': 'oxygen_inventory',
            'equipment_type': 'Oxygène (Inventaire)',
            'ambulance_id': null,
            'quantity': quantity,
            'rent_date': DateTime.now().toString().split(' ')[0],
            'is_returned': true,
            'cost': 0,
          },
        );
      }

      if (mounted) {
        setState(() {
          _totalOxygenBottles = quantity;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventaire défini: $quantity bouteilles d\'oxygène'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSetInventoryDialog() {
    final inventoryCtrl =
        TextEditingController(text: _totalOxygenBottles.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Définir Inventaire Oxygène'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nombre total de bouteilles d\'oxygène en stock:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: inventoryCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre de bouteilles',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(inventoryCtrl.text) ?? 0;
              if (qty >= 0) {
                _setOxygenBottlesInventory(qty);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  List<EquipmentRental> _getFilteredRentals() {
    switch (_filterStatus) {
      case 'active':
        return _allRentals
            .where((r) =>
                r.isReturned == false &&
                !(r.returnDate != null &&
                    r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0]))
            .toList();
      case 'returned':
        return _allRentals
            .where((r) =>
                r.isReturned == true &&
                !(r.returnDate != null &&
                    r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0]))
            .toList();
      case 'sold':
        return _allRentals
            .where((r) =>
                r.returnDate != null &&
                r.returnDate!.split(' ')[0] == r.rentDate.split(' ')[0])
            .toList();
      default:
        return _allRentals;
    }
  }

  void _showEditReturnDateDialog(EquipmentRental rental) {
    final returnDateCtrl =
        TextEditingController(text: rental.returnDate?.split(' ')[0] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier Date de Retour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ambulance: ${rental.ambulanceId}\nÉquipement: ${rental.equipmentType}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
                await _rentalService.updateReturnDate(
                    rental.id, returnDateCtrl.text);

                if (mounted) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Date mise à jour: ${returnDateCtrl.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  _loadAllRentals();
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

  void _showEditRentalDialog(EquipmentRental rental) {
    final ambulancierCtrl =
        TextEditingController(text: rental.ambulancierName ?? '');
    final patientNameCtrl =
        TextEditingController(text: rental.patientName ?? '');
    final patientAddressCtrl =
        TextEditingController(text: rental.patientAddress ?? '');
    final patientPhoneCtrl =
        TextEditingController(text: rental.patientPhoneNumber ?? '');
    final costCtrl = TextEditingController(text: rental.cost.toString());
    final notesCtrl = TextEditingController(text: rental.notes ?? '');
    final returnDateCtrl =
        TextEditingController(text: rental.returnDate?.split(' ')[0] ?? '');

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
                'Ambulance: ${rental.ambulanceId}\nÉquipement: ${rental.equipmentType}',
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

              // Patient phone number
              TextFormField(
                controller: patientPhoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Numéro Téléphone Patient (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '+216 XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
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

              // Cost
              TextFormField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                  patientPhoneNumber: patientPhoneCtrl.text.isEmpty
                      ? null
                      : patientPhoneCtrl.text,
                  returnDate: returnDateCtrl.text,
                  cost: double.tryParse(costCtrl.text) ?? rental.cost,
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

                  _loadAllRentals();
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

  void _showDeleteConfirmDialog(EquipmentRental rental) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir supprimer cette location?'),
            const SizedBox(height: 12),
            Text(
              'Équipement: ${rental.equipmentType}\nAmbulance: ${rental.ambulanceId}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
                await _apiClient.delete(
                    SupabaseConfig.equipmentRentalsTable, rental.id);

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Location supprimée'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  _loadAllRentals();
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredRentals = _getFilteredRentals();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Oxygen bottles inventory button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSetInventoryDialog,
              icon: const Icon(Icons.inventory_2),
              label: Text(
                'Inventaire Oxygène: $_totalOxygenBottles bouteilles',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterButton('En Location', 'active'),
                const SizedBox(width: 8),
                _buildFilterButton('Retournés', 'returned'),
                const SizedBox(width: 8),
                _buildFilterButton('Vendus', 'sold'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Actives',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == false).length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Retournées',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == true).length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Performance Section
          _buildPerformancePanel(),
          const SizedBox(height: 20),

          // Rentals list or empty state
          if (filteredRentals.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterStatus == 'all'
                        ? 'Aucun équipement en location'
                        : 'Aucun équipement $_filterStatus',
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
              itemCount: filteredRentals.length,
              itemBuilder: (context, index) {
                final rental = filteredRentals[index];
                return _buildRentalCard(rental);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPerformancePanel() {
    // Exclude inventory records (metadata field is not null)
    final rentalsOnly = _allRentals
        .where((r) => r.metadata == null || r.metadata!.isEmpty)
        .toList();

    final totalCost = rentalsOnly.fold<double>(0, (sum, r) => sum + r.cost);
    final soldCount = rentalsOnly
        .where((r) => r.transactionType == 'sale')
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final activeCount = rentalsOnly
        .where((r) => r.transactionType == 'rental' && r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final returnedCount = rentalsOnly
        .where((r) => r.transactionType == 'rental' && r.isReturned == true)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final averageCost =
        rentalsOnly.isNotEmpty ? totalCost / rentalsOnly.length : 0.0;

    // Calculate oxygen bottles rented and remaining
    final oxygenRented = rentalsOnly
        .where((r) =>
            (r.equipmentType.toLowerCase().contains('oxy')) &&
            r.transactionType == 'rental' &&
            r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final oxygenRemaining =
        _totalOxygenBottles > 0 ? _totalOxygenBottles - oxygenRented : 0;

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
            'PERFORMANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildPerformanceStat(
                'Revenu Total',
                '${totalCost.toStringAsFixed(2)} TND',
                Colors.green,
                Icons.monetization_on,
              ),
              _buildPerformanceStat(
                'Coût Moyen',
                '${averageCost.toStringAsFixed(2)} TND',
                Colors.blue,
                Icons.trending_up,
              ),
              _buildPerformanceStat(
                'En Location',
                activeCount.toString(),
                Colors.orange,
                Icons.local_shipping,
              ),
              _buildPerformanceStat(
                'Vendus',
                soldCount.toString(),
                Colors.orange,
                Icons.sell,
              ),
              _buildPerformanceStat(
                'Oxygène Loué',
                oxygenRented.toString(),
                Colors.red,
                Icons.local_fire_department,
              ),
              _buildPerformanceStat(
                'Oxygène Restant',
                oxygenRemaining.toString(),
                oxygenRemaining > 0 ? Colors.green : Colors.red,
                Icons.science,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isActive = _filterStatus == value;
    return ElevatedButton(
      onPressed: () => setState(() => _filterStatus = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? AppColors.primary : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.grey[700],
        elevation: isActive ? 2 : 0,
      ),
      child: Text(label),
    );
  }

  Widget _buildRentalCard(EquipmentRental rental) {
    final isReturned = rental.isReturned ?? false;
    final isSold = rental.returnDate != null &&
        rental.returnDate!.split(' ')[0] == rental.rentDate.split(' ')[0];
    final rentDateFormatted = rental.rentDate.split(' ')[0];
    final returnDateFormatted = rental.returnDate?.split(' ')[0] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equipment type and status
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
                            horizontal: 8, vertical: 4),
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
                    ],
                  ),
                ),
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
                IconButton(
                  onPressed: () => _showEditRentalDialog(rental),
                  icon: const Icon(Icons.edit_note, color: Colors.blue),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(rental),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Patient Information
            if (rental.patientName != null ||
                rental.patientAddress != null ||
                rental.patientPhoneNumber != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rental.patientName != null &&
                      rental.patientName!.isNotEmpty) ...[
                    const Text(
                      'Patient',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rental.patientName!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (rental.patientAddress != null &&
                      rental.patientAddress!.isNotEmpty) ...[
                    const Text(
                      'Adresse du Patient',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
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
                    const SizedBox(height: 8),
                  ],
                  if (rental.patientPhoneNumber != null &&
                      rental.patientPhoneNumber!.isNotEmpty) ...[
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Ambulance and Ambulancier
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ambulance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rental.ambulanceId,
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

            // Cost display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 12),

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
                      Row(
                        children: [
                          const Text(
                            'Date de Retour',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (!isReturned)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: GestureDetector(
                                onTap: () => _showEditReturnDateDialog(rental),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

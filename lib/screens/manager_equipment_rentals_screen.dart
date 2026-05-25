import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ambulance_model.dart';
import '../models/equipment_rental_model.dart';
import '../models/user_model.dart';
import '../services/equipment_rental_service.dart';
import '../services/api_client.dart';
import '../services/resume_refresh_service.dart';
import '../config/constants.dart';
import './equipment_rental_screen.dart'
    show AddEquipmentRentalDialog, SellEquipmentDialog;

// Base equipment types
const List<String> baseEquipmentTypes = ['Oxygéne', 'Autre'];

class ManagerEquipmentRentalsScreen extends StatefulWidget {
  final User user;

  const ManagerEquipmentRentalsScreen({Key? key, required this.user})
    : super(key: key);

  @override
  State<ManagerEquipmentRentalsScreen> createState() =>
      _ManagerEquipmentRentalsScreenState();
}

class _ManagerEquipmentRentalsScreenState
    extends State<ManagerEquipmentRentalsScreen> {
  late EquipmentRentalService _rentalService;
  final _apiClient = ApiClient();
  List<EquipmentRental> _allRentals = [];
  bool _isLoading = true;
  List<String> _allEquipmentTypes = [...baseEquipmentTypes];
  String _filterStatus = 'all'; // all, active, returned
  String _statsEquipmentType = 'all';
  Map<String, int> _inventoryByEquipmentType = {};
  int _totalOxygenBottles = 0; // Total oxygen bottles in inventory
  Map<String, String> _ambulanceNamesById = {};

  bool get _canSeeMoneySections {
    final role = widget.user.role?.trim().toLowerCase();
    return role == 'owner' || role == 'admin' || role == 'super_admin';
  }

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
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCustomEquipmentTypes();
    await _getTenantAmbulances();
    await _loadEquipmentInventories();
    await _loadAllRentals();
  }

  Future<List<Ambulance>> _getTenantAmbulances() async {
    final response = await _apiClient.get(SupabaseConfig.ambulancesTable);
    final ambulances = response
        .map((json) => Ambulance.fromJson(json))
        .toList();
    if (mounted) {
      setState(() {
        _ambulanceNamesById = {
          for (final ambulance in ambulances)
            ambulance.id: ambulance.ambulanceNumber,
        };
      });
    }
    return ambulances;
  }

  String _ambulanceLabel(String ambulanceId) =>
      _ambulanceNamesById[ambulanceId] ?? ambulanceId;

  bool _isSale(EquipmentRental rental) =>
      rental.transactionType.trim().toLowerCase() == 'sale';

  Future<void> _showAmbulancePickerDialog({required bool isSale}) async {
    try {
      final ambulances = await _getTenantAmbulances();
      if (!mounted) return;

      if (ambulances.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune ambulance disponible pour cet équipement'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(
            isSale
                ? 'Choisir une ambulance pour la vente'
                : 'Choisir une ambulance',
          ),
          children: ambulances
              .map(
                (ambulance) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (isSale) {
                      _showSellEquipmentDialog(ambulance);
                    } else {
                      _showAddEquipmentDialog(ambulance);
                    }
                  },
                  child: Text(ambulance.ambulanceNumber),
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEquipmentDialog(Ambulance ambulance) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddEquipmentRentalDialog(
        ambulanceId: ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: const [],
        onRentalAdded: (_) async {
          Navigator.pop(dialogContext);
          if (!mounted) return;
          setState(() => _isLoading = true);
          await _loadData();
        },
      ),
    );
  }

  void _showSellEquipmentDialog(Ambulance ambulance) {
    showDialog(
      context: context,
      builder: (dialogContext) => SellEquipmentDialog(
        ambulanceId: ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: const [],
        onEquipmentSold: (_) async {
          Navigator.pop(dialogContext);
          if (!mounted) return;
          setState(() => _isLoading = true);
          await _loadData();
        },
      ),
    );
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
      await _rentalService.setOxygenInventoryCount(quantity);
      if (mounted) {
        setState(() => _totalOxygenBottles = quantity);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inventaire oxygene mis a jour: $quantity bouteilles',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadOxygenBottlesInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise a jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSetInventoryDialog() {
    final inventoryCtrl = TextEditingController(
      text: _totalOxygenBottles.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Définir Inventaire Oxygene'),
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

  Future<void> _persistCustomEquipmentTypes(List<String> equipmentTypes) async {
    final prefs = await SharedPreferences.getInstance();
    final customTypes =
        equipmentTypes
            .map((type) => _canonicalEquipmentType(type))
            .where(
              (type) =>
                  !baseEquipmentTypes.contains(type) &&
                  !_isPlaceholderEquipmentType(type),
            )
            .toSet()
            .toList()
          ..sort();
    await prefs.setStringList(_equipmentTypesPrefsKey, customTypes);
  }

  Future<void> _loadEquipmentInventories() async {
    try {
      final inventories = await _rentalService.getEquipmentInventories();
      if (mounted) {
        setState(() {
          _inventoryByEquipmentType = inventories;
          _totalOxygenBottles =
              inventories['Oxygene'] ?? inventories['Oxygene'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading equipment inventories: $e');
      if (mounted) {
        setState(() {
          _inventoryByEquipmentType = {};
          _totalOxygenBottles = 0;
        });
      }
    }
  }

  Future<void> _loadAllRentals() async {
    try {
      final rentals = await _rentalService.getTenantEquipmentRentals();
      if (mounted) {
        setState(() {
          _allRentals = [...rentals];
          _allRentals.sort(
            (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''),
          );
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
            .where((r) => r.isReturned == false && !_isSale(r))
            .toList();
      case 'returned':
        return _allRentals
            .where((r) => r.isReturned == true && !_isSale(r))
            .toList();
      case 'sold':
        return _allRentals.where((r) => _isSale(r)).toList();
      default:
        return _allRentals;
    }
  }

  String _normalizeEquipmentType(String value) => value.trim().toLowerCase();

  bool _isInventoryEquipmentType(String value) =>
      _normalizeEquipmentType(value).contains('invent');

  bool _isPlaceholderEquipmentType(String value) {
    final normalized = _normalizeEquipmentType(value);
    return normalized == 'autre' || normalized == 'other';
  }

  bool _isOxygenEquipmentType(String value) =>
      _normalizeEquipmentType(value).contains('oxy');

  String _canonicalEquipmentType(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Equipement';
    if (_isOxygenEquipmentType(trimmed)) return 'Oxygene';
    return trimmed;
  }

  String _selectedInventoryTypeLabel() =>
      _statsEquipmentType == 'all' ? 'Stock' : _statsEquipmentType;

  int _selectedInventoryQuantity() {
    if (_statsEquipmentType == 'all') {
      return _inventoryByEquipmentType.values.fold<int>(
        0,
        (sum, qty) => sum + qty,
      );
    }

    if (_isOxygenEquipmentType(_statsEquipmentType)) {
      return _inventoryByEquipmentType['Oxygene'] ?? 0;
    }

    return _inventoryByEquipmentType[_statsEquipmentType] ?? 0;
  }

  List<String> _getStatsEquipmentTypes() {
    final uniqueTypes = <String>{};

    for (final type in _allEquipmentTypes) {
      final trimmed = type.trim();
      if (trimmed.isEmpty ||
          _isInventoryEquipmentType(trimmed) ||
          _isPlaceholderEquipmentType(trimmed)) {
        continue;
      }
      if (_isOxygenEquipmentType(trimmed)) {
        uniqueTypes.add('Oxygene');
      } else {
        uniqueTypes.add(trimmed);
      }
    }

    for (final rental in _allRentals) {
      final trimmed = rental.equipmentType.trim();
      if (trimmed.isEmpty ||
          _isInventoryEquipmentType(trimmed) ||
          _isPlaceholderEquipmentType(trimmed)) {
        continue;
      }
      if (_isOxygenEquipmentType(trimmed)) {
        uniqueTypes.add('Oxygene');
      } else {
        uniqueTypes.add(trimmed);
      }
    }

    final sortedTypes = uniqueTypes.toList()..sort();
    return ['all', ...sortedTypes];
  }

  List<EquipmentRental> _getStatsRentals() {
    final rentalsOnly = _allRentals
        .where((r) => r.metadata == null || r.metadata!.isEmpty)
        .toList();

    if (_statsEquipmentType == 'all') {
      return rentalsOnly;
    }

    if (_isOxygenEquipmentType(_statsEquipmentType)) {
      return rentalsOnly
          .where((r) => _isOxygenEquipmentType(r.equipmentType))
          .toList();
    }

    final selectedType = _normalizeEquipmentType(_statsEquipmentType);
    return rentalsOnly
        .where((r) => _normalizeEquipmentType(r.equipmentType) == selectedType)
        .toList();
  }

  void _showDynamicInventoryDialog() {
    _showSetInventoryDialog();
  }

  void _showEditRentalDialog(EquipmentRental rental) {
    final ambulancierCtrl = TextEditingController(
      text: rental.ambulancierName ?? '',
    );
    final patientNameCtrl = TextEditingController(
      text: rental.patientName ?? '',
    );
    final patientAddressCtrl = TextEditingController(
      text: rental.patientAddress ?? '',
    );
    final patientPhoneCtrl = TextEditingController(
      text: rental.patientPhoneNumber ?? '',
    );
    final costCtrl = TextEditingController(text: rental.cost.toString());
    final notesCtrl = TextEditingController(text: rental.notes ?? '');
    final returnDateCtrl = TextEditingController(
      text: rental.returnDate?.split(' ')[0] ?? '',
    );
    final isSold = _isSale(rental);

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
                'Ambulance: ${_ambulanceLabel(rental.ambulanceId)}\nÉquipement: ${rental.equipmentType}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
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
                  returnDate: isSold ? rental.returnDate : returnDateCtrl.text,
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
              'Ambulance: ${_ambulanceLabel(rental.ambulanceId)}\nÉquipement: ${rental.equipmentType}',
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
                  rental.id,
                  returnDateCtrl.text,
                );

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
              onPressed: _showDynamicInventoryDialog,
              icon: const Icon(Icons.inventory_2),
              label: Text(
                'Inventaire: ${_inventoryByEquipmentType.length} types',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAmbulancePickerDialog(isSale: false),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Ajouter equipement'),
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
                  onPressed: () => _showAmbulancePickerDialog(isSale: true),
                  icon: const Icon(Icons.sell),
                  label: const Text('Vendre equipement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Équipements en Location',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                    const Text(
                      'Actives',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == false && !_isSale(r)).length}',
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
                    const Text(
                      'Retournées',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == true && !_isSale(r)).length}',
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

          if (_canSeeMoneySections) ...[
            _buildDynamicPerformancePanel(),
            const SizedBox(height: 20),
          ],

          // Rentals list or empty state
          if (filteredRentals.isEmpty)
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
    final isSold = _isSale(rental);
    final rentDateFormatted = rental.rentDate.split(' ')[0];
    final returnDateFormatted = rental.returnDate?.split(' ')[0] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
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
                      Text(
                        'Quantite: ${rental.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
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
                        _ambulanceLabel(rental.ambulanceId),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
              'Équipement: ${rental.equipmentType}\nAmbulance: ${_ambulanceLabel(rental.ambulanceId)}',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformancePanel() {
    final rentalsOnly = _getStatsRentals();
    final equipmentTypeOptions = _getStatsEquipmentTypes();

    final totalCost = rentalsOnly.fold<double>(0, (sum, r) => sum + r.cost);
    final soldItems = rentalsOnly.where((r) => _isSale(r)).toList();
    final rentedItems = rentalsOnly
        .where((r) => !_isSale(r) && r.transactionType == 'rental')
        .toList();
    final soldCount = soldItems.fold<int>(0, (sum, r) => sum + r.quantity);
    final activeCount = rentedItems
        .where((r) => r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final returnedCount = rentedItems
        .where((r) => r.isReturned == true)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final totalQuantity = rentalsOnly.fold<int>(
      0,
      (sum, r) => sum + r.quantity,
    );

    double averageCostFor(List<EquipmentRental> items) {
      final totalQuantity = items.fold<int>(0, (sum, r) => sum + r.quantity);
      final totalAmount = items.fold<double>(0, (sum, r) => sum + r.cost);
      return totalQuantity > 0 ? totalAmount / totalQuantity : 0.0;
    }

    final rentedAverageCost = averageCostFor(rentedItems);
    final soldAverageCost = averageCostFor(soldItems);
    final selectedInventoryQuantity = _selectedInventoryQuantity();
    final selectedRentedQuantity = activeCount;
    final selectedRemainingQuantity =
        (selectedInventoryQuantity - selectedRentedQuantity) < 0
        ? 0
        : (selectedInventoryQuantity - selectedRentedQuantity);

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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: equipmentTypeOptions.contains(_statsEquipmentType)
                ? _statsEquipmentType
                : 'all',
            decoration: InputDecoration(
              labelText: 'Type d\'équipement',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: equipmentTypeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type == 'all' ? 'Tous les équipements' : type),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _statsEquipmentType = value);
            },
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
                'Loc: ${rentedAverageCost.toStringAsFixed(2)} TND\nVendu: ${soldAverageCost.toStringAsFixed(2)} TND',
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
                '${_selectedInventoryTypeLabel()} Loué',
                selectedRentedQuantity.toString(),
                Colors.red,
                Icons.local_fire_department,
              ),
              _buildPerformanceStat(
                '${_selectedInventoryTypeLabel()} Restant',
                selectedRemainingQuantity.toString(),
                selectedRemainingQuantity > 0 ? Colors.green : Colors.red,
                Icons.science,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPerformancePanel() {
    final rentalsOnly = _getStatsRentals();
    final equipmentTypeOptions = _getStatsEquipmentTypes();

    final totalCost = rentalsOnly.fold<double>(0, (sum, r) => sum + r.cost);
    final soldItems = rentalsOnly.where((r) => _isSale(r)).toList();
    final rentedItems = rentalsOnly
        .where((r) => !_isSale(r) && r.transactionType == 'rental')
        .toList();
    final soldCount = soldItems.fold<int>(0, (sum, r) => sum + r.quantity);
    final activeCount = rentedItems
        .where((r) => r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final returnedCount = rentedItems
        .where((r) => r.isReturned == true)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final totalQuantity = rentalsOnly.fold<int>(
      0,
      (sum, r) => sum + r.quantity,
    );

    double averageCostFor(List<EquipmentRental> items) {
      final quantity = items.fold<int>(0, (sum, r) => sum + r.quantity);
      final amount = items.fold<double>(0, (sum, r) => sum + r.cost);
      return quantity > 0 ? amount / quantity : 0.0;
    }

    final rentedAverageCost = averageCostFor(rentedItems);
    final soldAverageCost = averageCostFor(soldItems);
    final selectedInventoryQuantity = _selectedInventoryQuantity();
    final selectedRentedQuantity = activeCount;
    final selectedRemainingQuantity =
        (selectedInventoryQuantity - selectedRentedQuantity) < 0
        ? 0
        : (selectedInventoryQuantity - selectedRentedQuantity);

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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: equipmentTypeOptions.contains(_statsEquipmentType)
                ? _statsEquipmentType
                : 'all',
            decoration: InputDecoration(
              labelText: 'Type d\'équipement',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: equipmentTypeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type == 'all' ? 'Tous les équipements' : type),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _statsEquipmentType = value);
            },
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
                'Loc: ${rentedAverageCost.toStringAsFixed(2)} TND\nVendu: ${soldAverageCost.toStringAsFixed(2)} TND',
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
                'Retournés',
                returnedCount.toString(),
                Colors.teal,
                Icons.assignment_returned,
              ),
              _buildPerformanceStat(
                'Vendus',
                soldCount.toString(),
                Colors.deepOrange,
                Icons.sell,
              ),
              _buildPerformanceStat(
                'Quantité Totale',
                totalQuantity.toString(),
                Colors.purple,
                Icons.inventory_2,
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

  const ManagerEquipmentRentalScreenContent({Key? key, required this.user})
    : super(key: key);

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
  String _statsEquipmentType = 'all';
  int _totalOxygenBottles = 0;
  Map<String, int> _inventoryByEquipmentType = {};
  Map<String, String> _ambulanceNamesById = {};

  bool get _canSeeMoneySections {
    final role = widget.user.role?.trim().toLowerCase();
    return role == 'owner' || role == 'admin' || role == 'super_admin';
  }

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
    WidgetsBinding.instance.addObserver(this);
    ResumeRefreshService.events.addListener(_handleResumeRefreshEvent);
    _rentalService = EquipmentRentalService();
    _apiClient = ApiClient();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[ManagerEquipmentRentalScreenContent] Post-frame callback: loading rentals',
      );
      _loadData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ResumeRefreshService.events.removeListener(_handleResumeRefreshEvent);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ResumeRefreshService.markBackgrounded();
    }
  }

  void _handleResumeRefreshEvent() {
    final event = ResumeRefreshService.events.value;
    if (!mounted || event == null) return;
    if (event.scope != 'manager' || event.activeTabIndex != 3) return;

    if (event.shouldRefreshVisibleImmediately) {
      debugPrint(
        '[ManagerEquipmentRentalScreenContent] Long resume, refreshing visible tab',
      );
      _loadData();
    } else {
      debugPrint(
        '[ManagerEquipmentRentalScreenContent] Short resume, using cached data',
      );
    }
  }

  Future<void> _loadData() async {
    await _loadCustomEquipmentTypes();
    await _getTenantAmbulances();
    await _loadAllRentals();
    await _loadEquipmentInventories();
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

  Future<void> _loadAllRentals() async {
    try {
      final rentals = await _rentalService.getTenantEquipmentRentals();
      if (mounted) {
        setState(() {
          _allRentals = [...rentals];
          _allRentals.sort(
            (a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''),
          );
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

  Future<List<Ambulance>> _getTenantAmbulances() async {
    final response = await _apiClient.get(SupabaseConfig.ambulancesTable);
    final ambulances = response
        .map((json) => Ambulance.fromJson(json))
        .toList();
    if (mounted) {
      setState(() {
        _ambulanceNamesById = {
          for (final ambulance in ambulances)
            ambulance.id: ambulance.ambulanceNumber,
        };
      });
    }
    return ambulances;
  }

  String _ambulanceLabel(String ambulanceId) =>
      _ambulanceNamesById[ambulanceId] ?? ambulanceId;

  bool _isSale(EquipmentRental rental) =>
      rental.transactionType.trim().toLowerCase() == 'sale';

  Future<void> _showAmbulancePickerDialog({required bool isSale}) async {
    try {
      final ambulances = await _getTenantAmbulances();
      if (!mounted) return;

      if (ambulances.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune ambulance disponible pour cet équipement'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(
            isSale
                ? 'Choisir une ambulance pour la vente'
                : 'Choisir une ambulance',
          ),
          children: ambulances
              .map(
                (ambulance) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (isSale) {
                      _showSellEquipmentDialog(ambulance);
                    } else {
                      _showAddEquipmentDialog(ambulance);
                    }
                  },
                  child: Text(ambulance.ambulanceNumber),
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEquipmentDialog(Ambulance ambulance) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddEquipmentRentalDialog(
        ambulanceId: ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: const [],
        onRentalAdded: (_) async {
          Navigator.pop(dialogContext);
          if (!mounted) return;
          setState(() => _isLoading = true);
          await _loadData();
        },
      ),
    );
  }

  void _showSellEquipmentDialog(Ambulance ambulance) {
    showDialog(
      context: context,
      builder: (dialogContext) => SellEquipmentDialog(
        ambulanceId: ambulance.id,
        rentalService: _rentalService,
        equipmentTypes: _allEquipmentTypes,
        userId: widget.user.id!,
        currentUser: widget.user,
        companyStaff: const [],
        onEquipmentSold: (_) async {
          Navigator.pop(dialogContext);
          if (!mounted) return;
          setState(() => _isLoading = true);
          await _loadData();
        },
      ),
    );
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
      await _rentalService.setOxygenInventoryCount(quantity);
      if (mounted) {
        setState(() => _totalOxygenBottles = quantity);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inventaire oxygene mis a jour: $quantity bouteilles',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadOxygenBottlesInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise a jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSetInventoryDialog() {
    final inventoryCtrl = TextEditingController(
      text: _totalOxygenBottles.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Définir Inventaire Oxygene'),
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
            .where((r) => r.isReturned == false && !_isSale(r))
            .toList();
      case 'returned':
        return _allRentals
            .where((r) => r.isReturned == true && !_isSale(r))
            .toList();
      case 'sold':
        return _allRentals.where((r) => _isSale(r)).toList();
      default:
        return _allRentals;
    }
  }

  Future<void> _persistCustomEquipmentTypes(List<String> equipmentTypes) async {
    final prefs = await SharedPreferences.getInstance();
    final customTypes =
        equipmentTypes
            .map((type) => _canonicalEquipmentType(type))
            .where(
              (type) =>
                  !baseEquipmentTypes.contains(type) &&
                  !_isPlaceholderEquipmentType(type),
            )
            .toSet()
            .toList()
          ..sort();
    await prefs.setStringList(_equipmentTypesPrefsKey, customTypes);
  }

  Future<void> _loadEquipmentInventories() async {
    try {
      final inventories = await _rentalService.getEquipmentInventories();
      if (mounted) {
        setState(() {
          _inventoryByEquipmentType = inventories;
          _totalOxygenBottles = inventories['Oxygene'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading equipment inventories: $e');
      if (mounted) {
        setState(() {
          _inventoryByEquipmentType = {};
          _totalOxygenBottles = 0;
        });
      }
    }
  }

  String _normalizeEquipmentType(String value) => value.trim().toLowerCase();

  bool _isInventoryEquipmentType(String value) =>
      _normalizeEquipmentType(value).contains('invent');

  bool _isPlaceholderEquipmentType(String value) {
    final normalized = _normalizeEquipmentType(value);
    return normalized == 'autre' || normalized == 'other';
  }

  bool _isOxygenEquipmentType(String value) =>
      _normalizeEquipmentType(value).contains('oxy');

  String _canonicalEquipmentType(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Equipement';
    if (_isOxygenEquipmentType(trimmed)) return 'Oxygene';
    return trimmed;
  }

  String _selectedInventoryTypeLabel() =>
      _statsEquipmentType == 'all' ? 'Stock' : _statsEquipmentType;

  int _selectedInventoryQuantity() {
    if (_statsEquipmentType == 'all') {
      return _inventoryByEquipmentType.values.fold<int>(
        0,
        (sum, qty) => sum + qty,
      );
    }

    if (_isOxygenEquipmentType(_statsEquipmentType)) {
      return _inventoryByEquipmentType['Oxygene'] ?? 0;
    }

    return _inventoryByEquipmentType[_statsEquipmentType] ?? 0;
  }

  List<String> _getStatsEquipmentTypes() {
    final uniqueTypes = <String>{};

    for (final type in _allEquipmentTypes) {
      final trimmed = type.trim();
      if (trimmed.isEmpty ||
          _isInventoryEquipmentType(trimmed) ||
          _isPlaceholderEquipmentType(trimmed)) {
        continue;
      }
      if (_isOxygenEquipmentType(trimmed)) {
        uniqueTypes.add('Oxygene');
      } else {
        uniqueTypes.add(trimmed);
      }
    }

    for (final rental in _allRentals) {
      final trimmed = rental.equipmentType.trim();
      if (trimmed.isEmpty ||
          _isInventoryEquipmentType(trimmed) ||
          _isPlaceholderEquipmentType(trimmed)) {
        continue;
      }
      if (_isOxygenEquipmentType(trimmed)) {
        uniqueTypes.add('Oxygene');
      } else {
        uniqueTypes.add(trimmed);
      }
    }

    final sortedTypes = uniqueTypes.toList()..sort();
    return ['all', ...sortedTypes];
  }

  List<EquipmentRental> _getStatsRentals() {
    final rentalsOnly = _allRentals
        .where((r) => r.metadata == null || r.metadata!.isEmpty)
        .toList();

    if (_statsEquipmentType == 'all') {
      return rentalsOnly;
    }

    if (_isOxygenEquipmentType(_statsEquipmentType)) {
      return rentalsOnly
          .where((r) => _isOxygenEquipmentType(r.equipmentType))
          .toList();
    }

    final selectedType = _normalizeEquipmentType(_statsEquipmentType);
    return rentalsOnly
        .where((r) => _normalizeEquipmentType(r.equipmentType) == selectedType)
        .toList();
  }

  void _showDynamicInventoryDialog() {
    final workingInventory = <String, int>{};
    for (final entry in _inventoryByEquipmentType.entries) {
      final canonicalType = _canonicalEquipmentType(entry.key);
      workingInventory[canonicalType] = entry.value;
    }
    final equipmentTypes = <String>{
      ..._allEquipmentTypes
          .map((type) => _canonicalEquipmentType(type))
          .where(
            (type) => type.isNotEmpty && !_isPlaceholderEquipmentType(type),
          ),
      ...workingInventory.keys.where(
        (type) => !_isPlaceholderEquipmentType(type),
      ),
    }.toList()..sort();

    for (final type in equipmentTypes) {
      workingInventory.putIfAbsent(type, () => 0);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Définir Inventaire'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in equipmentTypes) ...[
                    TextFormField(
                      initialValue: (workingInventory[type] ?? 0).toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: type,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        workingInventory[type] = int.tryParse(value) ?? 0;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final controller = TextEditingController();
                        final newType = await showDialog<String>(
                          context: context,
                          builder: (nestedContext) => AlertDialog(
                            title: const Text('Ajouter équipement'),
                            content: TextFormField(
                              controller: controller,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Nom équipement',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(nestedContext),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(
                                  nestedContext,
                                  controller.text.trim(),
                                ),
                                child: const Text('Ajouter'),
                              ),
                            ],
                          ),
                        );

                        if (newType == null ||
                            newType.isEmpty ||
                            _isPlaceholderEquipmentType(newType)) {
                          return;
                        }
                        if (!equipmentTypes.contains(newType)) {
                          setDialogState(() {
                            equipmentTypes.add(newType);
                            equipmentTypes.sort();
                            workingInventory.putIfAbsent(newType, () => 0);
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('+ équipement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cleanedInventory = <String, int>{};
                for (final type in equipmentTypes) {
                  if (_isPlaceholderEquipmentType(type)) continue;
                  final canonicalType = _canonicalEquipmentType(type);
                  cleanedInventory[canonicalType] =
                      workingInventory[canonicalType] ?? 0;
                }

                await _persistCustomEquipmentTypes(equipmentTypes);
                await _rentalService.setEquipmentInventories(cleanedInventory);
                if (!mounted) return;
                setState(() {
                  _allEquipmentTypes = [
                    ...baseEquipmentTypes,
                    ...equipmentTypes.where(
                      (type) => !baseEquipmentTypes.contains(type),
                    ),
                  ];
                  _inventoryByEquipmentType = cleanedInventory;
                  _totalOxygenBottles = cleanedInventory['Oxygene'] ?? 0;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
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
              'Ambulance: ${_ambulanceLabel(rental.ambulanceId)}\nÉquipement: ${rental.equipmentType}',
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
                  rental.id,
                  returnDateCtrl.text,
                );

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
                await _rentalService.markAsReturned(
                  rental.id,
                  returnDateCtrl.text,
                );

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'OK: ${rental.equipmentType} retourné le ${returnDateCtrl.text}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadAllRentals();
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Retourner'),
          ),
        ],
      ),
    );
  }

  void _showEditRentalDialog(EquipmentRental rental) {
    final ambulancierCtrl = TextEditingController(
      text: rental.ambulancierName ?? '',
    );
    final patientNameCtrl = TextEditingController(
      text: rental.patientName ?? '',
    );
    final patientAddressCtrl = TextEditingController(
      text: rental.patientAddress ?? '',
    );
    final patientPhoneCtrl = TextEditingController(
      text: rental.patientPhoneNumber ?? '',
    );
    final costCtrl = TextEditingController(text: rental.cost.toString());
    final notesCtrl = TextEditingController(text: rental.notes ?? '');
    final returnDateCtrl = TextEditingController(
      text: rental.returnDate?.split(' ')[0] ?? '',
    );
    final isSold = _isSale(rental);

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
                'Ambulance: ${_ambulanceLabel(rental.ambulanceId)}\nÉquipement: ${rental.equipmentType}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ambulancierCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Nom de l'
                      'Ambulancier',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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

              if (!isSold) ...[
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
              ],

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

              TextFormField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText:
                      'État de l'
                      'équipement, conditions spéciales, etc.',
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
                  returnDate: isSold ? rental.returnDate : returnDateCtrl.text,
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
              'Équipement: ${rental.equipmentType}\nAmbulance: ${_ambulanceLabel(rental.ambulanceId)}',
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
                  SupabaseConfig.equipmentRentalsTable,
                  rental.id,
                );

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              onPressed: _showDynamicInventoryDialog,
              icon: const Icon(Icons.inventory_2),
              label: Text(
                'Inventaire: ${_inventoryByEquipmentType.length} types',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAmbulancePickerDialog(isSale: false),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Ajouter equipement'),
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
                  onPressed: () => _showAmbulancePickerDialog(isSale: true),
                  icon: const Icon(Icons.sell),
                  label: const Text('Vendre equipement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
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
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                    const Text(
                      'Actives',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == false && !_isSale(r)).length}',
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
                    const Text(
                      'Retournées',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${_allRentals.where((r) => r.isReturned == true && !_isSale(r)).length}',
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

          if (_canSeeMoneySections) ...[
            _buildPerformancePanel(),
            const SizedBox(height: 20),
          ],

          // Rentals list or empty state
          if (filteredRentals.isEmpty)
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
    final rentalsOnly = _getStatsRentals();
    final equipmentTypeOptions = _getStatsEquipmentTypes();

    final totalCost = rentalsOnly.fold<double>(0, (sum, r) => sum + r.cost);
    final soldItems = rentalsOnly.where((r) => _isSale(r)).toList();
    final rentedItems = rentalsOnly
        .where((r) => !_isSale(r) && r.transactionType == 'rental')
        .toList();
    final soldCount = soldItems.fold<int>(0, (sum, r) => sum + r.quantity);
    final activeCount = rentedItems
        .where((r) => r.isReturned == false)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final returnedCount = rentedItems
        .where((r) => r.isReturned == true)
        .fold<int>(0, (sum, r) => sum + r.quantity);
    final totalQuantity = rentalsOnly.fold<int>(
      0,
      (sum, r) => sum + r.quantity,
    );

    double averageCostFor(List<EquipmentRental> items) {
      final totalQuantity = items.fold<int>(0, (sum, r) => sum + r.quantity);
      final totalAmount = items.fold<double>(0, (sum, r) => sum + r.cost);
      return totalQuantity > 0 ? totalAmount / totalQuantity : 0.0;
    }

    final rentedAverageCost = averageCostFor(rentedItems);
    final soldAverageCost = averageCostFor(soldItems);
    final selectedInventoryQuantity = _selectedInventoryQuantity();
    final selectedRentedQuantity = activeCount;
    final selectedRemainingQuantity =
        (selectedInventoryQuantity - selectedRentedQuantity) < 0
        ? 0
        : (selectedInventoryQuantity - selectedRentedQuantity);

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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: equipmentTypeOptions.contains(_statsEquipmentType)
                ? _statsEquipmentType
                : 'all',
            decoration: InputDecoration(
              labelText: 'Type d\'équipement',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: equipmentTypeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type == 'all' ? 'Tous les équipements' : type),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _statsEquipmentType = value);
            },
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
                'Loc: ${rentedAverageCost.toStringAsFixed(2)} TND\nVendu: ${soldAverageCost.toStringAsFixed(2)} TND',
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
                '${_selectedInventoryTypeLabel()} Loué',
                selectedRentedQuantity.toString(),
                Colors.red,
                Icons.local_fire_department,
              ),
              _buildPerformanceStat(
                '${_selectedInventoryTypeLabel()} Restant',
                selectedRemainingQuantity.toString(),
                selectedRemainingQuantity > 0 ? Colors.green : Colors.red,
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
    final isSold = _isSale(rental);
    final rentDateFormatted = rental.rentDate.split(' ')[0];
    final returnDateFormatted = rental.returnDate?.split(' ')[0] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
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
                      Text(
                        'Quantite: ${rental.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
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
                        _ambulanceLabel(rental.ambulanceId),
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

            if (!isSold && !isReturned) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReturnDialog(rental),
                  icon: const Icon(Icons.assignment_return),
                  label: const Text('Retourner equipement'),
                ),
              ),
            ],

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
          ],
        ),
      ),
    );
  }
}

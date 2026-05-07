import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/equipment_rental_model.dart';

/// Equipment Rental Service
/// Handles sensitive equipment-rental operations through secure Edge Functions.
class EquipmentRentalService {
  static const String _oxygenType = 'Oxygene';
  bool _isInventoryMetadata(String? metadata) {
    if (metadata == null) return false;
    return metadata == 'oxygen_inventory' ||
        metadata.startsWith('equipment_inventory:');
  }

  String _normalizeEquipmentType(String value) => value.trim().toLowerCase();

  bool _isOxygenEquipmentType(String value) =>
      _normalizeEquipmentType(value).contains('oxy');

  String _canonicalEquipmentType(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Equipement';
    if (_isOxygenEquipmentType(trimmed)) return _oxygenType;
    return trimmed;
  }

  String _inventoryMetadataForType(String equipmentType) {
    if (_isOxygenEquipmentType(equipmentType)) return 'oxygen_inventory';
    return 'equipment_inventory:${_normalizeEquipmentType(equipmentType)}';
  }

  String _displayOxygenType() => 'Oxygene';

  bool _isUnsupportedActionError(Object error) =>
      error.toString().contains('Unsupported action');

  Future<List<EquipmentRental>> getAmbulanceEquipmentRentals(
    String ambulanceId,
  ) async {
    try {
      debugPrint(
        '📡 [EquipmentRental] Fetching rentals for ambulance through secure function',
      );

      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'list_by_ambulance', 'ambulance_id': ambulanceId},
      );

      final rows = List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['rentals'] ?? const [],
      );

      return rows.map(EquipmentRental.fromJson).toList();
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error fetching rentals: $e');
      rethrow;
    }
  }

  Future<List<EquipmentRental>> getTenantEquipmentRentals() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'list_all'},
      );

      final rows = List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['rentals'] ?? const [],
      );

      return rows.map(EquipmentRental.fromJson).toList();
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error fetching tenant rentals: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> _getEquipmentInventoriesFallback() async {
    final rentals = await getTenantEquipmentRentals();
    final inventories = <String, int>{};

    for (final rental in rentals) {
      if (!_isInventoryMetadata(rental.metadata)) continue;

      final equipmentType = _canonicalEquipmentType(rental.equipmentType);
      inventories[equipmentType] = rental.quantity;
    }

    return inventories;
  }

  Future<void> _setEquipmentInventoriesFallback(
    Map<String, int> inventories,
  ) async {
    final rentals = await getTenantEquipmentRentals();
    final existingRows = rentals.where((r) => _isInventoryMetadata(r.metadata));
    final rowsByMetadata = <String, EquipmentRental>{
      for (final row in existingRows)
        _inventoryMetadataForType(
          row.equipmentType.isEmpty ? (row.metadata ?? '') : row.equipmentType,
        ): row,
    };

    final now = DateTime.now().toIso8601String();
    final rentDate = now.split('T')[0];

    for (final entry in inventories.entries) {
      final canonicalType = _canonicalEquipmentType(entry.key);
      final metadata = _inventoryMetadataForType(canonicalType);
      final existing = rowsByMetadata[metadata];

      if (existing != null) {
        await updateRentalFieldMap(existing.id, {
          'equipment_type': canonicalType,
          'metadata': metadata,
          'quantity': entry.value,
          'cost': 0.0,
          'is_returned': true,
        });
        continue;
      }

      await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {
          'action': 'create',
          'data': {
            'id': const Uuid().v4(),
            'ambulance_id': null,
            'equipment_type': canonicalType,
            'ambulancier_name': 'Inventaire',
            'rent_date': rentDate,
            'return_date': rentDate,
            'cost': 0.0,
            'notes': null,
            'is_returned': true,
            'quantity': entry.value,
            'transaction_type': 'rental',
            'created_at': now,
            'metadata': metadata,
          },
        },
      );
    }
  }

  Future<Map<String, int>> getEquipmentInventories() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'get_inventory_v2'},
      );

      final rows = List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['inventories'] ?? const [],
      );

      final inventories = <String, int>{};
      for (final row in rows) {
        final equipmentType = (row['equipment_type'] as String? ?? '').trim();
        if (equipmentType.isEmpty) continue;
        final canonicalType = _canonicalEquipmentType(equipmentType);
        inventories[canonicalType] = row['quantity'] as int? ?? 0;
      }

      return inventories;
    } catch (e) {
      if (!_isUnsupportedActionError(e)) {
        debugPrint('Error fetching equipment inventories: $e');
      }
      return _getEquipmentInventoriesFallback();
    }
  }

  Future<void> setEquipmentInventories(Map<String, int> inventories) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'set_inventory_v2', 'inventories': inventories},
      );
    } catch (e) {
      if (!_isUnsupportedActionError(e)) {
        debugPrint('Error updating equipment inventories: $e');
      }
      await _setEquipmentInventoriesFallback(inventories);
    }
  }

  Future<int> getOxygenInventoryCount() async {
    try {
      final inventories = await getEquipmentInventories();
      return inventories[_displayOxygenType()] ?? 0;
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error fetching oxygen inventory: $e');
      rethrow;
    }
  }

  Future<void> setOxygenInventoryCount(int quantity) async {
    try {
      final inventories = await getEquipmentInventories();
      inventories[_displayOxygenType()] = quantity;
      await setEquipmentInventories(inventories);
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error updating oxygen inventory: $e');
      rethrow;
    }
  }

  Future<EquipmentRental> createEquipmentRental({
    required String ambulanceId,
    required String equipmentType,
    required String ambulancierName,
    required String rentDate,
    required double cost,
    String? returnDate,
    String? notes,
    String? patientName,
    String? patientAddress,
    String? patientPhoneNumber,
    int quantity = 1,
  }) async {
    try {
      final rentalId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {
          'action': 'create',
          'data': {
            'id': rentalId,
            'ambulance_id': ambulanceId,
            'equipment_type': equipmentType,
            'ambulancier_name': ambulancierName,
            'rent_date': rentDate,
            'return_date': returnDate,
            'cost': cost,
            'notes': notes,
            'is_returned': false,
            'quantity': quantity,
            'transaction_type': 'rental',
            'created_at': now,
            if (patientName != null) 'patient_name': patientName,
            if (patientAddress != null) 'patient_address': patientAddress,
            if (patientPhoneNumber != null)
              'patient_phone_number': patientPhoneNumber,
          },
        },
      );

      final data =
          (response.data as Map<String, dynamic>?)?['rental']
              as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Secure equipment rental creation returned no row.');
      }

      return EquipmentRental.fromJson(data);
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error creating rental: $e');
      rethrow;
    }
  }

  Future<void> updateRentalField(
    String rentalId,
    String fieldName,
    dynamic value,
  ) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {
          'action': 'update',
          'rental_id': rentalId,
          'patch': {fieldName: value},
        },
      );
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error updating rental field: $e');
      rethrow;
    }
  }

  Future<void> markAsReturned(String rentalId, String returnDate) async {
    await updateRentalFieldMap(rentalId, {
      'is_returned': true,
      'return_date': returnDate,
    });
  }

  Future<void> updateReturnDate(String rentalId, String newReturnDate) async {
    await updateRentalField(rentalId, 'return_date', newReturnDate);
  }

  Future<void> updateEquipmentRental({
    required String rentalId,
    String? ambulancierName,
    String? patientName,
    String? patientAddress,
    String? patientPhoneNumber,
    String? returnDate,
    double? cost,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{};

    if (ambulancierName != null) {
      updateData['ambulancier_name'] = ambulancierName;
    }
    if (patientName != null) {
      updateData['patient_name'] = patientName;
    }
    if (patientAddress != null) {
      updateData['patient_address'] = patientAddress;
    }
    if (patientPhoneNumber != null) {
      updateData['patient_phone_number'] = patientPhoneNumber;
    }
    if (returnDate != null) {
      updateData['return_date'] = returnDate;
    }
    if (cost != null) {
      updateData['cost'] = cost;
    }
    if (notes != null) {
      updateData['notes'] = notes;
    }

    if (updateData.isEmpty) {
      return;
    }

    await updateRentalFieldMap(rentalId, updateData);
  }

  Future<void> updateRentalFieldMap(
    String rentalId,
    Map<String, dynamic> patch,
  ) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'update', 'rental_id': rentalId, 'patch': patch},
      );
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error updating rental: $e');
      rethrow;
    }
  }

  Future<void> deleteRental(String rentalId) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {'action': 'delete', 'rental_id': rentalId},
      );
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error deleting rental: $e');
      rethrow;
    }
  }

  Future<EquipmentRental> sellEquipment({
    required String ambulanceId,
    required String equipmentType,
    required String ambulancierName,
    required String saleDate,
    required double cost,
    String? notes,
    String? patientName,
    String? patientAddress,
    String? patientPhoneNumber,
    int quantity = 1,
  }) async {
    try {
      final saleId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {
          'action': 'create',
          'data': {
            'id': saleId,
            'ambulance_id': ambulanceId,
            'equipment_type': equipmentType,
            'ambulancier_name': ambulancierName,
            'rent_date': saleDate,
            'return_date': saleDate,
            'cost': cost,
            'notes': notes,
            'is_returned': true,
            'quantity': quantity,
            'transaction_type': 'sale',
            'created_at': now,
            if (patientName != null) 'patient_name': patientName,
            if (patientAddress != null) 'patient_address': patientAddress,
            if (patientPhoneNumber != null)
              'patient_phone_number': patientPhoneNumber,
          },
        },
      );

      final data =
          (response.data as Map<String, dynamic>?)?['rental']
              as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Secure equipment sale creation returned no row.');
      }

      final canonicalType = _canonicalEquipmentType(equipmentType);
      final inventories = await getEquipmentInventories();
      final currentQuantity = inventories[canonicalType] ?? 0;
      inventories[canonicalType] = (currentQuantity - quantity) < 0
          ? 0
          : (currentQuantity - quantity);
      await setEquipmentInventories(inventories);

      return EquipmentRental.fromJson(data);
    } catch (e) {
      debugPrint('❌ [EquipmentRental] Error creating equipment sale: $e');
      rethrow;
    }
  }
}

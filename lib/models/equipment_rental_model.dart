/// Equipment Rental Model
/// Represents equipment rental records
class EquipmentRental {
  final String id;
  final String ambulanceId;
  final String equipmentType;
  final String ambulancierName;
  final String rentDate;
  final String? returnDate;
  final double cost;
  final String? notes;
  final bool? isReturned;
  final String? createdAt;
  final String? patientName;
  final String? patientAddress;
  final String? patientPhoneNumber;
  final int
      quantity; // Quantity of items rented (e.g., number of oxygen bottles)
  final String transactionType; // 'rental' or 'sale'
  final String? metadata; // Additional metadata (e.g., 'oxygen_inventory')

  EquipmentRental({
    required this.id,
    required this.ambulanceId,
    required this.equipmentType,
    required this.ambulancierName,
    required this.rentDate,
    this.returnDate,
    required this.cost,
    this.notes,
    this.isReturned,
    this.createdAt,
    this.patientName,
    this.patientAddress,
    this.patientPhoneNumber,
    this.quantity = 1,
    this.transactionType = 'rental',
    this.metadata,
  });

  /// Factory constructor to create EquipmentRental from JSON
  factory EquipmentRental.fromJson(Map<String, dynamic> json) {
    return EquipmentRental(
      id: _toString(json['id']),
      ambulanceId: _toString(json['ambulance_id']),
      equipmentType: json['equipment_type'] as String? ?? '',
      ambulancierName: json['ambulancier_name'] as String? ?? '',
      rentDate: json['rent_date'] as String? ?? '',
      returnDate: json['return_date'] as String?,
      cost: _toDoubleNullable(json['cost']) ?? 0.0,
      notes: json['notes'] as String?,
      isReturned: json['is_returned'] as bool?,
      createdAt: json['created_at'] as String?,
      patientName: json['patient_name'] as String?,
      patientAddress: json['patient_address'] as String?,
      patientPhoneNumber: json['patient_phone_number'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      transactionType: json['transaction_type'] as String? ?? 'rental',
      metadata: json['metadata'] as String?,
    );
  }

  /// Convert EquipmentRental to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'ambulance_id': ambulanceId,
        'equipment_type': equipmentType,
        'ambulancier_name': ambulancierName,
        'rent_date': rentDate,
        'return_date': returnDate,
        'cost': cost,
        'notes': notes,
        'is_returned': isReturned,
        'created_at': createdAt,
        'patient_name': patientName,
        'patient_address': patientAddress,
        'patient_phone_number': patientPhoneNumber,
        'quantity': quantity,
        'transaction_type': transactionType,
        'metadata': metadata,
      };

  /// Helper to safely convert any value to string
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  /// Helper to safely convert any value to nullable double
  static double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
  }
}

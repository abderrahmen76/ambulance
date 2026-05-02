/// Maintenance Record Model
/// Represents maintenance records for ambulances
class MaintenanceRecord {
  final String id;
  final String ambulanceId;
  final String date;
  final String maintenanceType;
  final String maintenanceDescription;
  final double? pricePerPiece;
  final String? mechanicName;
  final String? notes;
  final String? userId;
  final String? driverName;
  final double? limitValue;
  final String? limitUnit;
  final String? documentPath;
  final String? createdAt;
  final String? updatedAt;
  final String? nextDueDate;
  final int? intervalDays;
  final int? intervalKm;
  final double? kilometrage;

  MaintenanceRecord({
    required this.id,
    required this.ambulanceId,
    required this.date,
    required this.maintenanceType,
    required this.maintenanceDescription,
    this.pricePerPiece,
    this.mechanicName,
    this.notes,
    this.userId,
    this.driverName,
    this.limitValue,
    this.limitUnit,
    this.documentPath,
    this.createdAt,
    this.updatedAt,
    this.nextDueDate,
    this.intervalDays,
    this.intervalKm,
    this.kilometrage,
  });

  /// Factory constructor to create MaintenanceRecord from JSON
  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price_per_piece'];
    print(
        '[MaintenanceRecord] Parsing record ID: ${json['id']}, price_per_piece: $priceValue (type: ${priceValue.runtimeType})');

    final parsedPrice = _toDoubleNullable(priceValue);
    print('[MaintenanceRecord] Parsed price: $parsedPrice');

    return MaintenanceRecord(
      id: _toString(json['id']),
      ambulanceId: _toString(json['ambulance_id']),
      date: json['date'] as String? ?? '',
      maintenanceType: json['maintenance_type'] as String? ?? '',
      maintenanceDescription: json['maintenance_description'] as String? ?? '',
      pricePerPiece: parsedPrice,
      mechanicName: json['mechanic_name'] as String?,
      notes: json['notes'] as String?,
      userId: _toStringNullable(json['user_id']),
      driverName: json['driver_name'] as String?,
      limitValue: _toDoubleNullable(json['limit_value']),
      limitUnit: json['limit_unit'] as String?,
      documentPath: json['document_path'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      nextDueDate: json['next_due_date'] as String?,
      intervalDays: _toIntNullable(json['interval_days']),
      intervalKm: _toIntNullable(json['interval_km']),
      kilometrage: _toDoubleNullable(json['kilometrage']),
    );
  }

  /// Convert MaintenanceRecord to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'ambulance_id': ambulanceId,
        'date': date,
        'maintenance_type': maintenanceType,
        'maintenance_description': maintenanceDescription,
        'price_per_piece': pricePerPiece,
        'mechanic_name': mechanicName,
        'notes': notes,
        'user_id': userId,
        'driver_name': driverName,
        'limit_value': limitValue,
        'limit_unit': limitUnit,
        'document_path': documentPath,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'next_due_date': nextDueDate,
        'interval_days': intervalDays,
        'interval_km': intervalKm,
        'kilometrage': kilometrage,
      };

  @override
  String toString() =>
      'MaintenanceRecord(id: $id, ambulanceId: $ambulanceId, date: $date, maintenanceType: $maintenanceType, pricePerPiece: $pricePerPiece)';

  /// Helper to safely convert any value to string
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  /// Helper to safely convert any value to nullable string
  static String? _toStringNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Helper to safely convert any value to nullable double
  static double? _toDoubleNullable(dynamic value) {
    print('[_toDoubleNullable] Input: $value (type: ${value.runtimeType})');

    if (value == null) {
      print('[_toDoubleNullable] Value is null, returning null');
      return null;
    }
    if (value is double) {
      print('[_toDoubleNullable] Value is already double: $value');
      return value;
    }
    if (value is int) {
      print('[_toDoubleNullable] Converting int to double: $value');
      return value.toDouble();
    }
    if (value is String) {
      final trimmed = value.trim();
      print('[_toDoubleNullable] Trimmed string: "$trimmed"');
      if (trimmed.isEmpty) {
        print('[_toDoubleNullable] Trimmed string is empty, returning null');
        return null;
      }
      final parsed = double.tryParse(trimmed);
      print('[_toDoubleNullable] Parsed string to double: $parsed');
      return parsed;
    }
    if (value is num) {
      print('[_toDoubleNullable] Converting num to double: $value');
      return value.toDouble();
    }

    print('[_toDoubleNullable] Unknown type, returning null');
    return null;
  }

  /// Helper to safely convert any value to nullable int
  static int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }
}

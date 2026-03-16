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
  });

  /// Factory constructor to create MaintenanceRecord from JSON
  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: _toString(json['id']),
      ambulanceId: _toString(json['ambulance_id']),
      date: json['date'] as String? ?? '',
      maintenanceType: json['maintenance_type'] as String? ?? '',
      maintenanceDescription: json['maintenance_description'] as String? ?? '',
      pricePerPiece: (json['price_per_piece'] as num?)?.toDouble(),
      mechanicName: json['mechanic_name'] as String?,
      notes: json['notes'] as String?,
      userId: _toStringNullable(json['user_id']),
      driverName: json['driver_name'] as String?,
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
      };

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
}

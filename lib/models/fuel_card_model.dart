/// Fuel Card Model
/// Represents fuel card transaction records
class FuelCard {
  final String id;
  final String ambulanceId;
  final String date;
  final String driverName;
  final double soldesPaid;
  final double soldesRestant;
  final String? notes;
  final double? kilometrage;

  FuelCard({
    required this.id,
    required this.ambulanceId,
    required this.date,
    required this.driverName,
    this.soldesPaid = 0.0,
    this.soldesRestant = 0.0,
    this.notes,
    this.kilometrage,
  });

  /// Factory constructor to create FuelCard from JSON
  factory FuelCard.fromJson(Map<String, dynamic> json) {
    return FuelCard(
      id: _toString(json['id']),
      ambulanceId: _toString(json['ambulance_id']),
      date: json['date'] as String? ?? '',
      driverName: json['driver_name'] as String? ?? 'Unknown',
      soldesPaid: _toDoubleNullable(json['soldes_paid']) ?? 0.0,
      soldesRestant: _toDoubleNullable(json['soldes_restant']) ?? 0.0,
      notes: json['notes'] as String?,
      kilometrage: _toDoubleNullable(json['kilometrage']),
    );
  }

  /// Convert FuelCard to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'ambulance_id': ambulanceId,
        'date': date,
        'driver_name': driverName,
        'soldes_paid': soldesPaid,
        'soldes_restant': soldesRestant,
        'notes': notes,
        'kilometrage': kilometrage,
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

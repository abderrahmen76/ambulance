/// Fuel Card Model
/// Represents fuel card transaction records
class FuelCard {
  final String id;
  final String ambulanceId;
  final String date;
  final String driverName;
  final double fuelAmount;
  final double balance;
  final double? rechargeAmount;
  final String? notes;

  FuelCard({
    required this.id,
    required this.ambulanceId,
    required this.date,
    required this.driverName,
    required this.fuelAmount,
    required this.balance,
    this.rechargeAmount,
    this.notes,
  });

  /// Factory constructor to create FuelCard from JSON
  factory FuelCard.fromJson(Map<String, dynamic> json) {
    return FuelCard(
      id: _toString(json['id']),
      ambulanceId: _toString(json['ambulance_id']),
      date: json['date'] as String? ?? '',
      driverName: json['driver_name'] as String? ?? 'Unknown',
      fuelAmount: (json['fuel_amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      rechargeAmount: (json['recharge_amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  /// Convert FuelCard to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'ambulance_id': ambulanceId,
        'date': date,
        'driver_name': driverName,
        'fuel_amount': fuelAmount,
        'balance': balance,
        'recharge_amount': rechargeAmount,
        'notes': notes,
      };

  /// Helper to safely convert any value to string
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

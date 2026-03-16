/// Ambulance Model
/// Represents an ambulance entity in the system
class Ambulance {
  final String id;
  final String ambulanceNumber;
  final String? currentDriverId;
  final String? telephone;
  final String? currentMissionId;
  final String? currentDestination;
  final double? kilometrage;

  Ambulance({
    required this.id,
    required this.ambulanceNumber,
    this.currentDriverId,
    this.telephone,
    this.currentMissionId,
    this.currentDestination,
    this.kilometrage,
  });

  /// Factory constructor to create Ambulance from JSON
  factory Ambulance.fromJson(Map<String, dynamic> json) {
    return Ambulance(
      id: _toString(json['id']),
      ambulanceNumber: json['ambulance_number'] as String? ?? 'N/A',
      currentDriverId: _toStringNullable(json['current_driver_id']),
      telephone: json['telephone'] as String?,
      currentMissionId: _toStringNullable(json['current_mission_id']),
      currentDestination: json['current_destination'] as String?,
      kilometrage: (json['kilometrage'] as num?)?.toDouble(),
    );
  }

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

  /// Convert Ambulance to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'ambulance_number': ambulanceNumber,
        'current_driver_id': currentDriverId,
        'telephone': telephone,
        'current_mission_id': currentMissionId,
        'current_destination': currentDestination,
        'kilometrage': kilometrage,
      };

  /// Create a copy with modified fields
  Ambulance copyWith({
    String? id,
    String? ambulanceNumber,
    String? currentDriverId,
    String? telephone,
    String? currentMissionId,
    String? currentDestination,
    double? kilometrage,
  }) {
    return Ambulance(
      id: id ?? this.id,
      ambulanceNumber: ambulanceNumber ?? this.ambulanceNumber,
      currentDriverId: currentDriverId ?? this.currentDriverId,
      telephone: telephone ?? this.telephone,
      currentMissionId: currentMissionId ?? this.currentMissionId,
      currentDestination: currentDestination ?? this.currentDestination,
      kilometrage: kilometrage ?? this.kilometrage,
    );
  }
}

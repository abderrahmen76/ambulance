/// Mission Model
/// Represents a mission/task for the ambulance
class Mission {
  final String id;
  final String missionNumber;
  final String missionDate;
  final String fromLocation;
  final String toLocation;
  final String? patientPhone;
  final String status;
  final String priority;
  final String ambulanceId;
  final String? driverName;
  final String? startTime;
  final String? endTime;
  final String? infirmierName;
  final String? paymentType;
  final bool? isPaid;
  final String? patientFirstName;
  final String? patientLastName;
  final String? patientAge;
  final List<String>? medicalHistory;
  final Map<String, dynamic>? vitalSigns;
  final List<String>? patientNeeds;
  final String? fracturesInjuries;
  final String? reportType;
  final String? reportFilledAt;

  Mission({
    required this.id,
    required this.missionNumber,
    required this.missionDate,
    required this.fromLocation,
    required this.toLocation,
    this.patientPhone,
    required this.status,
    required this.priority,
    required this.ambulanceId,
    this.driverName,
    this.startTime,
    this.endTime,
    this.infirmierName,
    this.paymentType,
    this.isPaid,
    this.patientFirstName,
    this.patientLastName,
    this.patientAge,
    this.medicalHistory,
    this.vitalSigns,
    this.patientNeeds,
    this.fracturesInjuries,
    this.reportType,
    this.reportFilledAt,
  });

  /// Factory constructor to create Mission from JSON
  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: _toString(json['id']),
      missionNumber: json['mission_number'] as String? ?? 'N/A',
      missionDate: json['mission_date'] as String? ?? '',
      fromLocation: json['from_location'] as String? ?? '',
      toLocation: json['to_location'] as String? ?? '',
      patientPhone: json['patient_phone'] as String?,
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'normal',
      ambulanceId: _toString(json['ambulance_id']),
      driverName: json['driver_name'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      infirmierName: json['infirmier_name'] as String?,
      paymentType: json['payment_type'] as String?,
      isPaid: json['payment_status'] as bool?,
      patientFirstName: json['patient_first_name'] as String?,
      patientLastName: json['patient_last_name'] as String?,
      patientAge: _toNullableString(json['patient_age']),
      medicalHistory: _toStringList(json['medical_history']),
      vitalSigns: _toMap(json['vital_signs']),
      patientNeeds: _toStringList(json['patient_needs']),
      fracturesInjuries: json['fractures_injuries'] as String?,
      reportType: json['report_type'] as String?,
      reportFilledAt: json['report_filled_at'] as String?,
    );
  }

  /// Convert Mission to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'mission_number': missionNumber,
        'mission_date': missionDate,
        'from_location': fromLocation,
        'to_location': toLocation,
        'patient_phone': patientPhone,
        'status': status,
        'priority': priority,
        'ambulance_id': ambulanceId,
        'driver_name': driverName,
        'start_time': startTime,
        'end_time': endTime,
        'infirmier_name': infirmierName,
        'payment_type': paymentType,
        'payment_status': isPaid,
        'patient_first_name': patientFirstName,
        'patient_last_name': patientLastName,
        'patient_age': patientAge,
        'medical_history': medicalHistory,
        'vital_signs': vitalSigns,
        'patient_needs': patientNeeds,
        'fractures_injuries': fracturesInjuries,
        'report_type': reportType,
        'report_filled_at': reportFilledAt,
      };

  /// Helper to safely convert any value to string
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Helper to safely convert value to List<String>
  static List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return null;
  }

  /// Helper to safely convert value to Map<String, dynamic>
  static Map<String, dynamic>? _toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        // Handle JSON string if needed
        return value as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

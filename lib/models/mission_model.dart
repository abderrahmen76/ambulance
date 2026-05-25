import 'dart:convert';

/// Mission Model
/// Represents a mission/task for the ambulance
class Mission {
  final String id;
  final String? tenantId;
  final String missionNumber;
  final String missionDate;
  final String fromLocation;
  final String toLocation;
  final String? patientName;
  final String? patientPhone;
  final String status;
  final String? dispatchPhase;
  final String? assignedCompanyId;
  final String? selectedProviderTenantId;
  final String priority;
  final String ambulanceId;
  final String? assignedAmbulanceId;
  final String? driverName;
  final String? startTime;
  final String? endTime;
  final String? infirmierName;
  final String? paymentType;
  final bool? isPaid;
  final String? guarantee;
  final String? patientFirstName;
  final String? patientLastName;
  final String? patientAge;
  final String? notes;
  final String? missionPrice;
  final List<String>? medicalHistory;
  final Map<String, dynamic>? vitalSigns;
  final Map<String, dynamic>? patientNeeds;
  final List<Map<String, dynamic>>? medications;
  final String? fracturesInjuries;
  final String? reportType;
  final String? reportFilledAt;
  final String? clinicTenantId;
  final String? clinicName;
  final String? pickupAddress;
  final String? destinationAddress;
  final String? pickupLat;
  final String? pickupLng;
  final String? destinationLat;
  final String? destinationLng;
  final Map<String, dynamic>? requirements;

  Mission({
    required this.id,
    this.tenantId,
    required this.missionNumber,
    required this.missionDate,
    required this.fromLocation,
    required this.toLocation,
    this.patientName,
    this.patientPhone,
    required this.status,
    this.dispatchPhase,
    this.assignedCompanyId,
    this.selectedProviderTenantId,
    required this.priority,
    required this.ambulanceId,
    this.assignedAmbulanceId,
    this.driverName,
    this.startTime,
    this.endTime,
    this.infirmierName,
    this.paymentType,
    this.isPaid,
    this.guarantee,
    this.patientFirstName,
    this.patientLastName,
    this.patientAge,
    this.notes,
    this.missionPrice,
    this.medicalHistory,
    this.vitalSigns,
    this.patientNeeds,
    this.medications,
    this.fracturesInjuries,
    this.reportType,
    this.reportFilledAt,
    this.clinicTenantId,
    this.clinicName,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.requirements,
  });

  /// Factory constructor to create Mission from JSON
  factory Mission.fromJson(Map<String, dynamic> json) {
    final dispatchPhase = json['dispatch_phase'] as String?;
    final ambulanceId = _toString(
      json['assigned_ambulance_id'] ?? json['ambulance_id'],
    );

    return Mission(
      id: _toString(json['id']),
      tenantId: _toNullableString(json['tenant_id']),
      missionNumber: json['mission_number'] as String? ?? 'N/A',
      missionDate: json['mission_date'] as String? ?? '',
      fromLocation: json['from_location'] as String? ?? '',
      toLocation: json['to_location'] as String? ?? '',
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      status: json['status'] as String? ?? 'pending',
      dispatchPhase: dispatchPhase,
      assignedCompanyId: _toNullableString(json['assigned_company_id']),
      selectedProviderTenantId:
          _toNullableString(json['selected_provider_tenant_id']),
      priority: json['priority'] as String? ?? 'normal',
      ambulanceId: ambulanceId,
      assignedAmbulanceId: _toNullableString(json['assigned_ambulance_id']),
      driverName: json['driver_name'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      infirmierName: json['infirmier_name'] as String?,
      paymentType: json['payment_type'] as String?,
      isPaid: json['payment_status'] as bool?,
      guarantee: json['guarantee'] as String?,
      patientFirstName: json['patient_first_name'] as String?,
      patientLastName: json['patient_last_name'] as String?,
      patientAge: _toNullableString(json['patient_age']),
      notes: json['notes'] as String?,
      missionPrice: _toNullableString(json['mission_price']),
      medicalHistory: _toStringList(json['medical_history']),
      vitalSigns: _toMap(json['vital_signs']),
      patientNeeds: _toPatientNeedsMap(json['patient_needs']),
      medications: _toMedicationList(json['medications']),
      fracturesInjuries: json['fractures_injuries'] as String?,
      reportType: json['report_type'] as String?,
      reportFilledAt: json['report_filled_at'] as String?,
      clinicTenantId: _toNullableString(json['clinic_tenant_id']),
      clinicName: json['clinic_name'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
      pickupLat: _toNullableString(json['pickup_lat']),
      pickupLng: _toNullableString(json['pickup_lng']),
      destinationLat: _toNullableString(json['destination_lat']),
      destinationLng: _toNullableString(json['destination_lng']),
      requirements: _toMap(json['requirements']),
    );
  }

  /// Convert Mission to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'mission_number': missionNumber,
    'mission_date': missionDate,
    'from_location': fromLocation,
    'to_location': toLocation,
    'patient_name': patientName,
    'patient_phone': patientPhone,
    'status': status,
    'dispatch_phase': dispatchPhase,
    'assigned_company_id': assignedCompanyId,
    'selected_provider_tenant_id': selectedProviderTenantId,
    'priority': priority,
    'ambulance_id': ambulanceId,
    'assigned_ambulance_id': assignedAmbulanceId,
    'driver_name': driverName,
    'start_time': startTime,
    'end_time': endTime,
    'infirmier_name': infirmierName,
    'payment_type': paymentType,
    'payment_status': isPaid,
    'guarantee': guarantee,
    'patient_first_name': patientFirstName,
    'patient_last_name': patientLastName,
    'patient_age': patientAge,
    'notes': notes,
    'mission_price': missionPrice,
    'medical_history': medicalHistory,
    'vital_signs': vitalSigns,
    'patient_needs': patientNeeds,
    'medications': medications,
    'fractures_injuries': fracturesInjuries,
    'report_type': reportType,
    'report_filled_at': reportFilledAt,
    'clinic_tenant_id': clinicTenantId,
    'clinic_name': clinicName,
    'pickup_address': pickupAddress,
    'destination_address': destinationAddress,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'destination_lat': destinationLat,
    'destination_lng': destinationLng,
    'requirements': requirements,
  };

  Mission copyWith({
    String? id,
    String? tenantId,
    String? missionNumber,
    String? missionDate,
    String? fromLocation,
    String? toLocation,
    String? patientName,
    String? patientPhone,
    String? status,
    String? dispatchPhase,
    String? assignedCompanyId,
    String? selectedProviderTenantId,
    String? priority,
    String? ambulanceId,
    String? assignedAmbulanceId,
    String? driverName,
    String? startTime,
    String? endTime,
    String? infirmierName,
    String? paymentType,
    bool? isPaid,
    String? guarantee,
    String? patientFirstName,
    String? patientLastName,
    String? patientAge,
    String? notes,
    String? missionPrice,
    List<String>? medicalHistory,
    Map<String, dynamic>? vitalSigns,
    Map<String, dynamic>? patientNeeds,
    List<Map<String, dynamic>>? medications,
    String? fracturesInjuries,
    String? reportType,
    String? reportFilledAt,
    String? clinicTenantId,
    String? clinicName,
    String? pickupAddress,
    String? destinationAddress,
    String? pickupLat,
    String? pickupLng,
    String? destinationLat,
    String? destinationLng,
    Map<String, dynamic>? requirements,
  }) {
    return Mission(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      missionNumber: missionNumber ?? this.missionNumber,
      missionDate: missionDate ?? this.missionDate,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      status: status ?? this.status,
      dispatchPhase: dispatchPhase ?? this.dispatchPhase,
      assignedCompanyId: assignedCompanyId ?? this.assignedCompanyId,
      selectedProviderTenantId:
          selectedProviderTenantId ?? this.selectedProviderTenantId,
      priority: priority ?? this.priority,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      assignedAmbulanceId: assignedAmbulanceId ?? this.assignedAmbulanceId,
      driverName: driverName ?? this.driverName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      infirmierName: infirmierName ?? this.infirmierName,
      paymentType: paymentType ?? this.paymentType,
      isPaid: isPaid ?? this.isPaid,
      guarantee: guarantee ?? this.guarantee,
      patientFirstName: patientFirstName ?? this.patientFirstName,
      patientLastName: patientLastName ?? this.patientLastName,
      patientAge: patientAge ?? this.patientAge,
      notes: notes ?? this.notes,
      missionPrice: missionPrice ?? this.missionPrice,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      patientNeeds: patientNeeds ?? this.patientNeeds,
      medications: medications ?? this.medications,
      fracturesInjuries: fracturesInjuries ?? this.fracturesInjuries,
      reportType: reportType ?? this.reportType,
      reportFilledAt: reportFilledAt ?? this.reportFilledAt,
      clinicTenantId: clinicTenantId ?? this.clinicTenantId,
      clinicName: clinicName ?? this.clinicName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      requirements: requirements ?? this.requirements,
    );
  }

  String? get pickupGoogleMapsUrl =>
      requirements?['pickupGoogleMapsUrl']?.toString();

  String? get destinationGoogleMapsUrl =>
      requirements?['destinationGoogleMapsUrl']?.toString();

  bool get isGuestPatientMission {
    final requestSource = requirements?['requestSource']?.toString().trim();
    final guestRequest = requirements?['guestRequest'] == true;
    return requestSource == 'patient_guest' ||
        guestRequest ||
        missionNumber.startsWith('GUEST-');
  }

  String? get requestedAmbulanceNumber {
    final value = requirements?['requestedAmbulanceNumber']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get requestedCompanyName {
    final value = requirements?['requestedCompanyName']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Map<String, dynamic>? get missionPhoto {
    final raw = requirements?['missionPhoto'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  String? get missionPhotoBucket {
    final value = missionPhoto?['bucket']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get missionPhotoPath {
    final value = missionPhoto?['path']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasMissionPhoto =>
      missionPhotoBucket != null && missionPhotoPath != null;

  Map<String, dynamic> get patientRequestDetails {
    final raw = requirements?['patientRequestDetails'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  String? get patientRequestType =>
      _cleanDisplayString(patientRequestDetails['requestType']);

  String? get patientRequestMobility =>
      _cleanDisplayString(patientRequestDetails['mobility']);

  String? get patientRequestDestination =>
      _cleanDisplayString(patientRequestDetails['destination']);

  String? get patientRequestScheduledAt {
    final raw = _cleanDisplayString(patientRequestDetails['scheduledAt']);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month ${hour}h$minute';
  }

  String? get patientConditionSummary => _cleanDisplayString(notes);

  List<String> get patientNeedLabels {
    final labels = <String>[];
    final rawNeeds = patientRequestDetails['medicalNeeds'];

    if (rawNeeds is List) {
      for (final item in rawNeeds) {
        if (item is Map) {
          final label = _cleanDisplayString(item['label'] ?? item['name']);
          if (label != null) labels.add(label);
        } else {
          final label = _cleanDisplayString(item);
          if (label != null) labels.add(label);
        }
      }
    }

    patientNeeds?.forEach((key, value) {
      if (value is Map) {
        final label = _cleanDisplayString(value['label'] ?? value['name']);
        if (label != null) {
          labels.add(label);
          return;
        }
      }
      final label = _cleanDisplayString(key);
      if (label != null) labels.add(label);
    });

    return labels.toSet().toList();
  }

  bool get hasPatientRequestDetails =>
      patientRequestDetails.isNotEmpty ||
      patientRequestType != null ||
      patientRequestMobility != null ||
      patientRequestDestination != null ||
      patientRequestScheduledAt != null ||
      patientConditionSummary != null ||
      patientNeedLabels.isNotEmpty;

  String get pickupDisplayLabel {
    final address = pickupAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    if (fromLocation.trim().isNotEmpty) {
      return fromLocation;
    }
    return 'Aucune localisation';
  }

  static String? _cleanDisplayString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'null' ||
        text.toLowerCase() == 'destination to be confirmed') {
      return null;
    }
    return text;
  }

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

  // Helper to safely convert value to a list of strings.
  static List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        // Handle multi-level JSON encoding
        dynamic decoded = value;
        int decodeAttempts = 0;
        while (decoded is String && decoded.isNotEmpty && decodeAttempts < 3) {
          decoded = jsonDecode(decoded);
          decodeAttempts++;
        }

        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Helper to safely convert value to a string-keyed map.
  static Map<String, dynamic>? _toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        // Handle multi-level JSON encoding
        dynamic decoded = value;
        int decodeAttempts = 0;
        while (decoded is String && decoded.isNotEmpty && decodeAttempts < 3) {
          decoded = jsonDecode(decoded);
          decodeAttempts++;
        }

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Helper to convert patient needs data
  /// Database stores as: [{"name": "Oxygène", "quantity": "2", "type": "...", "children": [...]}, ...]
  /// Returns the data as-is or converts from JSON string
  static Map<String, dynamic>? _toPatientNeedsMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      // Already a Map, return as-is
      return value;
    }

    if (value is String && value.isNotEmpty) {
      try {
        // Handle multi-level JSON encoding
        dynamic decoded = value;
        int decodeAttempts = 0;
        while (decoded is String && decoded.isNotEmpty && decodeAttempts < 3) {
          decoded = jsonDecode(decoded);
          decodeAttempts++;
        }

        // Handle List format: [{"name": "...", "quantity": "...", "children": [...]}, ...]
        if (decoded is List) {
          // Return as-is for PDF to process, but wrap in a map for compatibility
          // The PDF service expects a Map, but we need to preserve the List structure
          // Create a Map where each item's name is the key and the full object is the value
          Map<String, dynamic> result = {};
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              final name = (item['name'] ?? item['label'])?.toString();
              if (name == null || name.trim().isEmpty) continue;
              // Preserve the entire structure including children
              result[name] = item;
            }
          }
          return result.isNotEmpty ? result : null;
        }

        // Handle Map format: {"oxygen": "2", "perfusion": "01", ...}
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        return null;
      }
    }

    // Handle List format directly (if it's already parsed as a List)
    if (value is List) {
      Map<String, dynamic> result = {};
      for (var item in value) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] ?? item['label'])?.toString();
          if (name == null || name.trim().isEmpty) continue;
          // Preserve entire structure including children
          result[name] = item;
        }
      }
      return result.isNotEmpty ? result : null;
    }

    return null;
  }

  static List<Map<String, dynamic>>? _toMedicationList(dynamic value) {
    if (value == null) return null;

    dynamic decoded = value;
    if (decoded is String && decoded.isNotEmpty) {
      try {
        int decodeAttempts = 0;
        while (decoded is String && decoded.isNotEmpty && decodeAttempts < 3) {
          decoded = jsonDecode(decoded);
          decodeAttempts++;
        }
      } catch (_) {
        return null;
      }
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return null;
  }
}

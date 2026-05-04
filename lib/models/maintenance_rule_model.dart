class MaintenanceRule {
  final String id;
  final String tenantId;
  final String maintenanceType;
  final int? intervalKm;
  final int? intervalDays;
  final int? warningBeforeKm;
  final int? warningBeforeDays;
  final bool enabled;

  const MaintenanceRule({
    required this.id,
    required this.tenantId,
    required this.maintenanceType,
    this.intervalKm,
    this.intervalDays,
    this.warningBeforeKm,
    this.warningBeforeDays,
    this.enabled = true,
  });

  bool get hasCondition => intervalKm != null || intervalDays != null;

  factory MaintenanceRule.fromJson(Map<String, dynamic> json) {
    return MaintenanceRule(
      id: _toString(json['id']),
      tenantId: _toString(json['tenant_id']),
      maintenanceType: _toString(json['maintenance_type']),
      intervalKm: _toIntNullable(json['interval_km']),
      intervalDays: _toIntNullable(json['interval_days']),
      warningBeforeKm: _toIntNullable(json['warning_before_km']),
      warningBeforeDays: _toIntNullable(json['warning_before_days']),
      enabled: json['enabled'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'maintenance_type': maintenanceType,
    'interval_km': intervalKm,
    'interval_days': intervalDays,
    'warning_before_km': warningBeforeKm,
    'warning_before_days': warningBeforeDays,
    'enabled': enabled,
  };

  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }
}

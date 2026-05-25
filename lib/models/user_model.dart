/// User Model
/// Represents a user in the system
class User {
  final String id;
  final String name;
  final String email;
  final String? role;
  final String? roleLabel;
  final String? tenantId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.roleLabel,
    this.tenantId,
  });

  /// Factory constructor to create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _toString(json['id']),
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      roleLabel: json['roleLabel'] as String?,
      tenantId: json['tenantId'] as String? ?? json['tenant_id'] as String?,
    );
  }

  /// Helper to safely convert any value to string
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'roleLabel': roleLabel,
        'tenantId': tenantId,
      };

  /// Create a copy with modified fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? roleLabel,
    String? tenantId,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      roleLabel: roleLabel ?? this.roleLabel,
      tenantId: tenantId ?? this.tenantId,
    );
  }
}

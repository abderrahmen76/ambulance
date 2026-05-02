import '../models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class CompanyStaffService {
  Future<List<User>> getCompanyStaff(String tenantId) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_users',
      body: {
        'action': 'list_company_staff',
        'tenant_id': tenantId,
      },
    );
    final rows = List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['users'] ?? const [],
    );

    return rows
        .map(User.fromJson)
        .where(
          (user) => user.name.trim().isNotEmpty && user.role != 'admin',
        )
        .toList();
  }

  Future<List<User>> getCompanyDrivers(String tenantId) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_users',
      body: {
        'action': 'list_company_drivers',
        'tenant_id': tenantId,
      },
    );
    final rows = List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['users'] ?? const [],
    );

    return rows
        .map(User.fromJson)
        .where((user) => user.name.trim().isNotEmpty)
        .toList();
  }
}

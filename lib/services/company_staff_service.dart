import '../models/user_model.dart';
import 'app_memory_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class CompanyStaffService {
  Future<List<User>> getCompanyStaff(String tenantId) async {
    final cacheKey = 'staff:$tenantId';
    final cachedRows = CompanyStaffCache.list.get(cacheKey);
    if (cachedRows != null) {
      return _mapStaffRows(cachedRows);
    }

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
    CompanyStaffCache.list.set(cacheKey, rows);

    return _mapStaffRows(rows);
  }

  Future<List<User>> getCompanyDrivers(String tenantId) async {
    final cacheKey = 'drivers:$tenantId';
    final cachedRows = CompanyStaffCache.list.get(cacheKey);
    if (cachedRows != null) {
      return _mapDriverRows(cachedRows);
    }

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
    CompanyStaffCache.list.set(cacheKey, rows);

    return _mapDriverRows(rows);
  }

  List<User> _mapStaffRows(List<dynamic> rows) {
    return rows
        .map((row) => User.fromJson(Map<String, dynamic>.from(row as Map)))
        .where(
          (user) => user.name.trim().isNotEmpty && user.role != 'admin',
        )
        .toList();
  }

  List<User> _mapDriverRows(List<dynamic> rows) {
    return rows
        .map((row) => User.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((user) => user.name.trim().isNotEmpty)
        .toList();
  }
}

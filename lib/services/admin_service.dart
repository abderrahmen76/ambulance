import '../config/constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// Admin Service
/// Handles CRUD operations for admin dashboard
/// Manages: Tenants, Users, Ambulances
class AdminService {
  static final AdminService _instance = AdminService._internal();
  final ApiClient _apiClient = ApiClient();

  factory AdminService() {
    return _instance;
  }

  AdminService._internal();

  // ==========================================
  // TENANTS CRUD
  // ==========================================

  /// Get all tenants (admin only)
  Future<List<Map<String, dynamic>>> getAllTenants() async {
    try {
      print('[AdminService] Fetching all tenants...');
      final tenants = await _apiClient.get('/rest/v1/tenants');
      print('[AdminService] Found ${tenants.length} tenants');
      return tenants;
    } catch (e) {
      print('[AdminService] Error fetching tenants: $e');
      rethrow;
    }
  }

  /// Get single tenant by ID
  Future<Map<String, dynamic>?> getTenantById(String tenantId) async {
    try {
      print('[AdminService] Fetching tenant: $tenantId');
      final response = await _apiClient.get(
        '/rest/v1/tenants',
        filters: {'id': 'eq.$tenantId'},
      );
      if (response.isEmpty) return null;
      return response.first;
    } catch (e) {
      print('[AdminService] Error fetching tenant: $e');
      rethrow;
    }
  }

  /// Create new tenant
  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String slug,
    String? description,
    String subscriptionTier = 'basic',
    int maxAmbulances = 10,
    int maxUsers = 50,
  }) async {
    try {
      print('[AdminService] Creating tenant: $name (slug: $slug)');
      final response = await _apiClient.post('/rest/v1/tenants', {
        'name': name,
        'slug': slug,
        'description': description ?? '',
        'subscription_tier': subscriptionTier,
        'max_ambulances': maxAmbulances,
        'max_users': maxUsers,
        'subscription_status': 'active',
      });
      print('[AdminService] Tenant created successfully');
      return response;
    } catch (e) {
      print('[AdminService] Error creating tenant: $e');
      rethrow;
    }
  }

  /// Update tenant
  Future<void> updateTenant(
    String tenantId, {
    String? name,
    String? description,
    String? subscriptionTier,
    String? subscriptionStatus,
    int? maxAmbulances,
    int? maxUsers,
  }) async {
    try {
      print('[AdminService] Updating tenant: $tenantId');
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (subscriptionTier != null)
        updateData['subscription_tier'] = subscriptionTier;
      if (subscriptionStatus != null)
        updateData['subscription_status'] = subscriptionStatus;
      if (maxAmbulances != null) updateData['max_ambulances'] = maxAmbulances;
      if (maxUsers != null) updateData['max_users'] = maxUsers;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _apiClient.patch(
        '/rest/v1/tenants?id=eq.$tenantId',
        updateData,
      );
      print('[AdminService] Tenant updated successfully');
    } catch (e) {
      print('[AdminService] Error updating tenant: $e');
      rethrow;
    }
  }

  /// Delete tenant
  Future<void> deleteTenant(String tenantId) async {
    try {
      print('[AdminService] Deleting tenant: $tenantId');
      await _apiClient.delete('/rest/v1/tenants', tenantId);
      print('[AdminService] Tenant deleted successfully');
    } catch (e) {
      print('[AdminService] Error deleting tenant: $e');
      rethrow;
    }
  }

  // ==========================================
  // USERS CRUD
  // ==========================================

  /// Get all users (admin - cross-tenant)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      print('[AdminService] Fetching all users...');
      final response = await Supabase.instance.client.functions.invoke(
        'secure_users',
        body: {
          'action': 'admin_list_all',
        },
      );
      final users = List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['users'] ?? const [],
      );
      print('[AdminService] Found ${users.length} users');
      return users;
    } catch (e) {
      print('[AdminService] Error fetching users: $e');
      rethrow;
    }
  }

  /// Get users for specific tenant
  Future<List<Map<String, dynamic>>> getUsersByTenant(String tenantId) async {
    try {
      print('[AdminService] Fetching users for tenant: $tenantId');
      final response = await Supabase.instance.client.functions.invoke(
        'secure_users',
        body: {
          'action': 'admin_list_by_tenant',
          'tenant_id': tenantId,
        },
      );
      final users = List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['users'] ?? const [],
      );
      print('[AdminService] Found ${users.length} users in tenant');
      return users;
    } catch (e) {
      print('[AdminService] Error fetching tenant users: $e');
      rethrow;
    }
  }

  /// Get single user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_users',
        body: {
          'action': 'admin_get_by_id',
          'user_id': userId,
        },
      );
      return (response.data as Map<String, dynamic>?)?['user']
          as Map<String, dynamic>?;
    } catch (e) {
      print('[AdminService] Error fetching user: $e');
      rethrow;
    }
  }

  /// Create new user via secure Edge Function
  /// The Edge Function handles auth user creation with admin privileges
  /// Then inserts user into public.users
  /// This is the SAFE Supabase pattern
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String name,
    required String tenantId,
    required String role,
    String? password,
  }) async {
    try {
      print(
          '[AdminService] Creating user: $email (role: $role, tenant: $tenantId)');

      // Generate temporary password if not provided
      final tempPassword = password ?? _generateTemporaryPassword();
      print('[AdminService] Generated temporary password');

      final supabase = Supabase.instance.client;

      // Refresh session to ensure JWT is valid
      print('[AdminService] Refreshing session...');
      try {
        await supabase.auth.refreshSession();
      } catch (e) {
        print('[AdminService] Warning: Could not refresh session: $e');
      }

      // Get current session for authentication
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated - no valid session');
      }

      // ✅ DEBUG: Print token to verify it's a real JWT
      final token = session.accessToken;
      final tokenStart = token.length > 30 ? token.substring(0, 30) : token;
      print(
          '[AdminService] 🔍 DEBUG: Access token starts with: $tokenStart...');
      print(
          '[AdminService] 🔍 DEBUG: Token is JWT? ${token.startsWith('eyJ')}');
      print(
          '[AdminService] 🔍 DEBUG: Token is anon key? ${token.startsWith('sb_')}');

      print(
          '[AdminService] Session valid. Access token exists: ${session.accessToken.isNotEmpty}');

      print('[AdminService] Calling create_drivers Edge Function...');

      // ✅ CRITICAL: Explicitly pass Authorization header with "Bearer " prefix
      // Supabase Flutter SDK may not do this automatically for Edge Functions
      // The prefix is REQUIRED or Supabase gateway rejects as "Invalid JWT"
      final authorizationHeader = 'Bearer $token';

      print(
          '[AdminService] 🔐 Auth header format: Bearer ${token.substring(0, 30)}...');

      final response = await supabase.functions.invoke(
        'create_drivers',
        body: {
          'email': email,
          'password': tempPassword,
          'name': name,
          'tenant_id': tenantId,
          'role': role,
        },
        headers: {
          'Authorization': authorizationHeader,
        },
      );

      print('[AdminService] ✅ Request body sent:');
      print('[AdminService]   - email: $email');
      print('[AdminService]   - name: $name');
      print('[AdminService]   - role: $role (TYPE: ${role.runtimeType})');
      print('[AdminService]   - tenant_id: $tenantId');
      print('[AdminService] Edge Function Response received');
      print('[AdminService] Response: $response');

      if (response == null) {
        throw Exception('Edge function returned null');
      }

      // Parse response - FunctionResponse.data contains the actual JSON response
      final result = response.data as Map<String, dynamic>;
      final message = result['message'] as String?;

      if (message != null && message.contains('Error')) {
        throw Exception(message);
      }

      final authUserId = result['auth_user_id'] as String?;
      if (authUserId == null) {
        throw Exception('Failed to create auth user');
      }

      print('[AdminService] Auth user created: $authUserId');
      print('[AdminService] User created successfully');
      print('[AdminService] ✅ User: $email | Role: $role | Tenant: $tenantId');
      print(
          '[AdminService] 🔐 Temporary password: $tempPassword (user should change on first login)');

      // Return user data with temporary password
      return {
        ...result,
        'temporary_password': tempPassword,
      };
    } catch (e) {
      print('[AdminService] Error creating user: $e');
      rethrow;
    }
  }

  /// Generate a secure temporary password
  String _generateTemporaryPassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Update user
  Future<void> updateUser(
    String userId, {
    String? name,
    String? email,
    String? tenantId,
    String? role,
    bool? isActive,
  }) async {
    try {
      print('[AdminService] Updating user: $userId');
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (tenantId != null) updateData['tenant_id'] = tenantId;
      if (role != null) updateData['role'] = role;
      if (isActive != null) updateData['is_active'] = isActive;
      await Supabase.instance.client.functions.invoke(
        'secure_users',
        body: {
          'action': 'admin_update_user',
          'user_id': userId,
          'patch': updateData,
        },
      );
      print('[AdminService] User updated successfully');
    } catch (e) {
      print('[AdminService] Error updating user: $e');
      rethrow;
    }
  }

  /// Deactivate user
  Future<void> deactivateUser(String userId) async {
    try {
      print('[AdminService] Deactivating user: $userId');
      await updateUser(userId, isActive: false);
    } catch (e) {
      print('[AdminService] Error deactivating user: $e');
      rethrow;
    }
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    try {
      print('[AdminService] Deleting user: $userId');
      await Supabase.instance.client.functions.invoke(
        'delete_user',
        body: {
          'userId': userId,
        },
      );
      print('[AdminService] User deleted successfully');
    } catch (e) {
      print('[AdminService] Error deleting user: $e');
      rethrow;
    }
  }

  // ==========================================
  // AMBULANCES CRUD
  // ==========================================

  /// Get all ambulances (admin - cross-tenant)
  Future<List<Map<String, dynamic>>> getAllAmbulances() async {
    try {
      print('[AdminService] Fetching all ambulances...');
      final ambulances = await _apiClient.get('/rest/v1/ambulances');
      print('[AdminService] Found ${ambulances.length} ambulances');
      return ambulances;
    } catch (e) {
      print('[AdminService] Error fetching ambulances: $e');
      rethrow;
    }
  }

  /// Get ambulances for specific tenant
  Future<List<Map<String, dynamic>>> getAmbulancesByTenant(
      String tenantId) async {
    try {
      print('[AdminService] Fetching ambulances for tenant: $tenantId');
      final ambulances = await _apiClient.get(
        '/rest/v1/ambulances',
        filters: {'tenant_id': 'eq.$tenantId'},
      );
      print('[AdminService] Found ${ambulances.length} ambulances in tenant');
      return ambulances;
    } catch (e) {
      print('[AdminService] Error fetching tenant ambulances: $e');
      rethrow;
    }
  }

  /// Get single ambulance by ID
  Future<Map<String, dynamic>?> getAmbulanceById(String ambulanceId) async {
    try {
      final response = await _apiClient.get(
        '/rest/v1/ambulances',
        filters: {'id': 'eq.$ambulanceId'},
      );
      if (response.isEmpty) return null;
      return response.first;
    } catch (e) {
      print('[AdminService] Error fetching ambulance: $e');
      rethrow;
    }
  }

  /// Create new ambulance
  Future<Map<String, dynamic>> createAmbulance({
    required String ambulanceNumber,
    required String tenantId,
    String? telephone,
    double? kilometrage,
  }) async {
    try {
      print('[AdminService] Creating ambulance: $ambulanceNumber');
      final response = await _apiClient.post('/rest/v1/ambulances', {
        'ambulance_number': ambulanceNumber,
        'tenant_id': tenantId,
        'telephone': telephone ?? '',
        'kilometrage': kilometrage ?? 0.0,
      });
      print('[AdminService] Ambulance created successfully');
      return response;
    } catch (e) {
      print('[AdminService] Error creating ambulance: $e');
      rethrow;
    }
  }

  /// Update ambulance
  Future<void> updateAmbulance(
    String ambulanceId, {
    String? ambulanceNumber,
    String? telephone,
    String? tenantId,
    String? currentDriverId,
    double? kilometrage,
  }) async {
    try {
      print('[AdminService] Updating ambulance: $ambulanceId');
      final updateData = <String, dynamic>{};
      if (ambulanceNumber != null)
        updateData['ambulance_number'] = ambulanceNumber;
      if (telephone != null) updateData['telephone'] = telephone;
      if (tenantId != null) updateData['tenant_id'] = tenantId;
      if (currentDriverId != null)
        updateData['current_driver_id'] = currentDriverId;
      if (kilometrage != null) updateData['kilometrage'] = kilometrage;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _apiClient.patch(
        '/rest/v1/ambulances?id=eq.$ambulanceId',
        updateData,
      );
      print('[AdminService] Ambulance updated successfully');
    } catch (e) {
      print('[AdminService] Error updating ambulance: $e');
      rethrow;
    }
  }

  /// Delete ambulance
  Future<void> deleteAmbulance(String ambulanceId) async {
    try {
      print('[AdminService] Deleting ambulance: $ambulanceId');
      await _apiClient.delete('/rest/v1/ambulances', ambulanceId);
      print('[AdminService] Ambulance deleted successfully');
    } catch (e) {
      print('[AdminService] Error deleting ambulance: $e');
      rethrow;
    }
  }

  // ==========================================
  // STATISTICS & ANALYTICS
  // ==========================================

  /// Get admin dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      print('[AdminService] Fetching dashboard statistics...');

      final tenants = await getAllTenants();
      final users = await getAllUsers();
      final ambulances = await getAllAmbulances();

      return {
        'total_tenants': tenants.length,
        'total_users': users.length,
        'total_ambulances': ambulances.length,
        'active_tenants':
            tenants.where((t) => t['subscription_status'] == 'active').length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('[AdminService] Error fetching dashboard stats: $e');
      rethrow;
    }
  }
}

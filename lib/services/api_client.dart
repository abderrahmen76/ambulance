import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

/// API Client Service
/// Handles all HTTP requests to Supabase REST API
/// Optimized for fast response times with connection pooling
///
/// ✅ CRITICAL FIX: Now uses authenticated JWT from Supabase session
/// After login, all requests are made as authenticated users (not anonymous)
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final http.Client _client = http.Client();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  /// Get dynamic headers with JWT token if user is authenticated
  /// Otherwise falls back to anonymous key
  /// This is called before EVERY request to ensure we always use the current JWT
  Map<String, String> _getHeaders() {
    try {
      // Try to get authenticated session first
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        // ✅ User is authenticated - use JWT token
        print('   [AUTH] Using authenticated session token');
        return {
          'apikey': SupabaseConfig.anonKey,
          'Authorization':
              'Bearer ${session.accessToken}', // ✅ JWT, not anonKey!
          'Content-Type': 'application/json',
        };
      }
    } catch (e) {
      // If anything fails, fall through to anonymous
      print('   [AUTH] Failed to get session');
    }

    // ❌ No authenticated session - use anonymous key (for login, signup, etc)
    print('   [ANON] Using anonymous key (no active session)');
    return {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      'Content-Type': 'application/json',
    };
  }

  /// Build the full URL for API requests
  String _buildUrl(String endpoint, {Map<String, String>? queryParams}) {
    String url = '${SupabaseConfig.supabaseUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url = '$url?$query';
    }
    return url;
  }

  bool _matchesTableEndpoint(String endpoint, String tablePath) {
    return endpoint == tablePath || endpoint.startsWith('$tablePath?');
  }

  String? _extractEqValueFromEndpoint(String endpoint, String fieldName) {
    final uri = Uri.tryParse('https://local$endpoint');
    if (uri == null) return null;
    final rawValue = uri.queryParameters[fieldName];
    if (rawValue == null || !rawValue.startsWith('eq.')) return null;
    return rawValue;
  }

  String? _extractEqOperandFromEndpoint(String endpoint, String fieldName) {
    final rawValue = _extractEqValueFromEndpoint(endpoint, fieldName);
    if (rawValue == null || rawValue.isEmpty) return null;
    return rawValue.startsWith('eq.') ? rawValue.substring(3) : rawValue;
  }

  Future<List<Map<String, dynamic>>> _invokeSecureUsersGet({
    required String endpoint,
    Map<String, dynamic>? filters,
  }) async {
    Map<String, dynamic> body;

    final idFilter = filters?['id']?.toString();
    final authUserIdFilter = filters?['auth_user_id']?.toString();
    final tenantFilter = filters?['tenant_id']?.toString();
    final roleFilter = filters?['role']?.toString();
    final isActiveFilter = filters?['is_active']?.toString();

    if (authUserIdFilter != null && authUserIdFilter.startsWith('eq.')) {
      body = {
        'action': 'get_self_profile',
      };
      final response = await Supabase.instance.client.functions.invoke(
        'secure_users',
        body: body,
      );
      final user = (response.data as Map<String, dynamic>?)?['user'];
      if (user == null) {
        return [];
      }
      return [Map<String, dynamic>.from(user as Map)];
    }

    if (idFilter != null && idFilter.startsWith('eq.')) {
      body = {
        'action': 'admin_get_by_id',
        'user_id': idFilter.substring(3),
      };
      final response =
          await Supabase.instance.client.functions.invoke('secure_users', body: body);
      final user = (response.data as Map<String, dynamic>?)?['user'];
      if (user == null) {
        return [];
      }
      return [Map<String, dynamic>.from(user as Map)];
    }

    if (tenantFilter != null && tenantFilter.startsWith('eq.')) {
      final tenantId = tenantFilter.substring(3);
      if (roleFilter == 'eq.driver' && isActiveFilter == 'eq.true') {
        body = {
          'action': 'list_company_drivers',
          'tenant_id': tenantId,
        };
        final response = await Supabase.instance.client.functions
            .invoke('secure_users', body: body);
        return List<Map<String, dynamic>>.from(
          (response.data as Map<String, dynamic>?)?['users'] ?? const [],
        );
      }

      if (isActiveFilter == 'eq.true') {
        body = {
          'action': 'list_company_staff',
          'tenant_id': tenantId,
        };
        final response = await Supabase.instance.client.functions
            .invoke('secure_users', body: body);
        return List<Map<String, dynamic>>.from(
          (response.data as Map<String, dynamic>?)?['users'] ?? const [],
        );
      }

      body = {
        'action': 'admin_list_by_tenant',
        'tenant_id': tenantId,
      };
      final response =
          await Supabase.instance.client.functions.invoke('secure_users', body: body);
      return List<Map<String, dynamic>>.from(
        (response.data as Map<String, dynamic>?)?['users'] ?? const [],
      );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'secure_users',
      body: {
        'action': 'admin_list_all',
      },
    );
    return List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['users'] ?? const [],
    );
  }

  Future<List<Map<String, dynamic>>> _invokeSecureEquipmentGet({
    required String endpoint,
    Map<String, dynamic>? filters,
  }) async {
    if (filters != null && filters['ambulance_id'] != null) {
      final ambulanceFilter = filters['ambulance_id'].toString();
      if (ambulanceFilter.startsWith('eq.')) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_equipment_rentals',
          body: {
            'action': 'list_by_ambulance',
            'ambulance_id': ambulanceFilter.substring(3),
          },
        );
        return List<Map<String, dynamic>>.from(
          (response.data as Map<String, dynamic>?)?['rentals'] ?? const [],
        );
      }
    }

    final metadataFilter =
        _extractEqValueFromEndpoint(endpoint, 'metadata');
    if (metadataFilter == 'oxygen_inventory') {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_equipment_rentals',
        body: {
          'action': 'get_inventory',
        },
      );
      final inventory = (response.data as Map<String, dynamic>?)?['inventory'];
      if (inventory == null) {
        return [];
      }
      return [Map<String, dynamic>.from(inventory as Map)];
    }

    final response = await Supabase.instance.client.functions.invoke(
      'secure_equipment_rentals',
      body: {
        'action': 'list_all',
      },
    );
    return List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['rentals'] ?? const [],
    );
  }

  Future<List<Map<String, dynamic>>> _invokeSecureFuelCardsGet({
    required String endpoint,
    Map<String, dynamic>? filters,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final idFilter =
        filters?['id']?.toString() ?? _extractEqValueFromEndpoint(endpoint, 'id');
    if (idFilter != null && idFilter.isNotEmpty) {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_fuel_cards',
        body: {
          'action': 'get_by_id',
          'fuel_card_id': idFilter.startsWith('eq.')
              ? idFilter.substring(3)
              : idFilter,
        },
      );
      final fuelCard = (response.data as Map<String, dynamic>?)?['fuel_card'];
      if (fuelCard == null) {
        return [];
      }
      return [Map<String, dynamic>.from(fuelCard as Map)];
    }

    final ambulanceFilter = filters?['ambulance_id']?.toString() ??
        _extractEqValueFromEndpoint(endpoint, 'ambulance_id');
    if (ambulanceFilter != null && ambulanceFilter.isNotEmpty) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_fuel_cards',
          body: {
            'action': 'list_by_ambulance',
            'ambulance_id': ambulanceFilter.startsWith('eq.')
                ? ambulanceFilter.substring(3)
                : ambulanceFilter,
            'order_by': orderBy,
            'limit': limit,
            'offset': offset,
          },
        );
        return List<Map<String, dynamic>>.from(
          (response.data as Map<String, dynamic>?)?['fuel_cards'] ?? const [],
        );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'secure_fuel_cards',
      body: {
        'action': 'list_all',
        'order_by': orderBy,
        'limit': limit,
        'offset': offset,
      },
    );
    return List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['fuel_cards'] ?? const [],
    );
  }

  Future<List<Map<String, dynamic>>> _invokeSecureMaintenanceGet({
    required String endpoint,
    Map<String, dynamic>? filters,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final idFilter =
        filters?['id']?.toString() ?? _extractEqValueFromEndpoint(endpoint, 'id');
    if (idFilter != null && idFilter.isNotEmpty) {
      final response = await Supabase.instance.client.functions.invoke(
        'secure_maintenance_records',
        body: {
          'action': 'get_by_id',
          'record_id': idFilter.startsWith('eq.')
              ? idFilter.substring(3)
              : idFilter,
        },
      );
      final record =
          (response.data as Map<String, dynamic>?)?['maintenance_record'];
      if (record == null) {
        return [];
      }
      return [Map<String, dynamic>.from(record as Map)];
    }

    final ambulanceFilter = filters?['ambulance_id']?.toString() ??
        _extractEqValueFromEndpoint(endpoint, 'ambulance_id');
    if (ambulanceFilter != null && ambulanceFilter.isNotEmpty) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_maintenance_records',
          body: {
            'action': 'list_by_ambulance',
            'ambulance_id': ambulanceFilter.startsWith('eq.')
                ? ambulanceFilter.substring(3)
                : ambulanceFilter,
            'order_by': orderBy,
            'limit': limit,
            'offset': offset,
          },
        );
        return List<Map<String, dynamic>>.from(
          (response.data as Map<String, dynamic>?)?['maintenance_records'] ??
              const [],
        );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'secure_maintenance_records',
      body: {
        'action': 'list_all',
        'order_by': orderBy,
        'limit': limit,
        'offset': offset,
      },
    );
    return List<Map<String, dynamic>>.from(
      (response.data as Map<String, dynamic>?)?['maintenance_records'] ??
          const [],
    );
  }

  /// GET request with query filters, ordering, and pagination
  /// Optimized for fast responses
  /// ✅ Now uses authenticated JWT (if available)
  Future<List<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? filters,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      if (_matchesTableEndpoint(endpoint, '/rest/v1/users')) {
        return await _invokeSecureUsersGet(endpoint: endpoint, filters: filters);
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.equipmentRentalsTable)) {
        return await _invokeSecureEquipmentGet(endpoint: endpoint, filters: filters);
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.fuelCardsTable)) {
        return await _invokeSecureFuelCardsGet(
          endpoint: endpoint,
          filters: filters,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.maintenanceRecordsTable)) {
        return await _invokeSecureMaintenanceGet(
          endpoint: endpoint,
          filters: filters,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        );
      }

      final apiStopwatch = Stopwatch()..start();
      print('   [HTTP] GET $endpoint');
      if (filters != null) {
        print('   [HTTP] Filters provided');
      }
      if (orderBy != null) {
        print('   [HTTP] OrderBy: $orderBy');
      }
      if (limit != null) {
        print('   [HTTP] Limit: $limit');
      }
      if (offset != null) {
        print('   ↪️  Offset: $offset');
      }

      final queryParams = _buildFilterQuery(filters,
          orderBy: orderBy, limit: limit, offset: offset);
      final url = _buildUrl(endpoint, queryParams: queryParams);

      final response = await _client
          .get(
            Uri.parse(url),
            headers: _getHeaders(), // ✅ Dynamic headers with JWT
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      apiStopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
            '   ✅ Response OK - ${(data is List ? data.length : 1)} record(s) - ${apiStopwatch.elapsedMilliseconds}ms');
        return List<Map<String, dynamic>>.from(data ?? []);
      } else if (response.statusCode == 401) {
        print(
            '   ❌ Unauthorized (401) - ${apiStopwatch.elapsedMilliseconds}ms');
        throw UnauthorizedException('Unauthorized access');
      } else {
        print(
            '   ❌ HTTP ${response.statusCode} - ${apiStopwatch.elapsedMilliseconds}ms');
        throw ApiException('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Error: $e');
      rethrow;
    }
  }

  /// POST request
  /// ✅ Now uses authenticated JWT (if available)
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      if (_matchesTableEndpoint(endpoint, '/rest/v1/user_fcm_tokens')) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_user_fcm_tokens',
          body: {
            'action': 'register',
            'fcm_token': body['fcm_token'],
            'device_name': body['device_name'],
          },
        );
        return Map<String, dynamic>.from(
          (response.data as Map<String, dynamic>?) ?? const {},
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.equipmentRentalsTable)) {
        if (body['metadata'] == 'oxygen_inventory') {
          final response = await Supabase.instance.client.functions.invoke(
            'secure_equipment_rentals',
            body: {
              'action': 'set_inventory',
              'quantity': body['quantity'] ?? 0,
            },
          );
          return Map<String, dynamic>.from(
            (response.data as Map<String, dynamic>?) ?? const {},
          );
        }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_equipment_rentals',
          body: {
            'action': 'create',
            'data': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['rental'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.fuelCardsTable)) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_fuel_cards',
          body: {
            'action': 'create',
            'data': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['fuel_card'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.maintenanceRecordsTable)) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_maintenance_records',
          body: {
            'action': 'create',
            'data': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['maintenance_record']
                  as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.missionsTable)) {
        final response = await Supabase.instance.client.functions.invoke(
          'secure_mission_phi',
          body: {
            'action': 'create_company_mission',
            'data': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['mission'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      final url = _buildUrl(endpoint);

      final response = await _client
          .post(
            Uri.parse(url),
            headers: _getHeaders(), // ✅ Dynamic headers with JWT
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Handle empty response body (Supabase sometimes returns no body on successful POST)
        if (response.body.isEmpty) {
          return {};
        }
        return jsonDecode(response.body) ?? {};
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized access');
      } else {
        // Log detailed error response
        print('❌ POST Error ${response.statusCode}:');
        print('   📋 URL: $url');
        print('   📄 Response body: ${response.body}');
        throw ApiException(
            'Failed to create resource: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// PATCH request
  /// ✅ Now uses authenticated JWT (if available)
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      if (_matchesTableEndpoint(endpoint, '/rest/v1/users')) {
        final userId = _extractEqValueFromEndpoint(endpoint, 'id');
        if (userId == null || userId.isEmpty) {
          throw ApiException('Missing user id for secure user update.');
        }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_users',
          body: {
            'action': 'admin_update_user',
            'user_id': userId,
            'patch': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['user'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.equipmentRentalsTable)) {
          final rentalId = _extractEqOperandFromEndpoint(endpoint, 'id');
          if (rentalId == null || rentalId.isEmpty) {
            throw ApiException('Missing rental id for secure equipment update.');
          }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_equipment_rentals',
          body: {
            'action': 'update',
            'rental_id': rentalId,
            'patch': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['rental'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.fuelCardsTable)) {
          final fuelCardId = _extractEqOperandFromEndpoint(endpoint, 'id');
          if (fuelCardId == null || fuelCardId.isEmpty) {
            throw ApiException('Missing fuel card id for secure fuel card update.');
          }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_fuel_cards',
          body: {
            'action': 'update',
            'fuel_card_id': fuelCardId,
            'patch': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['fuel_card'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.maintenanceRecordsTable)) {
          final recordId = _extractEqOperandFromEndpoint(endpoint, 'id');
          if (recordId == null || recordId.isEmpty) {
            throw ApiException(
                'Missing maintenance record id for secure maintenance update.');
        }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_maintenance_records',
          body: {
            'action': 'update',
            'record_id': recordId,
            'patch': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['maintenance_record']
                  as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.missionsTable)) {
        final missionId = _extractEqOperandFromEndpoint(endpoint, 'id');
        if (missionId == null || missionId.isEmpty) {
          throw ApiException('Missing mission id for secure mission update.');
        }

        final response = await Supabase.instance.client.functions.invoke(
          'secure_mission_phi',
          body: {
            'action': 'update_company_mission',
            'mission_id': missionId,
            'patch': body,
          },
        );
        return Map<String, dynamic>.from(
          ((response.data as Map<String, dynamic>?)?['mission'] as Map?) ??
              ((response.data as Map<String, dynamic>?) ?? const {}),
        );
      }

      final url = _buildUrl(endpoint);

      final response = await _client
          .patch(
            Uri.parse(url),
            headers: _getHeaders(), // ✅ Dynamic headers with JWT
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 204 No Content is also a success (common for PATCH operations)
        if (response.body.isEmpty) {
          return {};
        }
        return jsonDecode(response.body) ?? {};
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized access');
      } else {
        // Log detailed error response
        print('❌ PATCH Error ${response.statusCode}:');
        print('   📋 URL: $url');
        print('   📄 Response body: ${response.body}');
        throw ApiException('Failed to update resource: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE request with filters
  /// ✅ Now uses authenticated JWT (if available)
  Future<void> deleteWithFilters(
    String endpoint,
    Map<String, dynamic> filters,
  ) async {
    try {
      if (_matchesTableEndpoint(endpoint, '/rest/v1/user_fcm_tokens')) {
        final fcmToken = filters['fcm_token']?.toString();
        if (fcmToken == null || !fcmToken.startsWith('eq.')) {
          throw ApiException('Missing fcm token for secure token removal.');
        }
        await Supabase.instance.client.functions.invoke(
          'secure_user_fcm_tokens',
          body: {
            'action': 'remove',
            'fcm_token': fcmToken.substring(3),
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.fuelCardsTable)) {
        final fuelCardId = filters['id']?.toString();
        if (fuelCardId == null || !fuelCardId.startsWith('eq.')) {
          throw ApiException('Missing fuel card id for secure fuel card deletion.');
        }
        await Supabase.instance.client.functions.invoke(
          'secure_fuel_cards',
          body: {
            'action': 'delete',
            'fuel_card_id': fuelCardId.substring(3),
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.maintenanceRecordsTable)) {
        final recordId = filters['id']?.toString();
        if (recordId == null || !recordId.startsWith('eq.')) {
          throw ApiException(
              'Missing maintenance record id for secure maintenance deletion.');
        }
        await Supabase.instance.client.functions.invoke(
          'secure_maintenance_records',
          body: {
            'action': 'delete',
            'record_id': recordId.substring(3),
          },
        );
        return;
      }

      final queryParams = _buildFilterQuery(filters);
      final url = _buildUrl(endpoint, queryParams: queryParams);

      final response = await _client
          .delete(
            Uri.parse(url),
            headers: _getHeaders(), // ✅ Dynamic headers with JWT
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 204 No Content is also a success (common for DELETE operations)
        print('✅ DELETE successful for $endpoint with filters: $filters');
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized access');
      } else {
        print('❌ DELETE Error ${response.statusCode}:');
        print('   📋 URL: $url');
        throw ApiException('Failed to delete resource: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE request
  Future<void> delete(
    String endpoint,
    String id,
  ) async {
    try {
      if (_matchesTableEndpoint(endpoint, '/rest/v1/users')) {
        await Supabase.instance.client.functions.invoke(
          'delete_user',
          body: {
            'userId': id,
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.equipmentRentalsTable)) {
        await Supabase.instance.client.functions.invoke(
          'secure_equipment_rentals',
          body: {
            'action': 'delete',
            'rental_id': id,
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.fuelCardsTable)) {
        await Supabase.instance.client.functions.invoke(
          'secure_fuel_cards',
          body: {
            'action': 'delete',
            'fuel_card_id': id,
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.maintenanceRecordsTable)) {
        await Supabase.instance.client.functions.invoke(
          'secure_maintenance_records',
          body: {
            'action': 'delete',
            'record_id': id,
          },
        );
        return;
      }

      if (_matchesTableEndpoint(endpoint, SupabaseConfig.missionsTable)) {
        await Supabase.instance.client.functions.invoke(
          'secure_mission_phi',
          body: {
            'action': 'delete_company_mission',
            'mission_id': id,
          },
        );
        return;
      }

      final url = '${_buildUrl(endpoint)}?id=eq.$id';

      final response = await _client
          .delete(
            Uri.parse(url),
            headers: _getHeaders(),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 204 No Content is also a success (common for DELETE operations)
        print('✅ DELETE successful for $endpoint with id: $id');
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Unauthorized access');
      } else {
        print('❌ DELETE Error ${response.statusCode}:');
        print('   📋 URL: $url');
        throw ApiException('Failed to delete resource: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Filter builder for Supabase REST API
  /// Supports filters (eq=value, gt=value, lt=value, etc), ordering, limit, and offset
  Map<String, String> _buildFilterQuery(
    Map<String, dynamic>? filters, {
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final queryParams = <String, String>{};

    // Add filters
    if (filters != null) {
      filters.forEach((key, value) {
        queryParams[key] = value.toString();
      });
    }

    // Add ordering (format: column.asc or column.desc)
    if (orderBy != null) {
      queryParams['order'] = orderBy;
    }

    // Add limit
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }

    // Add offset
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }

    return queryParams;
  }

  /// Dispose the client (optional cleanup)
  void dispose() {
    _client.close();
  }
}

/// Custom API Exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

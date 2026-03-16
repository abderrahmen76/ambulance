import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// API Client Service
/// Handles all HTTP requests to Supabase REST API
/// Optimized for fast response times with connection pooling
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final http.Client _client = http.Client();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  /// Build the full URL for API requests
  String _buildUrl(String endpoint, {Map<String, String>? queryParams}) {
    String url = '${SupabaseConfig.supabaseUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url = '$url?$query';
    }
    return url;
  }

  /// GET request with query filters, ordering, and pagination
  /// Optimized for fast responses
  Future<List<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, dynamic>? filters,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final apiStopwatch = Stopwatch()..start();
      print('   📡 HTTP GET $endpoint');
      if (filters != null) {
        print('   🔍 Filters: $filters');
      }
      if (orderBy != null) {
        print('   📊 OrderBy: $orderBy');
      }
      if (limit != null) {
        print('   📏 Limit: $limit');
      }
      if (offset != null) {
        print('   ↪️  Offset: $offset');
      }
      
      final queryParams = _buildFilterQuery(filters, orderBy: orderBy, limit: limit, offset: offset);
      final url = _buildUrl(endpoint, queryParams: queryParams);

      final response = await _client.get(
        Uri.parse(url),
        headers: SupabaseConfig.headers,
      ).timeout(
        const Duration(milliseconds: 8000),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      apiStopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('   ✅ Response OK - ${(data is List ? data.length : 1)} record(s) - ${apiStopwatch.elapsedMilliseconds}ms');
        return List<Map<String, dynamic>>.from(data ?? []);
      } else if (response.statusCode == 401) {
        print('   ❌ Unauthorized (401) - ${apiStopwatch.elapsedMilliseconds}ms');
        throw UnauthorizedException('Unauthorized access');
      } else {
        print('   ❌ HTTP ${response.statusCode} - ${apiStopwatch.elapsedMilliseconds}ms');
        throw ApiException('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Error: $e');
      rethrow;
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = _buildUrl(endpoint);

      final response = await _client.post(
        Uri.parse(url),
        headers: SupabaseConfig.headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(milliseconds: 10000),
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
        print('   📦 Request body: $body');
        print('   📄 Response body: ${response.body}');
        throw ApiException('Failed to create resource: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = _buildUrl(endpoint);

      final response = await _client.patch(
        Uri.parse(url),
        headers: SupabaseConfig.headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(milliseconds: 10000),
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
        print('   📦 Request body: $body');
        print('   📄 Response body: ${response.body}');
        throw ApiException('Failed to update resource: ${response.statusCode}');
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
      final url = '${_buildUrl(endpoint)}?id=eq.$id';

      final response = await _client.delete(
        Uri.parse(url),
        headers: SupabaseConfig.headers,
      ).timeout(
        const Duration(milliseconds: 10000),
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

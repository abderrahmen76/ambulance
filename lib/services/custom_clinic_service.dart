import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import 'app_memory_cache_service.dart';
import 'api_client.dart';
import 'performance_log_service.dart';

/// Service for managing custom clinics
/// Stores user-created clinic names by city permanently in Supabase
class CustomClinicService {
  static final CustomClinicService _instance = CustomClinicService._internal();
  final ApiClient _apiClient = ApiClient();

  final Map<String, List<String>> _customClinicsByCity = {};

  factory CustomClinicService() {
    return _instance;
  }

  CustomClinicService._internal();

  /// Get all custom clinics for a specific city
  Future<List<String>> getClinicsByCity(String city) async {
    final cacheKey = city.trim().toLowerCase();
    final cached = CustomClinicsCache.instance.get(cacheKey);
    if (cached != null) {
      _customClinicsByCity[city] = cached;
      return cached;
    }

    await _loadCustomClinicsByCity(city);

    // Return only custom clinics for this city (no built-in clinics)
    final customClinics = _customClinicsByCity[city] ?? [];
    return customClinics;
  }

  /// Get all clinics (built-in + custom) - deprecated, use getClinicsByCity instead
  Future<List<String>> getAllClinics() async {
    return getClinicsByCity('Sfax');
  }

  /// Load custom clinics for a specific city from Supabase
  Future<void> _loadCustomClinicsByCity(String city) async {
    final trace = PerformanceLog.start(
      'custom clinics fetch',
      meta: {'city': city},
    );
    try {
      final result = await _apiClient.get(
        '/rest/v1/custom_clinics',
        filters: {'city': 'eq.$city'},
        limit: 1000,
      );

      final customClinics = (result as List)
          .map((item) => item['clinic_name'] as String)
          .toList();

      _customClinicsByCity[city] = customClinics;
      CustomClinicsCache.instance.set(city.trim().toLowerCase(), customClinics);

      debugPrint(
          '[CustomClinicService] Loaded ${customClinics.length} custom clinics for city: $city');
      trace.end(meta: {'city': city, 'count': customClinics.length});
    } catch (e) {
      debugPrint(
          '[CustomClinicService] Error loading custom clinics for $city: $e');
      _customClinicsByCity[city] = [];
      trace.end(meta: {'city': city, 'error': e.runtimeType});
    }
  }

  /// Add a new custom clinic for a specific city
  Future<bool> addCustomClinic(String clinicName, String city) async {
    final trimmed = clinicName.trim();

    try {
      if (trimmed.isEmpty) {
        debugPrint('[CustomClinicService] Clinic name cannot be empty');
        return false;
      }

      // Check if already exists (case-insensitive)
      final existingClinics = await getClinicsByCity(city);
      if (existingClinics
          .any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        debugPrint('[CustomClinicService] Clinic already exists: $trimmed');
        return false;
      }

      // Save to Supabase with city
      debugPrint(
          '[CustomClinicService] Attempting to insert: clinic_name=$trimmed, city=$city');
      await _apiClient.post(
        '/rest/v1/custom_clinics',
        {'clinic_name': trimmed, 'city': city},
      );

      // Add to local list for the city
      if (!_customClinicsByCity.containsKey(city)) {
        _customClinicsByCity[city] = [];
      }
      _customClinicsByCity[city]!.add(trimmed);
      CustomClinicsCache.instance.remove(city.trim().toLowerCase());

      debugPrint(
          '[CustomClinicService] Added custom clinic: $trimmed for city: $city');
      return true;
    } catch (e) {
      debugPrint(
          '[CustomClinicService] Error adding custom clinic "$trimmed" for $city: $e');

      // Check if it's a duplicate constraint error
      if (e.toString().contains('23505') ||
          e.toString().contains('duplicate')) {
        debugPrint(
            '[CustomClinicService] Clinic already exists for city $city');
      }
      return false;
    }
  }

  /// Delete a custom clinic
  Future<bool> deleteCustomClinic(String clinicName, String city) async {
    try {
      // Delete from Supabase by clinic_name and city
      await _apiClient.deleteWithFilters(
        '/rest/v1/custom_clinics',
        {
          'clinic_name': 'eq.$clinicName',
          'city': 'eq.$city',
        },
      );

      // Remove from local list
      if (_customClinicsByCity.containsKey(city)) {
        _customClinicsByCity[city]!
            .removeWhere((c) => c.toLowerCase() == clinicName.toLowerCase());
      }
      CustomClinicsCache.instance.remove(city.trim().toLowerCase());

      debugPrint(
          '[CustomClinicService] Deleted custom clinic: $clinicName from city: $city');
      return true;
    } catch (e) {
      debugPrint('[CustomClinicService] Error deleting custom clinic: $e');
      return false;
    }
  }

  /// Get clinics with "autre" option
  Future<List<String>> getClinicsWithOther() async {
    final clinics = await getAllClinics();
    return [...clinics, 'Autre (Ajouter une nouvelle)'];
  }
}

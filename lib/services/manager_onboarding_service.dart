import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import 'session_security_service.dart';

class ManagerOnboardingService {
  static final ManagerOnboardingService _instance =
      ManagerOnboardingService._internal();

  factory ManagerOnboardingService() => _instance;

  ManagerOnboardingService._internal();

  final SessionSecurityService _sessionSecurityService =
      SessionSecurityService();

  Future<Map<String, dynamic>> startSignup({
    required String companyName,
    required String companyPhone,
    required String companyCity,
    String? companyAddress,
    required String managerName,
    required String managerEmail,
    required String managerPassword,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'x-app-kind': 'mobile_app',
      },
      body: {
        'action': 'start_signup',
        'company_name': companyName,
        'company_phone': companyPhone,
        'company_city': companyCity,
        'company_address': companyAddress,
        'manager_name': managerName,
        'manager_email': managerEmail,
        'manager_password': managerPassword,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> getOnboardingState() async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'get_onboarding_state',
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> completeManagerSignup() async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'complete_manager_signup',
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> addAmbulance({
    required String ambulanceNumber,
    String? telephone,
    String? kilometrage,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'add_ambulance',
        'ambulance_number': ambulanceNumber,
        'telephone': telephone,
        'kilometrage': kilometrage,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> addDriver({
    required String driverName,
    required String driverEmail,
    required String driverPassword,
    String? driverPhone,
    String? ambulanceId,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'add_driver',
        'driver_name': driverName,
        'driver_email': driverEmail,
        'driver_password': driverPassword,
        'driver_phone': driverPhone,
        'ambulance_id': ambulanceId,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> finishOnboarding() async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'finish_onboarding',
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> updateCompanyValues({
    required String companyName,
    required List<String> companyPhones,
    String? companyDescription,
    String? companyCity,
    String? companyAddress,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'update_company_values',
        'company_name': companyName,
        'company_phones': companyPhones,
        'company_phone': companyPhones.isNotEmpty ? companyPhones.first : null,
        'company_description': companyDescription,
        'company_city': companyCity,
        'company_address': companyAddress,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> updateDriver({
    required String driverId,
    required String driverName,
    required String driverEmail,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'update_driver',
        'driver_id': driverId,
        'driver_name': driverName,
        'driver_email': driverEmail,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> deleteDriver({
    required String driverId,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'delete_driver',
        'driver_id': driverId,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> updateDriverPassword({
    required String driverId,
    required String newPassword,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'update_driver_password',
        'driver_id': driverId,
        'new_password': newPassword,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> updateAmbulance({
    required String ambulanceId,
    required String ambulanceNumber,
    String? telephone,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'update_ambulance',
        'ambulance_id': ambulanceId,
        'ambulance_number': ambulanceNumber,
        'telephone': telephone,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> deleteAmbulance({
    required String ambulanceId,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'secure_manager_onboarding',
      headers: await _sessionSecurityService.buildFunctionHeaders(),
      body: {
        'action': 'delete_ambulance',
        'ambulance_id': ambulanceId,
      },
    );

    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }
}

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
      headers: {'apikey': SupabaseConfig.anonKey, 'x-app-kind': 'mobile_app'},
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

  Future<Map<String, dynamic>> _invokeAuthenticatedFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    Future<FunctionResponse> invoke({required bool forceRefresh}) async {
      return Supabase.instance.client.functions.invoke(
        functionName,
        headers: await _sessionSecurityService.buildFunctionHeaders(
          forceRefresh: forceRefresh,
        ),
        body: body,
      );
    }

    try {
      final response = await invoke(forceRefresh: false);
      return _responseMap(response);
    } on FunctionException catch (error) {
      if (!_isExpiredSessionError(error)) {
        rethrow;
      }

      print(
        '[ManagerOnboardingService] Session rejected; refreshing and retrying ${body["action"]}',
      );
      final response = await invoke(forceRefresh: true);
      return _responseMap(response);
    }
  }

  Map<String, dynamic> _responseMap(FunctionResponse response) {
    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  bool _isExpiredSessionError(FunctionException error) {
    final status = '${error.status}';
    final details = '${error.details}';
    final message = error.toString();
    return status == '401' ||
        details.contains('Invalid or expired session') ||
        message.contains('Invalid or expired session');
  }

  Future<Map<String, dynamic>> getOnboardingState() async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'get_onboarding_state'},
    );
  }

  Future<Map<String, dynamic>> completeManagerSignup() async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'complete_manager_signup'},
    );
  }

  Future<Map<String, dynamic>> addAmbulance({
    required String ambulanceNumber,
    String? telephone,
    String? kilometrage,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'add_ambulance',
        'ambulance_number': ambulanceNumber,
        'telephone': telephone,
        'kilometrage': kilometrage,
      },
    );
  }

  Future<Map<String, dynamic>> addDriver({
    required String driverName,
    required String driverEmail,
    required String driverPassword,
    String? driverPhone,
    String? ambulanceId,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'add_driver',
        'driver_name': driverName,
        'driver_email': driverEmail,
        'driver_password': driverPassword,
        'driver_phone': driverPhone,
        'ambulance_id': ambulanceId,
      },
    );
  }

  Future<Map<String, dynamic>> addManager({
    required String managerName,
    required String managerEmail,
    required String managerPassword,
    String? managerPhone,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'add_manager',
        'manager_name': managerName,
        'manager_email': managerEmail,
        'manager_password': managerPassword,
        'manager_phone': managerPhone,
      },
    );
  }

  Future<Map<String, dynamic>> finishOnboarding() async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'finish_onboarding'},
    );
  }

  Future<Map<String, dynamic>> updateCompanyValues({
    required String companyName,
    required List<String> companyPhones,
    String? companyDescription,
    String? companyCity,
    String? companyAddress,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'update_company_values',
        'company_name': companyName,
        'company_phones': companyPhones,
        'company_description': companyDescription,
        'company_city': companyCity,
        'company_address': companyAddress,
      },
    );
  }

  Future<Map<String, dynamic>> updateDriver({
    required String driverId,
    required String driverName,
    required String driverEmail,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'update_driver',
        'driver_id': driverId,
        'driver_name': driverName,
        'driver_email': driverEmail,
      },
    );
  }

  Future<Map<String, dynamic>> updateManager({
    required String managerId,
    required String managerName,
    required String managerEmail,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'update_manager',
        'manager_id': managerId,
        'manager_name': managerName,
        'manager_email': managerEmail,
      },
    );
  }

  Future<Map<String, dynamic>> deleteManager({required String managerId}) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'delete_manager', 'manager_id': managerId},
    );
  }

  Future<Map<String, dynamic>> deleteDriver({required String driverId}) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'delete_driver', 'driver_id': driverId},
    );
  }

  Future<Map<String, dynamic>> updateDriverPassword({
    required String driverId,
    required String newPassword,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'update_driver_password',
        'driver_id': driverId,
        'new_password': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> updateCompanyUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_users',
      {
        'action': 'company_update_user_password',
        'user_id': userId,
        'new_password': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> updateAmbulance({
    required String ambulanceId,
    required String ambulanceNumber,
    String? telephone,
    String? kilometrage,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {
        'action': 'update_ambulance',
        'ambulance_id': ambulanceId,
        'ambulance_number': ambulanceNumber,
        'telephone': telephone,
        'kilometrage': kilometrage,
      },
    );
  }

  Future<Map<String, dynamic>> deleteAmbulance({
    required String ambulanceId,
  }) async {
    return _invokeAuthenticatedFunction(
      'secure_manager_onboarding',
      {'action': 'delete_ambulance', 'ambulance_id': ambulanceId},
    );
  }
}

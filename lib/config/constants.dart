import 'package:flutter/material.dart';
import 'environment.dart';

/// Supabase Configuration
/// Store all environment variables here for centralized management
class SupabaseConfig {
  // Supabase URL
  static const String supabaseUrl = 'https://uxsimhenmvyessotnnmx.supabase.co';

  // Anonymous key for client-side requests
  static const String anonKey =
      'sb_publishable_nlrCg7avzbCpLMzaAs-MBw_usjdOpTL';

  // Notification Backend Server URL (from environment.dart)
  static String get notificationBackendUrl =>
      EnvironmentConfig.notificationBackendUrl;

  // API endpoints
  static const String usersTable = '/rest/v1/users';
  static const String rolesTable = '/rest/v1/roles';
  static const String roleUserTable = '/rest/v1/role_user';
  static const String userRoleView = '/rest/v1/user_role_view';
  static const String ambulancesTable = '/rest/v1/ambulances';
  static const String missionsTable = '/rest/v1/missions';
  static const String fuelCardsTable = '/rest/v1/fuel_cards';
  static const String maintenanceRecordsTable = '/rest/v1/maintenance_records';
  static const String maintenanceRulesTable = '/rest/v1/maintenance_rules';
  static const String equipmentRentalsTable = '/rest/v1/equipment_rentals';
  static const String driverLocationsTable = '/rest/v1/driver_locations';
  static const String ambulanceLocationSnapshotsTable =
      '/rest/v1/ambulance_location_snapshots';

  // HTTP Headers (deprecated - use ApiClient.getHeaders() instead for JWT support)
  static Map<String, String> get headers => {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };
}

/// App Configuration
class AppConfig {
  static const String appName = 'Ambulance Driver';
  static const String appVersion = '1.0.0';

  // API Timeouts (milliseconds)
  static const int apiTimeout = 10000;
  static const int connectionTimeout = 15000;
}

/// Theme Colors
class AppColors {
  static const Color primary = Color(0xFFEF4444); // Red
  static const Color primaryDark = Color(0xFFDC2626);
  static const Color secondary = Color(0xFF475569); // Slate gray
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color lightPink = Color(
    0xFFFCE7F3,
  ); // Light pink for input fields
}

/// Clinics and Locations
class LocationData {
  // Clinics in Sfax
  static const List<String> clinicsSfax = [
    'Polyclinique El Habib',
    'Clinique Ibn Sina',
    'Hopital Hedi Chaker',
    'Clinique El Amal',
    'Centre Medical Sfax',
    'Clinique Espace Sante',
    'Hopital Universitaire',
  ];

  // Cities in Tunisia
  static const List<String> citiesTunisia = [
    'Tunis',
    'Sfax',
    'Sousse',
    'Kairouan',
    'Gafsa',
    'Tozeur',
    'Djerba',
    'Kebili',
    'Medenine',
    'Tataouine',
    'Ben Arous',
    'Ariana',
    'Manouba',
    'Nabeul',
    'Hammamet',
    'Monastir',
    'Mahdia',
    'Sidi Bouzid',
    'Kasserine',
    'Jendouba',
    'Kef',
    'Siliana',
    'Bizerte',
  ];

  // Cities in Libya
  static const List<String> citiesLibya = [
    'Tripoli',
    'Benghazi',
    'Misrata',
    'Derna',
    'Zawiya',
    'Tarhuna',
    'Bani Walid',
    'Ghadames',
    'Sebha',
    'Al Khums',
  ];

  // Priority options
  static const List<String> priorityOptions = [
    'normal',
    'urgent',
    'IRM',
    'scanner',
    'coro',
    'alerte thrombolyse',
    'transfert',
    'dialyse',
    'deces',
    'scintigraphie',
    'oxygenotherapie',
    'autre',
  ];

  // Motif de Transport options
  static const List<String> motifTransportOptions = [
    'urgence',
    'IRM',
    'scanner',
    'coro',
    'alerte thrombolyse',
    'transfert',
    'dialyse',
    'deces',
    'scintigraphie',
    'oxygenotherapie',
  ];

  // Get display name for priority
  static String getPriorityDisplayName(String priority) {
    switch (priority.toLowerCase()) {
      case 'normal':
        return 'Normal';
      case 'urgent':
        return 'Urgent';
      case 'irm':
        return 'IRM';
      case 'scanner':
        return 'Scanner';
      case 'coro':
        return 'Coronarographie';
      case 'alerte thrombolyse':
        return 'Alerte Thrombolyse';
      case 'transfert':
        return 'Transfert';
      case 'dialyse':
        return 'Dialyse';
      case 'deces':
        return 'Décès';
      case 'scintigraphie':
        return 'Scintigraphie';
      case 'oxygenotherapie':
        return 'Oxygénothérapie';
      case 'autre':
        return 'Autre (personnalisé)';
      default:
        return priority;
    }
  }

  // Get display name for motif de transport
  static String getMotifTransportDisplayName(String motif) {
    switch (motif.toLowerCase()) {
      case 'urgence':
        return 'Urgence';
      case 'irm':
        return 'IRM';
      case 'scanner':
        return 'Scanner';
      case 'coro':
        return 'Coronarographie';
      case 'alerte thrombolyse':
        return 'Alerte Thrombolyse';
      case 'transfert':
        return 'Transfert';
      case 'dialyse':
        return 'Dialyse';
      case 'deces':
        return 'Décès';
      case 'scintigraphie':
        return 'Scintigraphie';
      case 'oxygenotherapie':
        return 'Oxygénothérapie';
      default:
        return motif;
    }
  }
}

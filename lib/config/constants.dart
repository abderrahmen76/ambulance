import 'package:flutter/material.dart';

/// Supabase Configuration
/// Store all environment variables here for centralized management
class SupabaseConfig {
  // Supabase URL
  static const String supabaseUrl =
      'https://aaeglgmzusasbxatjkjl.supabase.co';

  // Anonymous key for client-side requests
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZWdsZ216dXNhc2J4YXRqa2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxNDEzNDAsImV4cCI6MjA4NzcxNzM0MH0.OyKGQbiqOtQE3fOv1uJKIcGuIi1axW9HQagqjbq011E';

  // Service role key (keep secure, don't expose in client)
  static const String serviceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZWdsZ216dXNhc2J4YXRqa2psIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjE0MTM0MCwiZXhwIjoyMDg3NzE3MzQwfQ.P-F1jvG_XrXZ9oyXciOV3YW1dn8xG4Z6mSLr2U5Oy6c';

  // API endpoints
  static const String usersTable = '/rest/v1/users';
  static const String rolesTable = '/rest/v1/roles';
  static const String roleUserTable = '/rest/v1/role_user';
  static const String ambulancesTable = '/rest/v1/ambulances';
  static const String missionsTable = '/rest/v1/missions';
  static const String fuelCardsTable = '/rest/v1/fuel_cards';
  static const String maintenanceRecordsTable = '/rest/v1/maintenance_records';

  // HTTP Headers
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
  static const Color lightPink = Color(0xFFFCE7F3); // Light pink for input fields
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
    'urgence',
  ];

  // Get display name for priority
  static String getPriorityDisplayName(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Urgent';
      case 'urgence':
        return 'Urgence';
      default:
        return 'Normal';
    }
  }
}

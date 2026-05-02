import 'package:flutter/material.dart';

/// Provides granular state management for settings sections
/// Instead of a single setState, each setting uses ValueNotifier for targeted updates
class SettingsProvider extends ChangeNotifier {
  // Fleet Configuration
  final ValueNotifier<int> maxDriversPerAmbulance = ValueNotifier(2);
  final ValueNotifier<String> defaultAmbulanceStatus =
      ValueNotifier('available');
  final ValueNotifier<List<String>> ambulanceTypes =
      ValueNotifier(['ALS Unit', 'BLS Unit']);

  // Tracking & Mission Settings
  final ValueNotifier<bool> forceTracking = ValueNotifier(true);
  final ValueNotifier<bool> autoAssignMissions = ValueNotifier(true);
  final ValueNotifier<String> priorityRule = ValueNotifier('fastest');

  // Fleet Settings
  final ValueNotifier<bool> maintenanceMode = ValueNotifier(false);
  final ValueNotifier<bool> fuelTracking = ValueNotifier(true);
  final ValueNotifier<bool> kilometrageTracking = ValueNotifier(true);

  // Driver Settings
  final ValueNotifier<bool> shiftSystem = ValueNotifier(true);
  final ValueNotifier<int> autoLogoutMinutes = ValueNotifier(20);
  final ValueNotifier<bool> geoFencing = ValueNotifier(true);
  final ValueNotifier<double> geoFencingRadius = ValueNotifier(15.5);
  final ValueNotifier<bool> driverAvailabilityRules = ValueNotifier(true);

  // Security & Maintenance
  final ValueNotifier<bool> autoFlagForService = ValueNotifier(true);
  final ValueNotifier<bool> preventDispatch = ValueNotifier(false);
  final ValueNotifier<bool> fuelConsumptionAPI = ValueNotifier(true);
  final ValueNotifier<bool> odometrySync = ValueNotifier(false);
  final ValueNotifier<int> maxContinuousHours = ValueNotifier(12);
  final ValueNotifier<String> shiftRotationMode =
      ValueNotifier('24/48 Rotation');
  final ValueNotifier<int> inactivityTimeout = ValueNotifier(20);
  final ValueNotifier<bool> forceEncryptedLogs = ValueNotifier(false);

  // Feature Flags & Roles
  final ValueNotifier<Map<String, String>> featureFlags = ValueNotifier({
    'gps_tracking': 'PRO',
    'analytics': 'PRO',
    'ai_dispatch': 'ENTERPRISE',
    'chat_system': 'ADD-ON',
  });

  /// Update a specific setting without rebuilding the entire screen
  void updateSetting<T>(ValueNotifier<T> setting, T value) {
    if (setting.value != value) {
      setting.value = value;
    }
  }

  /// Batch update multiple settings at once
  void batchUpdate(Map<ValueNotifier, dynamic> updates) {
    for (final entry in updates.entries) {
      entry.key.value = entry.value;
    }
  }

  @override
  void dispose() {
    maxDriversPerAmbulance.dispose();
    defaultAmbulanceStatus.dispose();
    ambulanceTypes.dispose();
    forceTracking.dispose();
    autoAssignMissions.dispose();
    priorityRule.dispose();
    maintenanceMode.dispose();
    fuelTracking.dispose();
    kilometrageTracking.dispose();
    shiftSystem.dispose();
    autoLogoutMinutes.dispose();
    geoFencing.dispose();
    geoFencingRadius.dispose();
    driverAvailabilityRules.dispose();
    autoFlagForService.dispose();
    preventDispatch.dispose();
    fuelConsumptionAPI.dispose();
    odometrySync.dispose();
    maxContinuousHours.dispose();
    shiftRotationMode.dispose();
    inactivityTimeout.dispose();
    forceEncryptedLogs.dispose();
    featureFlags.dispose();
    super.dispose();
  }
}

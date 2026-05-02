import 'notification_service.dart';

class MissionNotificationManager {
  /// Keep push content generic so route and patient details stay inside the app.
  static Future<void> notifyMissionAssigned({
    required String driverId,
    required String missionNumber,
    required String fromLocation,
    required String toLocation,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: driverId,
      title: 'New Mission Assigned',
      body: 'Mission $missionNumber requires your attention.',
      type: 'mission_assigned',
      extraData: {
        'mission_number': missionNumber,
      },
    );
  }

  static Future<void> notifyMissionStatusUpdate({
    required String userId,
    required String missionNumber,
    required String newStatus,
    required String missionId,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: userId,
      title: 'Mission Status Update',
      body: 'Mission $missionNumber status changed.',
      type: 'mission_status_update',
      extraData: {
        'mission_id': missionId,
        'mission_number': missionNumber,
        'new_status': newStatus,
      },
    );
  }

  static Future<void> notifyCriticalMission({
    required String driverId,
    required String missionNumber,
    required String fromLocation,
    required String toLocation,
    required String patientPhone,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: driverId,
      title: 'Critical Mission',
      body: 'Mission $missionNumber requires immediate response.',
      type: 'critical_alert',
      extraData: {
        'mission_number': missionNumber,
        'priority': 'critical',
      },
    );
  }

  static Future<void> notifyPaymentReceived({
    required String driverId,
    required String missionNumber,
    required String amount,
    required String paymentType,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: driverId,
      title: 'Payment Received',
      body: 'Mission $missionNumber payment was recorded.',
      type: 'payment_received',
      extraData: {
        'mission_number': missionNumber,
        'amount': amount,
        'payment_type': paymentType,
      },
    );
  }

  static Future<void> notifyMaintenanceReminder({
    required String managerId,
    required String ambulanceId,
    required String maintenanceType,
    required String dueDate,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: managerId,
      title: 'Maintenance Reminder',
      body: 'An ambulance maintenance reminder needs review.',
      type: 'maintenance_reminder',
      extraData: {
        'ambulance_id': ambulanceId,
        'maintenance_type': maintenanceType,
        'due_date': dueDate,
      },
    );
  }

  static Future<void> notifyAmbulanceAvailability({
    required String managerId,
    required String ambulanceId,
    required bool isAvailable,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      userId: managerId,
      title: isAvailable ? 'Ambulance Available' : 'Ambulance Unavailable',
      body: 'An ambulance availability update needs review.',
      type: 'ambulance_availability',
      extraData: {
        'ambulance_id': ambulanceId,
        'is_available': isAvailable.toString(),
      },
    );
  }
}

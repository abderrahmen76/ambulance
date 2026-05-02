import 'package:flutter/material.dart';
import 'dart:math';
import '../models/notification_model.dart';
import '../config/constants.dart';
import '../services/api_client.dart';

class NotificationServiceApp {
  static final NotificationServiceApp _instance =
      NotificationServiceApp._internal();

  final ApiClient _apiClient = ApiClient();

  factory NotificationServiceApp() {
    return _instance;
  }

  NotificationServiceApp._internal();

  static NotificationServiceApp get instance => _instance;

  /// Store a notification in the database
  Future<void> saveNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('[NotificationServiceApp] Saving notification metadata');

      // Generate a unique ID
      final randomId =
          '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';

      final notificationPayload = {
        'id': randomId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _apiClient.post(
        '/rest/v1/app_notifications',
        notificationPayload,
      );

      debugPrint('[NotificationServiceApp] Notification saved successfully');
    } catch (e) {
      debugPrint('[NotificationServiceApp] Error saving notification: $e');
      // Don't throw - notifications shouldn't crash the app
    }
  }

  /// Fetch all notifications sorted by newest
  Future<List<AppNotification>> getNotifications() async {
    try {
      debugPrint('[NotificationServiceApp] Fetching notifications...');

      final response = await _apiClient.get(
        '/rest/v1/app_notifications',
        filters: {
          'order': 'created_at.desc',
          'limit': '100',
        },
      );

      debugPrint(
          '[NotificationServiceApp] Fetched ${response.length} notifications');

      final notifications = response
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      return notifications;
    } catch (e) {
      debugPrint('[NotificationServiceApp] Error fetching notifications: $e');
      rethrow;
    }
  }

  /// Clear all notifications
  Future<void> clearNotifications() async {
    try {
      debugPrint(
          '[NotificationServiceApp] Fetching all notifications for deletion...');

      // Fetch all notifications
      final notifications = await getNotifications();
      debugPrint(
          '[NotificationServiceApp] Found ${notifications.length} notifications to delete');

      // Delete each notification
      for (final notification in notifications) {
        try {
          await _apiClient.delete(
              '/rest/v1/app_notifications', notification.id);
          debugPrint(
              '[NotificationServiceApp] Deleted notification: ${notification.id}');
        } catch (e) {
          debugPrint(
              '[NotificationServiceApp] Error deleting notification ${notification.id}: $e');
          // Continue deleting others even if one fails
        }
      }

      debugPrint('[NotificationServiceApp] All notifications deleted');
    } catch (e) {
      debugPrint('[NotificationServiceApp] Error in clearNotifications: $e');
      rethrow;
    }
  }
}

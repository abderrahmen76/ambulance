import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../config/constants.dart';
import '../services/api_client.dart';
import 'auth_service.dart';

class NotificationServiceApp {
  static final NotificationServiceApp _instance =
      NotificationServiceApp._internal();

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  static const String _localNotificationsPrefix = 'local_app_notifications_';

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
      final currentUser = _authService.cachedUser;
      final tenantId = currentUser?.tenantId?.trim();
      final userId = currentUser?.id.trim();
      final notificationData = Map<String, dynamic>.from(data ?? const {});
      if (tenantId != null && tenantId.isNotEmpty) {
        notificationData['tenant_id'] ??= tenantId;
        notificationData['tenantId'] ??= tenantId;
      }
      if (userId != null && userId.isNotEmpty) {
        notificationData['user_id'] ??= userId;
      }

      final notificationPayload = {
        'id': randomId,
        'title': title,
        'body': body,
        'type': type,
        'data': notificationData,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _saveLocalNotification(notificationPayload);

      try {
        await _apiClient.post(
          '/rest/v1/app_notifications',
          notificationPayload,
        );
      } catch (e) {
        debugPrint(
          '[NotificationServiceApp] Remote notification save failed, local copy kept: $e',
        );
      }

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
      final currentTenantId = _authService.cachedUser?.tenantId?.trim();
      final localNotifications = await _getLocalNotifications();

      List<Map<String, dynamic>> response = const [];
      try {
        response = await _apiClient.get(
          '/rest/v1/app_notifications',
          orderBy: 'created_at.desc',
          limit: 200,
        );
      } catch (e) {
        debugPrint(
          '[NotificationServiceApp] Remote fetch failed, using local cache: $e',
        );
      }

      debugPrint(
          '[NotificationServiceApp] Fetched ${response.length} notifications');

      final parsedNotifications = response
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      final notifications = <AppNotification>[];
      for (final notification in parsedNotifications) {
        if (await _belongsToCurrentTenant(notification, currentTenantId)) {
          notifications.add(notification);
        }
      }

      final mergedById = <String, AppNotification>{
        for (final notification in localNotifications)
          notification.id: notification,
        for (final notification in notifications) notification.id: notification,
      };
      final mergedNotifications = mergedById.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return mergedNotifications;
    } catch (e) {
      debugPrint('[NotificationServiceApp] Error fetching notifications: $e');
      try {
        return await _getLocalNotifications();
      } catch (_) {
        return const <AppNotification>[];
      }
    }
  }

  Future<void> _saveLocalNotification(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localNotificationsKey();
    final rawList = prefs.getStringList(key) ?? const <String>[];
    final updated = <String>[
      jsonEncode(payload),
      ...rawList.where((raw) {
        try {
          final decoded = jsonDecode(raw);
          return decoded is! Map || decoded['id'] != payload['id'];
        } catch (_) {
          return false;
        }
      }),
    ].take(200).toList();
    await prefs.setStringList(key, updated);
  }

  Future<List<AppNotification>> _getLocalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_localNotificationsKey()) ?? const [];
    final notifications = <AppNotification>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          notifications.add(
            AppNotification.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {}
    }
    return notifications;
  }

  String _localNotificationsKey() {
    final tenantId = _authService.cachedUser?.tenantId?.trim();
    if (tenantId != null && tenantId.isNotEmpty) {
      return '$_localNotificationsPrefix$tenantId';
    }
    return '${_localNotificationsPrefix}global';
  }

  Future<bool> _belongsToCurrentTenant(
    AppNotification notification,
    String? currentTenantId,
  ) async {
    if (currentTenantId == null || currentTenantId.isEmpty) {
      return true;
    }

    final data = notification.data ?? const <String, dynamic>{};
    final notificationTenantId = _firstNonEmpty([
      data['tenant_id'],
      data['tenantId'],
      data['provider_tenant_id'],
      data['providerTenantId'],
      data['target_tenant_id'],
      data['targetTenantId'],
    ]);
    final targetTenantIds = _stringList([
      data['target_tenant_ids'],
      data['targetTenantIds'],
      data['tenant_ids'],
      data['tenantIds'],
    ]);

    // Legacy rows without tenant metadata cannot be safely scoped.
    // Hide them for tenant users instead of leaking another company's feed.
    if (notificationTenantId == null && targetTenantIds.isEmpty) {
      return await _legacyNotificationBelongsToCurrentTenant(notification);
    }

    return notificationTenantId == currentTenantId ||
        targetTenantIds.contains(currentTenantId);
  }

  Future<bool> _legacyNotificationBelongsToCurrentTenant(
    AppNotification notification,
  ) async {
    try {
      final data = notification.data ?? const <String, dynamic>{};
      final missionNumber = _firstNonEmpty([
        data['missionNumber'],
        data['mission_number'],
      ]);
      if (missionNumber != null) {
        final missions = await _apiClient.get(
          SupabaseConfig.missionsTable,
          filters: {'mission_number': 'eq.$missionNumber'},
          limit: 1,
        );
        return missions.isNotEmpty;
      }

      final missionId = _firstNonEmpty([
        data['missionId'],
        data['mission_id'],
      ]);
      if (missionId != null) {
        final missions = await _apiClient.get(
          SupabaseConfig.missionsTable,
          filters: {'id': 'eq.$missionId'},
          limit: 1,
        );
        return missions.isNotEmpty;
      }

      final ambulanceId = _firstNonEmpty([
        data['ambulance_id'],
        data['ambulanceId'],
      ]);
      if (ambulanceId != null) {
        final ambulances = await _apiClient.get(
          SupabaseConfig.ambulancesTable,
          filters: {'id': 'eq.$ambulanceId'},
          limit: 1,
        );
        return ambulances.isNotEmpty;
      }
    } catch (e) {
      debugPrint(
        '[NotificationServiceApp] Legacy notification scope check failed: $e',
      );
    }

    return false;
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  List<String> _stringList(List<dynamic> values) {
    final result = <String>[];
    for (final value in values) {
      if (value is Iterable) {
        result.addAll(
          value
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty),
        );
      } else {
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) {
          result.add(text);
        }
      }
    }
    return result;
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localNotificationsKey());

      debugPrint('[NotificationServiceApp] All notifications deleted');
    } catch (e) {
      debugPrint('[NotificationServiceApp] Error in clearNotifications: $e');
      rethrow;
    }
  }
}

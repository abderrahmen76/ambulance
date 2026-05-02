
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/ambulance_model.dart';
import 'api_client.dart';
import 'tracking_presence_service.dart';

/// Ambulance Service
/// Handles fetching ambulance data for the current driver
/// Optimized for minimal queries and fast response
class AmbulanceService {
  static final AmbulanceService _instance = AmbulanceService._internal();
  final ApiClient _apiClient = ApiClient();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache ambulance data (improves performance on home screen)
  Ambulance? _cachedAmbulance;
  String? _cachedUserId;
  String? _cachedTenantId;

  factory AmbulanceService() {
    return _instance;
  }

  AmbulanceService._internal();

  /// Get ambulance visible to the current driver.
  /// Resolution order:
  /// 1. Direct assignment via ambulances.current_driver_id
  /// 2. Active tracking claim on this device
  /// 3. Single ambulance in the driver's tenant (compatibility fallback)
  Future<Ambulance?> getAmbulanceForDriver(
    String driverId, {
    String? tenantId,
  }) async {
    try {
      if (_cachedAmbulance != null &&
          _cachedUserId == driverId &&
          _cachedTenantId == tenantId) {
        return _cachedAmbulance;
      }

      final assignedAmbulances = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {
          'current_driver_id': 'eq.$driverId',
        },
      );

      if (assignedAmbulances.isNotEmpty) {
        return _cacheAmbulance(
          Ambulance.fromJson(assignedAmbulances.first),
          driverId: driverId,
          tenantId: tenantId,
        );
      }

      final claimedAmbulance = await _getAmbulanceFromActiveClaim(
        driverId: driverId,
        tenantId: tenantId,
      );
      if (claimedAmbulance != null) {
        return _cacheAmbulance(
          claimedAmbulance,
          driverId: driverId,
          tenantId: tenantId,
        );
      }

      if (tenantId != null && tenantId.isNotEmpty) {
        final tenantAmbulances = await _apiClient.get(
          SupabaseConfig.ambulancesTable,
          filters: {
            'tenant_id': 'eq.$tenantId',
          },
        );

        if (tenantAmbulances.length == 1) {
          return _cacheAmbulance(
            Ambulance.fromJson(tenantAmbulances.first),
            driverId: driverId,
            tenantId: tenantId,
          );
        }
      }

      _cachedAmbulance = null;
      _cachedUserId = driverId;
      _cachedTenantId = tenantId;
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<Ambulance?> _getAmbulanceFromActiveClaim({
    required String driverId,
    String? tenantId,
  }) async {
    try {
      await TrackingPresenceService().loadCurrentState(driverId);
      final activeClaim = TrackingPresenceService().activeClaim;

      if (activeClaim == null || activeClaim.ambulanceId.isEmpty) {
        return null;
      }

      if (tenantId != null &&
          tenantId.isNotEmpty &&
          activeClaim.tenantId.isNotEmpty &&
          activeClaim.tenantId != tenantId) {
        return null;
      }

      final rows = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {
          'id': 'eq.${activeClaim.ambulanceId}',
        },
      );

      if (rows.isEmpty) {
        return null;
      }

      return Ambulance.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }

  Ambulance _cacheAmbulance(
    Ambulance ambulance, {
    required String driverId,
    String? tenantId,
  }) {
    _cachedAmbulance = ambulance;
    _cachedUserId = driverId;
    _cachedTenantId = tenantId;
    return ambulance;
  }

  /// Get all ambulances (admin view)
  Future<List<Ambulance>> getAllAmbulances() async {
    try {
      final ambulances = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
      );

      return ambulances.map((json) => Ambulance.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get ambulances the driver can link to inside their tenant.
  Future<List<Ambulance>> getAvailableAmbulancesForDriver({
    required String driverId,
    required String tenantId,
  }) async {
    try {
      final ambulances = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {
          'tenant_id': 'eq.$tenantId',
        },
      );

      return ambulances
          .map((json) => Ambulance.fromJson(json))
          .where(
            (ambulance) =>
                ambulance.currentDriverId == null ||
                ambulance.currentDriverId!.isEmpty ||
                ambulance.currentDriverId == driverId,
          )
          .toList()
        ..sort((a, b) => a.ambulanceNumber.compareTo(b.ambulanceNumber));
    } catch (e) {
      rethrow;
    }
  }

  /// Link an ambulance to the current driver account.
  Future<void> assignAmbulanceToDriver({
    required String ambulanceId,
    required String driverId,
    required String tenantId,
  }) async {
    try {
      final currentlyAssigned =
          await getAmbulanceForDriver(driverId, tenantId: tenantId);
      if (currentlyAssigned != null && currentlyAssigned.id != ambulanceId) {
        throw Exception(
          'Libérez d\'abord l\'ambulance ${currentlyAssigned.ambulanceNumber} avant d\'en choisir une autre.',
        );
      }

      final selectedRows = await _apiClient.get(
        SupabaseConfig.ambulancesTable,
        filters: {
          'id': 'eq.$ambulanceId',
        },
      );

      if (selectedRows.isEmpty) {
        throw Exception('Ambulance introuvable.');
      }

      final selected = Ambulance.fromJson(selectedRows.first);
      if (selected.currentDriverId != null &&
          selected.currentDriverId!.isNotEmpty &&
          selected.currentDriverId != driverId) {
        throw Exception(
          'Cette ambulance est déjà affectée à un autre conducteur.',
        );
      }

      final updatedRow = await _supabase
          .from('ambulances')
          .update({
            'current_driver_id': driverId,
          })
          .eq('id', ambulanceId)
          .select('id, ambulance_number, current_driver_id')
          .maybeSingle();

      if (updatedRow == null) {
        throw Exception(
          'Impossible de lier cette ambulance. Vérifiez les règles RLS de la table ambulances.',
        );
      }

      final updatedDriverId = updatedRow['current_driver_id']?.toString();
      if (updatedDriverId != driverId) {
        throw Exception(
          'La liaison de l’ambulance n’a pas été enregistrée correctement.',
        );
      }

      clearCache();
    } catch (e) {
      rethrow;
    }
  }

  /// Release the currently linked ambulance from the driver account.
  Future<void> releaseAmbulanceFromDriver({
    required String ambulanceId,
    String? driverId,
  }) async {
    try {
      if (driverId != null && driverId.isNotEmpty) {
        await TrackingPresenceService().loadCurrentState(driverId);
        final activeClaim = TrackingPresenceService().activeClaim;
        if (activeClaim != null && activeClaim.ambulanceId == ambulanceId) {
          await TrackingPresenceService().releaseClaim();
        }
      }

      final updatedRow = await _supabase
          .from('ambulances')
          .update({
            'current_driver_id': null,
          })
          .eq('id', ambulanceId)
          .select('id, ambulance_number, current_driver_id')
          .maybeSingle();

      if (updatedRow == null) {
        throw Exception(
          'Impossible de libérer cette ambulance. Vérifiez les règles RLS de la table ambulances.',
        );
      }

      clearCache();
    } catch (e) {
      rethrow;
    }
  }

  /// Update ambulance current location/status
  Future<void> updateAmbulanceStatus({
    required String ambulanceId,
    required String? currentDestination,
    required double? kilometrage,
  }) async {
    try {
      await _apiClient.patch(
        '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId',
        {
          if (currentDestination != null)
            'current_destination': currentDestination,
          if (kilometrage != null) 'kilometrage': kilometrage,
        },
      );

      // Invalidate cache
      _cachedAmbulance = null;
      _cachedUserId = null;
      _cachedTenantId = null;
    } catch (e) {
      rethrow;
    }
  }

  /// Clear cache (for testing or when driver changes)
  void clearCache() {
    _cachedAmbulance = null;
    _cachedUserId = null;
    _cachedTenantId = null;
  }
}


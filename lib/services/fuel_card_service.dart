import '../config/constants.dart';
import '../models/fuel_card_model.dart';
import 'api_client.dart';

/// Fuel Card Service
/// Handles fetching fuel card transaction data
class FuelCardService {
  static final FuelCardService _instance = FuelCardService._internal();
  final ApiClient _apiClient = ApiClient();

  factory FuelCardService() {
    return _instance;
  }

  FuelCardService._internal();

  /// Get fuel card history for ambulance
  Future<List<FuelCard>> getFuelCardHistory(String ambulanceId,
      {int limit = 20, int offset = 0}) async {
    try {
      final fuelCards = await _apiClient.get(
        SupabaseConfig.fuelCardsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
        },
        orderBy: 'created_at.desc',
        limit: limit,
        offset: offset,
      );

      return fuelCards.map((json) => FuelCard.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get current fuel balance
  Future<double> getCurrentBalance(String ambulanceId) async {
    try {
      final response = await _apiClient.get(
        SupabaseConfig.fuelCardsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
        },
        orderBy: 'date.desc',
        limit: 1,
      );

      if (response.isEmpty) {
        return 0.0;
      }

      final fuelCard = FuelCard.fromJson(response.first);
      return fuelCard.soldesRestant;
    } catch (e) {
      rethrow;
    }
  }

  /// Add new fuel card transaction
  Future<void> addFuelTransaction(
    String ambulanceId,
    double fuelAmount,
    double rechargeAmount,
  ) async {
    try {
      final currentBalance = await getCurrentBalance(ambulanceId);
      final newBalance = currentBalance + fuelAmount;

      await _apiClient.post(SupabaseConfig.fuelCardsTable, {
        'ambulance_id': ambulanceId,
        'fuel_amount': fuelAmount,
        'recharge_amount': rechargeAmount,
        'balance': newBalance,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Add new fuel card with complete data from form
  Future<void> addFuelCard(Map<String, dynamic> fuelData) async {
    try {
      print('[FuelCardService] addFuelCard() called with data: $fuelData');

      // Extract kilometrage and ambulanceId for later use
      final kilometrage = fuelData['kilometrage'];
      final ambulanceId = fuelData['ambulance_id'];

      print(
          '[FuelCardService] Adding fuel card with kilometrage: $kilometrage, ambulanceId: $ambulanceId');

      // Post fuel card with all data including kilometrage
      final response = await _apiClient.post(
        SupabaseConfig.fuelCardsTable,
        fuelData,
      );

      print('[FuelCardService] addFuelCard() response: $response');

      // Update ambulance kilometrage AFTER fuel card is created
      if (kilometrage != null &&
          ambulanceId != null &&
          (kilometrage is double || kilometrage is int) &&
          kilometrage > 0) {
        try {
          print(
              '[FuelCardService] Attempting to update ambulance $ambulanceId with kilometrage $kilometrage');

          // Build endpoint with filter parameter
          final endpoint =
              '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId';

          // Convert to numeric if needed
          final numericKilometrage = kilometrage is double
              ? kilometrage
              : (kilometrage as int).toDouble();
          final patchBody = {'kilometrage': numericKilometrage};

          print('[FuelCardService] PATCH endpoint: $endpoint');
          print('[FuelCardService] PATCH body: $patchBody');

          await _apiClient.patch(
            endpoint,
            patchBody,
          );
          print(
              '[FuelCardService] Successfully updated ambulance $ambulanceId kilometrage to $numericKilometrage');
        } catch (e) {
          print(
              '[FuelCardService] Warning: Failed to update ambulance kilometrage: $e');
          // Don't rethrow - fuel card was already added
        }
      } else {
        print(
            '[FuelCardService] Skipping ambulance update - kilometrage: $kilometrage, ambulanceId: $ambulanceId');
      }
    } catch (e) {
      print('[FuelCardService] addFuelCard() ERROR: $e');
      rethrow;
    }
  }

  /// Get current card balance for an ambulance
  Future<double> getCurrentCardBalance(String ambulanceId) async {
    try {
      print(
          '[FuelCardService] getCurrentCardBalance() called for ambulance: $ambulanceId');

      final response = await _apiClient.get(
        SupabaseConfig.fuelCardsTable,
        filters: {
          'ambulance_id': 'eq.$ambulanceId',
        },
        orderBy: 'date.asc', // Get all entries in chronological order
      );

      print(
          '[FuelCardService] getCurrentCardBalance() response count: ${response.length}');

      if (response.isEmpty) {
        print('[FuelCardService] No fuel card history found, returning 0.0');
        return 0.0;
      }

      // Calculate balance: refills ADD, consumptions SUBTRACT
      double balance = 0.0;
      for (final entry in response) {
        final fuelCard = FuelCard.fromJson(entry);
        if (fuelCard.driverName.toLowerCase() == 'refill') {
          // Refill: ADD to balance
          balance += fuelCard.soldesPaid;
          print(
              '[FuelCardService] Refill: +${fuelCard.soldesPaid}, Balance: $balance');
        } else {
          // Consumption: SUBTRACT from balance
          balance -= fuelCard.soldesPaid;
          print(
              '[FuelCardService] Consumption by ${fuelCard.driverName}: -${fuelCard.soldesPaid}, Balance: $balance');
        }
      }

      print('[FuelCardService] Final calculated balance: $balance TND');
      return balance;
    } catch (e) {
      print('[FuelCardService] getCurrentCardBalance() ERROR: $e');
      rethrow;
    }
  }

  /// Refill fuel card with new amount
  Future<void> refillFuelCard(Map<String, dynamic> refillData) async {
    try {
      print('[FuelCardService] refillFuelCard() called with data: $refillData');

      // Extract kilometrage if provided
      final kilometrage = refillData['kilometrage'];
      final ambulanceId = refillData['ambulance_id'];

      // Record refill as a fuel card entry with driver_name = 'Refill'
      // This allows tracking refills separately from consumption
      final refillTransaction = {
        'ambulance_id': refillData['ambulance_id'],
        'date': refillData['date'],
        'driver_name': 'Refill', // Mark as refill type
        'soldes_paid': refillData['refill_amount'], // Record the refill amount
        'user_id': refillData['user_id'],
      };

      print('[FuelCardService] Submitting refill: $refillTransaction');

      final response = await _apiClient.post(
        SupabaseConfig.fuelCardsTable,
        refillTransaction,
      );

      print('[FuelCardService] refillFuelCard() response: $response');

      // Update ambulance kilometrage if provided
      if (kilometrage != null && ambulanceId != null) {
        try {
          // Build endpoint with filter parameter
          final endpoint =
              '${SupabaseConfig.ambulancesTable}?id=eq.$ambulanceId';
          // Send kilometrage as numeric value, not string (Supabase expects numeric type)
          final patchBody = {'kilometrage': kilometrage};
          print('[FuelCardService] PATCH body: $patchBody');
          await _apiClient.patch(
            endpoint,
            patchBody,
          );
          print(
              '[FuelCardService] Updated ambulance $ambulanceId kilometrage to $kilometrage');
        } catch (e) {
          print(
              '[FuelCardService] Warning: Failed to update ambulance kilometrage: $e');
          // Don't rethrow - fuel card was already added
        }
      }
    } catch (e) {
      print('[FuelCardService] refillFuelCard() ERROR: $e');
      rethrow;
    }
  }
}

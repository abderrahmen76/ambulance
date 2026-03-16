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
        orderBy: 'date.desc',
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
      return fuelCard.balance;
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
      
      final response = await _apiClient.post(
        SupabaseConfig.fuelCardsTable,
        fuelData,
      );
      
      print('[FuelCardService] addFuelCard() response: $response');
    } catch (e) {
      print('[FuelCardService] addFuelCard() ERROR: $e');
      rethrow;
    }
  }
}

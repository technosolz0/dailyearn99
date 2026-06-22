import 'dart:convert';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import '../models/fruit_models.dart';

class FruitRepository {
  final ApiClient _apiClient;

  FruitRepository(this._apiClient);

  Future<FruitSettingsModel> fetchFruitSettings() async {
    final response = await _apiClient.get(ApiConstants.fruitSettings);
    return FruitSettingsModel.fromJson(response.data);
  }

  Future<FruitGameModel> startFruitGame(double betAmount) async {
    final response = await _apiClient.post(
      ApiConstants.fruitStart,
      data: {'bet_amount': betAmount},
    );
    return FruitGameModel.fromJson(response.data);
  }

  Future<FruitGameModel> cashoutFruitGame({
    required int gameId,
    required double finalMultiplier,
    required String signature,
  }) async {
    final url = '${ApiConstants.fruitCashout(gameId)}?final_multiplier=$finalMultiplier&signature=$signature';
    final response = await _apiClient.post(url);
    return FruitGameModel.fromJson(response.data);
  }

  Future<FruitGameModel> bombFruitGame({
    required int gameId,
    required String signature,
  }) async {
    final url = '${ApiConstants.fruitBomb(gameId)}?signature=$signature';
    final response = await _apiClient.post(url);
    return FruitGameModel.fromJson(response.data);
  }

  Future<List<FruitGameModel>> fetchFruitHistory() async {
    final response = await _apiClient.get(ApiConstants.fruitHistory);
    final data = response.data as List;
    return data.map((json) => FruitGameModel.fromJson(json)).toList();
  }
}

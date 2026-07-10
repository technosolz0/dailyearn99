import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import '../models/lottery_models.dart';

class LotteryRepository {
  final ApiClient _apiClient;

  LotteryRepository(this._apiClient);

  Future<List<LotteryDrawModel>> fetchLotteryDraws() async {
    final response = await _apiClient.get(ApiConstants.lotteryDraws);
    final raw = response.data;

    final listData = raw is List
        ? raw
        : (raw is Map && raw.containsKey('results') && raw['results'] is List)
            ? raw['results'] as List
            : <dynamic>[];

    return listData
        .map(
          (json) => LotteryDrawModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<LotteryTicketModel>> fetchMyTickets() async {
    final response = await _apiClient.get(ApiConstants.lotteryMyTickets);
    final raw = response.data;

    final listData = raw is List
        ? raw
        : (raw is Map && raw.containsKey('results') && raw['results'] is List)
            ? raw['results'] as List
            : <dynamic>[];

    return listData
        .map(
          (json) => LotteryTicketModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<LotteryTicketModel> buyTicket(int drawId) async {
    final response = await _apiClient.post(
      ApiConstants.lotteryBuy,
      data: {'draw_id': drawId},
    );
    return LotteryTicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<LotteryWinnerModel>> fetchLotteryWinners() async {
    final response = await _apiClient.get(ApiConstants.lotteryWinners);
    final raw = response.data;

    final listData = raw is List
        ? raw
        : (raw is Map && raw.containsKey('results') && raw['results'] is List)
            ? raw['results'] as List
            : <dynamic>[];

    return listData
        .map(
          (json) => LotteryWinnerModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }
}

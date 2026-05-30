import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:target99/core/constants/api_constants.dart';
import 'package:target99/core/network/api_client.dart';
import '../models/fruit_models.dart';

class FruitRepository {
  final ApiClient _apiClient;

  FruitRepository(this._apiClient);

  Future<List<FruitContestModel>> fetchFruitContests() async {
    final response = await _apiClient.get(ApiConstants.fruitContests);
    final data = response.data as List;
    return data.map((json) => FruitContestModel.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> joinFruitContest(int contestId) async {
    final payload = {
      'contest_id': contestId,
      'device_fingerprint': 'flutter_mobile_client_production',
      'ip_address': '127.0.0.1',
    };
    final response = await _apiClient.post(
      ApiConstants.fruitJoin,
      data: payload,
    );
    return response.data;
  }

  Future<FruitSessionModel> startFruitSession(int contestId, String sessionId) async {
    final response = await _apiClient.post(
      '${ApiConstants.fruitStart(contestId)}?session_id=$sessionId',
    );
    return FruitSessionModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> submitFruitScore({
    required int contestId,
    required String sessionId,
    required int score,
    required int maxCombo,
    required int missCount,
    required int bombHitCount,
    required List<SwipeTelemetryModel> telemetry,
    required String signature,
  }) async {
    final payload = {
      'contest_id': contestId,
      'session_id': sessionId,
      'score': score,
      'max_combo': maxCombo,
      'miss_count': missCount,
      'bomb_hit_count': bombHitCount,
      'telemetry': telemetry.map((t) => t.toJson()).toList(),
      'signature': signature,
    };
    final response = await _apiClient.post(
      ApiConstants.fruitSubmit,
      data: payload,
    );
    return response.data;
  }

  Future<List<FruitLeaderboardItemModel>> fetchLeaderboard(int contestId) async {
    final response = await _apiClient.get(ApiConstants.fruitLeaderboard(contestId));
    final data = response.data as List;
    return data.map((json) => FruitLeaderboardItemModel.fromJson(json)).toList();
  }

  Stream<dynamic> connectToLeaderboard(int contestId) {
    final wsUrl = ApiConstants.fruitWs(contestId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return channel.stream.map((event) {
      if (event is String) {
        return jsonDecode(event);
      }
      return event;
    });
  }
}

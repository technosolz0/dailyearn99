import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import '../models/arrow_models.dart';

class ArrowRepository {
  final ApiClient _apiClient;

  ArrowRepository(this._apiClient);

  Future<List<ArrowContestModel>> fetchArrowContests() async {
    final response = await _apiClient.get(ApiConstants.arrowContests);
    final raw = response.data;

    final listData = raw is List
        ? raw
        : (raw is Map && raw.containsKey('results') && raw['results'] is List)
            ? raw['results'] as List
            : <dynamic>[];

    return listData
        .map(
          (json) => ArrowContestModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ArrowSessionModel> startArrowSession(int contestId) async {
    final response = await _apiClient.post(ApiConstants.arrowStart(contestId));
    return ArrowSessionModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> submitArrowScore({
    required int contestId,
    required String sessionId,
    required double completionSeconds,
    required int moves,
    required List<TapTelemetryModel> telemetry,
    required String signature,
  }) async {
    final payload = {
      'contest_id': contestId,
      'session_id': sessionId,
      'completion_seconds': completionSeconds,
      'moves': moves,
      'telemetry': telemetry.map((t) => t.toJson()).toList(),
      'device_fingerprint': 'flutter_mobile_client_production',
      'signature': signature,
    };
    final response = await _apiClient.post(
      ApiConstants.arrowSubmit,
      data: payload,
    );
    return response.data;
  }

  Future<List<dynamic>> fetchLeaderboard(int contestId) async {
    final response = await _apiClient.get(
      ApiConstants.arrowLeaderboard(contestId),
    );
    return response.data as List;
  }

  Stream<dynamic> connectToLeaderboard(int contestId) {
    final wsUrl = ApiConstants.arrowWs(contestId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return channel.stream.map((event) {
      if (event is String) {
        return jsonDecode(event);
      }
      return event;
    });
  }
}

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:target99/core/constants/api_constants.dart';
import 'package:target99/core/network/api_client.dart';
import '../models/puzzle_models.dart';

class PuzzleRepository {
  final ApiClient _apiClient;

  PuzzleRepository(this._apiClient);

  Future<List<PuzzleContestModel>> fetchPuzzleContests() async {
    final response = await _apiClient.get(ApiConstants.puzzleContests);
    final raw = response.data;

    // Some backends return a raw List, others wrap results inside a map (e.g. {"results": [...]})
    final listData = raw is List
        ? raw
        : (raw is Map && raw.containsKey('results') && raw['results'] is List)
        ? raw['results'] as List
        : <dynamic>[];

    return listData
        .map(
          (json) => PuzzleContestModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PuzzleSessionModel> startPuzzleSession(int contestId) async {
    final response = await _apiClient.post(ApiConstants.puzzleStart(contestId));
    return PuzzleSessionModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> submitPuzzleScore({
    required int contestId,
    required String sessionId,
    required double completionSeconds,
    required int moves,
    required int hintsUsed,
    required List<MoveTelemetryModel> telemetry,
    required String signature,
  }) async {
    final payload = {
      'contest_id': contestId,
      'session_id': sessionId,
      'completion_seconds': completionSeconds,
      'moves': moves,
      'hints_used': hintsUsed,
      'telemetry': telemetry.map((t) => t.toJson()).toList(),
      'device_fingerprint': 'flutter_mobile_client_production',
      'signature': signature,
    };
    final response = await _apiClient.post(
      ApiConstants.puzzleSubmit,
      data: payload,
    );
    return response.data;
  }

  Future<List<dynamic>> fetchLeaderboard(int contestId) async {
    final response = await _apiClient.get(
      ApiConstants.puzzleLeaderboard(contestId),
    );
    return response.data as List;
  }

  Stream<dynamic> connectToLeaderboard(int contestId) {
    final wsUrl = ApiConstants.puzzleWs(contestId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return channel.stream.map((event) {
      if (event is String) {
        return jsonDecode(event);
      }
      return event;
    });
  }
}

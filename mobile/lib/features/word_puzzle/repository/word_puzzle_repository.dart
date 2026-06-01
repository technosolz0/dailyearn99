import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import '../models/word_puzzle_models.dart';

class WordPuzzleRepository {
  final ApiClient _apiClient;

  WordPuzzleRepository(this._apiClient);

  Future<List<WordContestModel>> fetchWordContests() async {
    final response = await _apiClient.get(ApiConstants.wordContests);
    final data = response.data as List;
    return data.map((json) => WordContestModel.fromJson(json)).toList();
  }

  Future<WordStartSessionResponse> joinWordContest(int contestId) async {
    final payload = {
      'contest_id': contestId,
      'device_fingerprint': 'flutter_mobile_client_production',
      'ip_address': '127.0.0.1' // Fallback; handled server-side as well
    };
    final response = await _apiClient.post(
      ApiConstants.wordJoin,
      data: payload,
    );
    return WordStartSessionResponse.fromJson(response.data);
  }

  Future<WordSessionQuestionsResponse> startWordContest({
    required int contestId,
    required String sessionId,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.wordStart(contestId),
      queryParameters: {'session_id': sessionId},
    );
    return WordSessionQuestionsResponse.fromJson(response.data);
  }

  Future<WordAnswerResponseModel> submitWordAnswer({
    required String sessionId,
    required int questionId,
    required String answer,
    required double elapsedSeconds,
    required double timeTakenSeconds,
    required bool usedHint,
    required String signature,
    String? telemetry,
  }) async {
    final payload = {
      'session_id': sessionId,
      'question_id': questionId,
      'answer': answer,
      'elapsed_time_seconds': elapsedSeconds,
      'time_taken_seconds': timeTakenSeconds,
      'used_hint': usedHint,
      'signature': signature,
      'telemetry': telemetry,
    };
    final response = await _apiClient.post(
      ApiConstants.wordSubmit,
      data: payload,
    );
    return WordAnswerResponseModel.fromJson(response.data);
  }

  Future<List<WordLeaderboardItemModel>> fetchLeaderboard(int contestId) async {
    final response = await _apiClient.get(ApiConstants.wordLeaderboard(contestId));
    final data = response.data as List;
    return data.map((json) => WordLeaderboardItemModel.fromJson(json)).toList();
  }

  Stream<dynamic> connectToLeaderboard(int contestId) {
    final wsUrl = ApiConstants.wordWs(contestId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return channel.stream.map((event) {
      if (event is String) {
        return jsonDecode(event);
      }
      return event;
    });
  }
}

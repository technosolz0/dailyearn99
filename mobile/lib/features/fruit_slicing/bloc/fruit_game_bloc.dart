import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/fruit_models.dart';
import '../repository/fruit_repository.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

// --- EVENTS ---
abstract class FruitGameEvent {}

class LoadFruitGameEvent extends FruitGameEvent {
  final int contestId;
  LoadFruitGameEvent(this.contestId);
}

class RecordSwipeEvent extends FruitGameEvent {
  final List<Offset> points;
  final List<LocalSlicedItem> slicedItems;
  final bool isBombHit;

  RecordSwipeEvent({
    required this.points,
    required this.slicedItems,
    required this.isBombHit,
  });
}

class RegisterMissEvent extends FruitGameEvent {}

class SubmitFruitScoreEvent extends FruitGameEvent {}

class UpdateLiveLeaderboardEvent extends FruitGameEvent {
  final List<dynamic> leaderboard;
  UpdateLiveLeaderboardEvent(this.leaderboard);
}

// --- STATES ---
abstract class FruitGameState {}

class FruitGameInitialState extends FruitGameState {}

class FruitGameLoadingState extends FruitGameState {}

class FruitGameActiveState extends FruitGameState {
  final String seed;
  final int score;
  final int maxCombo;
  final int missCount;
  final int bombCount;
  final List<dynamic> liveLeaderboard;
  final int remainingSeconds;

  FruitGameActiveState({
    required this.seed,
    required this.score,
    required this.maxCombo,
    required this.missCount,
    required this.bombCount,
    required this.liveLeaderboard,
    required this.remainingSeconds,
  });
}

class FruitGameSubmittingState extends FruitGameState {}

class FruitGameSuccessState extends FruitGameState {
  final int finalScore;
  FruitGameSuccessState(this.finalScore);
}

class FruitGameErrorState extends FruitGameState {
  final String message;
  FruitGameErrorState(this.message);
}

// --- BLoC ---
class FruitGameBloc extends Bloc<FruitGameEvent, FruitGameState> {
  final FruitRepository _repository;
  final Stopwatch _matchStopwatch = Stopwatch();
  final List<SwipeTelemetryModel> _telemetryStream = [];

  int _contestId = 0;
  String? _sessionId;
  String? _signature;
  String? _seed;

  int _currentScore = 0;
  int _maxCombo = 0;
  int _missCount = 0;
  int _bombCount = 0;
  int _consecutiveSlices = 0;

  StreamSubscription? _wsSubscription;
  List<dynamic> _liveLeaderboard = [];
  Timer? _ticker;

  FruitGameBloc(this._repository) : super(FruitGameInitialState()) {
    on<LoadFruitGameEvent>(_onLoadGame);
    on<RecordSwipeEvent>(_onRecordSwipe);
    on<RegisterMissEvent>(_onRegisterMiss);
    on<SubmitFruitScoreEvent>(_onSubmitScore);
    on<UpdateLiveLeaderboardEvent>(_onUpdateLeaderboard);
  }

  Future<void> _onLoadGame(LoadFruitGameEvent event, Emitter<FruitGameState> emit) async {
    emit(FruitGameLoadingState());
    try {
      _contestId = event.contestId;

      // 1. Join Contest & Obtain Session ID
      final joinResult = await _repository.joinFruitContest(event.contestId);
      _sessionId = joinResult['session_id'];

      if (_sessionId == null) {
        throw Exception("Failed to acquire session token.");
      }

      // 2. Start Match Session
      final session = await _repository.startFruitSession(event.contestId, _sessionId!);
      _seed = session.seed;
      _signature = session.signature;

      _currentScore = 0;
      _maxCombo = 0;
      _missCount = 0;
      _bombCount = 0;
      _consecutiveSlices = 0;
      _telemetryStream.clear();
      _liveLeaderboard = [];

      _matchStopwatch.reset();
      _matchStopwatch.start();

      // Fetch initial leaderboard REST state
      try {
        final initialRanks = await _repository.fetchLeaderboard(event.contestId);
        _liveLeaderboard = initialRanks.map((item) => {
          'user_id': item.userId,
          'name': item.name,
          'score': item.score,
          'rank': item.rank,
        }).toList();
      } catch (err) {
        print("Failed to fetch initial leaderboard: $err");
      }

      // 3. Open WebSocket Channel
      _wsSubscription?.cancel();
      _wsSubscription = _repository.connectToLeaderboard(event.contestId).listen((data) {
        if (data is Map && data['type'] == 'leaderboard_update') {
          _liveLeaderboard = data['data'] as List;
          add(UpdateLiveLeaderboardEvent(_liveLeaderboard));
        }
      }, onError: (err) {
        print("Fruit Leaderboard WS socket read error: $err");
      });

      emit(FruitGameActiveState(
        seed: _seed!,
        score: max(0, _currentScore),
        maxCombo: _maxCombo,
        missCount: _missCount,
        bombCount: _bombCount,
        liveLeaderboard: _liveLeaderboard,
        remainingSeconds: 60,
      ));

      // 4. Start standard 60-second ticker
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        final elapsed = _matchStopwatch.elapsed.inSeconds;
        final remaining = 60 - elapsed;
        if (remaining <= 0) {
          _ticker?.cancel();
          add(SubmitFruitScoreEvent());
        } else if (state is FruitGameActiveState) {
          emit(FruitGameActiveState(
            seed: _seed!,
            score: max(0, _currentScore),
            maxCombo: _maxCombo,
            missCount: _missCount,
            bombCount: _bombCount,
            liveLeaderboard: _liveLeaderboard,
            remainingSeconds: remaining,
          ));
        }
      });
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  void _onRecordSwipe(RecordSwipeEvent event, Emitter<FruitGameState> emit) {
    if (state is! FruitGameActiveState) return;

    final telemetry = SwipeTelemetryModel(
      timestampMs: _matchStopwatch.elapsedMilliseconds,
      path: event.points.map((p) => CoordinateModel(x: p.dx, y: p.dy)).toList(),
      slicedItems: event.slicedItems.map((s) => SlicedItemModel(
        id: s.id,
        itemType: s.type,
        sliceAngle: s.angle
      )).toList(),
      isBombHit: event.isBombHit,
    );

    _telemetryStream.add(telemetry);

    if (event.isBombHit) {
      _bombCount++;
      _currentScore -= 100;
      _consecutiveSlices = 0;
    } else {
      final sliceCount = event.slicedItems.length;
      if (sliceCount > 0) {
        _currentScore += (sliceCount * 10);
        
        // Combo evaluations
        if (sliceCount >= 5) {
          _currentScore += 50;
          _consecutiveSlices = max(_consecutiveSlices, 5);
        } else if (sliceCount >= 3) {
          _currentScore += 20;
          _consecutiveSlices = max(_consecutiveSlices, 3);
        }
      }
    }

    _maxCombo = max(_maxCombo, _consecutiveSlices);

    emit(FruitGameActiveState(
      seed: _seed!,
      score: max(0, _currentScore),
      maxCombo: _maxCombo,
      missCount: _missCount,
      bombCount: _bombCount,
      liveLeaderboard: _liveLeaderboard,
      remainingSeconds: 60 - _matchStopwatch.elapsed.inSeconds,
    ));
  }

  void _onRegisterMiss(RegisterMissEvent event, Emitter<FruitGameState> emit) {
    if (state is! FruitGameActiveState) return;
    
    _missCount++;
    _consecutiveSlices = 0;
    _currentScore -= 5;

    emit(FruitGameActiveState(
      seed: _seed!,
      score: max(0, _currentScore),
      maxCombo: _maxCombo,
      missCount: _missCount,
      bombCount: _bombCount,
      liveLeaderboard: _liveLeaderboard,
      remainingSeconds: 60 - _matchStopwatch.elapsed.inSeconds,
    ));
  }

  void _onUpdateLeaderboard(UpdateLiveLeaderboardEvent event, Emitter<FruitGameState> emit) {
    if (state is! FruitGameActiveState) return;
    emit(FruitGameActiveState(
      seed: _seed!,
      score: max(0, _currentScore),
      maxCombo: _maxCombo,
      missCount: _missCount,
      bombCount: _bombCount,
      liveLeaderboard: event.leaderboard,
      remainingSeconds: 60 - _matchStopwatch.elapsed.inSeconds,
    ));
  }

  Future<void> _onSubmitScore(SubmitFruitScoreEvent event, Emitter<FruitGameState> emit) async {
    if (state is! FruitGameActiveState || _sessionId == null) return;
    
    emit(FruitGameSubmittingState());
    _matchStopwatch.stop();
    _ticker?.cancel();
    _wsSubscription?.cancel();

    try {
      final result = await _repository.submitFruitScore(
        contestId: _contestId,
        sessionId: _sessionId!,
        score: max(0, _currentScore),
        maxCombo: _maxCombo,
        missCount: _missCount,
        bombHitCount: _bombCount,
        telemetry: _telemetryStream,
        signature: _signature!,
      );
      emit(FruitGameSuccessState(result['score'] as int));
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _wsSubscription?.cancel();
    _matchStopwatch.stop();
    return super.close();
  }
}

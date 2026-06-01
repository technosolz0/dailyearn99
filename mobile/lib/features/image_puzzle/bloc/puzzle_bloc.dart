import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/puzzle_models.dart';
import '../repository/puzzle_repository.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

// --- EVENTS ---
abstract class PuzzleEvent {}

class LoadPuzzleGameEvent extends PuzzleEvent {
  final int contestId;
  LoadPuzzleGameEvent(this.contestId);
}

class SwapPiecesEvent extends PuzzleEvent {
  final int fromIdx;
  final int toIdx;
  SwapPiecesEvent(this.fromIdx, this.toIdx);
}

class UseHintEvent extends PuzzleEvent {}

class SubmitPuzzleScoreEvent extends PuzzleEvent {}

class UpdateLiveLeaderboardEvent extends PuzzleEvent {
  final List<dynamic> leaderboard;
  UpdateLiveLeaderboardEvent(this.leaderboard);
}

// --- STATES ---
abstract class PuzzleState {}

class PuzzleInitialState extends PuzzleState {}

class PuzzleLoadingState extends PuzzleState {}

class PuzzleActiveState extends PuzzleState {
  final List<PuzzlePieceModel> pieces;
  final int moves;
  final int hintsUsed;
  final int gridSize;
  final List<dynamic> liveLeaderboard;
  final double elapsedSeconds;

  PuzzleActiveState({
    required this.pieces,
    required this.moves,
    required this.hintsUsed,
    required this.gridSize,
    required this.liveLeaderboard,
    required this.elapsedSeconds,
  });
}

class PuzzleSubmittingState extends PuzzleState {}

class PuzzleSuccessState extends PuzzleState {
  final int finalScore;
  PuzzleSuccessState(this.finalScore);
}

class PuzzleErrorState extends PuzzleState {
  final String message;
  PuzzleErrorState(this.message);
}

// --- BLoC ---
class PuzzleBloc extends Bloc<PuzzleEvent, PuzzleState> {
  final PuzzleRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  final List<MoveTelemetryModel> _telemetry = [];
  Timer? _ticker;

  int _contestId = 0;
  String? _sessionId;
  String? _signature;
  int _hintsUsed = 0;
  int _movesCount = 0;
  int _gridSize = 3;
  List<PuzzlePieceModel> _currentLayout = [];
  StreamSubscription? _wsSubscription;
  List<dynamic> _liveLeaderboard = [];

  PuzzleBloc(this._repository) : super(PuzzleInitialState()) {
    on<LoadPuzzleGameEvent>(_onLoadPuzzle);
    on<SwapPiecesEvent>(_onSwapPieces);
    on<UseHintEvent>(_onUseHint);
    on<SubmitPuzzleScoreEvent>(_onSubmitScore);
    on<UpdateLiveLeaderboardEvent>(_onUpdateLeaderboard);
  }

  Future<void> _onLoadPuzzle(
    LoadPuzzleGameEvent event,
    Emitter<PuzzleState> emit,
  ) async {
    emit(PuzzleLoadingState());
    try {
      _contestId = event.contestId;
      final session = await _repository.startPuzzleSession(event.contestId);
      _sessionId = session.sessionId;
      _signature = session.signature;
      _gridSize = session.gridSize;

      // Calculate local dimensions based on grid sizing
      // Assuming a standardized layout viewport size of 300.0x300.0 on screens
      double segmentSize = 300.0 / _gridSize;

      _currentLayout = List.generate(session.shuffledLayout.length, (index) {
        int originalValue = session.shuffledLayout[index];
        int col = originalValue % _gridSize;
        int row = originalValue ~/ _gridSize;

        return PuzzlePieceModel(
          pieceId: originalValue,
          x: col * segmentSize,
          y: row * segmentSize,
          width: segmentSize,
          height: segmentSize,
          correctPos: originalValue,
          currentPos: index,
        );
      });

      _hintsUsed = 0;
      _movesCount = 0;
      _telemetry.clear();
      _liveLeaderboard = [];

      try {
        final initialRanks = await _repository.fetchLeaderboard(
          event.contestId,
        );
        _liveLeaderboard = initialRanks;
      } catch (err) {
        print("Failed to fetch initial leaderboard: $err");
      }

      _stopwatch.reset();
      _stopwatch.start();

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (state is PuzzleActiveState) {
          add(UpdateLiveLeaderboardEvent(_liveLeaderboard));
        }
      });

      _wsSubscription?.cancel();
      _wsSubscription = _repository
          .connectToLeaderboard(event.contestId)
          .listen(
            (data) {
              if (data is Map && data['type'] == 'leaderboard_update') {
                _liveLeaderboard = data['data'] as List;
                add(UpdateLiveLeaderboardEvent(_liveLeaderboard));
              }
            },
            onError: (err) {
              print("Leaderboard socket read failure: $err");
            },
          );

      emit(
        PuzzleActiveState(
          pieces: List.from(_currentLayout),
          moves: _movesCount,
          hintsUsed: _hintsUsed,
          gridSize: _gridSize,
          liveLeaderboard: _liveLeaderboard,
          elapsedSeconds: 0.0,
        ),
      );
    } catch (e, stackTrace) {
      emit(PuzzleErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  void _onSwapPieces(SwapPiecesEvent event, Emitter<PuzzleState> emit) {
    if (state is! PuzzleActiveState) return;

    _movesCount++;
    _telemetry.add(
      MoveTelemetryModel(
        fromIndex: event.fromIdx,
        toIndex: event.toIdx,
        dt: _stopwatch.elapsedMilliseconds,
      ),
    );

    // Update coordinate index assignments
    final tempPos = _currentLayout[event.fromIdx].currentPos;
    _currentLayout[event.fromIdx].currentPos =
        _currentLayout[event.toIdx].currentPos;
    _currentLayout[event.toIdx].currentPos = tempPos;

    // Order items so layout builds grid dynamically in index sequence [0, 1, ..., N]
    _currentLayout.sort((a, b) => a.currentPos.compareTo(b.currentPos));

    // If all pieces are in their correct positions, auto-submit the score
    final bool solved = _currentLayout.every((p) => p.isCorrect);
    if (solved) {
      // Emit updated active state first so UI shows final move
      emit(
        PuzzleActiveState(
          pieces: List.from(_currentLayout),
          moves: _movesCount,
          hintsUsed: _hintsUsed,
          gridSize: _gridSize,
          liveLeaderboard: _liveLeaderboard,
          elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        ),
      );

      // Trigger submission asynchronously
      add(SubmitPuzzleScoreEvent());
      return;
    }

    emit(
      PuzzleActiveState(
        pieces: List.from(_currentLayout),
        moves: _movesCount,
        hintsUsed: _hintsUsed,
        gridSize: _gridSize,
        liveLeaderboard: _liveLeaderboard,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  void _onUseHint(UseHintEvent event, Emitter<PuzzleState> emit) {
    if (state is! PuzzleActiveState) return;
    _hintsUsed++;
    emit(
      PuzzleActiveState(
        pieces: List.from(_currentLayout),
        moves: _movesCount,
        hintsUsed: _hintsUsed,
        gridSize: _gridSize,
        liveLeaderboard: _liveLeaderboard,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  void _onUpdateLeaderboard(
    UpdateLiveLeaderboardEvent event,
    Emitter<PuzzleState> emit,
  ) {
    if (state is! PuzzleActiveState) return;
    emit(
      PuzzleActiveState(
        pieces: List.from(_currentLayout),
        moves: _movesCount,
        hintsUsed: _hintsUsed,
        gridSize: _gridSize,
        liveLeaderboard: event.leaderboard,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  Future<void> _onSubmitScore(
    SubmitPuzzleScoreEvent event,
    Emitter<PuzzleState> emit,
  ) async {
    if (state is! PuzzleActiveState || _sessionId == null) return;
    emit(PuzzleSubmittingState());
    _stopwatch.stop();
    _ticker?.cancel();

    try {
      final double secs = _stopwatch.elapsedMilliseconds / 1000.0;
      final result = await _repository.submitPuzzleScore(
        contestId: _contestId,
        sessionId: _sessionId!,
        completionSeconds: secs,
        moves: _movesCount,
        hintsUsed: _hintsUsed,
        telemetry: _telemetry,
        signature: _signature!,
      );
      emit(PuzzleSuccessState(result['score'] as int));
    } catch (e, stackTrace) {
      emit(PuzzleErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _wsSubscription?.cancel();
    _stopwatch.stop();
    return super.close();
  }
}

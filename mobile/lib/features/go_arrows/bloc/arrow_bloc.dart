import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/arrow_models.dart';
import '../repository/arrow_repository.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

// --- EVENTS ---
abstract class ArrowEvent {}

class LoadArrowGameEvent extends ArrowEvent {
  final int contestId;
  LoadArrowGameEvent(this.contestId);
}

class TapArrowEvent extends ArrowEvent {
  final int blockId;
  TapArrowEvent(this.blockId);
}

class SubmitArrowScoreEvent extends ArrowEvent {}

class UpdateLiveArrowLeaderboardEvent extends ArrowEvent {
  final List<dynamic> leaderboard;
  UpdateLiveArrowLeaderboardEvent(this.leaderboard);
}

// --- STATES ---
abstract class ArrowState {}

class ArrowInitialState extends ArrowState {}

class ArrowLoadingState extends ArrowState {}

class ArrowActiveState extends ArrowState {
  final List<ArrowBlockModel> blocks;
  final int moves;
  final int gridSize;
  final List<dynamic> liveLeaderboard;
  final double elapsedSeconds;

  ArrowActiveState({
    required this.blocks,
    required this.moves,
    required this.gridSize,
    required this.liveLeaderboard,
    required this.elapsedSeconds,
  });
}

class ArrowSubmittingState extends ArrowState {}

class ArrowSuccessState extends ArrowState {
  final int finalScore;
  ArrowSuccessState(this.finalScore);
}

class ArrowErrorState extends ArrowState {
  final String message;
  ArrowErrorState(this.message);
}

// --- BLoC ---
class ArrowBloc extends Bloc<ArrowEvent, ArrowState> {
  final ArrowRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  final List<TapTelemetryModel> _telemetry = [];
  Timer? _ticker;

  int _contestId = 0;
  String? _sessionId;
  String? _signature;
  int _movesCount = 0;
  int _gridSize = 4;
  List<ArrowBlockModel> _currentLayout = [];
  StreamSubscription? _wsSubscription;
  List<dynamic> _liveLeaderboard = [];

  ArrowBloc(this._repository) : super(ArrowInitialState()) {
    on<LoadArrowGameEvent>(_onLoadArrow);
    on<TapArrowEvent>(_onTapArrow);
    on<SubmitArrowScoreEvent>(_onSubmitScore);
    on<UpdateLiveArrowLeaderboardEvent>(_onUpdateLeaderboard);
  }

  Future<void> _onLoadArrow(
    LoadArrowGameEvent event,
    Emitter<ArrowState> emit,
  ) async {
    emit(ArrowLoadingState());
    try {
      _contestId = event.contestId;
      final session = await _repository.startArrowSession(event.contestId);
      _sessionId = session.sessionId;
      _signature = session.signature;
      _gridSize = session.gridSize;
      _currentLayout = session.layout;

      _movesCount = 0;
      _telemetry.clear();
      _liveLeaderboard = [];

      try {
        final initialRanks = await _repository.fetchLeaderboard(event.contestId);
        _liveLeaderboard = initialRanks;
      } catch (err) {
        print("Failed to fetch initial leaderboard: $err");
      }

      _stopwatch.reset();
      _stopwatch.start();

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (state is ArrowActiveState) {
          add(UpdateLiveArrowLeaderboardEvent(_liveLeaderboard));
        }
      });

      _wsSubscription?.cancel();
      _wsSubscription = _repository
          .connectToLeaderboard(event.contestId)
          .listen(
            (data) {
              if (data is Map && data['type'] == 'leaderboard_update') {
                _liveLeaderboard = data['data'] as List;
                add(UpdateLiveArrowLeaderboardEvent(_liveLeaderboard));
              }
            },
            onError: (err) {
              print("Leaderboard socket read failure: $err");
            },
          );

      emit(
        ArrowActiveState(
          blocks: List.from(_currentLayout.map((b) => ArrowBlockModel(
            id: b.id,
            row: b.row,
            col: b.col,
            direction: b.direction,
            isCleared: b.isCleared,
          ))),
          moves: _movesCount,
          gridSize: _gridSize,
          liveLeaderboard: _liveLeaderboard,
          elapsedSeconds: 0.0,
        ),
      );
    } catch (e, stackTrace) {
      emit(ArrowErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  void _onTapArrow(TapArrowEvent event, Emitter<ArrowState> emit) {
    if (state is! ArrowActiveState) return;

    _movesCount++;

    final blockIndex = _currentLayout.indexWhere((b) => b.id == event.blockId);
    if (blockIndex == -1) return;

    final block = _currentLayout[blockIndex];
    if (block.isCleared) return;

    final blocked = _isBlockObstructed(block, _currentLayout, _gridSize);

    _telemetry.add(
      TapTelemetryModel(
        blockId: block.id,
        dt: _stopwatch.elapsedMilliseconds,
        success: !blocked,
      ),
    );

    if (!blocked) {
      block.isCleared = true;

      // Check if all are cleared
      final allCleared = _currentLayout.every((b) => b.isCleared);
      if (allCleared) {
        emit(
          ArrowActiveState(
            blocks: List.from(_currentLayout.map((b) => ArrowBlockModel(
              id: b.id,
              row: b.row,
              col: b.col,
              direction: b.direction,
              isCleared: b.isCleared,
            ))),
            moves: _movesCount,
            gridSize: _gridSize,
            liveLeaderboard: _liveLeaderboard,
            elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
          ),
        );
        add(SubmitArrowScoreEvent());
        return;
      }
    }

    emit(
      ArrowActiveState(
        blocks: List.from(_currentLayout.map((b) => ArrowBlockModel(
          id: b.id,
          row: b.row,
          col: b.col,
          direction: b.direction,
          isCleared: b.isCleared,
        ))),
        moves: _movesCount,
        gridSize: _gridSize,
        liveLeaderboard: _liveLeaderboard,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  void _onUpdateLeaderboard(
    UpdateLiveArrowLeaderboardEvent event,
    Emitter<ArrowState> emit,
  ) {
    if (state is! ArrowActiveState) return;
    emit(
      ArrowActiveState(
        blocks: List.from(_currentLayout.map((b) => ArrowBlockModel(
          id: b.id,
          row: b.row,
          col: b.col,
          direction: b.direction,
          isCleared: b.isCleared,
        ))),
        moves: _movesCount,
        gridSize: _gridSize,
        liveLeaderboard: event.leaderboard,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  Future<void> _onSubmitScore(
    SubmitArrowScoreEvent event,
    Emitter<ArrowState> emit,
  ) async {
    if (state is! ArrowActiveState || _sessionId == null) return;
    emit(ArrowSubmittingState());
    _stopwatch.stop();
    _ticker?.cancel();

    try {
      final double secs = _stopwatch.elapsedMilliseconds / 1000.0;
      final result = await _repository.submitArrowScore(
        contestId: _contestId,
        sessionId: _sessionId!,
        completionSeconds: secs,
        moves: _movesCount,
        telemetry: _telemetry,
        signature: _signature!,
      );
      emit(ArrowSuccessState(result['score'] as int));
    } catch (e, stackTrace) {
      emit(ArrowErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  bool _isBlockObstructed(ArrowBlockModel tappedBlock, List<ArrowBlockModel> activeBlocks, int gridSize) {
    int r = tappedBlock.row;
    int c = tappedBlock.col;
    String d = tappedBlock.direction;

    if (d == 'UP') {
      for (int rCheck = 0; rCheck < r; rCheck++) {
        if (activeBlocks.any((b) => !b.isCleared && b.row == rCheck && b.col == c)) {
          return true;
        }
      }
    } else if (d == 'DOWN') {
      for (int rCheck = r + 1; rCheck < gridSize; rCheck++) {
        if (activeBlocks.any((b) => !b.isCleared && b.row == rCheck && b.col == c)) {
          return true;
        }
      }
    } else if (d == 'LEFT') {
      for (int cCheck = 0; cCheck < c; cCheck++) {
        if (activeBlocks.any((b) => !b.isCleared && b.row == r && b.col == cCheck)) {
          return true;
        }
      }
    } else if (d == 'RIGHT') {
      for (int cCheck = c + 1; cCheck < gridSize; cCheck++) {
        if (activeBlocks.any((b) => !b.isCleared && b.row == r && b.col == cCheck)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _wsSubscription?.cancel();
    _stopwatch.stop();
    return super.close();
  }
}

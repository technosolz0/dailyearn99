import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/word_puzzle_models.dart';
import '../repository/word_puzzle_repository.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

// --- EVENTS ---
abstract class WordPuzzleEvent {}

class JoinWordContestEvent extends WordPuzzleEvent {
  final int contestId;
  JoinWordContestEvent(this.contestId);
}

class StartWordContestEvent extends WordPuzzleEvent {
  final int contestId;
  final String sessionId;
  StartWordContestEvent(this.contestId, this.sessionId);
}

class SubmitWordAnswerEvent extends WordPuzzleEvent {
  final String answer;
  final bool usedHint;
  SubmitWordAnswerEvent({required this.answer, required this.usedHint});
}

class TickTimerEvent extends WordPuzzleEvent {}

class UpdateWordLeaderboardEvent extends WordPuzzleEvent {
  final List<dynamic> leaderboard;
  UpdateWordLeaderboardEvent(this.leaderboard);
}

// --- STATES ---
abstract class WordPuzzleState {}

class WordPuzzleInitialState extends WordPuzzleState {}

class WordPuzzleLoadingState extends WordPuzzleState {}

class WordPuzzleLobbyJoinedState extends WordPuzzleState {
  final String sessionId;
  final double feeDeducted;
  WordPuzzleLobbyJoinedState({required this.sessionId, required this.feeDeducted});
}

class WordPuzzleActiveState extends WordPuzzleState {
  final List<WordQuestionModel> questions;
  final int currentQuestionIndex;
  final int score;
  final int hintsUsed;
  final int wrongAttempts;
  final double elapsedSeconds;
  final int remainingSeconds;
  final List<dynamic> liveLeaderboard;
  final bool isSubmittingAnswer;
  final String? feedbackMessage;

  WordPuzzleActiveState({
    required this.questions,
    required this.currentQuestionIndex,
    required this.score,
    required this.hintsUsed,
    required this.wrongAttempts,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.liveLeaderboard,
    required this.isSubmittingAnswer,
    this.feedbackMessage,
  });

  WordQuestionModel get currentQuestion => questions[currentQuestionIndex];

  WordPuzzleActiveState copyWith({
    List<WordQuestionModel>? questions,
    int? currentQuestionIndex,
    int? score,
    int? hintsUsed,
    int? wrongAttempts,
    double? elapsedSeconds,
    int? remainingSeconds,
    List<dynamic>? liveLeaderboard,
    bool? isSubmittingAnswer,
    String? feedbackMessage,
  }) {
    return WordPuzzleActiveState(
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      score: score ?? this.score,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      liveLeaderboard: liveLeaderboard ?? this.liveLeaderboard,
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
    );
  }
}

class WordPuzzleCompletedState extends WordPuzzleState {
  final int finalScore;
  final double completionTime;
  WordPuzzleCompletedState({required this.finalScore, required this.completionTime});
}

class WordPuzzleErrorState extends WordPuzzleState {
  final String message;
  WordPuzzleErrorState(this.message);
}

// --- BLoC ---
class WordPuzzleBloc extends Bloc<WordPuzzleEvent, WordPuzzleState> {
  final WordPuzzleRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription? _wsSubscription;

  int _contestId = 0;
  String? _sessionId;
  String? _signature;
  int _score = 0;
  int _hintsUsed = 0;
  int _wrongAttempts = 0;
  int _durationSeconds = 300;
  List<WordQuestionModel> _questions = [];
  int _currentIndex = 0;
  List<dynamic> _liveLeaderboard = [];
  double _questionStartTime = 0.0;

  WordPuzzleBloc(this._repository) : super(WordPuzzleInitialState()) {
    on<JoinWordContestEvent>(_onJoinContest);
    on<StartWordContestEvent>(_onStartContest);
    on<SubmitWordAnswerEvent>(_onSubmitAnswer);
    on<TickTimerEvent>(_onTickTimer);
    on<UpdateWordLeaderboardEvent>(_onUpdateLeaderboard);
  }

  Future<void> _onJoinContest(JoinWordContestEvent event, Emitter<WordPuzzleState> emit) async {
    emit(WordPuzzleLoadingState());
    try {
      _contestId = event.contestId;
      final joinResult = await _repository.joinWordContest(event.contestId);
      _sessionId = joinResult.sessionId;

      emit(WordPuzzleLobbyJoinedState(
        sessionId: joinResult.sessionId,
        feeDeducted: joinResult.entryFeeDeducted,
      ));
    } catch (e, stackTrace) {
      emit(WordPuzzleErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  Future<void> _onStartContest(StartWordContestEvent event, Emitter<WordPuzzleState> emit) async {
    emit(WordPuzzleLoadingState());
    try {
      _contestId = event.contestId;
      _sessionId = event.sessionId;

      final sessionData = await _repository.startWordContest(
        contestId: event.contestId,
        sessionId: event.sessionId,
      );

      _questions = sessionData.questions;
      _durationSeconds = sessionData.durationSeconds;
      _signature = sessionData.signature;

      _score = 0;
      _hintsUsed = 0;
      _wrongAttempts = 0;
      _currentIndex = 0;
      _liveLeaderboard = [];
      _questionStartTime = 0.0;

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

      _stopwatch.reset();
      _stopwatch.start();

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        add(TickTimerEvent());
      });

      _wsSubscription?.cancel();
      _wsSubscription = _repository.connectToLeaderboard(event.contestId).listen((data) {
        if (data is Map && data['type'] == 'leaderboard_update') {
          _liveLeaderboard = data['data'] as List;
          add(UpdateWordLeaderboardEvent(_liveLeaderboard));
        }
      }, onError: (err) {
        print("Word Leaderboard socket failure: $err");
      });

      emit(WordPuzzleActiveState(
        questions: _questions,
        currentQuestionIndex: _currentIndex,
        score: _score,
        hintsUsed: _hintsUsed,
        wrongAttempts: _wrongAttempts,
        elapsedSeconds: 0.0,
        remainingSeconds: _durationSeconds,
        liveLeaderboard: _liveLeaderboard,
        isSubmittingAnswer: false,
      ));
    } catch (e, stackTrace) {
      emit(WordPuzzleErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  void _onTickTimer(TickTimerEvent event, Emitter<WordPuzzleState> emit) {
    if (state is! WordPuzzleActiveState) return;
    final currentState = state as WordPuzzleActiveState;

    final double elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
    final int remaining = _durationSeconds - elapsed.floor();

    if (remaining <= 0) {
      _ticker?.cancel();
      _stopwatch.stop();
      emit(WordPuzzleCompletedState(
        finalScore: _score,
        completionTime: elapsed,
      ));
    } else {
      emit(currentState.copyWith(
        elapsedSeconds: elapsed,
        remainingSeconds: remaining,
      ));
    }
  }

  void _onUpdateLeaderboard(UpdateWordLeaderboardEvent event, Emitter<WordPuzzleState> emit) {
    if (state is! WordPuzzleActiveState) return;
    final currentState = state as WordPuzzleActiveState;
    emit(currentState.copyWith(liveLeaderboard: event.leaderboard));
  }

  Future<void> _onSubmitAnswer(SubmitWordAnswerEvent event, Emitter<WordPuzzleState> emit) async {
    if (state is! WordPuzzleActiveState || _sessionId == null) return;
    final currentState = state as WordPuzzleActiveState;

    emit(currentState.copyWith(isSubmittingAnswer: true, feedbackMessage: null));

    try {
      final double totalElapsed = _stopwatch.elapsedMilliseconds / 1000.0;
      final double timeTaken = totalElapsed - _questionStartTime;

      final result = await _repository.submitWordAnswer(
        sessionId: _sessionId!,
        questionId: currentState.currentQuestion.id,
        answer: event.answer,
        elapsedSeconds: totalElapsed,
        timeTakenSeconds: timeTaken,
        usedHint: event.usedHint,
        signature: _signature!,
      );

      _score = result.accumulatedScore;
      if (event.usedHint) _hintsUsed++;
      if (!result.isCorrect) _wrongAttempts++;

      _questionStartTime = totalElapsed; // Reset question start time reference

      if (result.isCorrect) {
        // Move to next question if available
        if (_currentIndex + 1 < _questions.length) {
          _currentIndex++;
          emit(WordPuzzleActiveState(
            questions: _questions,
            currentQuestionIndex: _currentIndex,
            score: _score,
            hintsUsed: _hintsUsed,
            wrongAttempts: _wrongAttempts,
            elapsedSeconds: totalElapsed,
            remainingSeconds: _durationSeconds - totalElapsed.floor(),
            liveLeaderboard: _liveLeaderboard,
            isSubmittingAnswer: false,
            feedbackMessage: "Correct! Moving to next puzzle.",
          ));
        } else {
          // Finished all puzzles
          _ticker?.cancel();
          _stopwatch.stop();
          emit(WordPuzzleCompletedState(
            finalScore: _score,
            completionTime: totalElapsed,
          ));
        }
      } else {
        // Wrong answer, stay on same puzzle but display feedback
        emit(currentState.copyWith(
          score: _score,
          hintsUsed: _hintsUsed,
          wrongAttempts: _wrongAttempts,
          isSubmittingAnswer: false,
          feedbackMessage: "Incorrect answer. Penalty applied! Try again.",
        ));
      }
    } catch (e, stackTrace) {
      emit(currentState.copyWith(
        isSubmittingAnswer: false,
        feedbackMessage: ErrorHandler.handle(e, stackTrace),
      ));
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

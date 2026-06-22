import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/fruit_models.dart';
import '../repository/fruit_repository.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

// --- EVENTS ---
abstract class FruitGameEvent {}

class LoadFruitSettingsEvent extends FruitGameEvent {}

class StartFruitGameEvent extends FruitGameEvent {
  final double betAmount;
  StartFruitGameEvent(this.betAmount);
}

class RegisterSliceEvent extends FruitGameEvent {
  final String itemType;
  RegisterSliceEvent(this.itemType);
}

class RegisterMissEvent extends FruitGameEvent {}

class TriggerCashoutEvent extends FruitGameEvent {}

class TriggerBombExplodeEvent extends FruitGameEvent {}

// --- STATES ---
abstract class FruitGameState {}

class FruitGameInitialState extends FruitGameState {}

class FruitGameLoadingSettingsState extends FruitGameState {}

class FruitGameSettingsLoadedState extends FruitGameState {
  final FruitSettingsModel settings;
  FruitGameSettingsLoadedState(this.settings);
}

class FruitGameLoadingState extends FruitGameState {}

class FruitGameActiveState extends FruitGameState {
  final FruitGameModel session;
  final FruitSettingsModel settings;
  final double multiplier;
  final double currentPayout;
  final int remainingSeconds;
  final int sliceCount;
  final int missCount;

  FruitGameActiveState({
    required this.session,
    required this.settings,
    required this.multiplier,
    required this.currentPayout,
    required this.remainingSeconds,
    required this.sliceCount,
    required this.missCount,
  });
}

class FruitGameSubmittingState extends FruitGameState {}

class FruitGameEndedState extends FruitGameState {
  final FruitGameModel session;
  final double finalMultiplier;
  final double payout;

  FruitGameEndedState({
    required this.session,
    required this.finalMultiplier,
    required this.payout,
  });
}

class FruitGameErrorState extends FruitGameState {
  final String message;
  FruitGameErrorState(this.message);
}

// --- BLoC ---
class FruitGameBloc extends Bloc<FruitGameEvent, FruitGameState> {
  final FruitRepository _repository;
  final Stopwatch _matchStopwatch = Stopwatch();

  FruitSettingsModel? _settings;
  FruitGameModel? _session;
  double _currentMultiplier = 1.0;
  int _sliceCount = 0;
  int _missCount = 0;
  Timer? _ticker;

  FruitGameBloc(this._repository) : super(FruitGameInitialState()) {
    on<LoadFruitSettingsEvent>(_onLoadSettings);
    on<StartFruitGameEvent>(_onStartGame);
    on<RegisterSliceEvent>(_onRegisterSlice);
    on<RegisterMissEvent>(_onRegisterMiss);
    on<TriggerCashoutEvent>(_onCashout);
    on<TriggerBombExplodeEvent>(_onBombExplode);
  }

  Future<void> _onLoadSettings(LoadFruitSettingsEvent event, Emitter<FruitGameState> emit) async {
    emit(FruitGameLoadingSettingsState());
    try {
      _settings = await _repository.fetchFruitSettings();
      emit(FruitGameSettingsLoadedState(_settings!));
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  Future<void> _onStartGame(StartFruitGameEvent event, Emitter<FruitGameState> emit) async {
    emit(FruitGameLoadingState());
    try {
      // 1. Start single player game on backend
      _session = await _repository.startFruitGame(event.betAmount);

      _currentMultiplier = 1.0;
      _sliceCount = 0;
      _missCount = 0;

      _matchStopwatch.reset();
      _matchStopwatch.start();

      emit(FruitGameActiveState(
        session: _session!,
        settings: _settings!,
        multiplier: _currentMultiplier,
        currentPayout: _currentMultiplier * _session!.betAmount,
        remainingSeconds: 30,
        sliceCount: _sliceCount,
        missCount: _missCount,
      ));

      // 2. Start 30-second countdown ticker
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        final elapsed = _matchStopwatch.elapsed.inSeconds;
        final remaining = 30 - elapsed;
        if (remaining <= 0) {
          _ticker?.cancel();
          add(TriggerCashoutEvent());
        } else if (state is FruitGameActiveState) {
          emit(FruitGameActiveState(
            session: _session!,
            settings: _settings!,
            multiplier: _currentMultiplier,
            currentPayout: _currentMultiplier * _session!.betAmount,
            remainingSeconds: remaining,
            sliceCount: _sliceCount,
            missCount: _missCount,
          ));
        }
      });
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  void _onRegisterSlice(RegisterSliceEvent event, Emitter<FruitGameState> emit) {
    if (state is! FruitGameActiveState) return;

    _sliceCount++;
    final multipliers = _settings?.getParsedMultipliers() ?? {};
    final double increment = multipliers[event.itemType] ?? 0.10; // default 0.10x increment

    _currentMultiplier += increment;

    final elapsed = _matchStopwatch.elapsed.inSeconds;
    final remaining = max(0, 30 - elapsed);

    emit(FruitGameActiveState(
      session: _session!,
      settings: _settings!,
      multiplier: _currentMultiplier,
      currentPayout: _currentMultiplier * _session!.betAmount,
      remainingSeconds: remaining,
      sliceCount: _sliceCount,
      missCount: _missCount,
    ));
  }

  void _onRegisterMiss(RegisterMissEvent event, Emitter<FruitGameState> emit) {
    if (state is! FruitGameActiveState) return;

    _missCount++;
    final multipliers = _settings?.getParsedMultipliers() ?? {};
    final double penalty = (multipliers['miss'] ?? -0.05).abs(); // penalty is subtracted

    // Deduct with floor of 0.1x
    _currentMultiplier = max(0.1, _currentMultiplier - penalty);

    final elapsed = _matchStopwatch.elapsed.inSeconds;
    final remaining = max(0, 30 - elapsed);

    emit(FruitGameActiveState(
      session: _session!,
      settings: _settings!,
      multiplier: _currentMultiplier,
      currentPayout: _currentMultiplier * _session!.betAmount,
      remainingSeconds: remaining,
      sliceCount: _sliceCount,
      missCount: _missCount,
    ));
  }

  Future<void> _onCashout(TriggerCashoutEvent event, Emitter<FruitGameState> emit) async {
    if (state is! FruitGameActiveState || _session == null) return;

    emit(FruitGameSubmittingState());
    _matchStopwatch.stop();
    _ticker?.cancel();

    try {
      final endedGame = await _repository.cashoutFruitGame(
        gameId: _session!.id,
        finalMultiplier: _currentMultiplier,
        signature: _session!.signature ?? '',
      );
      emit(FruitGameEndedState(
        session: endedGame,
        finalMultiplier: _currentMultiplier,
        payout: endedGame.winAmount,
      ));
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  Future<void> _onBombExplode(TriggerBombExplodeEvent event, Emitter<FruitGameState> emit) async {
    if (state is! FruitGameActiveState || _session == null) return;

    emit(FruitGameSubmittingState());
    _matchStopwatch.stop();
    _ticker?.cancel();

    try {
      final endedGame = await _repository.bombFruitGame(
        gameId: _session!.id,
        signature: _session!.signature ?? '',
      );
      emit(FruitGameEndedState(
        session: endedGame,
        finalMultiplier: 0.0,
        payout: 0.0,
      ));
    } catch (e, stackTrace) {
      emit(FruitGameErrorState(ErrorHandler.handle(e, stackTrace)));
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _matchStopwatch.stop();
    return super.close();
  }
}

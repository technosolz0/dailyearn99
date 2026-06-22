import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/fruit_game_bloc.dart';
import '../flame/fruit_slicing_game.dart';
import '../models/fruit_models.dart';

class TournamentGameScreen extends StatefulWidget {
  final String title;

  const TournamentGameScreen({Key? key, required this.title}) : super(key: key);

  @override
  State<TournamentGameScreen> createState() => _TournamentGameScreenState();
}

class _TournamentGameScreenState extends State<TournamentGameScreen> {
  FruitSlicingGame? _flameGame;

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<FruitGameBloc>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A1B),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF13102C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading:
            false, // Prevent users from going back mid-game easily
      ),
      body: BlocConsumer<FruitGameBloc, FruitGameState>(
        listener: (context, state) {
          if (state is FruitGameEndedState) {
            _showCompletionDialog(
              context,
              state.session,
              state.finalMultiplier,
              state.payout,
            );
          } else if (state is FruitGameErrorState) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.redAccent,
                ),
              );
          }
        },
        builder: (context, state) {
          if (state is FruitGameInitialState ||
              state is FruitGameLoadingSettingsState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4500)),
            );
          }

          if (state is FruitGameLoadingState) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF4500)),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing game session...',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          if (state is FruitGameActiveState) {
            _flameGame ??= FruitSlicingGame(
              gameBloc: bloc,
              seed: state.session.signature ?? 'default_seed_value',
            );

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatsBar(state),
                  const SizedBox(height: 4),

                  // Flame game screen canvas
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: GameWidget(game: _flameGame!),
                      ),
                    ),
                  ),

                  // Glowing bottom Cash out action button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13102C),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.06)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            bloc.add(TriggerCashoutEvent());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade700,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.greenAccent.withOpacity(0.5),
                            elevation: 8,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'CASH OUT (₹${state.currentPayout.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is FruitGameSubmittingState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.greenAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'SECURING PAYOUT...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registering winnings on blockchain secure ledger.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Text(
              'Session Terminated.',
              style: TextStyle(color: Colors.white38),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsBar(FruitGameActiveState state) {
    final String timeStr = '${state.remainingSeconds}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF13102C),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            'BET AMOUNT',
            '₹${state.session.betAmount.toStringAsFixed(0)}',
            Icons.stars,
            const Color(0xFFFF4500),
          ),
          _buildStatCard(
            'MULTIPLIER',
            '${state.multiplier.toStringAsFixed(2)}x',
            Icons.trending_up,
            Colors.cyanAccent,
          ),
          _buildStatCard(
            'TIME LEFT',
            timeStr,
            Icons.timer,
            state.remainingSeconds < 8 ? Colors.redAccent : Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D183B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white54,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(
    BuildContext context,
    FruitGameModel session,
    double finalMultiplier,
    double payout,
  ) {
    final bool isWon = session.status == 'WON';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13102C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isWon ? Colors.greenAccent : Colors.redAccent,
              width: 1.5,
            ),
          ),
          title: Center(
            child: Text(
              isWon ? 'CASHED OUT!' : 'GAME OVER / BOMB HIT',
              style: TextStyle(
                color: isWon ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWon ? Icons.emoji_events : Icons.error_outline,
                color: isWon ? Colors.amber : Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isWon
                    ? 'Winnings credited to your wallet balance.'
                    : 'A bomb has detonated! Winnings are forfeited.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '₹${payout.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isWon ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Text(
                'PAYOUT AMOUNT',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${finalMultiplier.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Text(
                'FINAL MULTIPLIER SCALE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  Navigator.of(context).pop(); // Exit screen back to Lobby
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'RETURN TO LOBBY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

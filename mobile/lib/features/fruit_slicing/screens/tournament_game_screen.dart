import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/fruit_game_bloc.dart';
import '../flame/fruit_slicing_game.dart';

class TournamentGameScreen extends StatefulWidget {
  final int contestId;
  final String title;

  const TournamentGameScreen({
    Key? key,
    required this.contestId,
    required this.title,
  }) : super(key: key);

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
      ),
      body: BlocConsumer<FruitGameBloc, FruitGameState>(
        listener: (context, state) {
          if (state is FruitGameSuccessState) {
            _showCompletionDialog(context, state.finalScore);
          } else if (state is FruitGameErrorState) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is FruitGameInitialState) {
            // Trigger automatic join loading
            bloc.add(LoadFruitGameEvent(widget.contestId));
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
                  SizedBox(height: 16),
                  Text(
                    'Acquiring secure gaming session...',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  )
                ],
              ),
            );
          }

          if (state is FruitGameActiveState) {
            // Lazy load the Flame game loop instance once seed is acquired
            _flameGame ??= FruitSlicingGame(gameBloc: bloc, seed: state.seed);

            return SafeArea(
              child: Column(
                children: [
                  _buildStatsBar(state),
                  const SizedBox(height: 4),
                  
                  // Central interactive Game Loop Canvas
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: GameWidget(game: _flameGame!),
                      ),
                    ),
                  ),

                  _buildLiveLeaderboard(state.liveLeaderboard),
                  const SizedBox(height: 8),
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
                    'VERIFYING PLAYBACK REPLAY...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anti-Cheat Kinematics verification active.',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Text(
              'Match Terminated.',
              style: TextStyle(color: Colors.white38),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsBar(FruitGameActiveState state) {
    final int mins = (state.remainingSeconds ~/ 60);
    final int secs = (state.remainingSeconds % 60);
    final String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

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
            'SCORE',
            '${state.score}',
            Icons.stars,
            const Color(0xFFFF4500),
          ),
          _buildStatCard(
            'TIME LEFT',
            timeStr,
            Icons.timer,
            state.remainingSeconds < 15 ? Colors.redAccent : Colors.greenAccent,
          ),
          _buildStatCard(
            'COMBO / MISS',
            '${state.maxCombo}x / ${state.missCount}',
            Icons.flash_on,
            Colors.amberAccent,
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

  Widget _buildLiveLeaderboard(List<dynamic> list) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13102C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Text(
            'LIVE RANKS:',
            style: TextStyle(
              color: Color(0xFFFF4500),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No matches logged yet. Play to set a score!',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D183B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${item['rank']}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item['name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${item['score']}',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(BuildContext context, int finalScore) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13102C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.greenAccent, width: 1.5),
          ),
          title: const Center(
            child: Text(
              'TOURNAMENT FINISHED!',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                'Replay telemetry verified successfully!\nstandings and cash distributions will refresh on contest end.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$finalScore PTS',
                style: const TextStyle(
                  color: Color(0xFFFF4500),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Text(
                'FINAL SCORE',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
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
                  'RETURN TO TOURNAMENTS',
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

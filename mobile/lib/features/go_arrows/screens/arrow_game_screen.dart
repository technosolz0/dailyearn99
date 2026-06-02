import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/arrow_bloc.dart';
import '../models/arrow_models.dart';

class ArrowGameScreen extends StatefulWidget {
  final int contestId;
  final String title;

  const ArrowGameScreen({
    super.key,
    required this.contestId,
    required this.title,
  });

  @override
  State<ArrowGameScreen> createState() => _ArrowGameScreenState();
}

class _ArrowGameScreenState extends State<ArrowGameScreen> {
  final Map<int, double> _shakeOffsets = {};

  void _triggerShake(int blockId) {
    if (!mounted) return;
    setState(() {
      _shakeOffsets[blockId] = 10.0;
    });
    Future.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      setState(() {
        _shakeOffsets[blockId] = -10.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() {
        _shakeOffsets[blockId] = 8.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _shakeOffsets[blockId] = -8.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() {
        _shakeOffsets[blockId] = 4.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _shakeOffsets[blockId] = 0.0;
      });
    });
  }

  bool _isObstructed(ArrowBlockModel tappedBlock, List<ArrowBlockModel> activeBlocks, int gridSize) {
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

  IconData _getArrowIcon(String direction) {
    switch (direction) {
      case 'UP':
        return Icons.arrow_upward_rounded;
      case 'DOWN':
        return Icons.arrow_downward_rounded;
      case 'LEFT':
        return Icons.arrow_back_rounded;
      case 'RIGHT':
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C091A),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        backgroundColor: const Color(0xFF140F2D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: BlocConsumer<ArrowBloc, ArrowState>(
        listener: (context, state) {
          if (state is ArrowSuccessState) {
            _showSuccessDialog(context, state.finalScore);
          } else if (state is ArrowErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ArrowLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9900)),
            );
          }

          if (state is ArrowActiveState) {
            return _buildGameplayArea(context, state);
          }

          return const Center(
            child: Text(
              'Initializing Challenge...',
              style: TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameplayArea(BuildContext context, ArrowActiveState state) {
    double totalWidth = MediaQuery.of(context).size.width - 40;
    double segmentSize = totalWidth / state.gridSize;

    return SafeArea(
      child: Column(
        children: [
          _buildStatsBar(state),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140F2D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF9900),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9900).withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: state.blocks.map((block) {
                        double shake = _shakeOffsets[block.id] ?? 0.0;
                        double leftPosition = block.col * segmentSize + shake;
                        double topPosition = block.row * segmentSize;

                        if (block.isCleared) {
                          if (block.direction == 'UP') {
                            topPosition = -MediaQuery.of(context).size.height;
                          } else if (block.direction == 'DOWN') {
                            topPosition = MediaQuery.of(context).size.height;
                          } else if (block.direction == 'LEFT') {
                            leftPosition = -MediaQuery.of(context).size.width;
                          } else if (block.direction == 'RIGHT') {
                            leftPosition = MediaQuery.of(context).size.width;
                          }
                        }

                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          left: leftPosition,
                          top: topPosition,
                          width: segmentSize,
                          height: segmentSize,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: block.isCleared ? 0.0 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: GestureDetector(
                                onTap: () {
                                  if (block.isCleared) return;
                                  final blocked = _isObstructed(block, state.blocks, state.gridSize);
                                  if (blocked) {
                                    _triggerShake(block.id);
                                  }
                                  context.read<ArrowBloc>().add(TapArrowEvent(block.id));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF241C44),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFF9900).withOpacity(0.6),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF9900).withOpacity(0.08),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _getArrowIcon(block.direction),
                                    color: const Color(0xFFFF9900),
                                    size: segmentSize * 0.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLiveLeaderboard(state.liveLeaderboard),
          const SizedBox(height: 12),
          _buildInstructionsText(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ArrowActiveState state) {
    int mins = (state.elapsedSeconds ~/ 60);
    int secs = (state.elapsedSeconds % 60).toInt();
    String timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF140F2D),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'TAPS',
            '${state.moves}',
            Icons.touch_app_rounded,
            Colors.cyanAccent,
          ),
          _buildStatCard(
            'TIME',
            timeStr,
            Icons.timer_rounded,
            Colors.greenAccent,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF221A44),
        borderRadius: BorderRadius.circular(10),
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
                  fontSize: 14,
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
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF130E30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Text(
            'LIVE RANKS:',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No completions logged yet.',
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22174C),
                          borderRadius: BorderRadius.circular(8),
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

  Widget _buildInstructionsText() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        '⚠️ Dhyan rahein: Agar arrow ke raste me koi dusra block hai toh tap karne par collision shake hoga aur score deduct hoga! Clear the entire board as fast as possible.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 10.5,
          height: 1.4,
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF140F2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF9900), width: 1.5),
          ),
          title: const Center(
            child: Text(
              'VICTORY SECURED!',
              style: TextStyle(
                color: Color(0xFFFF9900),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Your arrow telemetry has been successfully and securely verified by target99 systems:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                '$score PTS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to lobby
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9900),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('CONTINUE'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

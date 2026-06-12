import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/puzzle_bloc.dart';
import '../models/puzzle_models.dart';

class PuzzleGameScreen extends StatefulWidget {
  final int contestId;
  final String title;
  final String imageUrl;

  const PuzzleGameScreen({
    super.key,
    required this.contestId,
    required this.title,
    required this.imageUrl,
  });

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  int? _selectedTileIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF151030),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: BlocConsumer<PuzzleBloc, PuzzleState>(
        listener: (context, state) {
          if (state is PuzzleSuccessState) {
            _showSuccessDialog(context, state.finalScore);
          } else if (state is PuzzleErrorState) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PuzzleLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
            );
          }

          if (state is PuzzleActiveState) {
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

  Widget _buildReferenceImage() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A2BE2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.5),
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white30,
                  size: 24,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameplayArea(BuildContext context, PuzzleActiveState state) {
    return SafeArea(
      child: Column(
        children: [
          _buildStatsBar(state),
          const SizedBox(height: 12),
          _buildReferenceImage(),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151030),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8A2BE2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A2BE2).withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double boardSize = constraints.maxWidth;
                        final double tileSize = boardSize / state.gridSize;

                        return Stack(
                          children: state.pieces.map((piece) {
                            final double left =
                                (piece.currentPos % state.gridSize) * tileSize;
                            final double top =
                                (piece.currentPos ~/ state.gridSize) * tileSize;
                            final bool isSelected =
                                _selectedTileIndex == piece.currentPos;

                            return AnimatedPositioned(
                              key: ValueKey(piece.pieceId),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              left: left,
                              top: top,
                              width: tileSize,
                              height: tileSize,
                              child: DragTarget<int>(
                                builder:
                                    (context, candidateData, rejectedData) {
                                      return Draggable<int>(
                                        data: piece.currentPos,
                                        feedback: SizedBox(
                                          width: tileSize,
                                          height: tileSize,
                                          child: _buildPieceWidget(
                                            piece,
                                            state.gridSize,
                                            isDragging: true,
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.2,
                                          child: _buildPieceWidget(
                                            piece,
                                            state.gridSize,
                                          ),
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (_selectedTileIndex == null) {
                                                _selectedTileIndex =
                                                    piece.currentPos;
                                              } else if (_selectedTileIndex ==
                                                  piece.currentPos) {
                                                _selectedTileIndex = null;
                                              } else {
                                                final int fromIdx =
                                                    _selectedTileIndex!;
                                                final int toIdx =
                                                    piece.currentPos;
                                                _selectedTileIndex = null;
                                                BlocProvider.of<PuzzleBloc>(
                                                  context,
                                                ).add(
                                                  SwapPiecesEvent(
                                                    fromIdx,
                                                    toIdx,
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                          child: _buildPieceWidget(
                                            piece,
                                            state.gridSize,
                                            isSelected: isSelected,
                                          ),
                                        ),
                                      );
                                    },
                                onWillAcceptWithDetails: (details) =>
                                    details.data != piece.currentPos,
                                onAcceptWithDetails: (details) {
                                  setState(() {
                                    _selectedTileIndex = null;
                                  });
                                  BlocProvider.of<PuzzleBloc>(context).add(
                                    SwapPiecesEvent(
                                      details.data,
                                      piece.currentPos,
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLiveLeaderboard(state.liveLeaderboard),
          _buildBottomActionBar(context, state),
        ],
      ),
    );
  }

  Widget _buildPieceWidget(
    PuzzlePieceModel piece,
    int gridSize, {
    bool isDragging = false,
    bool isSelected = false,
  }) {
    // Col and row indices of original sorted layout positions
    int originalCol = piece.pieceId % gridSize;
    int originalRow = piece.pieceId ~/ gridSize;

    // Standard alignment offsets between -1.0 and 1.0 mapping coordinates
    double alignX = gridSize > 1
        ? -1.0 + (originalCol * (2.0 / (gridSize - 1)))
        : 0.0;
    double alignY = gridSize > 1
        ? -1.0 + (originalRow * (2.0 / (gridSize - 1)))
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              widthFactor: gridSize.toDouble(),
              heightFactor: gridSize.toDouble(),
              alignment: Alignment(alignX, alignY),
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white30,
                    ),
                  );
                },
              ),
            ),
            if (isDragging)
              Container(color: Colors.black45)
            else if (isSelected) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FFFF), width: 3),
                  color: const Color(0xFF00FFFF).withOpacity(0.15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(PuzzleActiveState state) {
    int mins = (state.elapsedSeconds ~/ 60);
    int secs = (state.elapsedSeconds % 60).toInt();
    String timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF151030),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            'MOVES',
            '${state.moves}',
            Icons.swap_horiz,
            Colors.cyanAccent,
          ),
          _buildStatCard('TIME', timeStr, Icons.timer, Colors.greenAccent),
          _buildStatCard(
            'HINTS',
            '${state.hintsUsed}',
            Icons.lightbulb,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF221845),
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
        color: const Color(0xFF1A133B),
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
                          color: const Color(0xFF2A1D54),
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

  Widget _buildBottomActionBar(BuildContext context, PuzzleActiveState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                BlocProvider.of<PuzzleBloc>(context).add(UseHintEvent());
              },
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('USE HINT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32236E),
                foregroundColor: Colors.amberAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                BlocProvider.of<PuzzleBloc>(
                  context,
                ).add(SubmitPuzzleScoreEvent());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A2BE2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'SUBMIT SCORE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1440),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.greenAccent, width: 1.5),
          ),
          title: const Center(
            child: Text(
              'VICTORY SECURED!',
              style: TextStyle(
                color: Colors.greenAccent,
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
                'Your score telemetry has been securely verified on the server side:',
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
                  Navigator.of(context).pop(); // Close Success Dialog
                  Navigator.of(
                    context,
                  ).pop(); // Exit Gameplay view back to Lobby
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  foregroundColor: Colors.white,
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

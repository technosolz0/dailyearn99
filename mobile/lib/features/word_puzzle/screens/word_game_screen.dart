import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/word_puzzle_bloc.dart';
import '../models/word_puzzle_models.dart';

class WordGameScreen extends StatefulWidget {
  final int contestId;
  final String title;

  const WordGameScreen({Key? key, required this.contestId, required this.title})
    : super(key: key);

  @override
  State<WordGameScreen> createState() => _WordGameScreenState();
}

class _WordGameScreenState extends State<WordGameScreen> {
  final TextEditingController _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

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
      body: BlocConsumer<WordPuzzleBloc, WordPuzzleState>(
        listener: (context, state) {
          if (state is WordPuzzleCompletedState) {
            _showSuccessDialog(context, state.finalScore, state.completionTime);
          } else if (state is WordPuzzleLobbyJoinedState) {
            // Automatically launch game session and start play instantly!
            BlocProvider.of<WordPuzzleBloc>(context).add(
              StartWordContestEvent(widget.contestId, state.sessionId),
            );
          } else if (state is WordPuzzleErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is WordPuzzleLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
            );
          }

          if (state is WordPuzzleLobbyJoinedState) {
            return _buildLobbyScreen(context, state);
          }

          if (state is WordPuzzleActiveState) {
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

  Widget _buildLobbyScreen(
    BuildContext context,
    WordPuzzleLobbyJoinedState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: Colors.amberAccent, size: 72),
            const SizedBox(height: 20),
            const Text(
              'CHALLENGE LOCKED & READY!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Entry fee of ₹${state.feeDeducted.toStringAsFixed(0)} was paid successfully.\nYou are connected to the matchmaking server.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                BlocProvider.of<WordPuzzleBloc>(
                  context,
                ).add(StartWordContestEvent(widget.contestId, state.sessionId));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A2BE2),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'START GAME NOW',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameplayArea(BuildContext context, WordPuzzleActiveState state) {
    final double progress =
        (state.currentQuestionIndex + 1) / state.questions.length;

    return SafeArea(
      child: Column(
        children: [
          _buildStatsBar(state),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUESTION ${state.currentQuestionIndex + 1} OF ${state.questions.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8A2BE2),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildQuestionContainer(context, state),
                  const SizedBox(height: 20),
                  _buildInteractivePuzzleWidget(context, state),
                ],
              ),
            ),
          ),
          if (state.feedbackMessage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                state.feedbackMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      state.feedbackMessage!.contains('Incorrect') ||
                          state.feedbackMessage!.contains('Error')
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          _buildLiveLeaderboard(state.liveLeaderboard),
          _buildActionInputArea(context, state),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer(
    BuildContext context,
    WordPuzzleActiveState state,
  ) {
    String typeLabel = '';
    switch (state.currentQuestion.gameType) {
      case 'WORD_SEARCH':
        typeLabel = '🔎 Word Search Challenge';
        break;
      case 'UNSCRAMBLE':
        typeLabel = '🔤 Unscramble Word';
        break;
      case 'MISSING_LETTERS':
        typeLabel = '❓ Guess Missing Letters';
        break;
      case 'CROSSWORD':
        typeLabel = '🧩 Crossword Puzzle';
        break;
      default:
        typeLabel = '📝 Solve Puzzle';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeLabel,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (state.currentQuestion.clues != null) ...[
            const Text(
              'CLUE / HINT:',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${state.currentQuestion.clues}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ] else ...[
            const Text(
              'INSTRUCTION:',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Solve the word puzzle shown below and enter your solution.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractivePuzzleWidget(
    BuildContext context,
    WordPuzzleActiveState state,
  ) {
    final gameType = state.currentQuestion.gameType;
    final puzzleData = state.currentQuestion.puzzleData;

    if (gameType == 'WORD_SEARCH') {
      try {
        final List<dynamic> rawGrid = puzzleData['grid'] as List;
        final List<List<String>> grid = rawGrid
            .map((row) => List<String>.from(row as List))
            .toList();

        return Column(
          children: [
            WordSearchGridWidget(
              grid: grid,
              onWordSelected: (selectedWord, coords) {
                _answerController.text = selectedWord;
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'Drag letters to select words in the grid.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        );
      } catch (e) {
        return _buildFallbackGrid();
      }
    }

    if (gameType == 'UNSCRAMBLE') {
      try {
        final String scrambled = puzzleData['scrambled'] as String;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: scrambled.split('').map((char) {
            return InkWell(
              onTap: () {
                _answerController.text += char;
                setState(() {});
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF221845),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8A2BE2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  char,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      } catch (e) {
        return const SizedBox();
      }
    }

    if (gameType == 'MISSING_LETTERS') {
      try {
        final String pattern = puzzleData['pattern'] as String;
        return Text(
          pattern,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 6.0,
            fontFamily: 'monospace',
          ),
        );
      } catch (e) {
        return const SizedBox();
      }
    }

    return const SizedBox();
  }

  Widget _buildFallbackGrid() {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: const Text(
        'Interactive Board Loading...',
        style: TextStyle(color: Colors.white38),
      ),
    );
  }

  Widget _buildStatsBar(WordPuzzleActiveState state) {
    final int mins = (state.remainingSeconds ~/ 60);
    final int secs = (state.remainingSeconds % 60);
    final String timeStr =
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
            'SCORE',
            '${state.score}',
            Icons.stars,
            Colors.cyanAccent,
          ),
          _buildStatCard(
            'TIME LEFT',
            timeStr,
            Icons.timer,
            state.remainingSeconds < 30 ? Colors.redAccent : Colors.greenAccent,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildActionInputArea(
    BuildContext context,
    WordPuzzleActiveState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter word puzzle solution...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF151030),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    suffixIcon: _answerController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white30,
                            ),
                            onPressed: () {
                              _answerController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: state.isSubmittingAnswer
                    ? null
                    : () {
                        BlocProvider.of<WordPuzzleBloc>(context).add(
                          SubmitWordAnswerEvent(
                            answer: _answerController.text,
                            usedHint: true,
                          ),
                        );
                      },
                icon: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amberAccent,
                ),
                tooltip: 'Use Hint (-20 pts)',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                state.isSubmittingAnswer || _answerController.text.isEmpty
                ? null
                : () {
                    BlocProvider.of<WordPuzzleBloc>(context).add(
                      SubmitWordAnswerEvent(
                        answer: _answerController.text,
                        usedHint: false,
                      ),
                    );
                    _answerController.clear();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF8A2BE2).withOpacity(0.3),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: state.isSubmittingAnswer
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'SUBMIT WORD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, int score, double time) {
    int mins = (time ~/ 60);
    int secs = (time % 60).toInt();
    String timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

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
              'CHALLENGE COMPLETED!',
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
              Text(
                'All puzzle sets solved successfully!\nFinalizing ranks on server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'TOTAL SCORE',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$score PTS',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'TOTAL TIME',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
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

class WordSearchGridWidget extends StatefulWidget {
  final List<List<String>> grid;
  final Function(String selectedWord, List<Point> coords) onWordSelected;

  const WordSearchGridWidget({
    Key? key,
    required this.grid,
    required this.onWordSelected,
  }) : super(key: key);

  @override
  _WordSearchGridWidgetState createState() => _WordSearchGridWidgetState();
}

class _WordSearchGridWidgetState extends State<WordSearchGridWidget> {
  List<Point> selectedLetters = [];
  bool isDragging = false;

  Point? _getPointFromPosition(Offset localPosition, double cellSize) {
    int x = (localPosition.dx / cellSize).floor();
    int y = (localPosition.dy / cellSize).floor();
    if (x >= 0 &&
        x < widget.grid[0].length &&
        y >= 0 &&
        y < widget.grid.length) {
      return Point(x, y);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double cellSize = constraints.maxWidth / widget.grid[0].length;

        return GestureDetector(
          onPanStart: (details) {
            setState(() {
              isDragging = true;
              selectedLetters.clear();
              Point? pt = _getPointFromPosition(
                details.localPosition,
                cellSize,
              );
              if (pt != null) selectedLetters.add(pt);
            });
          },
          onPanUpdate: (details) {
            Point? pt = _getPointFromPosition(details.localPosition, cellSize);
            if (pt != null && !selectedLetters.contains(pt)) {
              setState(() {
                selectedLetters.add(pt);
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              isDragging = false;
              String resultWord = selectedLetters
                  .map((p) => widget.grid[p.y][p.x])
                  .join();
              widget.onWordSelected(resultWord, selectedLetters);
            });
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, cellSize * widget.grid.length),
                painter: SelectionLinePainter(selectedLetters, cellSize),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.grid[0].length,
                ),
                itemCount: widget.grid.length * widget.grid[0].length,
                itemBuilder: (context, index) {
                  int x = index % widget.grid[0].length;
                  int y = (index / widget.grid[0].length).floor();
                  bool isSelected = selectedLetters.contains(Point(x, y));

                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blueGrey.shade900,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      widget.grid[y][x],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.cyanAccent : Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class Point {
  final int x;
  final int y;
  Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

class SelectionLinePainter extends CustomPainter {
  final List<Point> points;
  final double cellSize;

  SelectionLinePainter(this.points, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF8A2BE2).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cellSize * 0.7;

    final path = Path();
    path.moveTo(
      points[0].x * cellSize + cellSize / 2,
      points[0].y * cellSize + cellSize / 2,
    );
    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        points[i].x * cellSize + cellSize / 2,
        points[i].y * cellSize + cellSize / 2,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SelectionLinePainter oldDelegate) => true;
}

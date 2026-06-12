import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/arrow_bloc.dart';

class ArrowRenderItem {
  final int id;
  final int row;
  final int col;
  final String direction;
  bool isCleared;

  // Animation states
  double flightProgress; // 0.0 to 1.0
  double shakeProgress;  // -1.0 to 1.0 (obstruction shake)
  Color? flyColor;

  ArrowRenderItem({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    required this.isCleared,
    this.flightProgress = 0.0,
    this.shakeProgress = 0.0,
    this.flyColor,
  });
}

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

class _ArrowGameScreenState extends State<ArrowGameScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  List<ArrowRenderItem> _renderItems = [];
  String _selectedShape = 'arrow';

  final List<Color> _vibrantColors = const [
    Color(0xFFFF2D55), // Vibrant Pink/Red
    Color(0xFFFF9500), // Sunset Orange
    Color(0xFF4CD964), // Emerald Green
    Color(0xFF5AC8FA), // Sky Blue
    Color(0xFF5856D6), // Purple
    Color(0xFF007AFF), // Blue
    Color(0xFFFFCC00), // Yellow
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Grape
    Color(0xFF00BCD4), // Teal
    Color(0xFF8BC34A), // Lime
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    bool needsRepaint = false;

    for (var item in _renderItems) {
      // 1. Smooth flight animation
      if (item.isCleared && item.flightProgress < 1.0) {
        item.flightProgress += 0.08;
        if (item.flightProgress > 1.0) {
          item.flightProgress = 1.0;
        }
        needsRepaint = true;
      }

      // 2. Smooth springy shake decay
      if (item.shakeProgress != 0.0) {
        if (item.shakeProgress.abs() > 0.05) {
          item.shakeProgress = -item.shakeProgress * 0.72; // invert & decay
        } else {
          item.shakeProgress = 0.0;
        }
        needsRepaint = true;
      }
    }

    if (needsRepaint) {
      setState(() {});
    }
  }

  bool _isLocalObstructed(
    ArrowRenderItem tappedBlock,
    List<ArrowRenderItem> activeBlocks,
    int gridSize,
  ) {
    int r = tappedBlock.row;
    int c = tappedBlock.col;
    String d = tappedBlock.direction;

    if (d == 'UP') {
      for (int rCheck = 0; rCheck < r; rCheck++) {
        if (activeBlocks.any(
          (b) => !b.isCleared && b.row == rCheck && b.col == c,
        )) {
          return true;
        }
      }
    } else if (d == 'DOWN') {
      for (int rCheck = r + 1; rCheck < gridSize; rCheck++) {
        if (activeBlocks.any(
          (b) => !b.isCleared && b.row == rCheck && b.col == c,
        )) {
          return true;
        }
      }
    } else if (d == 'LEFT') {
      for (int cCheck = 0; cCheck < c; cCheck++) {
        if (activeBlocks.any(
          (b) => !b.isCleared && b.row == r && b.col == cCheck,
        )) {
          return true;
        }
      }
    } else if (d == 'RIGHT') {
      for (int cCheck = c + 1; cCheck < gridSize; cCheck++) {
        if (activeBlocks.any(
          (b) => !b.isCleared && b.row == r && b.col == cCheck,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  void _handleTapDown(TapDownDetails details, double segmentSize, int gridSize) {
    final x = details.localPosition.dx;
    final y = details.localPosition.dy;
    final col = (x / segmentSize).floor();
    final row = (y / segmentSize).floor();

    if (col < 0 || col >= gridSize || row < 0 || row >= gridSize) return;

    final itemIndex = _renderItems.indexWhere((item) => item.row == row && item.col == col);
    if (itemIndex == -1) return;

    final item = _renderItems[itemIndex];
    if (item.isCleared) return;

    final blocked = _isLocalObstructed(item, _renderItems, gridSize);
    if (blocked) {
      setState(() {
        item.shakeProgress = 1.0; // Trigger collision shake
      });
    } else {
      final random = math.Random();
      setState(() {
        item.isCleared = true;
        item.flightProgress = 0.0;
        item.flyColor = _vibrantColors[random.nextInt(_vibrantColors.length)];
      });
    }

    context.read<ArrowBloc>().add(TapArrowEvent(item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFEB),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        backgroundColor: const Color(0xFFF5EFEB),
        iconTheme: const IconThemeData(color: Color(0xFF5D4037)),
        elevation: 0,
      ),
      body: BlocConsumer<ArrowBloc, ArrowState>(
        listener: (context, state) {
          if (state is ArrowSuccessState) {
            _showSuccessDialog(context, state.finalScore);
          } else if (state is ArrowErrorState) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (state is ArrowActiveState) {
            if (_renderItems.isEmpty || state.moves == 0) {
              setState(() {
                _renderItems = state.blocks.map((b) => ArrowRenderItem(
                  id: b.id,
                  row: b.row,
                  col: b.col,
                  direction: b.direction,
                  isCleared: b.isCleared,
                )).toList();
              });
            } else {
              // Confirm clearances in local state
              final random = math.Random();
              for (var b in state.blocks) {
                final localItemIndex = _renderItems.indexWhere((item) => item.id == b.id);
                if (localItemIndex != -1) {
                  final localItem = _renderItems[localItemIndex];
                  if (b.isCleared && !localItem.isCleared) {
                    setState(() {
                      localItem.isCleared = true;
                      localItem.flightProgress = 0.0;
                      localItem.flyColor ??= _vibrantColors[random.nextInt(_vibrantColors.length)];
                    });
                  }
                }
              }
            }
          }
        },
        builder: (context, state) {
          if (state is ArrowLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5D4037)),
            );
          }

          if (state is ArrowActiveState) {
            return _buildGameplayArea(context, state);
          }

          return const Center(
            child: Text(
              'Initializing Challenge...',
              style: TextStyle(color: Color(0xFF8D6E63)),
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
          const SizedBox(height: 12),
          _buildShapeSelector(),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEBE5DB),
                      width: 2.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A5D4037),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GestureDetector(
                      onTapDown: (details) => _handleTapDown(details, segmentSize, state.gridSize),
                      child: CustomPaint(
                        painter: GameBoardPainter(
                          items: _renderItems,
                          gridSize: state.gridSize,
                          shapeType: _selectedShape,
                          dotColor: const Color(0x338D6E63),
                        ),
                      ),
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
        color: Color(0xFFFAF6F0),
        border: Border(bottom: BorderSide(color: Color(0xFFEBE5DB), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'TAPS',
            '${state.moves}',
            Icons.touch_app_rounded,
            const Color(0xFF8D6E63),
          ),
          _buildStatCard(
            'TIME',
            timeStr,
            Icons.timer_rounded,
            const Color(0xFF8D6E63),
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
        color: const Color(0xFFF5EFEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEBE5DB)),
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
                  color: Color(0xFF8D6E63),
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5D4037),
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
        color: const Color(0xFFFAF6F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBE5DB)),
      ),
      child: Row(
        children: [
          const Text(
            'LIVE RANKS:',
            style: TextStyle(
              color: Color(0xFF8D6E63),
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
                      style: TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
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
                          color: const Color(0xFFF5EFEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEBE5DB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${item['rank']}',
                              style: const TextStyle(
                                color: Color(0xFF8D6E63),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item['name']}',
                              style: const TextStyle(
                                color: Color(0xFF5D4037),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${item['score']}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
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
        style: TextStyle(color: Color(0xFF8D6E63), fontSize: 10.5, height: 1.4),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF6F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
          ),
          title: const Center(
            child: Text(
              'VICTORY SECURED!',
              style: TextStyle(
                color: Color(0xFF5D4037),
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
                style: TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                '$score PTS',
                style: const TextStyle(
                  color: Color(0xFF5D4037),
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
                  backgroundColor: const Color(0xFF5D4037),
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

  Widget _buildShapeSelector() {
    final shapes = [
      {'id': 'arrow', 'name': 'ARROW', 'icon': Icons.navigation_rounded},
      {'id': 'delta', 'name': 'DELTA', 'icon': Icons.change_history_rounded},
      {'id': 'pentagon', 'name': 'SHIELD', 'icon': Icons.shield_rounded},
      {'id': 'classic', 'name': 'CLASSIC', 'icon': Icons.crop_square_rounded},
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Text(
            'SHAPE:',
            style: TextStyle(
              color: Color(0xFF8D6E63),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: shapes.map((shape) {
                final isSelected = _selectedShape == shape['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedShape = shape['id'] as String;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF5D4037)
                          : const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF5D4037)
                            : const Color(0xFFEBE5DB),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          shape['icon'] as IconData,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF8D6E63),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          shape['name'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF8D6E63),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class GameBoardPainter extends CustomPainter {
  final List<ArrowRenderItem> items;
  final int gridSize;
  final String shapeType;
  final Color dotColor;

  GameBoardPainter({
    required this.items,
    required this.gridSize,
    required this.shapeType,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double segmentSize = size.width / gridSize;

    // 1. Draw dot grid background (revealed as arrows fly off)
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final double cx = c * segmentSize + segmentSize / 2;
        final double cy = r * segmentSize + segmentSize / 2;
        canvas.drawCircle(Offset(cx, cy), 3.0, dotPaint);
      }
    }

    // Max flight distance calculation: size width * 1.5 to fly completely out
    final double maxFlightDistance = size.width * 1.5;

    // 2. Draw active and flying arrows
    for (var item in items) {
      if (item.isCleared && item.flightProgress >= 1.0) {
        continue; // Fully flown off screen
      }

      canvas.save();

      // Translate to cell center
      double cx = item.col * segmentSize + segmentSize / 2;
      double cy = item.row * segmentSize + segmentSize / 2;
      canvas.translate(cx, cy);

      // Rotate canvas based on arrow direction so that local Y is always 'UP'
      double angle = 0;
      if (item.direction == 'RIGHT') {
        angle = math.pi / 2;
      } else if (item.direction == 'DOWN') {
        angle = math.pi;
      } else if (item.direction == 'LEFT') {
        angle = 3 * math.pi / 2;
      }
      canvas.rotate(angle);

      // Apply local offsets (Flight along local Y axis, shake along local X axis)
      double flightOffset = item.flightProgress * maxFlightDistance;
      double shakeOffset = item.shakeProgress * 8.0;

      canvas.translate(shakeOffset, -flightOffset);

      // Translate back so drawing is done from top-left (0,0) of cell box
      canvas.translate(-segmentSize / 2, -segmentSize / 2);

      // Fade out opacity as it flies
      double opacity = 1.0 - item.flightProgress;
      if (opacity < 0.0) opacity = 0.0;

      // Draw arrow path
      final path = Path();
      double pad = 3.0;
      double w = segmentSize;
      double h = segmentSize;
      double pw = w - pad * 2;
      double ph = h - pad * 2;

      if (shapeType == 'arrow') {
        path.moveTo(w / 2, pad);
        path.lineTo(w - pad, ph * 0.42 + pad);
        path.lineTo(w * 0.70, ph * 0.38 + pad);
        path.lineTo(w * 0.70, ph * 0.95 + pad);
        path.lineTo(w * 0.30, ph * 0.95 + pad);
        path.lineTo(w * 0.30, ph * 0.38 + pad);
        path.lineTo(pad, ph * 0.42 + pad);
        path.close();
      } else if (shapeType == 'delta') {
        path.moveTo(w / 2, pad);
        path.lineTo(w - pad, ph * 0.95 + pad);
        path.lineTo(w / 2, ph * 0.75 + pad);
        path.lineTo(pad, ph * 0.95 + pad);
        path.close();
      } else if (shapeType == 'pentagon') {
        path.moveTo(w / 2, pad);
        path.lineTo(w - pad, ph * 0.45 + pad);
        path.lineTo(w - pad, ph * 0.95 + pad);
        path.lineTo(pad, ph * 0.95 + pad);
        path.lineTo(pad, ph * 0.45 + pad);
        path.close();
      } else {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pad, pad, pw, ph),
            const Radius.circular(12),
          ),
        );
      }

      // Linear gradients for filling the arrows
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: item.flyColor != null
              ? [item.flyColor!.withOpacity(0.65 * opacity), item.flyColor!.withOpacity(opacity)]
              : item.shakeProgress != 0.0
                  ? [
                      const Color(0xFFD32F2F).withOpacity(opacity), // Red tail
                      const Color(0xFFFF5252).withOpacity(opacity), // Red head
                    ]
                  : [
                      const Color(0xFF5D4037).withOpacity(opacity), // Chocolate brown tail
                      const Color(0xFF8D6E63).withOpacity(opacity), // Lighter brown body
                      const Color(0xFFA1887F).withOpacity(opacity), // Light tip
                    ],
          stops: item.flyColor != null ? const [0.0, 1.0] : const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      // Draw shadow path
      canvas.drawPath(
        path,
        Paint()
          ..color = (item.flyColor != null
              ? item.flyColor!.withOpacity(0.4 * opacity)
              : item.shakeProgress != 0.0
                  ? const Color(0xFFFF5252).withOpacity(0.3 * opacity)
                  : const Color(0xFF5D4037).withOpacity(0.15 * opacity))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // Draw fill
      canvas.drawPath(path, fillPaint);

      // Border outline
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (item.flyColor != null
            ? item.flyColor!.withOpacity(opacity)
            : item.shakeProgress != 0.0
                ? const Color(0xFFFF5252).withOpacity(opacity)
                : const Color(0xFF4E342E).withOpacity(opacity));

      canvas.drawPath(path, borderPaint);

      // Inner chevrons
      final innerPath1 = Path();
      innerPath1.moveTo(w / 2, h * 0.32);
      innerPath1.lineTo(w * 0.65, h * 0.46);
      innerPath1.lineTo(w * 0.58, h * 0.51);
      innerPath1.lineTo(w / 2, h * 0.39);
      innerPath1.lineTo(w * 0.42, h * 0.51);
      innerPath1.lineTo(w * 0.35, h * 0.46);
      innerPath1.close();

      final innerPath2 = Path();
      innerPath2.moveTo(w / 2, h * 0.46);
      innerPath2.lineTo(w * 0.65, h * 0.60);
      innerPath2.lineTo(w * 0.58, h * 0.65);
      innerPath2.lineTo(w / 2, h * 0.53);
      innerPath2.lineTo(w * 0.42, h * 0.65);
      innerPath2.lineTo(w * 0.35, h * 0.60);
      innerPath2.close();

      final innerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFAF6F0).withOpacity(0.85 * opacity);

      canvas.drawPath(innerPath1, innerPaint);
      canvas.drawPath(innerPath2, innerPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GameBoardPainter oldDelegate) {
    return true; // Driven by the ticker at 60 FPS
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dailyearn99/core/models/blackjack_model.dart';
import 'poker_chip.dart';

class PlayingCard extends StatefulWidget {
  final bool isFaceUp;
  final Widget front;
  final Widget back;
  final Offset startOffset;
  final int delayMillis;

  const PlayingCard({
    super.key,
    required this.isFaceUp,
    required this.front,
    required this.back,
    required this.startOffset,
    required this.delayMillis,
  });

  @override
  State<PlayingCard> createState() => _PlayingCardState();
}

class _PlayingCardState extends State<PlayingCard>
    with TickerProviderStateMixin {
  late AnimationController _dealController;
  late Animation<double> _dealCurve;
  late AnimationController _flipController;
  bool _isFaceUp = false;

  @override
  void initState() {
    super.initState();
    _isFaceUp = widget.isFaceUp;

    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _dealCurve = CurvedAnimation(
      parent: _dealController,
      curve: Curves.easeOutBack,
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: _isFaceUp ? 1.0 : 0.0,
    );

    if (widget.delayMillis > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMillis), () {
        if (mounted) {
          _dealController.forward();
        }
      });
    } else {
      _dealController.forward();
    }
  }

  @override
  void didUpdateWidget(PlayingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFaceUp != widget.isFaceUp) {
      if (widget.isFaceUp) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
      _isFaceUp = widget.isFaceUp;
    }
  }

  @override
  void dispose() {
    _dealController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _dealCurve,
        builder: (context, child) {
          final double t = _dealCurve.value;
          final double dx = (1.0 - t) * widget.startOffset.dx;
          final double dy = (1.0 - t) * widget.startOffset.dy;
          final double scale = t * 0.7 + 0.3;
          final double angle = (1.0 - t) * -0.6;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(angle: angle, child: child),
            ),
          );
        },
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            final double flipValue = _flipController.value;
            final isFront = flipValue >= 0.5;
            final angle = (1.0 - flipValue) * math.pi;

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(isFront ? angle : angle + math.pi),
              alignment: Alignment.center,
              child: isFront
                  ? widget.front
                  : Transform.flip(flipX: true, child: widget.back),
            );
          },
        ),
      ),
    );
  }
}

class CardStack extends StatelessWidget {
  final List<BlackjackCardModel> cards;
  final double cardWidth;
  final double cardHeight;
  final double overlapOffset;
  final bool isDealerHand;
  final bool isGameInProgress;
  final String? scoreLabel;
  final Offset cardStartOffset;
  final bool isSplit;

  const CardStack({
    super.key,
    required this.cards,
    this.cardWidth = 74.0,
    this.cardHeight = 110.0,
    this.overlapOffset = 22.0,
    this.isDealerHand = false,
    this.isGameInProgress = false,
    this.scoreLabel,
    this.cardStartOffset = const Offset(160, -220),
    this.isSplit = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    int displayCount = cards.length;
    if (isDealerHand && isGameInProgress) {
      displayCount = cards.length + 1;
    }

    final totalWidth = cardWidth + (displayCount - 1) * overlapOffset;

    return SizedBox(
      width: totalWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * overlapOffset,
              top: 0,
              child: _buildCardItem(i, displayCount),
            ),
          if (scoreLabel != null)
            Positioned(
              right: -10,
              bottom: -10,
              child: PokerChipWidget(
                label: scoreLabel!,
                color: const Color(0xFF15803D),
                size: 32.0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardItem(int index, int displayCount) {
    if (index >= displayCount) return const SizedBox.shrink();

    final bool isFaceUp =
        !(isDealerHand && isGameInProgress && index == displayCount - 1);

    Widget frontWidget;
    if (index < cards.length) {
      frontWidget = _buildCardFrontWidget(cards[index], cardWidth, cardHeight);
    } else {
      frontWidget = _buildCardBackWidget(cardWidth, cardHeight);
    }

    final backWidget = _buildCardBackWidget(cardWidth, cardHeight);

    int delayMillis = 0;
    if (!isSplit && index < 2) {
      if (isDealerHand) {
        delayMillis = index == 0 ? 250 : 750;
      } else {
        delayMillis = index == 0 ? 0 : 500;
      }
    }

    return PlayingCard(
      key: ValueKey(
        'playing_card_${isDealerHand ? "dealer" : "player"}_$index',
      ),
      isFaceUp: isFaceUp,
      front: frontWidget,
      back: backWidget,
      startOffset: cardStartOffset,
      delayMillis: delayMillis,
    );
  }

  Widget _buildCardFrontWidget(
    BlackjackCardModel card,
    double width,
    double height,
  ) {
    final isRed = card.suit == '♥' || card.suit == '♦';
    final cardColor = isRed ? const Color(0xFFDC2626) : const Color(0xFF1F2937);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              card.suit,
              style: TextStyle(
                color: cardColor,
                fontSize: width * 0.43,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            top: width * 0.08,
            left: width * 0.08,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.rank,
                  style: TextStyle(
                    color: cardColor,
                    fontSize: width * 0.22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                Text(
                  card.suit,
                  style: TextStyle(
                    color: cardColor,
                    fontSize: width * 0.16,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: width * 0.08,
            right: width * 0.08,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rank,
                    style: TextStyle(
                      color: cardColor,
                      fontSize: width * 0.22,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    card.suit,
                    style: TextStyle(
                      color: cardColor,
                      fontSize: width * 0.16,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBackWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(5),
          ),
          child: CustomPaint(painter: CardBackPatternPainter()),
        ),
      ),
    );
  }
}

class CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final spacing = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x + size.height, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

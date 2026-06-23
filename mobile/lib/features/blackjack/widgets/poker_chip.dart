import 'dart:math' as math;
import 'package:flutter/material.dart';

class PokerChipWidget extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  const PokerChipWidget({
    super.key,
    required this.label,
    required this.color,
    this.size = 50.0,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = CustomPaint(
      size: Size(size, size),
      painter: PokerChipPainter(
        color: color,
        label: label,
        isSelected: isSelected,
      ),
    );

    if (onTap != null) {
      chip = GestureDetector(onTap: onTap, child: chip);
    }

    if (isSelected) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: chip,
      );
    }

    return chip;
  }
}

class PokerChipPainter extends CustomPainter {
  final Color color;
  final String label;
  final bool isSelected;

  PokerChipPainter({
    required this.color,
    required this.label,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.72;
    final centerRadius = outerRadius * 0.55;

    // Outer circle
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // Inner stripes / dashes around the edge
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerRadius * 0.12;

    const dashCount = 8;
    const dashAngle = 2 * math.pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final angle = i * dashAngle;
      final startAngle = angle - 0.15;
      const sweepAngle = 0.3;
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: outerRadius - (outerRadius * 0.08),
        ),
        startAngle,
        sweepAngle,
        false,
        dashPaint,
      );
    }

    // Inner dark circle for text
    final innerPaint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerPaint);

    // Highlight border inside dark circle
    final innerBorderPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, centerRadius, innerBorderPaint);

    // Value text in center
    if (label.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: outerRadius * 0.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PokerChipPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.label != label ||
        oldDelegate.isSelected != isSelected;
  }
}

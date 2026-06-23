import 'dart:math' as math;
import 'package:flutter/material.dart';

class TableLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = -90.0; // Place the circle center above the table felt
    final center = Offset(centerX, centerY);

    final double rOuterBorder = 320.0;
    final double rText1 = 345.0; // BLACKJACK PAYS 3 TO 2
    final double rText2 = 375.0; // Dealer must hit soft 17
    final double rText3 = 405.0; // INSURANCE PAYS 2 TO 1
    final double rInnerBorder = 430.0;

    final goldLinePaint = Paint()
      ..color = const Color(0xFFEAB308).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final goldLinePaintDouble = Paint()
      ..color = const Color(0xFFEAB308).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final startAngle = math.pi / 2 - 0.52;
    final sweepAngle = 1.04;

    // Draw the outer curved border
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rOuterBorder),
      startAngle,
      sweepAngle,
      false,
      goldLinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rOuterBorder - 4),
      startAngle,
      sweepAngle,
      false,
      goldLinePaintDouble,
    );

    // Draw the inner curved border
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rInnerBorder),
      startAngle,
      sweepAngle,
      false,
      goldLinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rInnerBorder + 4),
      startAngle,
      sweepAngle,
      false,
      goldLinePaintDouble,
    );

    // Connect borders to form pointed diamond tips at left and right
    final xOuterL = centerX + rOuterBorder * math.cos(startAngle);
    final yOuterL = centerY + rOuterBorder * math.sin(startAngle);
    final xInnerL = centerX + rInnerBorder * math.cos(startAngle);
    final yInnerL = centerY + rInnerBorder * math.sin(startAngle);

    final midRadius = (rOuterBorder + rInnerBorder) / 2;
    final tipAngleL = startAngle - 0.03;
    final xTipL = centerX + midRadius * math.cos(tipAngleL);
    final yTipL = centerY + midRadius * math.sin(tipAngleL);

    final pathL = Path()
      ..moveTo(xOuterL, yOuterL)
      ..lineTo(xTipL, yTipL)
      ..lineTo(xInnerL, yInnerL);
    canvas.drawPath(pathL, goldLinePaint);

    final endAngle = startAngle + sweepAngle;
    final xOuterR = centerX + rOuterBorder * math.cos(endAngle);
    final yOuterR = centerY + rOuterBorder * math.sin(endAngle);
    final xInnerR = centerX + rInnerBorder * math.cos(endAngle);
    final yInnerR = centerY + rInnerBorder * math.sin(endAngle);

    final tipAngleR = endAngle + 0.03;
    final xTipR = centerX + midRadius * math.cos(tipAngleR);
    final yTipR = centerY + midRadius * math.sin(tipAngleR);

    final pathR = Path()
      ..moveTo(xOuterR, yOuterR)
      ..lineTo(xTipR, yTipR)
      ..lineTo(xInnerR, yInnerR);
    canvas.drawPath(pathR, goldLinePaint);

    // Paint floating gold diamonds at the tip outer bounds
    final diamondPaint = Paint()
      ..color = const Color(0xFFEAB308).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    _drawDiamond(
      canvas,
      Offset(xTipL + 8 * math.cos(tipAngleL), yTipL + 8 * math.sin(tipAngleL)),
      5,
      diamondPaint,
    );
    _drawDiamond(
      canvas,
      Offset(xTipR + 8 * math.cos(tipAngleR), yTipR + 8 * math.sin(tipAngleR)),
      5,
      diamondPaint,
    );

    // Render Curved Texts along the concentric arcs
    _drawTextOnCurve(
      canvas,
      "BLACKJACK PAYS 3 TO 2",
      center,
      rText1,
      math.pi / 2,
      const TextStyle(
        color: Color(0xFFFEF08A),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.8,
        fontFamily: 'serif',
      ),
    );

    _drawTextOnCurve(
      canvas,
      "Dealer must hit soft 17",
      center,
      rText2,
      math.pi / 2,
      const TextStyle(
        color: Colors.white60,
        fontSize: 7.5,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
      ),
    );

    _drawTextOnCurve(
      canvas,
      "INSURANCE PAYS 2 TO 1",
      center,
      rText3,
      math.pi / 2,
      const TextStyle(
        color: Color(0xFFFDE047),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontFamily: 'serif',
      ),
    );
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawTextOnCurve(
    Canvas canvas,
    String text,
    Offset center,
    double radius,
    double startAngle,
    TextStyle style,
  ) {
    List<TextPainter> painters = [];
    double totalWidth = 0.0;

    for (int i = 0; i < text.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      painters.add(tp);
      totalWidth += tp.width;
      if (i < text.length - 1) {
        totalWidth += (style.letterSpacing ?? 0.0);
      }
    }

    final totalAngle = totalWidth / radius;
    // Start on the left side (larger angle) and decrease to layout from left to right
    double currentAngle = startAngle + (totalAngle / 2);

    for (int i = 0; i < text.length; i++) {
      final tp = painters[i];
      final charAngle = tp.width / radius;
      final spacingAngle = (style.letterSpacing ?? 0.0) / radius;
      final angle = currentAngle - charAngle / 2;

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle - math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      currentAngle -= (charAngle + spacingAngle);
    }
  }

  @override
  bool shouldRepaint(covariant TableLinesPainter oldDelegate) => false;
}

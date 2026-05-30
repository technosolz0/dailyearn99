import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BladeTrail extends PositionComponent {
  final List<Offset> points = [];
  final int maxPoints = 15;

  BladeTrail() {
    size = Vector2.zero();
    anchor = Anchor.topLeft;
    position = Vector2.zero();
  }

  void addPoint(Offset p) {
    points.add(p);
    if (points.length > maxPoints) {
      points.removeAt(0);
    }
  }

  void reset() {
    points.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Slowly decay trail if user stops dragging
    if (points.isNotEmpty) {
      lifeDecay();
    }
  }

  void lifeDecay() {
    points.removeAt(0);
  }

  @override
  void render(Canvas canvas) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Outer glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.cyan.withOpacity(0.1), Colors.white.withOpacity(0.8)],
      ).createShader(Rect.fromPoints(points.first, points.last))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Inner sharp blade cut
    final bladePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, bladePaint);
  }
}

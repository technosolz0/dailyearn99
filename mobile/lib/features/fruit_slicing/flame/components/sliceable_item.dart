import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';

class SliceableItem extends PositionComponent {
  final int itemId;
  final String itemType;
  final double radius;
  final bool isBomb;

  // Physics properties
  late Vector2 velocity;
  final double gravity = 450.0; // Gravity pixels/sec^2
  double angularVelocity = 0.0;
  double rotationAngle = 0.0;

  bool isSliced = false;
  double sliceAngle = 0.0;
  double sliceSplitOffset = 0.0;

  SliceableItem({
    required this.itemId,
    required this.itemType,
    required this.radius,
    required this.isBomb,
    required Vector2 startPosition,
    required this.velocity,
  }) {
    position = startPosition;
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
    angularVelocity = (math.Random().nextDouble() * 4) - 2; // -2 to +2 rad/sec
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Apply gravity
    velocity.y += gravity * dt;
    
    // Apply velocity to coordinates
    position += velocity * dt;
    
    // Spin item
    rotationAngle += angularVelocity * dt;

    if (isSliced) {
      sliceSplitOffset += 200.0 * dt; // Half split speed
    }
  }

  void slice(double angle) {
    if (isSliced) return;
    isSliced = true;
    sliceAngle = angle;
    angularVelocity = (angularVelocity * 2.5); // Spin faster when cut
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotationAngle);

    if (isBomb) {
      _renderBomb(canvas);
    } else {
      _renderFruit(canvas);
    }

    canvas.restore();
  }

  void _renderBomb(Canvas canvas) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.grey, Colors.black87, Colors.black],
        stops: [0.1, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

    // Fuse spark
    if (!isSliced) {
      final fusePaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(0, -radius)
        ..quadraticBezierTo(radius * 0.3, -radius * 1.3, radius * 0.4, -radius * 1.5);
      canvas.drawPath(path, fusePaint);

      // Spark sparkler point
      final sparkPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(radius * 0.4, -radius * 1.5), 5.0, sparkPaint);
    }

    // Draw main shell
    canvas.drawCircle(Offset.zero, radius, paint);

    // Glowing red indicator warning lamp
    final glowColor = math.sin(DateTime.now().millisecondsSinceEpoch / 100) > 0 
        ? Colors.red 
        : Colors.red.shade900;
    
    final corePaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius * 0.25, corePaint);

    final warningPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, radius * 0.4, warningPaint);
  }

  void _renderFruit(Canvas canvas) {
    Color outerColor;
    Color innerColor;
    List<Color> stripeColors;

    switch (itemType) {
      case 'watermelon':
        outerColor = Colors.green.shade900;
        innerColor = Colors.red.shade600;
        stripeColors = [Colors.green.shade800, Colors.red.shade500];
        break;
      case 'orange':
        outerColor = Colors.orange.shade800;
        innerColor = Colors.orange.shade400;
        stripeColors = [Colors.orange.shade600, Colors.white];
        break;
      case 'banana':
        outerColor = Colors.yellow.shade800;
        innerColor = Colors.yellow.shade300;
        stripeColors = [Colors.yellow.shade400, Colors.yellow.shade200];
        break;
      default: // Coconut
        outerColor = Colors.brown.shade800;
        innerColor = Colors.white;
        stripeColors = [Colors.brown.shade700, Colors.white70];
    }

    if (!isSliced) {
      // Draw whole fruit outer skin
      final skinPaint = Paint()
        ..shader = RadialGradient(
          colors: [innerColor, outerColor],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
      canvas.drawCircle(Offset.zero, radius, skinPaint);
      
      // Draw standard inner details
      if (itemType == 'watermelon') {
        _drawWatermelonSeeds(canvas);
      } else if (itemType == 'orange') {
        _drawOrangeSegments(canvas);
      }
    } else {
      // Render two halves splitting away orthogonally from slice angle
      final angleDiff = sliceAngle + math.pi / 2;
      final dx = math.cos(angleDiff) * sliceSplitOffset;
      final dy = math.sin(angleDiff) * sliceSplitOffset;

      // Draw first half
      canvas.save();
      canvas.translate(dx, dy);
      _drawHalf(canvas, outerColor, innerColor, true);
      canvas.restore();

      // Draw second half
      canvas.save();
      canvas.translate(-dx, -dy);
      _drawHalf(canvas, outerColor, innerColor, false);
      canvas.restore();
    }
  }

  void _drawHalf(Canvas canvas, Color outerColor, Color innerColor, bool isLeftHalf) {
    final clipPath = Path();
    if (isLeftHalf) {
      clipPath.addRect(Rect.fromLTRB(-radius - 10, -radius - 10, 0, radius + 10));
    } else {
      clipPath.addRect(Rect.fromLTRB(0, -radius - 10, radius + 10, radius + 10));
    }
    
    canvas.save();
    canvas.clipPath(clipPath);

    // Paint outer skin
    final skinPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, skinPaint);

    // Paint inner flesh
    final fleshPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius * 0.88, fleshPaint);

    // Paint fruit structures
    if (itemType == 'watermelon') {
      _drawWatermelonSeeds(canvas);
    } else if (itemType == 'orange') {
      _drawOrangeSegments(canvas);
    } else if (itemType == 'coconut') {
      // Draw coconut inner liquid layer
      final liquidPaint = Paint()
        ..color = Colors.lightBlue.shade50
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, radius * 0.4, liquidPaint);
    }

    canvas.restore();
  }

  void _drawWatermelonSeeds(Canvas canvas) {
    final seedPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Draw standard micro seed positions
    canvas.drawCircle(Offset(-radius * 0.4, -radius * 0.2), 3.0, seedPaint);
    canvas.drawCircle(Offset(-radius * 0.3, radius * 0.3), 3.0, seedPaint);
    canvas.drawCircle(Offset(radius * 0.4, -radius * 0.1), 3.0, seedPaint);
    canvas.drawCircle(Offset(radius * 0.3, radius * 0.4), 3.0, seedPaint);
  }

  void _drawOrangeSegments(Canvas canvas) {
    final linePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    // Draw slice radial spokes
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * radius * 0.85, math.sin(angle) * radius * 0.85),
        linePaint,
      );
    }
  }
}

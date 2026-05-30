import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SplashParticles extends PositionComponent {
  final Offset spawnPosition;
  final Color color;
  
  late List<ParticleDrop> drops;
  double lifeTime = 0.0;
  final double maxLife = 0.6; // duration in seconds

  SplashParticles({
    required this.spawnPosition,
    required this.color,
  }) {
    position = Vector2(spawnPosition.dx, spawnPosition.dy);
    size = Vector2(100, 100);
    anchor = Anchor.center;

    final random = math.Random();
    drops = List.generate(15, (index) {
      final double angle = random.nextDouble() * 2 * math.pi;
      final double speed = (random.nextDouble() * 250) + 100; // 100 to 350 px/s
      return ParticleDrop(
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        radius: (random.nextDouble() * 5.0) + 2.0, // 2-7px drops
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    lifeTime += dt;
    if (lifeTime >= maxLife) {
      removeFromParent();
      return;
    }

    final double gravity = 400.0;
    for (var drop in drops) {
      drop.velocity = Offset(drop.velocity.dx, drop.velocity.dy + gravity * dt);
      drop.offset += drop.velocity * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final double progress = lifeTime / maxLife;
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    for (var drop in drops) {
      canvas.drawCircle(drop.offset, drop.radius, paint);
    }
  }
}

class ParticleDrop {
  Offset offset = Offset.zero;
  Offset velocity;
  final double radius;

  ParticleDrop({
    required this.velocity,
    required this.radius,
  });
}

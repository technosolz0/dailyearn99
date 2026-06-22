import 'dart:math' as math;
import 'package:flame/components.dart';
import 'sliceable_item.dart';

class Spawner extends Component with HasGameRef {
  final math.Random seededRandom;

  double spawnTimer = 0.0;
  double totalTime = 0.0;
  int itemCounter = 0;

  Spawner({required this.seededRandom});

  @override
  void update(double dt) {
    super.update(dt);
    totalTime += dt;
    spawnTimer += dt;

    // Calculate dynamic spawn rate: initially 2.5 seconds, down to 1.1 seconds near match end
    final double spawnInterval = math.max(1.1, 2.5 - (totalTime / 40.0));

    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0.0;

      // Determine bundle count (combos): initially 1, up to 3 items launched simultaneously
      int count = 1;
      if (totalTime > 40) {
        count = seededRandom.nextDouble() > 0.4 ? 3 : 2;
      } else if (totalTime > 15) {
        count = seededRandom.nextDouble() > 0.5 ? 2 : 1;
      }

      for (int i = 0; i < count; i++) {
        _spawnLaunch();
      }
    }
  }

  void _spawnLaunch() {
    final Vector2 canvasSize = gameRef.canvasSize;
    if (canvasSize.x <= 0 || canvasSize.y <= 0) return;

    itemCounter++;

    // 1. Pick starting horizontal position and launch towards center
    final double startX =
        (seededRandom.nextDouble() * (canvasSize.x * 0.7)) +
        (canvasSize.x * 0.15);
    final double startY = canvasSize.y + 50.0;

    // 2. Direct velocities so items sweep upwards in arcs peaking near center screen
    final double targetCenter = canvasSize.x / 2;
    final double vx =
        (targetCenter - startX) *
        (0.8 + seededRandom.nextDouble() * 0.4); // Aim towards center
    final double vy =
        -(seededRandom.nextDouble() * 250 +
            600); // Launch speed -600 to -850 px/s

    // 3. Determine if bomb or fruit
    final bool spawnBomb =
        seededRandom.nextDouble() < 0.30; // 30% bomb spawn rate

    final List<String> types = [
      'apple',
      'orange',
      'banana',
      'coconut',
      'watermelon',
      'tomato',
      'carrot',
      'broccoli',
      'pepper',
      'pineapple',
      'strawberry',
      'blueberry',
      'grape',
      'peach',
      'potato',
      'corn',
      'onion',
    ];
    final String chosenType = types[seededRandom.nextInt(types.length)];

    final double radius = spawnBomb ? 28.0 : 32.0;

    final item = SliceableItem(
      itemId: itemCounter,
      itemType: chosenType,
      radius: radius,
      isBomb: spawnBomb,
      startPosition: Vector2(startX, startY),
      velocity: Vector2(vx, vy),
    );

    gameRef.add(item);
  }
}

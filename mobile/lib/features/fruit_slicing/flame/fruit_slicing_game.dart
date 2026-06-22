import 'dart:math' as math;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../bloc/fruit_game_bloc.dart';
import '../models/fruit_models.dart';
import 'components/blade_trail.dart';
import 'components/sliceable_item.dart';
import 'components/spawner.dart';
import 'effects/splash_particles.dart';

class FruitSlicingGame extends FlameGame with DragCallbacks {
  final FruitGameBloc gameBloc;
  final String seed;

  late Spawner spawner;
  late BladeTrail bladeTrail;
  late math.Random seededRandom;

  FruitSlicingGame({required this.gameBloc, required this.seed});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Initialize custom seeded PRNG with safe positive DJB2 hash
    int seedHash = 5381;
    for (int i = 0; i < seed.length; i++) {
      seedHash = ((seedHash << 5) + seedHash) + seed.codeUnitAt(i);
      seedHash = seedHash & 0x7FFFFFFF;
    }
    seededRandom = math.Random(seedHash);

    // 2. Add Component layers
    bladeTrail = BladeTrail();
    add(bladeTrail);

    spawner = Spawner(seededRandom: seededRandom);
    add(spawner);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Track items that fall below the screen height
    final double screenHeight = canvasSize.y;
    final List<SliceableItem> activeItems = children
        .whereType<SliceableItem>()
        .toList();

    for (var item in activeItems) {
      if (item.position.y > screenHeight + 70.0) {
        // If fruit fell down uncut, register a miss
        if (!item.isSliced && !item.isBomb) {
          gameBloc.add(RegisterMissEvent());
        }
        // Clean up component memory
        item.removeFromParent();
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final Vector2 localPosition = event.localEndPosition;
    bladeTrail.addPoint(localPosition.toOffset());

    // Sweep Collision Detection:
    final List<SliceableItem> activeItems = children
        .whereType<SliceableItem>()
        .toList();
    final List<SliceableItem> slicedThisFrame = [];

    if (bladeTrail.points.length >= 2) {
      final Offset p1 = bladeTrail.points[bladeTrail.points.length - 2];
      final Offset p2 = bladeTrail.points.last;

      for (var item in activeItems) {
        if (item.isSliced) continue;

        // Sweep intersection check: Line segment (p1 -> p2) vs Circle (item position, radius)
        if (_checkIntersection(
          p1,
          p2,
          item.absolutePosition.toOffset(),
          item.radius,
        )) {
          slicedThisFrame.add(item);
        }
      }
    }

    if (slicedThisFrame.isNotEmpty) {
      final bool hitBomb = slicedThisFrame.any((element) => element.isBomb);

      // Calculate swipe angle
      double angle = 0.0;
      if (bladeTrail.points.length >= 2) {
        final Offset diff =
            bladeTrail.points.last -
            bladeTrail.points[bladeTrail.points.length - 2];
        angle = math.atan2(diff.dy, diff.dx);
      }

      // Slice items and trigger particle visuals
      for (var item in slicedThisFrame) {
        item.slice(angle);

        // Trigger multi-color splatters
        Color splashColor;
        switch (item.itemType) {
          case 'watermelon':
          case 'apple':
          case 'tomato':
          case 'pepper':
          case 'strawberry':
            splashColor = Colors.redAccent;
            break;
          case 'orange':
          case 'carrot':
          case 'peach':
            splashColor = Colors.orangeAccent;
            break;
          case 'banana':
          case 'pineapple':
          case 'corn':
            splashColor = Colors.yellowAccent;
            break;
          case 'blueberry':
          case 'grape':
          case 'onion':
            splashColor = Colors.purpleAccent;
            break;
          case 'broccoli':
            splashColor = Colors.greenAccent;
            break;
          case 'coconut':
          case 'potato':
            splashColor = Colors.white;
            break;
          default:
            splashColor = Colors.grey;
        }

        if (!item.isBomb) {
          add(
            SplashParticles(
              spawnPosition: item.absolutePosition.toOffset(),
              color: splashColor,
            ),
          );
          // Dispatch individual slice event to BLoC
          gameBloc.add(RegisterSliceEvent(item.itemType));
        }
      }

      if (hitBomb) {
        // Stop spawning and dispatch bomb explosion
        spawner.removeFromParent();
        gameBloc.add(TriggerBombExplodeEvent());
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    bladeTrail.reset();
  }

  bool _checkIntersection(Offset p1, Offset p2, Offset center, double radius) {
    // Project circle center onto drag segment vector line to detect swipe contact
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double l2 = dx * dx + dy * dy;

    if (l2 == 0) return (p1 - center).distance <= radius;

    final double t = ((center.dx - p1.dx) * dx + (center.dy - p1.dy) * dy) / l2;
    final double clampedT = math.max(0.0, math.min(1.0, t));

    final Offset projection = Offset(
      p1.dx + clampedT * dx,
      p1.dy + clampedT * dy,
    );

    return (projection - center).distance <= radius;
  }
}

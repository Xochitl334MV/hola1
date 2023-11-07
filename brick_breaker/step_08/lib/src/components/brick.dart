import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../brick_breaker.dart';
import '../config.dart';
import 'ball.dart';
import 'bat.dart';

class Brick extends RectangleComponent
    with CollisionCallbacks, HasGameRef<BrickBreaker> {
  Brick(Vector2 position, Color color)
      : super(
            position: position,
            size: Vector2(brickWidth, brickHeight),
            anchor: Anchor.center,
            paint: Paint()
              ..color = color
              ..style = PaintingStyle.fill);

  @override
  onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Ball) {
      game.world.remove(this);

      if (game.world.children.whereType<Brick>().length == 1) {
        game.world.removeAll(game.world.children.whereType<Ball>());
        game.world.removeAll(game.world.children.whereType<Bat>());
      }
    }
  }
}
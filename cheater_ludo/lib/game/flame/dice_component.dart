import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../engine/player.dart';
import 'ludo_game.dart';

class DiceComponent extends PositionComponent with TapCallbacks {
  final LudoGame game;
  int currentFace = 1;
  final Random _random = Random();

  DiceComponent({required this.game}) {
    width = 60;
    height = 60;
    anchor = Anchor.center;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x / 2, size.y / 2 + 50);
  }

  @override
  void render(Canvas canvas) {
    var paint = Paint()..color = Colors.white;
    var rect = Rect.fromLTWH(0, 0, width, height);
    var rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black, 4.0, true);
    canvas.drawRRect(rrect, paint);
    
    var cp = game.gameState.players[game.gameState.currentPlayerIndex];
    Color borderColor = Colors.grey;
    if (!game.gameState.players.every((p) => p.hasWon)) {
      if (cp.color == PlayerColor.red) borderColor = Colors.red;
      if (cp.color == PlayerColor.green) borderColor = Colors.green;
      if (cp.color == PlayerColor.blue) borderColor = Colors.blue;
      if (cp.color == PlayerColor.yellow) borderColor = Colors.yellow;
    }

    var borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);

    var dotPaint = Paint()..color = Colors.black;
    double r = 4.5;
    double c = width / 2;
    double l = width * 0.25;
    double right = width * 0.75;
    double t = height * 0.25;
    double b = height * 0.75;

    if (currentFace == 1 || currentFace == 3 || currentFace == 5) {
      canvas.drawCircle(Offset(c, c), r, dotPaint);
    }
    if (currentFace > 1) {
      canvas.drawCircle(Offset(l, t), r, dotPaint);
      canvas.drawCircle(Offset(right, b), r, dotPaint);
    }
    if (currentFace > 3) {
      canvas.drawCircle(Offset(right, t), r, dotPaint);
      canvas.drawCircle(Offset(l, b), r, dotPaint);
    }
    if (currentFace == 6) {
      canvas.drawCircle(Offset(l, c), r, dotPaint);
      canvas.drawCircle(Offset(right, c), r, dotPaint);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isRolling || game.isMoving || game.waitingForPlayerMove) return;
    
    var cp = game.gameState.players[game.gameState.currentPlayerIndex];
    if (cp.type == PlayerType.human) {
      game.rollDice();
    }
  }

  Future<void> animateRoll(int finalResult) async {
    for (int i = 0; i < 10; i++) {
      currentFace = _random.nextInt(6) + 1;
      await Future.delayed(const Duration(milliseconds: 60));
    }
    currentFace = finalResult;
  }
}

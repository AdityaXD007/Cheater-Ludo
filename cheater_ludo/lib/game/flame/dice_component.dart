import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../utils/haptics.dart';
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
    position = Vector2(size.x / 2, size.y / 2);
    
    // Scale dice proportionally to the board
    double minDim = min(size.x, size.y) * 0.95;
    double expectedCellSize = minDim / 15;
    width = expectedCellSize * 1.5;
    height = expectedCellSize * 1.5;
  }

  @override
  void render(Canvas canvas) {
    // Hidden: The old center dice is completely removed.
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isRolling || game.isMoving || game.waitingForPlayerMove) return;
    
    var cp = game.gameState.players[game.gameState.currentPlayerIndex];
    if (cp.type == PlayerType.human) {
      Haptics.tap();
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

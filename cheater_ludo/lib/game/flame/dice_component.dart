import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../../utils/haptics.dart';
import '../engine/player.dart';
import 'ludo_game.dart';

class DiceComponent extends SpriteAnimationComponent with TapCallbacks {
  final LudoGame game;
  int currentFace = 1;
  late SpriteAnimation _rollAnimation;
  final Map<int, SpriteAnimation> _faceAnimations = {};

  DiceComponent({required this.game}) {
    width = 60;
    height = 60;
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    List<String> framePaths = List.generate(
      25, 
      (i) => 'dice/roll/roll_${(i+1).toString().padLeft(4, '0')}.png'
    );
    await game.images.loadAll(framePaths);
    
    List<String> facePaths = List.generate(6, (i) => 'dice/final/face_${i+1}.png');
    await game.images.loadAll(facePaths);

    List<Sprite> rollSprites = framePaths.map((path) => Sprite(game.images.fromCache(path))).toList();
    _rollAnimation = SpriteAnimation.spriteList(rollSprites, stepTime: 0.033, loop: false);

    for (int i = 1; i <= 6; i++) {
      _faceAnimations[i] = SpriteAnimation.spriteList(
        [Sprite(game.images.fromCache('dice/final/face_$i.png'))],
        stepTime: double.infinity,
      );
    }
    
    animation = _faceAnimations[1];
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x / 2, size.y / 2);
    
    // Scale dice proportionally to the board
    double minDim = min(size.x, size.y) * 0.95;
    double expectedCellSize = minDim / 15;
    width = expectedCellSize * 2.0;
    height = expectedCellSize * 2.0;
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
    animation = _rollAnimation;
    animationTicker?.reset();
    
    // Fallback to a reliable timer since Flame's ticker.completed can hang
    // 25 frames * 0.033s = ~825ms
    await Future.delayed(const Duration(milliseconds: 825));
    
    animation = _faceAnimations[finalResult];
    currentFace = finalResult;
  }
}

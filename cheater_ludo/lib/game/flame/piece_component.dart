import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import '../../utils/haptics.dart';
import '../engine/piece.dart';
import '../engine/player.dart';
import '../engine/board_constants.dart';
import 'ludo_game.dart';
import 'board_component.dart';

class PieceComponent extends PositionComponent with TapCallbacks {
  final Piece piece;
  final Player player;
  final LudoGame game;
  
  late Paint _paint;
  late Paint _strokePaint;

  PieceComponent({required this.piece, required this.player, required this.game}) {
    Color c = Colors.white;
    switch (player.color) {
      case PlayerColor.red: c = BoardComponent.redColor; break;
      case PlayerColor.green: c = BoardComponent.greenColor; break;
      case PlayerColor.blue: c = BoardComponent.blueColor; break;
      case PlayerColor.yellow: c = BoardComponent.yellowColor; break;
    }
    _paint = Paint()..color = c;
    _strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    anchor = Anchor.center;
  }

  @override
  void onMount() {
    super.onMount();
    _updatePositionInstantly();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    var board = game.children.whereType<BoardComponent>().first;
    width = board.cellSize * 0.6;
    height = board.cellSize * 0.6;
    
    // Only update position instantly if we are not currently animating.
    // This prevents UI state changes (like tapping) from causing a layout shift
    // that instantly snaps the piece to its destination during a MoveToEffect.
    if (children.whereType<MoveToEffect>().isEmpty) {
      _updatePositionInstantly();
    }
  }

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    bool isMyTurn = piece.playerId == game.gameState.players[game.gameState.currentPlayerIndex].id;
    bool isWaitingForMe = game.waitingForPlayerMove && isMyTurn;
    bool isValid = isWaitingForMe && game.gameState.lastRoll != null && game.isValidMove(piece, game.gameState.lastRoll!);

    double alpha = 1.0;
    if (piece.isFinished) {
      alpha = 0.5;
    } else if (isWaitingForMe && !isValid) {
      alpha = 0.5; // Invalid pieces (cannot move this turn): opacity 0.5
    }

    canvas.save();
    canvas.translate(width / 2, height / 2);

    if (isValid) {
      canvas.scale(1.1);
    }

    Paint currentPaint = Paint()..color = _paint.color.withAlpha((alpha * 255).toInt());
    Paint currentStroke = Paint()
      ..color = _strokePaint.color.withAlpha((alpha * 255).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset.zero, width / 2, currentPaint);
    canvas.drawCircle(Offset.zero, width / 2, currentStroke);
    
    if (isValid) {
       // Oscillate opacity 0.6 -> 1.0 -> 0.6 every 600ms
       // sin(t) gives -1 to 1. Normalized gives 0 to 1.
       double pulse = (math.sin(_time * math.pi * 2 / 0.6) + 1) / 2;
       double pulseAlpha = 0.6 + (0.4 * pulse);
       
       Color ringColor = player.color == PlayerColor.yellow ? Colors.white : const Color(0xFFFFD700);
       
       canvas.drawCircle(
         Offset.zero, 
         width / 2 + 2, 
         Paint()
           ..color = ringColor.withAlpha((pulseAlpha * 255).toInt())
           ..style = PaintingStyle.stroke
           ..strokeWidth = 3.0
       );
    }
    
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) {
    Haptics.tap();
    game.handlePieceTap(piece);
  }

  void _updatePositionInstantly() {
    var board = game.children.whereType<BoardComponent>().first;
    if (board.cellSize == 0) return;
    Vector2 target = _getVectorForPosition(piece.position, board);
    position = target;
  }

  Future<void> moveToBoard() async {
    FlameAudio.play('piece_move.m4a', volume: 0.6);
    var board = game.children.whereType<BoardComponent>().first;
    Vector2 target = _getVectorForPosition(0, board);
    await _animateTo(target);
  }

  Future<void> moveToNextSquare() async {
    FlameAudio.play('piece_move.m4a', volume: 0.6);
    var board = game.children.whereType<BoardComponent>().first;
    Vector2 target = _getVectorForPosition(piece.position, board);
    await _animateTo(target);
  }

  Future<void> sendHome() async {
    var board = game.children.whereType<BoardComponent>().first;
    Vector2 target = _getVectorForPosition(-1, board);
    await _animateTo(target);
  }

  Future<void> _animateTo(Vector2 target) async {
    final effect = MoveToEffect(
      target,
      EffectController(duration: 0.25, curve: Curves.easeInOut),
    );
    add(effect);
    // Completer is handled internally by Flame but we await the controller completion
    await Future.delayed(const Duration(milliseconds: 260)); 
  }

  Vector2 _getVectorForPosition(int pos, BoardComponent board) {
    if (pos == -1) {
      List<BoardPos> bases;
      switch (player.color) {
        case PlayerColor.red: bases = BoardConstants.redHomeBase; break;
        case PlayerColor.green: bases = BoardConstants.greenHomeBase; break;
        case PlayerColor.blue: bases = BoardConstants.blueHomeBase; break;
        case PlayerColor.yellow: bases = BoardConstants.yellowHomeBase; break;
      }
      var bp = bases[piece.id];
      return Vector2(
        board.boardOffset.x + (bp.x + 0.5) * board.cellSize,
        board.boardOffset.y + (bp.y + 0.5) * board.cellSize,
      );
    }
    
    List<BoardPos> path;
    switch (player.color) {
      case PlayerColor.red: path = BoardConstants.redPath; break;
      case PlayerColor.green: path = BoardConstants.greenPath; break;
      case PlayerColor.blue: path = BoardConstants.bluePath; break;
      case PlayerColor.yellow: path = BoardConstants.yellowPath; break;
    }
    
    if (pos >= path.length) pos = path.length - 1;
    var bp = path[pos];
    
    return board.getCellCenter(bp.x, bp.y);
  }
}

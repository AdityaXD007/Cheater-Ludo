import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../engine/game_state.dart';
import '../engine/player.dart';
import '../engine/piece.dart';
import '../../utils/haptics.dart';
import '../engine/rigged_dice_engine.dart';
import '../engine/board_constants.dart';
import '../ai/ai_player.dart';
import 'board_component.dart';
import 'piece_component.dart';


class LudoGame extends FlameGame {
  final GameState gameState;
  late final RiggedDiceEngine diceEngine;
  
  // UI callbacks
  VoidCallback? onStateChanged;
  
  bool isRolling = false;
  bool isMoving = false;
  bool waitingForPlayerMove = false;
  
  final Map<int, AiPlayer> _aiPlayers = {};

  LudoGame(this.gameState) {
    diceEngine = RiggedDiceEngine();
    
    // Initialize AI players
    for (var p in gameState.players) {
      if (p.type == PlayerType.ai) {
        _aiPlayers[p.id] = AiPlayer(playerId: p.id, difficulty: p.difficulty ?? AiDifficulty.medium);
      }
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF121212); // Material dark theme background

  @override
  Future<void> onLoad() async {
    // Add Board
    add(BoardComponent());
    
    // Add Pieces
    for (var player in gameState.players) {
      for (var piece in player.pieces) {
        add(PieceComponent(piece: piece, player: player, game: this));
      }
    }
    
    gameState.phase = GamePhase.playing;
    _notifyUI();
    _startTurn();
  }

  void _notifyUI() {
    if (onStateChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChanged?.call();
      });
    }
  }

  Future<void> _startTurn() async {
    if (gameState.phase != GamePhase.playing) return;
    
    var currentPlayer = gameState.players[gameState.currentPlayerIndex];
    waitingForPlayerMove = false;
    _notifyUI();

    if (currentPlayer.type == PlayerType.ai) {
      await Future.delayed(const Duration(milliseconds: 500));
      await rollDice();
    } else {
      // Wait for human to tap dice (handled by DiceComponent tap event)
    }
  }

  Future<void> rollDice() async {
    if (isRolling || isMoving || waitingForPlayerMove) return;
    
    Haptics.heavy();
    
    isRolling = true;
    _notifyUI();

    try {
      int result = diceEngine.roll(gameState);
      
      // Wait for corner badge dice animation to play (25 frames * 33ms)
      await Future.delayed(const Duration(milliseconds: 825));
      
      gameState.lastRoll = result;
      gameState.rollHistory.add(result);
      gameState.players[gameState.currentPlayerIndex].lastRoll = result;
      
      if (result == 6) {
        gameState.consecutiveSixes++;
        if (gameState.consecutiveSixes >= 3) {
          // Forfeit turn
          gameState.consecutiveSixes = 0;
          isRolling = false;
          _notifyUI();
          _nextTurn();
          return;
        }
      } else {
        gameState.consecutiveSixes = 0;
      }

      isRolling = false;
      _notifyUI();
      await _handlePostRoll(result);
    } catch (e) {
      isRolling = false;
      _notifyUI();
      rethrow;
    }
  }

  Future<void> _handlePostRoll(int roll) async {
    var currentPlayer = gameState.players[gameState.currentPlayerIndex];
    var validPieces = currentPlayer.pieces.where((p) => isValidMove(p, roll)).toList();

    if (validPieces.isEmpty) {
      _notifyUI();
      await Future.delayed(const Duration(milliseconds: 800));
      _nextTurn();
      return;
    }

    if (currentPlayer.type == PlayerType.ai) {
      await Future.delayed(const Duration(milliseconds: 600));
      var ai = _aiPlayers[currentPlayer.id]!;
      int? pieceIdToMove = ai.selectPiece(roll, gameState);
      if (pieceIdToMove != null) {
        await movePiece(currentPlayer.pieces.firstWhere((p) => p.id == pieceIdToMove));
      } else {
        _nextTurn();
      }
    } else {
      // If only one valid move, auto-move it
      if (validPieces.length == 1) {
         await movePiece(validPieces.first);
      } else {
        waitingForPlayerMove = true;
        _notifyUI();
      }
    }
  }

  bool isValidMove(Piece piece, int roll) {
    if (piece.isFinished) return false;
    if (piece.isHome && roll != 6) return false;
    if (!piece.isHome && piece.position + roll > 56) return false;
    return true;
  }

  // Called when a human taps a piece
  Future<void> handlePieceTap(Piece piece) async {
    if (!waitingForPlayerMove || isMoving) return;
    
    var currentPlayer = gameState.players[gameState.currentPlayerIndex];
    if (piece.playerId != currentPlayer.id) return;
    
    if (!isValidMove(piece, gameState.lastRoll!)) return;
    
    waitingForPlayerMove = false;
    _notifyUI();
    await movePiece(piece);
  }

  Future<void> movePiece(Piece piece) async {
    isMoving = true;
    int roll = gameState.lastRoll!;
    
    int oldPos = piece.position;
    
    // Animate movement step by step
    var pieceComp = children.whereType<PieceComponent>().firstWhere((c) => c.piece == piece);
    
    if (oldPos == -1) {
      piece.position = 0;
      await pieceComp.moveToBoard();
    } else {
      for (int i = 1; i <= roll; i++) {
        piece.position = oldPos + i;
        await pieceComp.moveToNextSquare();
      }
    }
    
    await _checkCaptures(piece);
    _checkWinCondition();
    
    isMoving = false;
    _notifyUI();
    
    // Extra turn on 6, unless won
    var currentPlayer = gameState.players[gameState.currentPlayerIndex];
    if (roll == 6 && !currentPlayer.hasWon) {
      _startTurn();
    } else {
      _nextTurn();
    }
  }

  Future<void> _checkCaptures(Piece piece) async {
    if (piece.position > 50 || piece.position < 0) return; // Only capture on shared ring
    
    var currentPlayer = gameState.players.firstWhere((p) => p.id == piece.playerId);
    int globalPos = _toGlobal(currentPlayer.color, piece.position);
    
    if (BoardConstants.safeSquares.contains(globalPos)) return;
    
    for (var other in gameState.players) {
      if (other.id == piece.playerId) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          if (opGlobal == globalPos) {
            // Capture!
            op.position = -1;
            var opComp = children.whereType<PieceComponent>().firstWhere((c) => c.piece == op);
            await opComp.sendHome();
          }
        }
      }
    }
  }

  int _toGlobal(PlayerColor color, int pos) {
    int offset = 0;
    switch (color) {
      case PlayerColor.red: offset = 0; break;
      case PlayerColor.green: offset = 13; break;
      case PlayerColor.blue: offset = 26; break;
      case PlayerColor.yellow: offset = 39; break;
    }
    return (offset + pos) % 52;
  }

  void _checkWinCondition() {
    var currentPlayer = gameState.players[gameState.currentPlayerIndex];
    if (currentPlayer.hasWon) {
      // Technically should remove player and continue, but for now just end game
      gameState.phase = GamePhase.finished;
      _notifyUI();
    }
  }

  void _nextTurn() {
    if (gameState.phase == GamePhase.finished) return;
    
    gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.length;
    // Skip finished players
    while(gameState.players[gameState.currentPlayerIndex].hasWon) {
       gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.length;
    }
    
    _startTurn();
  }
}

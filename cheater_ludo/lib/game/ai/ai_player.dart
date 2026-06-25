import 'dart:math';
import '../engine/game_state.dart';
import '../engine/player.dart';
import '../engine/piece.dart';
import '../engine/board_constants.dart';

class AiPlayer {
  final int playerId;
  final AiDifficulty difficulty;
  final Random _random = Random();

  AiPlayer({required this.playerId, required this.difficulty});

  // Returns piece id to move, or null if no valid move
  int? selectPiece(int roll, GameState state) {
    var player = state.players.firstWhere((p) => p.id == playerId);
    var validPieces = player.pieces.where((p) => _isValidMove(p, roll)).toList();

    if (validPieces.isEmpty) return null;

    if (difficulty == AiDifficulty.easy) {
      return validPieces[_random.nextInt(validPieces.length)].id;
    }

    if (difficulty == AiDifficulty.medium) {
      // 1. Capture
      for (var p in validPieces) {
        if (_capturesOpponent(state, player, p, roll)) return p.id;
      }
      // 2. Closest to finishing
      validPieces.sort((a, b) => b.position.compareTo(a.position));
      for (var p in validPieces) {
        if (p.position + roll == 56) return p.id;
      }
      // 3. Enter board
      if (roll == 6) {
        for (var p in validPieces) {
          if (p.isHome) return p.id;
        }
      }
      // 4. Out of danger
      for (var p in validPieces) {
        if (_isInDanger(state, player, p) && !_isDangerZone(state, player, p, roll)) return p.id;
      }
      // 5. Fallback (Move piece furthest along)
      return validPieces.first.id;
    }

    // Hard
    int bestScore = -9999;
    int? bestPieceId;

    for (var p in validPieces) {
      int score = _scoreMove(state, player, p, roll);
      if (score > bestScore) {
        bestScore = score;
        bestPieceId = p.id;
      }
    }

    return bestPieceId ?? validPieces.first.id;
  }

  bool _isValidMove(Piece piece, int roll) {
    if (piece.isFinished) return false;
    if (piece.isHome && roll != 6) return false;
    if (!piece.isHome && piece.position + roll > 56) return false;
    return true;
  }

  int _scoreMove(GameState state, Player player, Piece piece, int roll) {
    int score = 0;
    
    if (_capturesOpponent(state, player, piece, roll)) score += 10;
    
    int nextPos = piece.position == -1 ? 0 : piece.position + roll;
    
    // Enters home stretch
    if (piece.position < 51 && nextPos >= 51 && nextPos < 56) score += 8;
    
    // Lands on safe square
    if (nextPos >= 0 && nextPos <= 50) {
      int globalNext = _toGlobal(player.color, nextPos);
      if (BoardConstants.safeSquares.contains(globalNext)) score += 6;
    }

    // Moves furthest along piece (approximate with position scaling)
    if (piece.position > 0) score += (piece.position ~/ 10);
    
    // Custom logic: prioritize finishing!
    if (nextPos == 56) score += 15;
    
    // Moves into capture range
    if (_isDangerZone(state, player, piece, roll)) score -= 8;
    
    // Moves off safe unnecessarily
    if (piece.position >= 0 && piece.position <= 50) {
      int globalCurrent = _toGlobal(player.color, piece.position);
      if (BoardConstants.safeSquares.contains(globalCurrent)) {
        int globalNext = _toGlobal(player.color, nextPos);
        if (!BoardConstants.safeSquares.contains(globalNext)) score -= 4;
      }
    }
    
    // Protect new pieces
    if (piece.position >= 0 && piece.position <= 6) score -= 2;

    return score;
  }

  bool _capturesOpponent(GameState state, Player player, Piece piece, int roll) {
    if (piece.position == -1 && roll != 6) return false;
    int boardPos = piece.position == -1 ? 0 : piece.position + roll;
    if (boardPos > 50) return false; 
    
    int globalPos = _toGlobal(player.color, boardPos);
    if (BoardConstants.safeSquares.contains(globalPos)) return false;

    for (var other in state.players) {
      if (other.id == player.id) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          if (opGlobal == globalPos) return true;
        }
      }
    }
    return false;
  }

  bool _isDangerZone(GameState state, Player player, Piece piece, int roll) {
    int nextPos = piece.position == -1 ? 0 : piece.position + roll;
    if (nextPos > 50) return false;

    int globalNext = _toGlobal(player.color, nextPos);
    if (BoardConstants.safeSquares.contains(globalNext)) return false;

    return _isGlobalDanger(state, player, globalNext);
  }

  bool _isInDanger(GameState state, Player player, Piece piece) {
    if (piece.position < 0 || piece.position > 50) return false;
    int globalPos = _toGlobal(player.color, piece.position);
    if (BoardConstants.safeSquares.contains(globalPos)) return false;
    return _isGlobalDanger(state, player, globalPos);
  }

  bool _isGlobalDanger(GameState state, Player player, int globalPos) {
    for (var other in state.players) {
      if (other.id == player.id) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          int distance = (globalPos - opGlobal) % 52;
          if (distance >= 1 && distance <= 6) return true;
        }
      }
    }
    return false;
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
}

import 'dart:math';
import 'game_state.dart';
import 'player.dart';
import 'piece.dart';
import 'board_constants.dart';

class RiggedDiceEngine {
  final Random _random;
  final Map<int, int> _turnCounts = {};
  final Map<int, int> _unfavorableStreaks = {};
  final Map<int, int> _graceTurns = {};

  RiggedDiceEngine({int? seed}) : _random = seed != null ? Random(seed) : Random();

  int roll(GameState state) {
    final currentPlayer = state.players[state.currentPlayerIndex];
    final isWinner = state.designatedWinnerId != null && currentPlayer.id == state.designatedWinnerId;

    _turnCounts[currentPlayer.id] = (_turnCounts[currentPlayer.id] ?? 0) + 1;

    // Never produce three 6s in a row
    if (state.consecutiveSixes >= 2) return _safeRoll();

    if (!state.isRigged || state.designatedWinnerId == null) return _pureRandom();

    if (_isNaturalMoment(state, currentPlayer.id)) return _pureRandom();

    // Check grace turns
    if ((_graceTurns[currentPlayer.id] ?? 0) > 0) {
      _graceTurns[currentPlayer.id] = _graceTurns[currentPlayer.id]! - 1;
      return _pureRandom();
    }

    final biasProbability = _getBiasProbability(state, isWinner);
    final applyBias = _random.nextDouble() < biasProbability;

    if (!applyBias) {
      final roll = _pureRandom();
      if (!isWinner && _isUnfavorable(state, currentPlayer, roll)) {
        _unfavorableStreaks[currentPlayer.id] = (_unfavorableStreaks[currentPlayer.id] ?? 0) + 1;
        if (_unfavorableStreaks[currentPlayer.id]! >= 8) {
          _graceTurns[currentPlayer.id] = _random.nextInt(2) + 2; // 2 or 3 turns
          _unfavorableStreaks[currentPlayer.id] = 0;
        }
      } else {
        _unfavorableStreaks[currentPlayer.id] = 0;
      }
      return roll;
    }

    final favorableRolls = isWinner
        ? _getFavorableRolls(state, currentPlayer)
        : _getUnfavorableRolls(state, currentPlayer);

    if (favorableRolls.isEmpty) return _pureRandom();
    
    int chosenRoll = favorableRolls[_random.nextInt(favorableRolls.length)];

    if (!isWinner) {
      _unfavorableStreaks[currentPlayer.id] = (_unfavorableStreaks[currentPlayer.id] ?? 0) + 1;
      if (_unfavorableStreaks[currentPlayer.id]! >= 8) {
        _graceTurns[currentPlayer.id] = _random.nextInt(2) + 2;
        _unfavorableStreaks[currentPlayer.id] = 0;
      }
    } else {
      _unfavorableStreaks[currentPlayer.id] = 0;
    }

    return chosenRoll;
  }

  List<int> _getFavorableRolls(GameState state, Player player) {
    List<int> valid = [];
    
    // Priority 1: Return [6] if winner has pieces stuck at home
    if (player.pieces.any((p) => p.isHome)) {
      return [6];
    }

    // Evaluate all 6 possible rolls
    for (int r = 1; r <= 6; r++) {
      if (_isFavorable(state, player, r)) {
        valid.add(r);
      }
    }

    // Priority 4: High numbers if pieces are on home stretch
    if (valid.isEmpty && player.pieces.any((p) => p.position >= 51 && p.position < 56)) {
      return [4, 5, 6];
    }

    return valid;
  }

  List<int> _getUnfavorableRolls(GameState state, Player player) {
    List<int> valid = [];
    for (int r = 1; r <= 6; r++) {
      if (_isUnfavorable(state, player, r)) {
        valid.add(r);
      }
    }
    // Avoid making it obvious - never return only [1, 2] every time
    if (valid.every((r) => r <= 2) && valid.isNotEmpty) {
      valid.add(3); // Mix it up
    }
    return valid;
  }

  bool _isFavorable(GameState state, Player player, int roll) {
    for (var piece in player.pieces) {
      if (piece.isHome && roll == 6) return true;
      if (piece.isFinished) continue;
      
      int nextPos = piece.position + roll;
      if (nextPos > 56) continue;
      
      // Check if lands on safe square
      if (nextPos >= 0 && nextPos <= 50) {
         int globalPos = _toGlobal(player.color, nextPos);
         if (BoardConstants.safeSquares.contains(globalPos)) return true;
      }
      
      // Check if captures an opponent piece
      if (_capturesOpponent(state, player, piece, roll)) return true;
    }
    return false;
  }

  bool _isUnfavorable(GameState state, Player player, int roll) {
    bool canMoveAny = false;
    bool entersDanger = false;

    for (var piece in player.pieces) {
      if (piece.isHome && roll == 6) {
        canMoveAny = true;
        continue;
      }
      if (piece.isHome || piece.isFinished) continue;
      
      int nextPos = piece.position + roll;
      if (nextPos > 56) continue;
      
      canMoveAny = true;

      // Moves off safe square into danger
      if (_isDangerZone(state, player, piece, roll)) {
        entersDanger = true;
      }
    }

    // Priority 1: Rolls where no piece can move
    if (!canMoveAny) return true;
    
    // Priority 2 & 3: Rolls that land in capture range or off safe square
    if (entersDanger) return true;

    return false;
  }

  bool _capturesOpponent(GameState state, Player player, Piece piece, int roll) {
    if (piece.position == -1 && roll != 6) return false;
    int boardPos = piece.position == -1 ? 0 : piece.position + roll;
    if (boardPos > 50) return false; // Only captures on shared ring
    
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
    int nextPos = piece.position + roll;
    if (nextPos > 50) return false;

    int globalNext = _toGlobal(player.color, nextPos);
    if (BoardConstants.safeSquares.contains(globalNext)) return false;

    // Check if any opponent is within 1-6 squares behind
    for (var other in state.players) {
      if (other.id == player.id) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          int distance = (globalNext - opGlobal) % 52;
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

  double _getBiasProbability(GameState state, bool isWinner) {
    if (state.designatedWinnerId == null) return 0.0;
    
    // Blowout prevention check
    int winnerAvg = _getAvgPosition(state.players.firstWhere((p) => p.id == state.designatedWinnerId!));
    bool isBlowout = true;
    for (var p in state.players) {
      if (p.id != state.designatedWinnerId) {
        if (winnerAvg - _getAvgPosition(p) < 15) {
          isBlowout = false;
          break;
        }
      }
    }
    
    if (isBlowout) return 0.1;
    return isWinner ? 0.45 : 0.35;
  }

  bool _isNaturalMoment(GameState state, int playerId) {
    // Early game (first 3 turns)
    if ((_turnCounts[playerId] ?? 1) <= 3) return true;

    if (state.designatedWinnerId != null) {
      var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
      // Winner all in home stretch
      if (winner.pieces.every((p) => p.position >= 51 || p.isFinished)) return true;
    }

    return false;
  }

  int _getAvgPosition(Player player) {
    int sum = 0;
    for (var p in player.pieces) {
      if (p.isFinished) {
        sum += 56;
      } else if (p.position > 0) {
        sum += p.position;
      }
    }
    return (sum / 4).round();
  }

  int _pureRandom() => _random.nextInt(6) + 1;

  int _safeRoll() => _random.nextInt(5) + 1;
}

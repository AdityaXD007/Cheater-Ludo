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
    if (state.consecutiveSixes >= 2) {
      int r = _safeRoll();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    if (!state.isRigged || state.designatedWinnerId == null) return _pureRandom();

    // 1. EMERGENCY SABOTAGE (Overrides everything else)
    final emergencyId = _getEmergencySabotagePlayer(state);
    if (emergencyId != null && currentPlayer.id == emergencyId) {
      if (_random.nextDouble() < 0.90) {
        final unfavorableRolls = _getUnfavorableRolls(state, currentPlayer);
        if (unfavorableRolls.isNotEmpty) {
          int r = unfavorableRolls[_random.nextInt(unfavorableRolls.length)];
          return _applySafeguards(state, currentPlayer, isWinner, r);
        }
      }
      int r = _pureRandom();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    final isHardMode = _guaranteeWinnerLeads(state);

    // Global naturalizer: skip bias randomly on 15% of turns (DISABLED in Hard Mode)
    if (!isHardMode && _random.nextDouble() < 0.15) {
      int r = _pureRandom();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    if (_isNaturalMoment(state, currentPlayer.id)) {
      int r = _pureRandom();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    // Check grace turns
    if ((_graceTurns[currentPlayer.id] ?? 0) > 0) {
      _graceTurns[currentPlayer.id] = _graceTurns[currentPlayer.id]! - 1;
      int r = _pureRandom();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    final biasProbability = _getBiasProbability(state, isWinner, isHardMode);
    final applyBias = _random.nextDouble() < biasProbability;

    if (!applyBias) {
      final roll = _pureRandom();
      if (!isWinner && _isUnfavorable(state, currentPlayer, roll)) {
        _unfavorableStreaks[currentPlayer.id] = (_unfavorableStreaks[currentPlayer.id] ?? 0) + 1;
        if (_unfavorableStreaks[currentPlayer.id]! >= 5) {
          _graceTurns[currentPlayer.id] = _random.nextInt(2) + 1;
          _unfavorableStreaks[currentPlayer.id] = 0;
        }
      } else {
        _unfavorableStreaks[currentPlayer.id] = 0;
      }
      return _applySafeguards(state, currentPlayer, isWinner, roll);
    }

    final favorableRolls = isWinner
        ? _getFavorableRolls(state, currentPlayer)
        : _getUnfavorableRolls(state, currentPlayer);

    if (favorableRolls.isEmpty) {
      int r = _pureRandom();
      return _applySafeguards(state, currentPlayer, isWinner, r);
    }

    int chosenRoll = favorableRolls[_random.nextInt(favorableRolls.length)];

    if (!isWinner) {
      _unfavorableStreaks[currentPlayer.id] = (_unfavorableStreaks[currentPlayer.id] ?? 0) + 1;
      if (_unfavorableStreaks[currentPlayer.id]! >= 5) {
        _graceTurns[currentPlayer.id] = _random.nextInt(2) + 1;
        _unfavorableStreaks[currentPlayer.id] = 0;
      }
    } else {
      _unfavorableStreaks[currentPlayer.id] = 0;
    }

    return _applySafeguards(state, currentPlayer, isWinner, chosenRoll);
  }

  /// Final safeguard applied to EVERY roll before returning.
  /// Ensures no non-winner can ever finish the game.
  int _applySafeguards(GameState state, Player currentPlayer, bool isWinner, int roll) {
    if (!state.isRigged || state.designatedWinnerId == null || isWinner) return roll;

    // Layer 1: Block ANY roll that would let a non-winner finish their last piece(s)
    if (_wouldFinishAnyPiece(currentPlayer, roll)) {
      // Find a roll that doesn't finish any piece
      for (int r = 1; r <= 6; r++) {
        if (!_wouldFinishAnyPiece(currentPlayer, r)) return r;
      }
      // All rolls finish a piece — return the one that finishes the fewest
      return _leastFinishingRoll(currentPlayer);
    }

    // Layer 2: If any piece is at position 55 (one step from finishing), block roll of 1
    if (roll == 1 && currentPlayer.pieces.any((p) => !p.isFinished && p.position == 55)) {
      // Return anything except 1
      List<int> safe = [2, 3, 4, 5, 6].where((r) => !_wouldFinishAnyPiece(currentPlayer, r)).toList();
      if (safe.isNotEmpty) return safe[_random.nextInt(safe.length)];
      return 2; // fallback
    }

    return roll;
  }

  /// Checks if the given roll would move ANY of the player's pieces to position 56
  bool _wouldFinishAnyPiece(Player player, int roll) {
    for (var p in player.pieces) {
      if (p.isFinished) continue;
      if (p.isHome) continue;
      if (p.position > 0 && p.position + roll == 56) return true;
    }
    return false;
  }

  /// Returns the roll that finishes the fewest pieces (last resort)
  int _leastFinishingRoll(Player player) {
    int bestRoll = 1;
    int minFinishes = 999;
    for (int r = 1; r <= 6; r++) {
      int count = 0;
      for (var p in player.pieces) {
        if (!p.isFinished && !p.isHome && p.position > 0 && p.position + r == 56) count++;
      }
      if (count < minFinishes) {
        minFinishes = count;
        bestRoll = r;
      }
    }
    return bestRoll;
  }

  int? _getEmergencySabotagePlayer(GameState state) {
    if (state.designatedWinnerId == null) return null;
    var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
    int winnerFinalStretch = winner.pieces.where((p) => p.position >= 46 || p.isFinished).length;
    
    // If winner already has 3+ in final stretch, no need to sabotage
    if (winnerFinalStretch >= 3) return null;

    for (var p in state.players) {
      if (p.id == state.designatedWinnerId) continue;
      int pFinalStretch = p.pieces.where((piece) => piece.position >= 46 || piece.isFinished).length;
      if (pFinalStretch >= 3) return p.id;
    }
    return null;
  }

  bool _guaranteeWinnerLeads(GameState state) {
    if (state.designatedWinnerId == null) return false;
    var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
    double winnerScore = _progressScore(winner);
    
    for (var p in state.players) {
      if (p.id == state.designatedWinnerId) continue;
      if (_progressScore(p) >= winnerScore + 10.0) {
        return true;
      }
    }
    return false;
  }

  List<int> _getFavorableRolls(GameState state, Player player) {
    List<int> valid = [];
    
    // Layer 3: Force winner to get pieces on board if stuck at home after turn 5
    int turnCount = _turnCounts[player.id] ?? 0;
    if (turnCount >= 5 && player.pieces.any((p) => p.isHome)) {
      int onBoard = player.pieces.where((p) => !p.isHome).length;
      if (onBoard < 2) {
        return [6];
      }
    }

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
      if (!_isFavorable(state, player, 3)) valid.add(3);
    }
    // Strict fallback: if we have NO unfavorable rolls, supply unplayable rolls
    if (valid.isEmpty) {
      for (int r = 1; r <= 6; r++) {
         bool canMove = false;
         for (var p in player.pieces) {
            if (p.isHome && r == 6) canMove = true;
            if (!p.isHome && !p.isFinished && p.position + r <= 56) canMove = true;
         }
         if (!canMove) valid.add(r);
      }
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

  double _getBiasProbability(GameState state, bool isWinner, bool isHardMode) {
    if (state.designatedWinnerId == null) return 0.0;
    
    // Blowout prevention check
    var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId!);
    double winnerAvg = _progressScore(winner);
    bool isBlowout = true;
    for (var p in state.players) {
      if (p.id != state.designatedWinnerId) {
        if (winnerAvg - _progressScore(p) < 15.0) {
          isBlowout = false;
          break;
        }
      }
    }
    
    if (isBlowout) return 0.1;
    
    if (isHardMode) {
      return isWinner ? 0.85 : 0.75;
    }
    return isWinner ? 0.45 : 0.35;
  }

  bool _isNaturalMoment(GameState state, int playerId) {
    // Early game (first 3 turns)
    if ((_turnCounts[playerId] ?? 1) <= 3) return true;

    if (state.designatedWinnerId != null) {
      var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
      // Winner all in home stretch (but disable naturalizer if any opponent is close)
      if (winner.pieces.every((p) => p.position >= 51 || p.isFinished)) {
         bool opponentClose = false;
         for (var p in state.players) {
           if (p.id == state.designatedWinnerId) continue;
           if (p.pieces.any((piece) => piece.position >= 45)) opponentClose = true;
         }
         if (!opponentClose) return true;
      }
    }

    return false;
  }

  double _progressScore(Player player) {
    int sum = 0;
    for (var p in player.pieces) {
      if (p.isFinished) {
        sum += 56;
      } else if (p.position > 0) {
        sum += p.position;
      }
    }
    return sum / 4.0;
  }

  int _pureRandom() => _random.nextInt(6) + 1;

  int _safeRoll() => _random.nextInt(5) + 1;
}

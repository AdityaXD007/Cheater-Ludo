import 'dart:math';
import 'game_state.dart';
import 'player.dart';
import 'piece.dart';
import 'board_constants.dart';
import 'rigging_config.dart';

class RiggedDiceEngine {
  final Random _random;
  final RiggingConfig config;
  final void Function(RollDebugInfo)? debugHook;

  final Map<int, int> _turnCounts = {};
  final Map<int, int> _unfavorableStreaks = {};
  final Map<int, int> _graceTurns = {};
  final Map<int, int> _finalPieceStuckTurns = {};

  /// Persistent hard-mode state for hysteresis (Item 3).
  bool _isHardMode = false;

  RiggedDiceEngine({
    int? seed,
    this.config = const RiggingConfig(),
    this.debugHook,
  }) : _random = seed != null ? Random(seed) : Random();

  // ---------------------------------------------------------------------------
  // Public API (signature unchanged)
  // ---------------------------------------------------------------------------

  int roll(GameState state) {
    final currentPlayer = state.players[state.currentPlayerIndex];
    final isWinner = state.designatedWinnerId != null &&
        currentPlayer.id == state.designatedWinnerId;

    _turnCounts[currentPlayer.id] =
        (_turnCounts[currentPlayer.id] ?? 0) + 1;

    // Layer 0: Never produce three 6s in a row
    if (state.consecutiveSixes >= 2) {
      int r = _safeRoll();
      r = _applySafeguards(state, currentPlayer, isWinner, r);
      _emitDebug(currentPlayer.id, r, 'L0_TripleSix', 'Blocked 3rd consecutive 6', isWinner);
      return r;
    }

    // Unrigged games get pure random
    if (!state.isRigged || state.designatedWinnerId == null) {
      int r = _pureRandom();
      _emitDebug(currentPlayer.id, r, 'Unrigged', 'No rigging active', isWinner);
      return r;
    }

    // Layer 1: Emergency sabotage
    final emergencyId = _getEmergencySabotagePlayer(state);
    if (emergencyId != null && currentPlayer.id == emergencyId) {
      if (_random.nextDouble() < config.emergencySabotageProbability) {
        final unfavorableRolls = _getUnfavorableRolls(state, currentPlayer);
        if (unfavorableRolls.isNotEmpty) {
          int r = unfavorableRolls[_random.nextInt(unfavorableRolls.length)];
          r = _applySafeguards(state, currentPlayer, isWinner, r);
          _emitDebug(currentPlayer.id, r, 'L1_Emergency', 'Emergency sabotage: player threatening win', isWinner);
          return r;
        }
      }
      int r = _pureRandom();
      r = _applySafeguards(state, currentPlayer, isWinner, r);
      _emitDebug(currentPlayer.id, r, 'L1_Emergency', 'Emergency sabotage: 10% passthrough', isWinner);
      return r;
    }

    // Evaluate hard mode with hysteresis
    bool isHardMode = _evaluateHardMode(state);

    int roll = _pureRandom();

    // Determine if the winner is trailing or has no pieces on board
    bool isTrailing = false;
    bool hasNoPiecesOnBoard = false;
    if (isWinner && state.designatedWinnerId != null) {
      var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
      double winnerAvg = _progressScore(winner);
      for (var p in state.players) {
        if (p.id != state.designatedWinnerId && _progressScore(p) > winnerAvg) {
          isTrailing = true;
        }
      }
      hasNoPiecesOnBoard = !winner.pieces.any((p) => !p.isHome && !p.isFinished);
    }

    double currentNaturalizerRate = config.globalNaturalizerRate;
    if (isHardMode) {
      currentNaturalizerRate = 0.0;
    } else if (isWinner && (isTrailing || hasNoPiecesOnBoard)) {
      currentNaturalizerRate = config.trailingWinnerNaturalizerRate;
    }

    if (currentNaturalizerRate > 0 &&
        _random.nextDouble() < currentNaturalizerRate) {
      _emitDebug(currentPlayer.id, roll, 'L4_Naturalizer', 'Naturalizer active, using random roll', isWinner);
      return _applySafeguards(state, currentPlayer, isWinner, roll);
    }

    // Layer 3: Natural moments (early game, winner cruising)
    if (_isNaturalMoment(state, currentPlayer.id)) {
      int r = _pureRandom();
      r = _applySafeguards(state, currentPlayer, isWinner, r);
      _emitDebug(currentPlayer.id, r, 'L3_Natural', 'Natural moment: early game or winner cruising', isWinner);
      return r;
    }

    // Layer 4: Grace turns (mercy after long unfavorable streaks)
    if ((_graceTurns[currentPlayer.id] ?? 0) > 0) {
      _graceTurns[currentPlayer.id] = _graceTurns[currentPlayer.id]! - 1;
      int r = _pureRandom();
      r = _applySafeguards(state, currentPlayer, isWinner, r);
      _emitDebug(currentPlayer.id, r, 'L4_Grace', 'Grace turn (mercy after streak)', isWinner);
      return r;
    }

    // Layer 5: Biased roll selection
    final biasProbability =
        _getBiasProbability(state, isWinner, isHardMode);
    final applyBias = _random.nextDouble() < biasProbability;
    final layerName = 'L5_Bias';
    final reason = 'Bias coin flip';

    // Determine favorable and unfavorable rolls
    List<int> favorableRolls = _getFavorableRolls(state, currentPlayer);
    List<int> unfavorableRolls = _getUnfavorableRolls(state, currentPlayer);

    int chosenRoll;
    if (isWinner) {
      // The winner is rarely sabotaged (probabilistic split).
      // If bias is applied, they get a favorable roll. Otherwise, 95% pure random / 5% unfavorable.
      if (applyBias && favorableRolls.isNotEmpty) {
        chosenRoll = favorableRolls[_random.nextInt(favorableRolls.length)];
        _trackUnfavorableStreak(state, currentPlayer, isWinner, chosenRoll);
        chosenRoll = _applySafeguards(state, currentPlayer, isWinner, chosenRoll);
        _emitDebug(currentPlayer.id, chosenRoll, layerName, '$reason (Winner Bias applied)', isWinner);
      } else {
        if (_random.nextDouble() < config.winnerSabotageProbabilityWhenNoBias && unfavorableRolls.isNotEmpty) {
          chosenRoll = unfavorableRolls[_random.nextInt(unfavorableRolls.length)];
          _trackUnfavorableStreak(state, currentPlayer, isWinner, chosenRoll);
          chosenRoll = _applySafeguards(state, currentPlayer, isWinner, chosenRoll);
          _emitDebug(currentPlayer.id, chosenRoll, layerName, '$reason (Winner Sabotage applied via 5% split)', isWinner);
        } else {
          int r = _pureRandom();
          _trackUnfavorableStreak(state, currentPlayer, isWinner, r);
          chosenRoll = _applySafeguards(state, currentPlayer, isWinner, r);
          _emitDebug(currentPlayer.id, chosenRoll, 'L5_NoBias', 'Winner Bias inactive, using pure random', isWinner);
        }
      }
    } else {
      // Non-winners are sabotaged when bias is applied (getting unfavorable rolls).
      // Otherwise they receive pure random rolls (never helped).
      if (applyBias && unfavorableRolls.isNotEmpty) {
        chosenRoll = unfavorableRolls[_random.nextInt(unfavorableRolls.length)];
        _trackUnfavorableStreak(state, currentPlayer, isWinner, chosenRoll);
        chosenRoll = _applySafeguards(state, currentPlayer, isWinner, chosenRoll);
        _emitDebug(currentPlayer.id, chosenRoll, layerName, '$reason (Loser Sabotage applied)', isWinner);
      } else {
        int r = _pureRandom();
        _trackUnfavorableStreak(state, currentPlayer, isWinner, r);
        chosenRoll = _applySafeguards(state, currentPlayer, isWinner, r);
        _emitDebug(currentPlayer.id, chosenRoll, 'L5_NoBias', 'Loser Sabotage inactive, using pure random', isWinner);
      }
    }

    // Reset consecutive stuck turns if they are able to make progress
    if (!isWinner) {
      int finishedCount = currentPlayer.pieces.where((p) => p.isFinished).length;
      if (finishedCount == 3) {
        if (_canMove(currentPlayer, chosenRoll)) {
          _finalPieceStuckTurns[currentPlayer.id] = 0;
        }
      }
    }

    return chosenRoll;
  }

  bool _canMove(Player player, int roll) {
    for (var p in player.pieces) {
      if (p.isFinished) continue;
      if (p.isHome && roll != 6) continue;
      if (p.position > 0 && p.position + roll > 56) continue;
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Layer 6: Safeguards — now with per-player last-piece tracking (Items 1 & 2)
  // ---------------------------------------------------------------------------

  /// Final safeguard applied to EVERY roll before returning.
  ///
  /// Item 1 change: Only blocks the 4th (final) piece from finishing.
  /// Pieces 1-3 can finish freely with zero interference.
  int _applySafeguards(
      GameState state, Player currentPlayer, bool isWinner, int roll) {
    if (!state.isRigged || state.designatedWinnerId == null || isWinner) {
      return roll;
    }

    final finishedCount =
        currentPlayer.pieces.where((p) => p.isFinished).length;

    // Pieces 1-3: no interference — let them finish naturally
    if (finishedCount < 3) return roll;

    // 4th piece (finishedCount == 3): hard block — this piece must NEVER finish
    final lastPiece = currentPlayer.pieces
        .firstWhere((p) => !p.isFinished, orElse: () => currentPlayer.pieces.first);

    // Check if this roll would finish the last piece (or is 1 at pos 55)
    bool wouldFinish = (!lastPiece.isHome && lastPiece.position > 0 && lastPiece.position + roll == 56) ||
                       (roll == 1 && !lastPiece.isHome && lastPiece.position == 55);

    // Active Rescue: If they've been stuck for too long, forcibly rescue them regardless of what they rolled.
    int stuckCount = _finalPieceStuckTurns[currentPlayer.id] ?? 0;
    var designatedWinner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
    int winnerUnfinished = 4 - designatedWinner.pieces.where((p) => p.isFinished).length;
    int dynamicLimit = min(config.dynamicStuckCapMax, config.dynamicStuckCapBase + winnerUnfinished);

    if (stuckCount >= dynamicLimit) {
      if (designatedWinner.hasWon) {
        // Force a finishing roll!
        int finishRoll = 56 - lastPiece.position;
        _emitDebug(currentPlayer.id, finishRoll, 'L6_GraceFinish', 'Stuck cap reached, winner finished, grace finish forced', false);
        return finishRoll; 
      } else {
        // Capture Escape Valve: try to let an opponent capture them.
        if (_canBeCaptured(state, currentPlayer, lastPiece)) {
           _emitDebug(currentPlayer.id, roll, 'L6_CaptureValve', 'Waiting to be captured by opponent', false);
           return _findOvershootRoll(lastPiece);
        }

        // Winner hasn't finished yet. Try to find a legal non-finishing roll to break the cycle.
        int? legalAdvance = _findLegalNonFinishingRoll(lastPiece);
        if (legalAdvance != null) {
          _emitDebug(currentPlayer.id, legalAdvance, 'L6_LegalAdvance', 'Stuck cap reached, legal advance granted', false);
          return legalAdvance;
        } else {
          // Position 55 edge case: No legal non-finishing roll exists.
          int finishRoll = 1;
          _emitDebug(currentPlayer.id, finishRoll, 'L6_CapBypass_Finish', 'Stuck cap reached at pos 55, winner not done. Forced to let loser finish to obey cap.', false);
          return finishRoll;
        }
      }
    }

    // Normal operation: if the roll would finish the piece (and cap not reached), block it.
    if (wouldFinish) {
      _finalPieceStuckTurns[currentPlayer.id] = (_finalPieceStuckTurns[currentPlayer.id] ?? 0) + 1;
      int overshoot = _findOvershootRoll(lastPiece);
      _emitDebug(currentPlayer.id, overshoot, 'L6_BlockFinish', 'Natural finish blocked, overshoot generated', false);
      return overshoot;
    }

    return roll;
  }

  int? _findLegalNonFinishingRoll(Piece lastPiece) {
    List<int> safe = [];
    for (int r = 1; r <= 6; r++) {
      if (lastPiece.position + r < 56) safe.add(r);
    }
    if (safe.isNotEmpty) return safe[_random.nextInt(safe.length)];
    return null;
  }

  int _findOvershootRoll(Piece lastPiece) {
    List<int> overshoots = [];
    for (int r = 1; r <= 6; r++) {
      if (lastPiece.position + r > 56) overshoots.add(r);
    }
    if (overshoots.isNotEmpty) return overshoots[_random.nextInt(overshoots.length)];
    
    // Fallback: any roll that doesn't land on exactly 56 (shouldn't happen)
    for (int r = 1; r <= 6; r++) {
      if (lastPiece.position + r != 56) return r;
    }
    return 1;
  }

  bool _canBeCaptured(GameState state, Player player, Piece piece) {
    if (piece.position > 50 || piece.position < 0) return false;
    
    int globalPos = _toGlobal(player.color, piece.position);
    if (BoardConstants.safeSquares.contains(globalPos)) return false;

    for (var other in state.players) {
      if (other.id == player.id) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          // Check if opponent is up to 6 squares behind
          int diff = globalPos - opGlobal;
          if (diff < 0) diff += 52;
          if (diff > 0 && diff <= 6) return true;
        }
      }
    }
    return false;
  }


  // ---------------------------------------------------------------------------
  // Emergency sabotage
  // ---------------------------------------------------------------------------

  int? _getEmergencySabotagePlayer(GameState state) {
    if (state.designatedWinnerId == null) return null;
    var winner = state.players
        .firstWhere((p) => p.id == state.designatedWinnerId);
    int winnerFinalStretch = winner.pieces
        .where((p) => p.position >= 46 || p.isFinished)
        .length;

    // If winner already has 2+ in final stretch, no need to sabotage
    if (winnerFinalStretch >= 2) return null;

    for (var p in state.players) {
      if (p.id == state.designatedWinnerId) continue;
      int pFinalStretch = p.pieces
          .where((piece) => piece.position >= 46 || piece.isFinished)
          .length;
      if (pFinalStretch >= 2) return p.id;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Hard mode with hysteresis (Item 3)
  // ---------------------------------------------------------------------------

  /// Evaluates hard mode using two thresholds to prevent flapping.
  bool _evaluateHardMode(GameState state) {
    if (state.designatedWinnerId == null) {
      _isHardMode = false;
      return false;
    }

    var winner = state.players
        .firstWhere((p) => p.id == state.designatedWinnerId);
    double winnerScore = _progressScore(winner);

    // Find the maximum gap (any loser ahead of the winner)
    double maxGap = 0.0;
    for (var p in state.players) {
      if (p.id == state.designatedWinnerId) continue;
      double gap = _progressScore(p) - winnerScore;
      if (gap > maxGap) maxGap = gap;
    }

    // Hysteresis: enter at enterGap, exit only when below exitGap
    if (!_isHardMode && maxGap >= config.hardModeEnterGap) {
      _isHardMode = true;
    } else if (_isHardMode && maxGap < config.hardModeExitGap) {
      _isHardMode = false;
    }

    return _isHardMode;
  }

  // ---------------------------------------------------------------------------
  // Favorable / Unfavorable roll evaluation
  // ---------------------------------------------------------------------------

  List<int> _getFavorableRolls(GameState state, Player player) {
    List<int> valid = [];
    bool isWinner = state.designatedWinnerId == player.id;

    // Force winner to get pieces on board if stuck at home after turn threshold
    int turnCount = _turnCounts[player.id] ?? 0;
    if (turnCount >= config.earlyGameTurnCount + 2 &&
        player.pieces.any((p) => p.isHome)) {
      int onBoard = player.pieces.where((p) => !p.isHome).length;
      if (onBoard < 2) {
        return [6];
      }
    }

    // Priority 1: Return [6] if winner has pieces stuck at home.
    // The actual probability of getting this 6 is governed by _getBiasProbability,
    // making it a probabilistic priority rather than a hard bypass.
    if (isWinner && player.pieces.any((p) => p.isHome)) {
      return [6];
    }

    // Evaluate all 6 possible rolls for tactical advantages (captures, safe squares)
    for (int r = 1; r <= 6; r++) {
      if (_isFavorable(state, player, r)) {
        valid.add(r);
      }
    }

    if (valid.isEmpty) {
      // Priority 4: Exact numbers to finish if pieces are on home stretch
      List<int> finishRolls = [];
      for (var p in player.pieces) {
        if (p.position >= 51 && p.position < 56) {
          finishRolls.add(56 - p.position);
        }
      }
      if (finishRolls.isNotEmpty) {
        return finishRolls;
      }

      // If no tactical moves exist, give the winner high rolls to boost baseline pacing.
      // 4 is included but 5 and 6 are weighted more heavily (no hard exclusions).
      if (isWinner) {
        return [4, 5, 5, 6, 6, 6];
      }
    }

    return valid;
  }

  List<int> _getUnfavorableRolls(GameState state, Player player) {
    List<int> unfavorable = [];
    for (int r = 1; r <= 6; r++) {
      if (!_isFavorable(state, player, r)) {
        // Sabotage: exclude finishing rolls so they are less likely to finish under sabotage
        bool isFinishing = false;
        for (var p in player.pieces) {
          if (!p.isFinished && !p.isHome && p.position + r == 56) {
            isFinishing = true;
            break;
          }
        }
        if (!isFinishing) {
          unfavorable.add(r);
        }
      }
    }
    if (unfavorable.isEmpty) {
      unfavorable = [1, 2, 3, 4, 5, 6];
    }
    return unfavorable;
  }

  bool _isFavorable(GameState state, Player player, int roll) {
    for (var piece in player.pieces) {
      if (piece.isHome && roll == 6) return true;
      if (piece.isFinished) continue;

      int nextPos = piece.position + roll;
      if (nextPos > 56) continue;

      // Check if captures an opponent piece
      if (_capturesOpponent(state, player, piece, roll)) return true;

      // Check if lands on safe square
      if (nextPos >= 0 && nextPos <= 50) {
        int globalPos = _toGlobal(player.color, nextPos);
        if (BoardConstants.safeSquares.contains(globalPos)) {
          // For the winner, ignore low rolls that just land on safe squares
          // to maintain high pacing, unless they are near the end.
          // This is probabilistic so it's not a hard, detectable rule.
          if (state.designatedWinnerId == player.id && roll < 4) {
            if (_random.nextDouble() < config.ignoreLowSafeSquareProbability) {
              continue;
            }
          }
          return true;
        }
      }
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

  // ---------------------------------------------------------------------------
  // Board position helpers
  // ---------------------------------------------------------------------------

  bool _capturesOpponent(
      GameState state, Player player, Piece piece, int roll) {
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

  bool _isDangerZone(
      GameState state, Player player, Piece piece, int roll) {
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
      case PlayerColor.red:
        offset = 0;
        break;
      case PlayerColor.green:
        offset = 13;
        break;
      case PlayerColor.blue:
        offset = 26;
        break;
      case PlayerColor.yellow:
        offset = 39;
        break;
    }
    return (offset + pos) % 52;
  }

  // ---------------------------------------------------------------------------
  // Bias probability
  // ---------------------------------------------------------------------------

  double _getBiasProbability(
      GameState state, bool isWinner, bool isHardMode) {
    if (state.designatedWinnerId == null) return 0.0;

    // Blowout prevention check
    var winner = state.players
        .firstWhere((p) => p.id == state.designatedWinnerId!);
    double winnerAvg = _progressScore(winner);
    bool isBlowout = true;
    
    double maxOpponentAvg = 0.0;
    for (var p in state.players) {
      if (p.id != state.designatedWinnerId) {
        double avg = _progressScore(p);
        if (avg > maxOpponentAvg) maxOpponentAvg = avg;
        if (winnerAvg - avg < config.blowoutGapThreshold) {
          isBlowout = false;
        }
      }
    }

    if (isBlowout) return config.blowoutBias;

    double baseProb;
    if (isHardMode) {
      baseProb = isWinner ? config.hardWinnerBias : config.hardLoserBias;
    } else {
      if (isWinner) {
        double deficit = maxOpponentAvg - winnerAvg;
        if (deficit > 0) {
          // Steeper deficit-to-bias curve: reaches max bias at deficit of 0.5 (instead of 1.0)
          double t = deficit / 0.5;
          if (t > 1.0) t = 1.0;
          baseProb = config.normalWinnerBias + t * (config.hardWinnerBias - config.normalWinnerBias);
          
          // Probabilistic Priority 6s for trailing winner with pieces at home
          if (winner.pieces.any((p) => p.isHome)) {
            if (baseProb < config.prioritySixTrailingBias) {
              baseProb = config.prioritySixTrailingBias;
            }
          }
        } else {
          // Winner is ahead in average score. 
          // If they have NO pieces on the board, they desperately need a 6 to not waste turns.
          bool hasOnBoard = winner.pieces.any((p) => !p.isHome && !p.isFinished);
          if (!hasOnBoard && winner.pieces.any((p) => p.isHome)) {
             baseProb = config.prioritySixTrailingBias;
          } else {
             baseProb = config.normalWinnerBias;
          }
        }
      } else {
        baseProb = config.normalLoserBias;
      }
    }

    // Dampen bias for non-winners who have pieces in the final stretch (51-55).
    // Use the flat cap to ensure Hard Mode doesn't skew near-finish rolls too heavily.
    if (!isWinner) {
      final currentPlayer = state.players[state.currentPlayerIndex];
      bool nearFinish = currentPlayer.pieces.any(
          (p) => !p.isFinished && !p.isHome && p.position >= 51 && p.position <= 55);
      if (nearFinish && baseProb > config.nearFinishLoserBiasCap) {
        baseProb = config.nearFinishLoserBiasCap;
      }
    }

    return baseProb;
  }

  // ---------------------------------------------------------------------------
  // Natural moments & streaks
  // ---------------------------------------------------------------------------

  bool _isNaturalMoment(GameState state, int playerId) {
    // Early game
    if ((_turnCounts[playerId] ?? 1) <= config.earlyGameTurnCount) {
      return true;
    }

    if (state.designatedWinnerId != null) {
      var winner = state.players
          .firstWhere((p) => p.id == state.designatedWinnerId);
      // Winner all in home stretch (but disable naturalizer if any
      // opponent is close)
      if (winner.pieces
          .every((p) => p.position >= 51 || p.isFinished)) {
        bool opponentClose = false;
        for (var p in state.players) {
          if (p.id == state.designatedWinnerId) continue;
          if (p.pieces.any((piece) => piece.position >= 45)) {
            opponentClose = true;
          }
        }
        if (!opponentClose) return true;
      }
    }

    return false;
  }

  void _trackUnfavorableStreak(
      GameState state, Player currentPlayer, bool isWinner, int roll) {
    if (!isWinner && _isUnfavorable(state, currentPlayer, roll)) {
      _unfavorableStreaks[currentPlayer.id] =
          (_unfavorableStreaks[currentPlayer.id] ?? 0) + 1;
      if (_unfavorableStreaks[currentPlayer.id]! >=
          config.unfavorableStreakThreshold) {
        _graceTurns[currentPlayer.id] =
            _random.nextInt(config.graceTurnMax - config.graceTurnMin + 1) +
                config.graceTurnMin;
        _unfavorableStreaks[currentPlayer.id] = 0;
      }
    } else {
      _unfavorableStreaks[currentPlayer.id] = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Random helpers
  // ---------------------------------------------------------------------------

  int _pureRandom() => _random.nextInt(6) + 1;

  int _safeRoll() => _random.nextInt(5) + 1;

  // ---------------------------------------------------------------------------
  // Debug logging (Item 6) — compiles out in release builds
  // ---------------------------------------------------------------------------

  void _emitDebug(
      int playerId, int roll, String layer, String reason, bool isWinner) {
    assert(() {
      debugHook?.call(RollDebugInfo(
        playerId: playerId,
        roll: roll,
        layerName: layer,
        reason: reason,
        isWinner: isWinner,
      ));
      return true;
    }());
  }

  // ---------------------------------------------------------------------------
  // Serialization (Save & Resume)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'turnCounts': _turnCounts.map((k, v) => MapEntry(k.toString(), v)),
    'unfavorableStreaks': _unfavorableStreaks.map((k, v) => MapEntry(k.toString(), v)),
    'graceTurns': _graceTurns.map((k, v) => MapEntry(k.toString(), v)),
    'finalPieceStuckTurns': _finalPieceStuckTurns.map((k, v) => MapEntry(k.toString(), v)),
    'isHardMode': _isHardMode,
  };

  void loadFromJson(Map<String, dynamic> json) {
    if (json['turnCounts'] != null) {
      _turnCounts.clear();
      (json['turnCounts'] as Map).forEach((k, v) {
        _turnCounts[int.parse(k.toString())] = v as int;
      });
    }
    if (json['unfavorableStreaks'] != null) {
      _unfavorableStreaks.clear();
      (json['unfavorableStreaks'] as Map).forEach((k, v) {
        _unfavorableStreaks[int.parse(k.toString())] = v as int;
      });
    }
    if (json['graceTurns'] != null) {
      _graceTurns.clear();
      (json['graceTurns'] as Map).forEach((k, v) {
        _graceTurns[int.parse(k.toString())] = v as int;
      });
    }
    if (json['finalPieceStuckTurns'] != null) {
      _finalPieceStuckTurns.clear();
      (json['finalPieceStuckTurns'] as Map).forEach((k, v) {
        _finalPieceStuckTurns[int.parse(k.toString())] = v as int;
      });
    }
    if (json['isHardMode'] != null) {
      _isHardMode = json['isHardMode'] as bool;
    }
  }
}

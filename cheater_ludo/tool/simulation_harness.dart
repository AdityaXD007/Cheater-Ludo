// Simulation Harness for RiggedDiceEngine
// Pure Dart, no Flutter dependencies. Run with:
//   dart run tool/simulation_harness.dart
//
// Simulates 10,000 4-player games (rigged + unrigged control) and reports
// statistical metrics to verify the rigging system's correctness and
// undetectability.

import 'dart:math';
import '../lib/game/engine/rigged_dice_engine.dart';
import '../lib/game/engine/rigging_config.dart';
import '../lib/game/engine/game_state.dart';
import '../lib/game/engine/player.dart';
import '../lib/game/engine/board_constants.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const int kTotalGames = 10000;
const int kMaxTurnsPerGame = 2000; // safety cap to prevent infinite games
const int kSeed = 42;

// ---------------------------------------------------------------------------
// Lightweight game simulator (no Flame, no UI)
// ---------------------------------------------------------------------------

class SimulatedGame {
  final GameState state;
  final RiggedDiceEngine engine;
  final Random _moveRng;

  // Stats
  int totalTurns = 0;
  final Map<int, List<int>> rollsByPlayer = {};
  
  // Splitting near-finish metrics
  final Map<int, List<Map<String, dynamic>>> nearFinishRolls1to3 = {};
  final Map<int, List<Map<String, dynamic>>> nearFinishRolls4 = {};
  
  final Map<int, int> consecutiveStuckTurns = {};
  final Map<int, List<int>> totalStuckSpans = {};

  bool _isHardMode = false;

  SimulatedGame({
    required this.state,
    required this.engine,
    required Random moveRng,
  }) : _moveRng = moveRng {
    for (var p in state.players) {
      rollsByPlayer[p.id] = [];
      nearFinishRolls1to3[p.id] = [];
      nearFinishRolls4[p.id] = [];
      consecutiveStuckTurns[p.id] = 0;
      totalStuckSpans[p.id] = [];
    }
  }

  String _currentTier() {
    if (state.designatedWinnerId == null) return 'Normal';
    
    var winner = state.players.firstWhere((p) => p.id == state.designatedWinnerId);
    double winnerScore = _progressScore(winner);
    
    // Blowout check
    bool isBlowout = true;
    for (var p in state.players) {
      if (p.id != state.designatedWinnerId) {
        if (winnerScore - _progressScore(p) < engine.config.blowoutGapThreshold) {
          isBlowout = false;
          break;
        }
      }
    }
    if (isBlowout) return 'Blowout';
    
    // Hard mode hysteresis duplication
    double maxGap = 0.0;
    for (var p in state.players) {
      if (p.id == state.designatedWinnerId) continue;
      double gap = _progressScore(p) - winnerScore;
      if (gap > maxGap) maxGap = gap;
    }

    if (!_isHardMode && maxGap >= engine.config.hardModeEnterGap) {
      _isHardMode = true;
    } else if (_isHardMode && maxGap < engine.config.hardModeExitGap) {
      _isHardMode = false;
    }

    return _isHardMode ? 'Hard' : 'Normal';
  }

  double _progressScore(Player player) {
    int sum = 0;
    for (var p in player.pieces) {
      if (p.isFinished) sum += 56;
      else if (p.position > 0) sum += p.position;
    }
    return sum / 4.0;
  }

  int? runToCompletion() {
    state.phase = GamePhase.playing;

    while (state.phase == GamePhase.playing && totalTurns < kMaxTurnsPerGame) {
      _playTurn();
    }
    
    // Conclude any ongoing stuck spans
    for (var p in state.players) {
      if (consecutiveStuckTurns[p.id]! > 0) {
        totalStuckSpans[p.id]!.add(consecutiveStuckTurns[p.id]!);
        consecutiveStuckTurns[p.id] = 0;
      }
    }

    if (state.phase == GamePhase.finished) {
      return state.players.firstWhere((p) => p.hasWon).id;
    }
    return null; // timed out
  }

  void _playTurn() {
    final player = state.players[state.currentPlayerIndex];
    bool extraTurn = false;
    String tier = _currentTier();

    int finishedCount = player.pieces.where((p) => p.isFinished).length;
    var nearFinishPieces = player.pieces.where(
        (p) => !p.isFinished && !p.isHome && p.position >= 51 && p.position <= 55).toList();

    // Roll
    state.consecutiveSixes = 0;
    int roll = engine.roll(state);
    totalTurns++;

    rollsByPlayer[player.id]!.add(roll);
    
    if (nearFinishPieces.isNotEmpty) {
      if (finishedCount == 3) {
        nearFinishRolls4[player.id]!.add({'roll': roll, 'tier': tier});
      } else {
        nearFinishRolls1to3[player.id]!.add({'roll': roll, 'tier': tier});
      }
    }

    state.lastRoll = roll;
    player.lastRoll = roll;
    if (roll == 6) state.consecutiveSixes++;

    // Find valid pieces for this roll
    List<int> validPieceIndices = [];
    for (int i = 0; i < player.pieces.length; i++) {
      var p = player.pieces[i];
      if (_isValidMove(p, roll)) {
        validPieceIndices.add(i);
      }
    }

    // Check stuck metric for 4th piece
    if (finishedCount == 3 && nearFinishPieces.isNotEmpty) {
      if (validPieceIndices.isEmpty) {
        // Player couldn't move because they rolled too high (overshoot fallback)
        consecutiveStuckTurns[player.id] = consecutiveStuckTurns[player.id]! + 1;
      } else {
        // They moved something, so the stuck span ended
        if (consecutiveStuckTurns[player.id]! > 0) {
          totalStuckSpans[player.id]!.add(consecutiveStuckTurns[player.id]!);
          consecutiveStuckTurns[player.id] = 0;
        }
      }
    }

    if (validPieceIndices.isEmpty) {
      _nextPlayer();
      return;
    }

    // Pick a piece to move (random selection for simplicity)
    int chosenIdx = validPieceIndices[_moveRng.nextInt(validPieceIndices.length)];
    var piece = player.pieces[chosenIdx];

    // Execute move
    if (piece.isHome && roll == 6) {
      piece.position = 0;
      extraTurn = true;
    } else {
      int oldPos = piece.position;
      piece.position = oldPos + roll;

      // Check captures
      if (piece.position >= 0 && piece.position <= 50) {
        _checkCaptures(player, piece);
      }

      if (roll == 6) extraTurn = true;
    }

    // Check win
    if (player.hasWon) {
      state.phase = GamePhase.finished;
      return;
    }

    if (extraTurn) return; // goes again

    _nextPlayer();
  }

  bool _isValidMove(dynamic piece, int roll) {
    if (piece.isFinished) return false;
    if (piece.isHome && roll != 6) return false;
    if (piece.isHome && roll == 6) return true;
    if (piece.position + roll > 56) return false;
    return true;
  }

  void _checkCaptures(Player currentPlayer, dynamic piece) {
    if (piece.position > 50 || piece.position < 0) return;

    int globalPos = _toGlobal(currentPlayer.color, piece.position);
    if (BoardConstants.safeSquares.contains(globalPos)) return;

    for (var other in state.players) {
      if (other.id == currentPlayer.id) continue;
      for (var op in other.pieces) {
        if (op.position >= 0 && op.position <= 50) {
          int opGlobal = _toGlobal(other.color, op.position);
          if (opGlobal == globalPos) op.position = -1; // send home
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

  void _nextPlayer() {
    state.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.players.length;
    int safety = 0;
    while (state.players[state.currentPlayerIndex].hasWon && safety < 8) {
      state.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.players.length;
      safety++;
    }
  }
}

// ---------------------------------------------------------------------------
// Batch runner
// ---------------------------------------------------------------------------

class BatchResult {
  int totalGames = 0;
  int winnerWins = 0;
  int timedOut = 0;
  int totalTurns = 0;
  
  final Map<int, List<double>> avgRollByPlayer = {0: [], 1: [], 2: [], 3: []};
  
  // Tiered stats for pieces 1-3
  final Map<String, Map<int, int>> nearFinish1to3 = {
    'Normal': {1:0, 2:0, 3:0, 4:0, 5:0, 6:0},
    'Hard': {1:0, 2:0, 3:0, 4:0, 5:0, 6:0},
    'Blowout': {1:0, 2:0, 3:0, 4:0, 5:0, 6:0},
  };
  final Map<String, int> nearFinish1to3Totals = {'Normal': 0, 'Hard': 0, 'Blowout': 0};
  
  // Stats for piece 4
  final Map<int, int> nearFinish4 = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0};
  int nearFinish4Total = 0;
  int nearFinish4Encounters = 0; // how many times this state arose
  
  List<int> stuckSpans = [];

  // Escape paths
  int captureValveCount = 0;
  int dynamicCapTimeoutCount = 0;
  int finalBypassCount = 0;
}

BatchResult runBatch({
  required bool rigged,
  required int numGames,
  required int baseSeed,
}) {
  final result = BatchResult();

  for (int g = 0; g < numGames; g++) {
    final seed = baseSeed + g;

    final players = [
      Player(id: 0, name: 'P0_Red', type: PlayerType.human, color: PlayerColor.red),
      Player(id: 1, name: 'P1_Green', type: PlayerType.ai, color: PlayerColor.green),
      Player(id: 2, name: 'P2_Blue', type: PlayerType.ai, color: PlayerColor.blue),
      Player(id: 3, name: 'P3_Yellow', type: PlayerType.ai, color: PlayerColor.yellow),
    ];

    final state = GameState(
      players: players,
      currentPlayerIndex: 0,
      isRigged: rigged,
      designatedWinnerId: rigged ? 0 : null,
    );

    final engine = RiggedDiceEngine(
      seed: seed,
      debugHook: (info) {
        if (info.layerName == 'L6_CaptureValve') result.captureValveCount++;
        else if (info.layerName == 'L6_CapBypass_Finish' || info.layerName == 'L6_LegalAdvance' || info.layerName == 'L6_GraceFinish') result.dynamicCapTimeoutCount++;
        else if (info.layerName == 'L6_CapBypass') result.finalBypassCount++;
      },
    );
    final moveRng = Random(seed + 100000);

    final sim = SimulatedGame(
      state: state,
      engine: engine,
      moveRng: moveRng,
    );

    final winnerId = sim.runToCompletion();

    result.totalGames++;
    result.totalTurns += sim.totalTurns;

    if (winnerId == null) {
      result.timedOut++;
    } else if (winnerId == 0) {
      result.winnerWins++;
    }

    // Collect non-winner roll averages
    for (int pid = 0; pid < 4; pid++) {
      final rolls = sim.rollsByPlayer[pid]!;
      if (rolls.isNotEmpty) {
        double avg = rolls.reduce((a, b) => a + b) / rolls.length;
        result.avgRollByPlayer[pid]!.add(avg);
      }
    }

    // Collect near-finish distribution for pieces 1-3
    for (int pid = 1; pid < 4; pid++) {
      for (var entry in sim.nearFinishRolls1to3[pid]!) {
        String tier = entry['tier'];
        int roll = entry['roll'];
        result.nearFinish1to3[tier]![roll] = (result.nearFinish1to3[tier]![roll] ?? 0) + 1;
        result.nearFinish1to3Totals[tier] = (result.nearFinish1to3Totals[tier] ?? 0) + 1;
      }
    }

    // Collect near-finish distribution for 4th piece
    for (int pid = 1; pid < 4; pid++) {
      if (sim.nearFinishRolls4[pid]!.isNotEmpty) result.nearFinish4Encounters++;
      for (var entry in sim.nearFinishRolls4[pid]!) {
        int roll = entry['roll'];
        result.nearFinish4[roll] = (result.nearFinish4[roll] ?? 0) + 1;
        result.nearFinish4Total++;
      }
    }
    
    // Collect stuck spans
    for (int pid = 1; pid < 4; pid++) {
      result.stuckSpans.addAll(sim.totalStuckSpans[pid]!);
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

void printReport(String label, BatchResult r) {
  print('');
  print('=' * 70);
  print('  $label');
  print('=' * 70);
  print('');

  final winRate = r.totalGames > 0
      ? (r.winnerWins / r.totalGames * 100).toStringAsFixed(2)
      : 'N/A';
  final avgGameLen = r.totalGames > 0
      ? (r.totalTurns / r.totalGames).toStringAsFixed(1)
      : 'N/A';

  print('  Games played:        ${r.totalGames}');
  print('  Timed out:           ${r.timedOut}');
  print('  Designated winner    Player 0 (Red)');
  print('  Winner win rate:     $winRate%');
  print('  Avg game length:     $avgGameLen turns');
  print('');

  // Near-finish distribution for non-winners (Pieces 1-3)
  print('  Non-Winner Near-Finish Rolls (Pieces 1-3):');
  print('  ${'Roll'.padRight(6)} ${'Normal'.padRight(12)} ${'Hard'.padRight(12)} ${'Blowout'.padRight(12)} ${'Expected'.padRight(10)}');
  print('  ${'-' * 54}');
  for (int roll = 1; roll <= 6; roll++) {
    String pNormal = _pct(r.nearFinish1to3['Normal']![roll], r.nearFinish1to3Totals['Normal']);
    String pHard = _pct(r.nearFinish1to3['Hard']![roll], r.nearFinish1to3Totals['Hard']);
    String pBlowout = _pct(r.nearFinish1to3['Blowout']![roll], r.nearFinish1to3Totals['Blowout']);
    print('  ${roll.toString().padRight(6)} ${pNormal.padRight(12)} ${pHard.padRight(12)} ${pBlowout.padRight(12)} 16.7%');
  }
  print('  Total Normal:  ${r.nearFinish1to3Totals['Normal']}');
  print('  Total Hard:    ${r.nearFinish1to3Totals['Hard']}');
  print('  Total Blowout: ${r.nearFinish1to3Totals['Blowout']}');
  print('');
  
  // Near-finish distribution for 4th Piece
  print('  Non-Winner Near-Finish Rolls (4th Piece / Hard Block):');
  if (r.nearFinish4Total == 0) {
    print('  (No 4th-piece near-finish data available)');
  } else {
    print('  Encounters per game: ${(r.nearFinish4Encounters / r.totalGames).toStringAsFixed(3)} (this specific state is very rare)');
    print('  ${'Roll'.padRight(8)} ${'Count'.padRight(10)} ${'Pct'.padRight(10)}');
    print('  ${'-' * 30}');
    for (int roll = 1; roll <= 6; roll++) {
      int count = r.nearFinish4[roll] ?? 0;
      double pct = count / r.nearFinish4Total * 100;
      print('  ${roll.toString().padRight(8)} ${count.toString().padRight(10)} ${pct.toStringAsFixed(1).padRight(10)}');
    }
    print('  Total samples: ${r.nearFinish4Total}');
  }
  print('');
  
  // Stuck metrics
  if (r.stuckSpans.isNotEmpty) {
    double avgStuck = r.stuckSpans.reduce((a, b) => a + b) / r.stuckSpans.length;
    int maxStuck = r.stuckSpans.reduce(max);
    print('  4th-Piece Stuck Turns (Consecutive Overshoots):');
    print('  Average: ${avgStuck.toStringAsFixed(2)} turns');
    print('  Max:     $maxStuck turns');
    
    print('');
    print('  Escape Path Frequency:');
    print('  Capture Valve:          ${r.captureValveCount}');
    print('  Dynamic Cap Timeout:    ${r.dynamicCapTimeoutCount}');
    print('  Final Bypass (Pos 55):  ${r.finalBypassCount}');
    print('');
  }
}

String _pct(int? val, int? total) {
  if (val == null || total == null || total == 0) return '0.0%';
  return '${(val / total * 100).toStringAsFixed(1)}%';
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final sw = Stopwatch()..start();

  print('Running $kTotalGames rigged games...');
  final rigged = runBatch(rigged: true, numGames: kTotalGames, baseSeed: kSeed);

  print('Running $kTotalGames unrigged control games...');
  final control = runBatch(rigged: false, numGames: kTotalGames, baseSeed: kSeed + 500000);

  sw.stop();

  printReport('RIGGED GAMES (Player 0 = Designated Winner)', rigged);
  printReport('UNRIGGED CONTROL GAMES (No Rigging)', control);

  print('');
  print('Completed in ${sw.elapsedMilliseconds}ms');
}

import 'dart:io';
import 'package:cheater_ludo/game/engine/rigged_dice_engine.dart';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';
import 'package:cheater_ludo/game/ai/ai_player.dart';

void main() {
  int totalGames = 10000; // run 10,000 games
  int winnerWins = 0;
  
  int totalCapTimeouts = 0;
  int realCapTimeouts = 0;
  int postWinCapTimeouts = 0;
  Map<int, int> timeoutsPerGame = {};
  Map<String, int> globalLayerCounts = {};
  
  int totalFirstReach51 = 0;
  int sumWinnerUnfinishedAt51 = 0;

  int totalBufferMeasurements = 0;
  int sumBufferTurns = 0;
  Map<int, int> bufferDistribution = {};
  Map<int, int> bufferCapTimeouts = {}; // Count of cap timeouts in games with buffer of X
  Map<int, int> sumWinnerUnfinishedByBuffer = {};
  Map<int, int> countWinnerUnfinishedByBuffer = {};
  int totalGamesWithReached51 = 0;
  
  for (int i = 0; i < totalGames; i++) {
    var players = [
      Player(id: 0, name: 'P0', type: PlayerType.ai, color: PlayerColor.red),
      Player(id: 1, name: 'P1', type: PlayerType.ai, color: PlayerColor.blue),
      Player(id: 2, name: 'P2', type: PlayerType.ai, color: PlayerColor.green),
      Player(id: 3, name: 'P3', type: PlayerType.ai, color: PlayerColor.yellow),
    ];
    var state = GameState(players: players, designatedWinnerId: 0, isRigged: true);
    
    int capTimeoutsThisGame = 0;
    Map<int, int> hit51TurnCount = {};
    Map<int, bool> blockedFinishRecorded = {};
    Map<int, int> playerTurnCount = {0: 0, 1: 0, 2: 0, 3: 0};
    Map<int, int> winnerUnfinishedAt51 = {};
    
    // We will keep track of buffers recorded in this game: Map<playerId, bufferVal>
    Map<int, int> buffersThisGame = {};
    
    var engine = RiggedDiceEngine(debugHook: (info) {
      if (info.layerName == 'L6_CapBypass_Finish' || info.layerName == 'L6_LegalAdvance' || info.layerName == 'L6_CaptureValve' || info.layerName == 'L6_GraceFinish' || info.layerName == 'L6_EdgeCase_Finish') {
        capTimeoutsThisGame++;
        totalCapTimeouts++;
        
        if (state.players[0].hasWon) {
          postWinCapTimeouts++;
        } else {
          realCapTimeouts++;
        }
        
        // Count specific layer firings in global state
        globalLayerCounts[info.layerName] = (globalLayerCounts[info.layerName] ?? 0) + 1;
      }
      if (info.layerName == 'L6_BlockFinish') {
        if (hit51TurnCount.containsKey(info.playerId) && !(blockedFinishRecorded[info.playerId] ?? false)) {
           blockedFinishRecorded[info.playerId] = true;
           int buffer = playerTurnCount[info.playerId]! - hit51TurnCount[info.playerId]!;
           sumBufferTurns += buffer;
           totalBufferMeasurements++;
           bufferDistribution[buffer] = (bufferDistribution[buffer] ?? 0) + 1;
           buffersThisGame[info.playerId] = buffer;
           
           int unfinished = winnerUnfinishedAt51[info.playerId]!;
           sumWinnerUnfinishedByBuffer[buffer] = (sumWinnerUnfinishedByBuffer[buffer] ?? 0) + unfinished;
           countWinnerUnfinishedByBuffer[buffer] = (countWinnerUnfinishedByBuffer[buffer] ?? 0) + 1;
        }
      }
    });
    
    Map<int, bool> hasReached51 = {1: false, 2: false, 3: false};
    
    int turnCount = 0;
    while(turnCount < 10000) {
      // Run until winner finishes AND all players who reached 51 have recorded a block (no infinite default)
      bool winnerDone = state.players[0].hasWon;
      bool nonWinnersDone = true;
      for (var p in state.players) {
        if (p.id != 0) {
          if (hasReached51[p.id]! && !(blockedFinishRecorded[p.id] ?? false)) {
            nonWinnersDone = false;
          }
        }
      }
      
      if (winnerDone && nonWinnersDone) {
        break;
      }

      turnCount++;
      var cp = state.players[state.currentPlayerIndex];
      playerTurnCount[cp.id] = (playerTurnCount[cp.id] ?? 0) + 1;
      
      // Check 51 reach before roll
      if (cp.id != 0 && !hasReached51[cp.id]!) {
        int finished = cp.pieces.where((p) => p.isFinished).length;
        if (finished == 3) {
          var last = cp.pieces.firstWhere((p) => !p.isFinished);
          if (last.position >= 51) {
            hasReached51[cp.id] = true;
            hit51TurnCount[cp.id] = playerTurnCount[cp.id]!;
            var winner = state.players.firstWhere((p) => p.id == 0);
            int winnerUnfinished = 4 - winner.pieces.where((p) => p.isFinished).length;
            winnerUnfinishedAt51[cp.id] = winnerUnfinished;
            totalFirstReach51++;
            sumWinnerUnfinishedAt51 += winnerUnfinished;
          }
        }
      }
      
      int roll = engine.roll(state);
      var ai = AiPlayer(playerId: cp.id, difficulty: AiDifficulty.hard);
      int? moveId = ai.selectPiece(roll, state);
      
      if (moveId != null) {
        var move = cp.pieces.firstWhere((p) => p.id == moveId);
        if (move.position == -1 && roll == 6) {
          move.position = 0;
        } else if (move.position >= 0) {
          move.position += roll;
        }
      }
      
      if (cp.hasWon) {
        if (cp.id == 0 && state.phase != GamePhase.finished) {
          winnerWins++;
        }
        state.phase = GamePhase.finished;
        
        // Pass turn to next player who hasn't won
        do {
          state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 4;
        } while (state.players[state.currentPlayerIndex].hasWon);
        state.consecutiveSixes = 0;
      } else {
        if (roll != 6 || state.consecutiveSixes >= 2) {
          do {
            state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 4;
          } while (state.players[state.currentPlayerIndex].hasWon);
          state.consecutiveSixes = 0;
        } else {
          state.consecutiveSixes++;
        }
      }
    }
    
    if (turnCount >= 10000) {
      print('Game $i hit 10000 turns timeout!');
    }
    
    if (hasReached51.values.any((val) => val)) {
      totalGamesWithReached51++;
    }
    
    // After game ends, check if this game had a cap timeout and record it for the buffers
    if (capTimeoutsThisGame > 0) {
      for (var bufferVal in buffersThisGame.values) {
        bufferCapTimeouts[bufferVal] = (bufferCapTimeouts[bufferVal] ?? 0) + 1;
      }
    }
    
    timeoutsPerGame[capTimeoutsThisGame] = (timeoutsPerGame[capTimeoutsThisGame] ?? 0) + 1;
  }
  
  print('Total Games: $totalGames');
  print('Win Rate: ${(winnerWins / totalGames * 100).toStringAsFixed(2)}%');
  print('Total Cap Timeouts: $totalCapTimeouts (Real/Active: $realCapTimeouts, Post-Win Run-Out: $postWinCapTimeouts)');
  print('Layer count breakdown: $globalLayerCounts');
  print('Timeouts per game distribution:');
  var sortedKeys = timeoutsPerGame.keys.toList()..sort();
  for (var k in sortedKeys) {
    print('  $k timeouts: ${timeoutsPerGame[k]} games');
  }
  
  if (totalFirstReach51 > 0) {
    print('Avg Winner Unfinished when Non-Winner 4th piece hits 51: ${(sumWinnerUnfinishedAt51 / totalFirstReach51).toStringAsFixed(2)}');
  }

  if (totalBufferMeasurements > 0) {
    print('Total Reached 51 Instances with Buffer: $totalBufferMeasurements (in $totalGamesWithReached51 games)');
    print('Avg Natural Travel-Time Buffer: ${(sumBufferTurns / totalBufferMeasurements).toStringAsFixed(2)} player turns');
    print('Buffer Distribution and Cap-Timeout Correlation:');
    var sortedBufferKeys = bufferDistribution.keys.toList()..sort();
    for (var k in sortedBufferKeys) {
      int count = bufferDistribution[k]!;
      double pct = count / totalBufferMeasurements * 100;
      int timeouts = bufferCapTimeouts[k] ?? 0;
      double timeoutRate = count > 0 ? (timeouts / count * 100) : 0.0;
      
      double avgUnfinished = countWinnerUnfinishedByBuffer[k] != null && countWinnerUnfinishedByBuffer[k]! > 0
          ? sumWinnerUnfinishedByBuffer[k]! / countWinnerUnfinishedByBuffer[k]!
          : 0.0;
          
      print('  $k turns: $count occurrences (${pct.toStringAsFixed(2)}%) | Cap-Timeout Rate: ${timeoutRate.toStringAsFixed(2)}% ($timeouts/$count) | Avg Winner Unfinished at 51: ${avgUnfinished.toStringAsFixed(2)}');
    }
  }
}

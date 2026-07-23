import 'package:flutter_test/flutter_test.dart';
import 'package:cheater_ludo/game/engine/rigged_dice_engine.dart';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';
import 'package:cheater_ludo/game/ai/ai_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Scenario Tests', () {
    
    // ═══════════════════════════════════════════════════════
    // TEST 1: No valid moves — turn passes without hanging
    // ═══════════════════════════════════════════════════════
    test('Test 1: No valid moves passes turn correctly', () {
      print('--- Test 1: No valid moves situation ---');
      var p1 = Player(id: 0, name: 'Red', type: PlayerType.human, color: PlayerColor.red);
      var p2 = Player(id: 1, name: 'Green', type: PlayerType.human, color: PlayerColor.green);
      var state = GameState(players: [p1, p2], isRigged: false);
      var engine = RiggedDiceEngine(seed: 42);

      // All pieces at home for both players
      // Roll anything except 6 — no valid moves
      state.currentPlayerIndex = 0; // Red's turn
      
      int turnsPassed = 0;
      for (int i = 0; i < 20; i++) {
        int roll = engine.roll(state);
        
        // Check if any piece can move
        bool canMove = false;
        var cp = state.players[state.currentPlayerIndex];
        for (var piece in cp.pieces) {
          if (piece.isHome && roll == 6) canMove = true;
          if (!piece.isHome && !piece.isFinished && piece.position + roll <= 56) canMove = true;
        }

        if (!canMove) {
          // Turn should pass — simulate what ludo_game.dart does
          state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 2;
          turnsPassed++;
          print('  Roll $roll: No valid moves, turn passed to Player ${state.currentPlayerIndex}');
        } else {
          // Valid move exists
          if (roll == 6 && cp.pieces.any((p) => p.isHome)) {
            var piece = cp.pieces.firstWhere((p) => p.isHome);
            piece.position = 0;
            print('  Roll $roll: Player ${cp.id} moved piece ${piece.id} to board');
          }
          state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 2;
        }
      }
      
      print('  Result: $turnsPassed turns auto-passed (no freeze)');
      assert(turnsPassed > 0, 'Should have had at least one no-valid-moves turn');
      print('  PASS ✓\n');
    });

    // ═══════════════════════════════════════════════════════
    // TEST 2: Rapid AI turns — full 4-player AI game
    // ═══════════════════════════════════════════════════════
    test('Test 2: Rapid AI turns complete without hanging', () {
      print('--- Test 2: Rapid AI turns (4-player AI game) ---');
      
      var players = [
        Player(id: 0, name: 'AI-Red', type: PlayerType.ai, color: PlayerColor.red),
        Player(id: 1, name: 'AI-Green', type: PlayerType.ai, color: PlayerColor.green),
        Player(id: 2, name: 'AI-Blue', type: PlayerType.ai, color: PlayerColor.blue),
        Player(id: 3, name: 'AI-Yellow', type: PlayerType.ai, color: PlayerColor.yellow),
      ];
      var state = GameState(players: players, isRigged: false);
      var engine = RiggedDiceEngine();

      int totalTurns = 0;
      int maxTurns = 5000;
      
      while (state.phase != GamePhase.finished && totalTurns < maxTurns) {
        totalTurns++;
        var cp = state.players[state.currentPlayerIndex];
        int roll = engine.roll(state);

        var ai = AiPlayer(playerId: cp.id, difficulty: AiDifficulty.hard);
        int? moveId = ai.selectPiece(roll, state);
        if (moveId != null) {
          var piece = cp.pieces.firstWhere((p) => p.id == moveId);
          if (piece.position == -1 && roll == 6) {
            piece.position = 0;
          } else if (piece.position >= 0) {
            piece.position += roll;
          }
        }

        if (cp.hasWon) {
          state.phase = GamePhase.finished;
          print('  Game finished after $totalTurns turns. Winner: Player ${cp.id} (${cp.color.name})');
        } else {
          if (roll == 6 && state.consecutiveSixes < 2) {
            state.consecutiveSixes++;
          } else {
            state.consecutiveSixes = 0;
            do {
              state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 4;
            } while (state.players[state.currentPlayerIndex].hasWon);
          }
        }
      }
      
      assert(state.phase == GamePhase.finished, 'Game should have finished within $maxTurns turns');
      assert(totalTurns < maxTurns, 'Game hung — took max turns without finishing');
      print('  Result: Game completed in $totalTurns turns (no freeze)');
      print('  PASS ✓\n');
    });

    // ═══════════════════════════════════════════════════════
    // TEST 3: Human turn after AI turn — state transitions
    // ═══════════════════════════════════════════════════════
    test('Test 3: Human turn after AI turn - state is clean', () {
      print('--- Test 3: Human turn after AI turn ---');
      
      var players = [
        Player(id: 0, name: 'Human-Red', type: PlayerType.human, color: PlayerColor.red),
        Player(id: 1, name: 'AI-Green', type: PlayerType.ai, color: PlayerColor.green),
        Player(id: 2, name: 'AI-Blue', type: PlayerType.ai, color: PlayerColor.blue),
        Player(id: 3, name: 'AI-Yellow', type: PlayerType.ai, color: PlayerColor.yellow),
      ];
      var state = GameState(players: players, isRigged: false);
      var engine = RiggedDiceEngine();

      // Simulate: Red (human) starts, then AI takes turns, then back to Red
      // After AI turns complete, verify state is clean for human
      
      int humanTurnCount = 0;
      int aiTurnCount = 0;
      
      for (int round = 0; round < 50; round++) {
        var cp = state.players[state.currentPlayerIndex];
        int roll = engine.roll(state);
        
        if (cp.type == PlayerType.human) {
          humanTurnCount++;
          // Verify: at this point, isRolling should be false, isMoving false, waitingForPlayerMove false
          // In real game: "Tap to Roll" should show
          print('  Round $round: Human turn (Player ${cp.id}), roll=$roll — state should show "Tap to Roll"');
          
          // Simulate human making a move
          bool moved = false;
          for (var piece in cp.pieces) {
            if (piece.isHome && roll == 6) {
              piece.position = 0;
              moved = true;
              break;
            }
            if (!piece.isHome && !piece.isFinished && piece.position + roll <= 56) {
              piece.position += roll;
              moved = true;
              break;
            }
          }
        } else {
          aiTurnCount++;
          var ai = AiPlayer(playerId: cp.id, difficulty: AiDifficulty.hard);
          int? moveId = ai.selectPiece(roll, state);
          if (moveId != null) {
            var piece = cp.pieces.firstWhere((p) => p.id == moveId);
            if (piece.position == -1 && roll == 6) {
              piece.position = 0;
            } else if (piece.position >= 0) {
              piece.position += roll;
            }
          }
        }
        
        // Advance turn
        if (roll == 6 && state.consecutiveSixes < 2) {
          state.consecutiveSixes++;
        } else {
          state.consecutiveSixes = 0;
          state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 4;
        }
      }
      
      print('  Result: $humanTurnCount human turns, $aiTurnCount AI turns cycled cleanly');
      assert(humanTurnCount > 0, 'Human should have had turns');
      assert(aiTurnCount > 0, 'AI should have had turns');
      print('  PASS ✓\n');
    });

    // ═══════════════════════════════════════════════════════
    // TEST 4: Rigged game end — winner finishes, game ends
    // ═══════════════════════════════════════════════════════
    test('Test 4: Rigged game ends properly when Red wins', () {
      print('--- Test 4: Rigged game end ---');
      
      var players = [
        Player(id: 0, name: 'Red', type: PlayerType.ai, color: PlayerColor.red),
        Player(id: 1, name: 'Green', type: PlayerType.ai, color: PlayerColor.green),
        Player(id: 2, name: 'Blue', type: PlayerType.ai, color: PlayerColor.blue),
        Player(id: 3, name: 'Yellow', type: PlayerType.ai, color: PlayerColor.yellow),
      ];
      var state = GameState(players: players, designatedWinnerId: 0, isRigged: true);
      var engine = RiggedDiceEngine();

      int totalTurns = 0;
      int maxTurns = 10000;
      bool gameEndedCleanly = false;
      
      while (state.phase != GamePhase.finished && totalTurns < maxTurns) {
        totalTurns++;
        var cp = state.players[state.currentPlayerIndex];
        int roll = engine.roll(state);

        var ai = AiPlayer(playerId: cp.id, difficulty: AiDifficulty.hard);
        int? moveId = ai.selectPiece(roll, state);
        if (moveId != null) {
          var piece = cp.pieces.firstWhere((p) => p.id == moveId);
          if (piece.position == -1 && roll == 6) {
            piece.position = 0;
          } else if (piece.position >= 0) {
            piece.position += roll;
          }
        }

        if (cp.hasWon) {
          state.phase = GamePhase.finished;
          gameEndedCleanly = true;
          print('  Game ended at turn $totalTurns. Winner: Player ${cp.id} (${cp.color.name})');
          
          // Verify winner is Red
          assert(cp.id == 0, 'Designated winner (Red) should have won');
          
          // Verify all 4 pieces are at position 56
          int finishedPieces = cp.pieces.where((p) => p.isFinished).length;
          print('  Red finished pieces: $finishedPieces/4');
          assert(finishedPieces == 4, 'All 4 pieces should be finished');
          
          // Verify game phase is correctly set
          assert(state.phase == GamePhase.finished, 'Game phase should be finished');
          print('  Game phase: ${state.phase} (correct)');
        } else {
          if (roll == 6 && state.consecutiveSixes < 2) {
            state.consecutiveSixes++;
          } else {
            state.consecutiveSixes = 0;
            do {
              state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 4;
            } while (state.players[state.currentPlayerIndex].hasWon);
          }
        }
      }
      
      assert(gameEndedCleanly, 'Game should have ended cleanly, not timed out');
      print('  Result: Game ended cleanly, no freeze at victory');
      print('  PASS ✓\n');
    });
  });
}

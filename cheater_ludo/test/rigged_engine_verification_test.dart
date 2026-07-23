import 'package:flutter_test/flutter_test.dart';
import 'package:cheater_ludo/game/engine/rigged_dice_engine.dart';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';
import 'package:cheater_ludo/game/ai/ai_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RiggedDiceEngine Verification', () {
    test('Bias Tiers Verification', () {
      print('--- Bias Tier Test ---');
      
      var p1 = Player(id: 0, name: 'Winner', type: PlayerType.ai, color: PlayerColor.red);
      var p2 = Player(id: 1, name: 'Loser', type: PlayerType.ai, color: PlayerColor.blue);
      var state = GameState(players: [p1, p2], designatedWinnerId: 0, isRigged: true);
      var engine = RiggedDiceEngine(seed: 123);

      // Skip grace period
      state.currentPlayerIndex = 0;
      for (int i = 0; i < 10; i++) {
        engine.roll(state);
      }

      int favorable = 0;
      for (int i = 0; i < 1000; i++) {
        int r = engine.roll(state);
        if (r == 6) favorable++;
        state.consecutiveSixes = 0;
      }
      double normalBiasRate = favorable / 1000.0;
      print('NORMAL: favorable rolls for winner ~45%: ${normalBiasRate.toStringAsFixed(2)}');
      assert(normalBiasRate >= 0.40 && normalBiasRate <= 0.55, 'Normal bias rate failed');

      // Test HARD
      p2.pieces[0].position = 40; // Makes loser ahead by 10 avg
      favorable = 0;
      for (int i = 0; i < 1000; i++) {
        int r = engine.roll(state);
        if (r == 6) favorable++;
        state.consecutiveSixes = 0;
      }
      double hardBiasRate = favorable / 1000.0;
      print('HARD: favorable rolls for winner ~85%: ${hardBiasRate.toStringAsFixed(2)}');
      assert(hardBiasRate >= 0.80, 'Hard bias rate failed');

      // Test EMERGENCY
      p2.pieces[0].position = 53;
      p2.pieces[1].position = 53;
      p2.pieces[2].position = 53;
      
      state.currentPlayerIndex = 1; // It's loser's turn
      int unfavorable = 0;
      for (int i = 0; i < 1000; i++) {
        int r = engine.roll(state);
        // Unfavorable rolls returned by engine when at 53 (meaning 4,5,6 are invalid)
        // are strictly the invalid ones! The engine forces the player to skip turn.
        // So they will get rolls they can't move with (e.g. 4, 5, 6).
        if (r > 3) unfavorable++; 
        state.consecutiveSixes = 0;
      }
      double emergencyRate = unfavorable / 1000.0;
      print('EMERGENCY: sabotage rate for non-winner ~90%: ${emergencyRate.toStringAsFixed(2)}');
      assert(emergencyRate >= 0.85, 'Emergency sabotage rate failed');
    });
    
    test('Full 5x AI Game Verification', () {
      print('\n--- Full Simulation Test ---');
      
      for (int i = 0; i < 5; i++) {
        var players = [
          Player(id: 0, name: 'P0', type: PlayerType.ai, color: PlayerColor.red),
          Player(id: 1, name: 'P1', type: PlayerType.ai, color: PlayerColor.blue),
          Player(id: 2, name: 'P2', type: PlayerType.ai, color: PlayerColor.green),
          Player(id: 3, name: 'P3', type: PlayerType.ai, color: PlayerColor.yellow),
        ];
        var state = GameState(players: players, designatedWinnerId: 0, isRigged: true);
        var engine = RiggedDiceEngine();
        
        int turnCount = 0;
        while(state.phase != GamePhase.finished && turnCount < 10000) {
          turnCount++;
          var cp = state.players[state.currentPlayerIndex];
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
            state.phase = GamePhase.finished;
            print('Game ${i + 1}: Winner = Player ${cp.id}');
            assert(cp.id == 0, 'Game ${i + 1} was not won by the designated winner Player 0');
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
      }
    });
  });
}

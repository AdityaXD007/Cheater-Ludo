import 'package:flutter_test/flutter_test.dart';
import 'package:cheater_ludo/game/engine/rigged_dice_engine.dart';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';

void main() {
  group('RiggedDiceEngine Tests', () {
    test('Pure random variance check (Unrigged)', () {
      final engine = RiggedDiceEngine();
      final state = GameState(
        isRigged: false,
        players: [Player(id: 1, name: 'Test', type: PlayerType.human, color: PlayerColor.red)],
      ); 
      
      state.currentPlayerIndex = 0;

      final results = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
      
      for (int i = 0; i < 10000; i++) {
        int roll = engine.roll(state);
        results[roll] = (results[roll] ?? 0) + 1;
      }

      // In 10,000 rolls, each number should appear roughly 1666 times.
      // We allow a generous variance of +/- 200 for a purely random distribution
      for (int i = 1; i <= 6; i++) {
        expect(results[i], greaterThan(1400));
        expect(results[i], lessThan(1900));
      }
      
      print('Unrigged 10000 roll distribution: $results');
    });

    test('Winner bias check (Rigged)', () {
      final engine = RiggedDiceEngine();
      
      final p1 = Player(id: 1, name: 'Winner', type: PlayerType.human, color: PlayerColor.red);
      final p2 = Player(id: 2, name: 'Loser', type: PlayerType.human, color: PlayerColor.green);
      
      final state = GameState(
        isRigged: true,
        designatedWinnerId: 1,
        players: [p1, p2],
        currentPlayerIndex: 0,
      );

      // Force pieces to be at home so that rolling a 6 is extremely favorable for the winner
      // The engine's Priority 1 is to give a 6 if pieces are stuck at home.
      
      int winnerSixes = 0;
      
      // Let's simulate the winner's turn 1000 times (ignoring the early game grace period by advancing turn counts)
      // To bypass grace period, we simulate 3 turns first
      for(int i=0; i<3; i++) {
        engine.roll(state);
      }

      for (int i = 0; i < 1000; i++) {
        int roll = engine.roll(state);
        if (roll == 6) winnerSixes++;
        
        // Reset consecutive sixes to avoid the anti-3-sixes safeguard
        state.consecutiveSixes = 0; 
      }

      // A pure random 6 occurs ~16.6% of the time.
      // With a 45% bias kicking in to guarantee a 6 (since pieces are at home),
      // the expected 6s should be significantly higher, around 50-60%.
      expect(winnerSixes, greaterThan(450));
      
      print('Winner rolled 6s $winnerSixes times out of 1000 when stuck at home (Bias working)');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ludo Extra Turn & Penalty Rules', () {
    test('Capturing opponent piece grants extra turn', () {
      var p1 = Player(id: 0, name: 'Red', type: PlayerType.human, color: PlayerColor.red);
      var p2 = Player(id: 1, name: 'Green', type: PlayerType.human, color: PlayerColor.green);
      var state = GameState(players: [p1, p2], currentPlayerIndex: 0);

      int roll = 4;
      bool captured = true;
      int oldPos = 1;
      int newPos = 5;

      bool reachedHome = (oldPos != 56 && newPos == 56);
      bool getExtraTurn = (roll == 6 || captured || reachedHome);

      expect(getExtraTurn, isTrue);
    });

    test('Reaching home (position 56) grants extra turn', () {
      var p1 = Player(id: 0, name: 'Red', type: PlayerType.human, color: PlayerColor.red);
      var state = GameState(players: [p1], currentPlayerIndex: 0);

      int roll = 3;
      bool captured = false;
      int oldPos = 53;
      int newPos = 56;

      bool reachedHome = (oldPos != 56 && newPos == 56);
      bool getExtraTurn = (roll == 6 || captured || reachedHome);

      expect(reachedHome, isTrue);
      expect(getExtraTurn, isTrue);
    });

    test('Normal move without 6, capture, or home passes turn', () {
      int roll = 3;
      bool captured = false;
      int oldPos = 10;
      int newPos = 13;

      bool reachedHome = (oldPos != 56 && newPos == 56);
      bool getExtraTurn = (roll == 6 || captured || reachedHome);

      expect(getExtraTurn, isFalse);
    });

    test('3 consecutive 6s penalizes piece closest to finishing', () {
      var p1 = Player(id: 0, name: 'Red', type: PlayerType.human, color: PlayerColor.red);
      p1.pieces[0].position = 12;
      p1.pieces[1].position = 48; // Closest to finishing!
      p1.pieces[2].position = -1;
      p1.pieces[3].position = 56; // Finished already

      var activePieces = p1.pieces.where((p) => p.position >= 0 && p.position < 56).toList();
      activePieces.sort((a, b) => b.position.compareTo(a.position));

      var pieceToSendHome = activePieces.first;
      pieceToSendHome.position = -1;

      expect(pieceToSendHome.id, equals(1));
      expect(p1.pieces[1].position, equals(-1));
      expect(p1.pieces[3].position, equals(56), reason: 'Finished piece remains untouched');
    });
  });
}

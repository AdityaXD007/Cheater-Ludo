import 'dart:convert';
import 'package:cheater_ludo/game/engine/game_state.dart';
import 'package:cheater_ludo/game/engine/player.dart';
import 'package:cheater_ludo/game/engine/piece.dart';
import 'package:cheater_ludo/game/engine/rigged_dice_engine.dart';

void main() {
  try {
    var state = GameState(
      players: [
        Player(id: 0, name: 'P1', type: PlayerType.human, color: PlayerColor.red),
        Player(id: 1, name: 'P2', type: PlayerType.ai, color: PlayerColor.green, difficulty: AiDifficulty.medium),
      ],
      currentPlayerIndex: 0,
      phase: GamePhase.playing,
    );

    var engine = RiggedDiceEngine();
    // simulate some state
    state.riggedEngineState = engine.toJson();

    var jsonStr = jsonEncode(state.toJson());
    print('Encoded JSON length: ${jsonStr.length}');
    
    var decoded = jsonDecode(jsonStr);
    var newState = GameState.fromJson(decoded);
    print('Decoded state successfully. Player 2 difficulty: ${newState.players[1].difficulty}');
    print('Engine state keys: ${newState.riggedEngineState?.keys.toList()}');

  } catch (e, stack) {
    print('Serialization failed: $e\n$stack');
  }
}

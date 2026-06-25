import 'player.dart';

enum GamePhase { setup, playing, finished }

class GameState {
  List<Player> players;
  int currentPlayerIndex;
  int consecutiveSixes;
  int? designatedWinnerId; // hidden, never logged or printed
  int? lastRoll;
  GamePhase phase;
  List<int> rollHistory; // last 10 rolls per player for suspicion detection
  bool isRigged;

  GameState({
    List<Player>? players,
    this.currentPlayerIndex = 0,
    this.consecutiveSixes = 0,
    this.designatedWinnerId,
    this.lastRoll,
    this.phase = GamePhase.setup,
    List<int>? rollHistory,
    this.isRigged = true,
  }) : players = players ?? [],
       rollHistory = rollHistory ?? [];
}

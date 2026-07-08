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
  Map<String, dynamic>? riggedEngineState;

  GameState({
    List<Player>? players,
    this.currentPlayerIndex = 0,
    this.consecutiveSixes = 0,
    this.designatedWinnerId,
    this.lastRoll,
    this.phase = GamePhase.setup,
    List<int>? rollHistory,
    this.isRigged = true,
    this.riggedEngineState,
  }) : players = players ?? [],
       rollHistory = rollHistory ?? [];

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'consecutiveSixes': consecutiveSixes,
    'designatedWinnerId': designatedWinnerId,
    'lastRoll': lastRoll,
    'phase': phase.name,
    'rollHistory': rollHistory,
    'isRigged': isRigged,
    'riggedEngineState': riggedEngineState,
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    var state = GameState(
      players: (json['players'] as List).map((p) => Player.fromJson(p as Map<String, dynamic>)).toList(),
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      consecutiveSixes: json['consecutiveSixes'] as int,
      designatedWinnerId: json['designatedWinnerId'] as int?,
      lastRoll: json['lastRoll'] as int?,
      phase: GamePhase.values.byName(json['phase'] as String),
      rollHistory: (json['rollHistory'] as List).map((e) => e as int).toList(),
      isRigged: json['isRigged'] as bool? ?? true,
      riggedEngineState: json['riggedEngineState'] as Map<String, dynamic>?,
    );
    return state;
  }
}

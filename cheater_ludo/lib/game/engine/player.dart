import 'piece.dart';

enum PlayerType { human, ai, none }
enum PlayerColor { red, green, blue, yellow }
enum AiDifficulty { easy, medium, hard }

class Player {
  final int id;
  final String name;
  final PlayerType type;
  final PlayerColor color;
  final AiDifficulty? difficulty; // null if human
  final List<Piece> pieces; // always 4
  int? lastRoll;

  Player({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.difficulty,
  }) : pieces = List.generate(4, (index) => Piece(id: index, playerId: id));

  bool get hasWon => pieces.every((p) => p.isFinished);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'color': color.name,
    'difficulty': difficulty?.name,
    'pieces': pieces.map((p) => p.toJson()).toList(),
    'lastRoll': lastRoll,
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    var p = Player(
      id: json['id'] as int,
      name: json['name'] as String,
      type: PlayerType.values.byName(json['type'] as String),
      color: PlayerColor.values.byName(json['color'] as String),
      difficulty: json['difficulty'] != null 
          ? AiDifficulty.values.byName(json['difficulty'] as String) 
          : null,
    );
    p.lastRoll = json['lastRoll'] as int?;
    
    if (json['pieces'] != null) {
      var piecesList = json['pieces'] as List;
      for (int i = 0; i < piecesList.length && i < 4; i++) {
        p.pieces[i] = Piece.fromJson(piecesList[i] as Map<String, dynamic>);
      }
    }
    return p;
  }
}

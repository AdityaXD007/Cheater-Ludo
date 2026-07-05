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
}

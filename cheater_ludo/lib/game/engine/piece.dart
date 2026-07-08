class Piece {
  final int id;
  final int playerId;
  int position; // -1 home, 0-55 board, 56 finished

  Piece({
    required this.id,
    required this.playerId,
    this.position = -1,
  });

  bool get isHome => position == -1;
  bool get isFinished => position == 56;

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerId': playerId,
    'position': position,
  };

  factory Piece.fromJson(Map<String, dynamic> json) {
    return Piece(
      id: json['id'] as int,
      playerId: json['playerId'] as int,
      position: json['position'] as int? ?? -1,
    );
  }
}

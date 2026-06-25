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
}

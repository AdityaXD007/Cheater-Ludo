class BoardPos {
  final int x;
  final int y;
  const BoardPos(this.x, this.y);
}

class BoardConstants {
  static const int boardSize = 15;
  
  static const List<int> safeSquares = [0, 8, 13, 21, 26, 34, 39, 47];

  static const List<BoardPos> sharedRing = [
    BoardPos(6, 13), BoardPos(6, 12), BoardPos(6, 11), BoardPos(6, 10), BoardPos(6, 9),
    BoardPos(5, 8), BoardPos(4, 8), BoardPos(3, 8), BoardPos(2, 8), BoardPos(1, 8),
    BoardPos(0, 8), BoardPos(0, 7), BoardPos(0, 6), BoardPos(1, 6), BoardPos(2, 6),
    BoardPos(3, 6), BoardPos(4, 6), BoardPos(5, 6), BoardPos(6, 5), BoardPos(6, 4),
    BoardPos(6, 3), BoardPos(6, 2), BoardPos(6, 1), BoardPos(6, 0), BoardPos(7, 0),
    BoardPos(8, 0), BoardPos(8, 1), BoardPos(8, 2), BoardPos(8, 3), BoardPos(8, 4),
    BoardPos(8, 5), BoardPos(9, 6), BoardPos(10, 6), BoardPos(11, 6), BoardPos(12, 6),
    BoardPos(13, 6), BoardPos(14, 6), BoardPos(14, 7), BoardPos(14, 8), BoardPos(13, 8),
    BoardPos(12, 8), BoardPos(11, 8), BoardPos(10, 8), BoardPos(9, 8), BoardPos(8, 9),
    BoardPos(8, 10), BoardPos(8, 11), BoardPos(8, 12), BoardPos(8, 13), BoardPos(8, 14),
    BoardPos(7, 14), BoardPos(6, 14)
  ];

  static final List<BoardPos> redPath = _generatePath(0, const [
    BoardPos(7, 13), BoardPos(7, 12), BoardPos(7, 11), BoardPos(7, 10), BoardPos(7, 9)
  ]);

  static final List<BoardPos> greenPath = _generatePath(13, const [
    BoardPos(1, 7), BoardPos(2, 7), BoardPos(3, 7), BoardPos(4, 7), BoardPos(5, 7)
  ]);

  static final List<BoardPos> bluePath = _generatePath(26, const [
    BoardPos(7, 1), BoardPos(7, 2), BoardPos(7, 3), BoardPos(7, 4), BoardPos(7, 5)
  ]);

  static final List<BoardPos> yellowPath = _generatePath(39, const [
    BoardPos(13, 7), BoardPos(12, 7), BoardPos(11, 7), BoardPos(10, 7), BoardPos(9, 7)
  ]);

  static List<BoardPos> _generatePath(int offset, List<BoardPos> homeStretch) {
    List<BoardPos> path = [];
    // 51 squares on the shared ring
    for (int i = 0; i < 51; i++) {
      path.add(sharedRing[(offset + i) % 52]);
    }
    // 5 home stretch squares
    path.addAll(homeStretch);
    // position 56 (finished) is implicitly at the center or handled by game logic
    // we'll add one more point representing the final finished state
    path.add(const BoardPos(7, 7)); // Center
    return path;
  }
  
  // Home bases for rendering pieces that are at position -1
  static const List<BoardPos> redHomeBase = [BoardPos(2, 11), BoardPos(2, 12), BoardPos(3, 11), BoardPos(3, 12)];
  static const List<BoardPos> greenHomeBase = [BoardPos(2, 2), BoardPos(2, 3), BoardPos(3, 2), BoardPos(3, 3)];
  static const List<BoardPos> blueHomeBase = [BoardPos(11, 2), BoardPos(11, 3), BoardPos(12, 2), BoardPos(12, 3)];
  static const List<BoardPos> yellowHomeBase = [BoardPos(11, 11), BoardPos(11, 12), BoardPos(12, 11), BoardPos(12, 12)];
}

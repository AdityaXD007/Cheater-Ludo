import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../engine/board_constants.dart';
import '../engine/player.dart';

import 'ludo_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<LudoGame> {
  static const Color redColor = Color(0xFFc0392b);
  static const Color greenColor = Color(0xFF27ae60);
  static const Color blueColor = Color(0xFF2980b9);
  static const Color yellowColor = Color(0xFFf39c12);
  static const Color boardBackground = Color(0xFFEEEEEE);
  static const Color safeColor = Color(0xFFB0BEC5);

  double cellSize = 0;
  Vector2 boardOffset = Vector2.zero();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    double minDim = min(size.x, size.y) * 0.95; // 5% margin
    cellSize = minDim / BoardConstants.boardSize;
    boardOffset = Vector2((size.x - minDim) / 2, (size.y - minDim) / 2);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (cellSize == 0) return;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(boardOffset.x, boardOffset.y, cellSize * 15, cellSize * 15), bgPaint);

    _drawHomeBase(canvas, 0, 0, greenColor);
    _drawHomeBase(canvas, 9, 0, blueColor);
    _drawHomeBase(canvas, 0, 9, redColor);
    _drawHomeBase(canvas, 9, 9, yellowColor);

    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final safePaint = Paint()..color = safeColor;
    
    // Draw cells
    for (int x = 0; x < 15; x++) {
      for (int y = 0; y < 15; y++) {
        if (_isPathCell(x, y)) {
          Rect rect = _getRect(x, y);
          canvas.drawRect(rect, outlinePaint);
          
          // Draw safe squares
          if (_isSafeSquare(x, y)) {
            canvas.drawRect(rect, safePaint);
            canvas.drawRect(rect, outlinePaint);
          }

          // Draw home stretch colors
          if (x == 7 && y >= 1 && y <= 5) _fillCell(canvas, rect, blueColor); // Blue stretch
          if (x == 7 && y >= 9 && y <= 13) _fillCell(canvas, rect, redColor); // Red stretch
          if (y == 7 && x >= 1 && x <= 5) _fillCell(canvas, rect, greenColor); // Green stretch
          if (y == 7 && x >= 9 && x <= 13) _fillCell(canvas, rect, yellowColor); // Yellow stretch
          
          // Start squares
          if (x == 1 && y == 6) _fillCell(canvas, rect, greenColor);
          if (x == 8 && y == 1) _fillCell(canvas, rect, blueColor);
          if (x == 13 && y == 8) _fillCell(canvas, rect, yellowColor);
          if (x == 6 && y == 13) _fillCell(canvas, rect, redColor);

          // Draw stars on all safe squares (which includes start squares)
          if (_isSafeSquare(x, y)) {
            _drawStar(canvas, rect, color: Colors.white);
          }
        }
      }
    }

    _drawCenter(canvas);
  }

  void _drawHomeBase(Canvas canvas, int gridX, int gridY, Color color) {
    Rect baseRect = _getRect(gridX, gridY, width: 6, height: 6);
    
    bool isActive = false;
    String colorName = "";
    try {
      PlayerColor pColor;
      if (color == redColor) { pColor = PlayerColor.red; colorName = "RED"; }
      else if (color == greenColor) { pColor = PlayerColor.green; colorName = "GREEN"; }
      else if (color == blueColor) { pColor = PlayerColor.blue; colorName = "BLUE"; }
      else { pColor = PlayerColor.yellow; colorName = "YELLOW"; }
      
      var p = game.gameState.players.firstWhere((p) => p.color == pColor);
      if (game.gameState.players[game.gameState.currentPlayerIndex].id == p.id) {
        isActive = true;
      }
    } catch (_) {}

    Paint fill = Paint()..color = color;
    canvas.drawRect(baseRect, fill);

    if (isActive) {
      Paint insetGlowPaint = Paint()
        ..color = const Color(0xFFffd700).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(baseRect.deflate(1.5), insetGlowPaint);
    }

    Rect innerRect = _getRect(gridX + 1, gridY + 1, width: 4, height: 4);
    Paint innerFill = Paint()..color = Colors.white;
    canvas.drawRect(innerRect, innerFill);

    // Draw 4 circles for home positions
    Paint circlePaint = Paint()..color = color;
    double p1 = 2.0;
    double p2 = 4.0;
    double radius = cellSize * 0.7;
    canvas.drawCircle(Offset(boardOffset.x + (gridX + p1) * cellSize, boardOffset.y + (gridY + p1) * cellSize), radius, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + p2) * cellSize, boardOffset.y + (gridY + p1) * cellSize), radius, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + p1) * cellSize, boardOffset.y + (gridY + p2) * cellSize), radius, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + p2) * cellSize, boardOffset.y + (gridY + p2) * cellSize), radius, circlePaint);

    if (colorName.isNotEmpty) {
      final textSpan = TextSpan(
        text: colorName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(minWidth: 0, maxWidth: cellSize * 6);
      
      double textY = boardOffset.y + gridY * cellSize + 8.0;
      double textX = boardOffset.x + gridX * cellSize + (cellSize * 6 - textPainter.width) / 2;
      
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  void _drawCenter(Canvas canvas) {
    Path path = Path();
    
    // Center is 6,6 to 8,8
    double cx = boardOffset.x + 7.5 * cellSize;
    double cy = boardOffset.y + 7.5 * cellSize;

    // Top Blue triangle
    path.moveTo(boardOffset.x + 6 * cellSize, boardOffset.y + 6 * cellSize);
    path.lineTo(boardOffset.x + 9 * cellSize, boardOffset.y + 6 * cellSize);
    path.lineTo(cx, cy);
    path.close();
    canvas.drawPath(path, Paint()..color = blueColor);

    // Right Yellow triangle
    path = Path();
    path.moveTo(boardOffset.x + 9 * cellSize, boardOffset.y + 6 * cellSize);
    path.lineTo(boardOffset.x + 9 * cellSize, boardOffset.y + 9 * cellSize);
    path.lineTo(cx, cy);
    path.close();
    canvas.drawPath(path, Paint()..color = yellowColor);

    // Bottom Red triangle
    path = Path();
    path.moveTo(boardOffset.x + 9 * cellSize, boardOffset.y + 9 * cellSize);
    path.lineTo(boardOffset.x + 6 * cellSize, boardOffset.y + 9 * cellSize);
    path.lineTo(cx, cy);
    path.close();
    canvas.drawPath(path, Paint()..color = redColor);

    // Left Green triangle
    path = Path();
    path.moveTo(boardOffset.x + 6 * cellSize, boardOffset.y + 9 * cellSize);
    path.lineTo(boardOffset.x + 6 * cellSize, boardOffset.y + 6 * cellSize);
    path.lineTo(cx, cy);
    path.close();
    canvas.drawPath(path, Paint()..color = greenColor);
  }

  void _drawStar(Canvas canvas, Rect rect, {Color color = Colors.white}) {
    double cx = rect.center.dx;
    double cy = rect.center.dy;
    double rOuter = rect.width * 0.35;
    double rInner = rect.width * 0.15;
    int points = 5;
    double angle = -pi / 2; // start at top

    Path path = Path();
    for (int i = 0; i < points * 2; i++) {
      double r = (i % 2 == 0) ? rOuter : rInner;
      double x = cx + cos(angle) * r;
      double y = cy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += pi / points;
    }
    path.close();
    
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  void _fillCell(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
    canvas.drawRect(rect, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  bool _isPathCell(int x, int y) {
    if (x >= 6 && x <= 8 && y < 6) return true; // Top arm
    if (x >= 6 && x <= 8 && y > 8) return true; // Bottom arm
    if (y >= 6 && y <= 8 && x < 6) return true; // Left arm
    if (y >= 6 && y <= 8 && x > 8) return true; // Right arm
    return false;
  }

  bool _isSafeSquare(int x, int y) {
    for (int idx in BoardConstants.safeSquares) {
      if (idx < BoardConstants.sharedRing.length) {
        var pos = BoardConstants.sharedRing[idx];
        if (pos.x == x && pos.y == y) return true;
      }
    }
    return false;
  }

  Rect _getRect(int x, int y, {int width = 1, int height = 1}) {
    return Rect.fromLTWH(
      boardOffset.x + x * cellSize,
      boardOffset.y + y * cellSize,
      cellSize * width,
      cellSize * height,
    );
  }

  Vector2 getCellCenter(int x, int y) {
    return Vector2(
      boardOffset.x + (x + 0.5) * cellSize,
      boardOffset.y + (y + 0.5) * cellSize,
    );
  }
}

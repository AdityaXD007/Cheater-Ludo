import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../engine/board_constants.dart';

import 'ludo_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<LudoGame> {
  static const Color redColor = Color(0xFFE53935);
  static const Color greenColor = Color(0xFF43A047);
  static const Color blueColor = Color(0xFF1E88E5);
  static const Color yellowColor = Color(0xFFFDD835);
  static const Color boardBackground = Color(0xFFEEEEEE);
  static const Color safeColor = Color(0xFFB0BEC5);

  double cellSize = 0;
  Vector2 boardOffset = Vector2.zero();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    double minDim = min(size.x, size.y);
    cellSize = minDim / BoardConstants.boardSize;
    boardOffset = Vector2((size.x - minDim) / 2, (size.y - minDim) / 2 + 50); // Offset down slightly for UI
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (cellSize == 0) return;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(boardOffset.x, boardOffset.y, cellSize * 15, cellSize * 15), bgPaint);

    _drawHomeBase(canvas, 0, 0, greenColor);
    _drawHomeBase(canvas, 9, 0, yellowColor);
    _drawHomeBase(canvas, 0, 9, redColor);
    _drawHomeBase(canvas, 9, 9, blueColor);

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
        }
      }
    }

    _drawCenter(canvas);
  }

  void _drawHomeBase(Canvas canvas, int gridX, int gridY, Color color) {
    Rect baseRect = _getRect(gridX, gridY, width: 6, height: 6);
    Paint fill = Paint()..color = color;
    canvas.drawRect(baseRect, fill);

    Rect innerRect = _getRect(gridX + 1, gridY + 1, width: 4, height: 4);
    Paint innerFill = Paint()..color = Colors.white;
    canvas.drawRect(innerRect, innerFill);

    // Draw 4 circles for home positions
    Paint circlePaint = Paint()..color = color;
    canvas.drawCircle(Offset(boardOffset.x + (gridX + 2.5) * cellSize, boardOffset.y + (gridY + 2.5) * cellSize), cellSize * 0.8, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + 3.5) * cellSize, boardOffset.y + (gridY + 2.5) * cellSize), cellSize * 0.8, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + 2.5) * cellSize, boardOffset.y + (gridY + 3.5) * cellSize), cellSize * 0.8, circlePaint);
    canvas.drawCircle(Offset(boardOffset.x + (gridX + 3.5) * cellSize, boardOffset.y + (gridY + 3.5) * cellSize), cellSize * 0.8, circlePaint);
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

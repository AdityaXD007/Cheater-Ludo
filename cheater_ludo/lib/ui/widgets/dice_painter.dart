import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/haptics.dart';

class DicePainter extends CustomPainter {
  final int value;
  final Color pipColor;

  DicePainter(this.value, this.pipColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (value < 1 || value > 6) return;

    final dotPaint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;

    final double dotRadius = 6.0; // Fixed 6px radius as requested

    void drawDot(double xFrac, double yFrac) {
      canvas.drawCircle(Offset(size.width * xFrac, size.height * yFrac), dotRadius, dotPaint);
    }

    if (value == 1) {
      drawDot(0.5, 0.5);
    } else if (value == 2) {
      drawDot(0.75, 0.25);
      drawDot(0.25, 0.75);
    } else if (value == 3) {
      drawDot(0.75, 0.25);
      drawDot(0.5, 0.5);
      drawDot(0.25, 0.75);
    } else if (value == 4) {
      drawDot(0.25, 0.25);
      drawDot(0.75, 0.25);
      drawDot(0.25, 0.75);
      drawDot(0.75, 0.75);
    } else if (value == 5) {
      drawDot(0.25, 0.25);
      drawDot(0.75, 0.25);
      drawDot(0.5, 0.5);
      drawDot(0.25, 0.75);
      drawDot(0.75, 0.75);
    } else if (value == 6) {
      drawDot(0.25, 0.25);
      drawDot(0.25, 0.5);
      drawDot(0.25, 0.75);
      drawDot(0.75, 0.25);
      drawDot(0.75, 0.5);
      drawDot(0.75, 0.75);
    }
  }

  @override
  bool shouldRepaint(covariant DicePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.pipColor != pipColor;
  }
}

class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final VoidCallback? onTap;
  final double size;
  final Duration rollDuration;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double borderRadius;
  final Color pipColor;
  final bool rapidRoll; // Determines if it should do the 80ms rapid roll

  const DiceWidget({
    super.key,
    this.value,
    this.isRolling = false,
    this.onTap,
    this.size = 80.0,
    this.rollDuration = const Duration(milliseconds: 600),
    this.border,
    this.boxShadow,
    this.borderRadius = 16.0,
    this.pipColor = const Color(0xFF2980b9), // Default blue
    this.rapidRoll = false,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {
  Timer? _timer; // Used for rapid roll
  int _displayValue = 1;

  @override
  void initState() {
    super.initState();
    _startAnimationIfNeeded();
  }

  void _startAnimationIfNeeded() {
    _timer?.cancel();
    
    if (widget.isRolling) {
      if (widget.rapidRoll) {
        _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
          setState(() {
            _displayValue = Random().nextInt(6) + 1;
          });
        });
      }
    } else if (widget.value != null) {
      // Result shown
      _displayValue = widget.value!;
    }
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling != oldWidget.isRolling || 
        widget.value != oldWidget.value) {
      _startAnimationIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget diceContent;
    if (widget.value == null && !widget.isRolling) {
      // Default to 1 if no value is provided and not rolling
      diceContent = CustomPaint(
        painter: DicePainter(1, widget.pipColor),
      );
    } else {
      diceContent = CustomPaint(
        painter: DicePainter(_displayValue, widget.pipColor),
      );
    }

    return GestureDetector(
      onTap: widget.onTap != null ? () {
        Haptics.tap();
        widget.onTap!();
      } : null,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: widget.boxShadow ?? [
            BoxShadow(
              color: const Color(0xFF1e5aa0).withValues(alpha: 0.2),
              blurRadius: 24,
              offset: Offset.zero,
            ),
          ],
        ),
        child: diceContent,
      ),
    );
  }
}

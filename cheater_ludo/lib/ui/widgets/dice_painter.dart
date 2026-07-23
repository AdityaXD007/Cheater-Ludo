import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import '../../utils/haptics.dart';

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
  final bool rapidRoll;

  const DiceWidget({
    super.key,
    this.value,
    this.isRolling = false,
    this.onTap,
    this.size = 50,
    this.rollDuration = const Duration(milliseconds: 600),
    this.border,
    this.boxShadow,
    this.borderRadius = 16.0,
    this.pipColor = const Color(0xFF2980b9), // Note: pipColor might not apply to pre-rendered sprites
    this.rapidRoll = false,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> {
  static bool _imagesPrecached = false;
  Timer? _timer;
  int _frame = 1;

  @override
  void initState() {
    super.initState();
    _startAnimationIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      // Precache 25 roll frames
      for (int i = 1; i <= 25; i++) {
        precacheImage(AssetImage('assets/dice/roll/roll_${i.toString().padLeft(4, '0')}.png'), context);
      }
      // Precache 6 static face frames
      for (int i = 1; i <= 6; i++) {
        precacheImage(AssetImage('assets/dice/final/face_$i.png'), context);
      }
    }
  }

  void _startAnimationIfNeeded() {
    _timer?.cancel();
    _timer = null;
    if (widget.isRolling) {
      FlameAudio.play('dice_roll.m4a');
      _frame = 1;
      _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
        if (!mounted) {
          timer.cancel();
          _timer = null;
          return;
        }
        setState(() {
          _frame = (_frame % 25) + 1;
        });
      });
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
    final cachePx = (widget.size * MediaQuery.of(context).devicePixelRatio).toInt().clamp(64, 256);
    
    if (widget.isRolling) {
      // Rolling state: loop through 25 pre-rendered tumble frames
      String frameStr = _frame.toString().padLeft(4, '0');
      diceContent = Image.asset(
        'assets/dice/roll/roll_$frameStr.png',
        width: widget.size,
        height: widget.size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        fit: BoxFit.contain,
      );
    } else {
      // Idle/Result state: static final face
      int face = widget.value ?? 1;
      diceContent = Image.asset(
        'assets/dice/final/face_$face.png',
        width: widget.size,
        height: widget.size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        fit: BoxFit.contain,
      );
    }

    // Slight zoom to trim remaining transparent margins in the 512x512 PNGs
    diceContent = Transform.scale(
      scale: 1.3,
      child: diceContent,
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap != null ? () {
          Haptics.tap();
          widget.onTap!();
        } : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.transparent, // Background baked into sprite
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border,
            boxShadow: widget.boxShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: diceContent,
          ),
        ),
      ),
    );
  }
}

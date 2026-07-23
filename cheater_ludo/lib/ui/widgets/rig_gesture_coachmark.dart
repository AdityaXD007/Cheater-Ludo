import 'package:flutter/material.dart';

/// A coach-mark overlay that points at the first player's pawn icon,
/// showing an animated "hold to rig" gesture hint.
class RigGestureCoachMark extends StatefulWidget {
  /// GlobalKey of the target pawn widget to highlight.
  final GlobalKey targetKey;
  /// Called when the coach-mark should be dismissed.
  final VoidCallback onDismiss;

  const RigGestureCoachMark({
    super.key,
    required this.targetKey,
    required this.onDismiss,
  });

  @override
  State<RigGestureCoachMark> createState() => _RigGestureCoachMarkState();
}

class _RigGestureCoachMarkState extends State<RigGestureCoachMark>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _progressAnim;
  late final Animation<double> _fadeAnim;

  Offset? _pawnCenter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _calculatePosition());

    // Pulsing hand icon: scale 1.0 → 1.15 → 1.0, repeating
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Circular progress ring: fills over 2s, then resets
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Fade-in on appear
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Auto-dismiss after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) _dismiss();
    });
  }

  void _calculatePosition() {
    if (!mounted) return;
    final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && overlayBox != null && overlayBox.hasSize) {
      final globalCenter = renderBox.localToGlobal(
        Offset(renderBox.size.width / 2, renderBox.size.height / 2),
      );
      final localCenter = overlayBox.globalToLocal(globalCenter);
      if (_pawnCenter != localCenter) {
        setState(() {
          _pawnCenter = localCenter;
        });
      }
    }
  }

  void _dismiss() {
    _fadeController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not calculated yet, attempt post-frame calculation and render nothing for 1 frame
    if (_pawnCenter == null) {
      _calculatePosition();
      if (_pawnCenter == null) {
        return const SizedBox.shrink();
      }
    }

    final pawnCenter = _pawnCenter!;

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.translucent,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Semi-transparent scrim
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),

              // Circular progress ring around pawn
              Positioned(
                left: pawnCenter.dx - 38,
                top: pawnCenter.dy - 38,
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, child) {
                    return SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: _progressAnim.value,
                        strokeWidth: 3.5,
                        backgroundColor: const Color(0x44D89B2A),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFD89B2A),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Cutout highlight where the pawn sits (bright circle)
              Positioned(
                left: pawnCenter.dx - 30,
                top: pawnCenter.dy - 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEFE1C6).withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD89B2A).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // Pulsing hand icon
              Positioned(
                left: pawnCenter.dx - 20,
                top: pawnCenter.dy - 56,
                child: ScaleTransition(
                  scale: _pulseAnim,
                  child: const Icon(
                    Icons.touch_app,
                    size: 40,
                    color: Color(0xFFD89B2A),
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 6,
                        color: Color(0x66000000),
                      ),
                    ],
                  ),
                ),
              ),

              // Caption label
              Positioned(
                left: pawnCenter.dx + 36,
                top: pawnCenter.dy - 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD89B2A),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Hold to rig',
                    style: TextStyle(
                      color: Color(0xFF5A3A12),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


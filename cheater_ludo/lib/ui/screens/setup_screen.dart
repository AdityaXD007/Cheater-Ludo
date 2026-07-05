import 'package:flutter/material.dart';
import 'dart:async';
import '../../game/engine/player.dart';
import '../../game/engine/game_state.dart';
import '../../utils/haptics.dart';
import 'game_screen.dart';
import 'game_mode.dart';

// ─── Color Sets for Pawns ──────────────────────────────────────────────
class PawnColorSet {
  final Color topGradient;
  final Color bottomGradient;
  final Color highlightColor;

  const PawnColorSet({
    required this.topGradient,
    required this.bottomGradient,
    required this.highlightColor,
  });

  static const red = PawnColorSet(
    topGradient: Color(0xFFF4645C),
    bottomGradient: Color(0xFFB7241E),
    highlightColor: Color(0xFFFFA09B),
  );

  static const gold = PawnColorSet(
    topGradient: Color(0xFFF8D25C),
    bottomGradient: Color(0xFFC7952A),
    highlightColor: Color(0xFFFFEDA0),
  );

  static const gray = PawnColorSet(
    topGradient: Color(0xFFB9B9B9),
    bottomGradient: Color(0xFF7C7C7C),
    highlightColor: Color(0xFFD8D8D8),
  );

  static const green = PawnColorSet(
    topGradient: Color(0xFF55D463),
    bottomGradient: Color(0xFF27A338),
    highlightColor: Color(0xFF90EE99),
  );

  static const blue = PawnColorSet(
    topGradient: Color(0xFF5CA8F4),
    bottomGradient: Color(0xFF1E5CB7),
    highlightColor: Color(0xFF9BC8FF),
  );
}

// ─── Pawn CustomPainter ────────────────────────────────────────────────
class PawnPainter extends CustomPainter {
  final PawnColorSet colors;
  final bool showGlow;

  PawnPainter({required this.colors, this.showGlow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow ellipse
    final shadowPaint = Paint()
      ..color = const Color(0x26000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.93),
        width: w * 0.7,
        height: h * 0.1,
      ),
      shadowPaint,
    );

    // Gold glow if rigged
    if (showGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.5),
            const Color(0xFFFFD700).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5),
          width: w * 1.4,
          height: h * 1.2,
        ));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5),
          width: w * 1.4,
          height: h * 1.2,
        ),
        glowPaint,
      );
    }

    // Body (teardrop shape) — wider at the bottom, narrower at the top
    final bodyPath = Path();
    bodyPath.moveTo(w * 0.5, h * 0.30);
    bodyPath.cubicTo(
      w * 0.15, h * 0.45,
      w * 0.12, h * 0.80,
      w * 0.5, h * 0.88,
    );
    bodyPath.cubicTo(
      w * 0.88, h * 0.80,
      w * 0.85, h * 0.45,
      w * 0.5, h * 0.30,
    );
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.topGradient, colors.bottomGradient],
      ).createShader(Rect.fromLTWH(0, h * 0.3, w, h * 0.58));
    canvas.drawPath(bodyPath, bodyPaint);

    // Body highlight ellipse (light catch)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 0.8,
        colors: [
          colors.highlightColor.withValues(alpha: 0.55),
          colors.highlightColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.15, h * 0.35, w * 0.5, h * 0.35));
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.40, w * 0.38, h * 0.25),
      highlightPaint,
    );

    // Head (sphere on top of body)
    final headCenter = Offset(w * 0.5, h * 0.22);
    final headRadius = w * 0.19;

    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [colors.topGradient, colors.bottomGradient],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius));
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Head highlight
    final headHighlight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius));
    canvas.drawCircle(headCenter, headRadius * 0.7, headHighlight);
  }

  @override
  bool shouldRepaint(PawnPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.showGlow != showGlow;
}

// ─── Pawn Widget ───────────────────────────────────────────────────────
class PawnWidget extends StatelessWidget {
  final PawnColorSet colors;
  final bool showGlow;
  final double width;
  final double height;

  const PawnWidget({
    super.key,
    required this.colors,
    this.showGlow = false,
    this.width = 46,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: PawnPainter(colors: colors, showGlow: showGlow),
    );
  }
}

// ─── Glossy Button ─────────────────────────────────────────────────────
class GlossyButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;
  final List<Color> gradientColors;

  const GlossyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
    this.borderRadius = 16,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onPressed?.call();
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top highlight overlay (fakes inset highlight)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: height * 0.48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(borderRadius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom shadow overlay (fakes inset shadow)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height * 0.3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(borderRadius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Child content centered
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Selector ──────────────────────────────────────────────────────
class TabSelector extends StatelessWidget {
  final int activePlayerCount;
  final ValueChanged<int> onChanged;

  const TabSelector({
    super.key,
    required this.activePlayerCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          for (int count in [2, 3, 4]) ...[
            if (count > 2) const SizedBox(width: 6),
            Expanded(
              child: _TabButton(
                label: '$count Players',
                isActive: activePlayerCount == count,
                onTap: () {
                  Haptics.selection();
                  onChanged(count);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isActive
                    ? [const Color(0xFFFBDB6E), const Color(0xFFD89B2A)]
                    : [const Color(0xFFA88A56), const Color(0xFF8A6E3E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top highlight
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom shadow
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Label
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF5A3A12)
                          : const Color(0xFF8A6A3A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Green checkmark badge for active tab
          if (isActive)
            Positioned(
              left: -8,
              top: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4CAF50),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Player Row ────────────────────────────────────────────────────────
class PlayerRow extends StatelessWidget {
  final int index;
  final String name;
  final bool isActive;
  final bool isRigged;
  final PawnColorSet pawnColors;
  final VoidCallback? onEdit;
  final GestureTapDownCallback? onPawnTapDown;
  final GestureTapUpCallback? onPawnTapUp;
  final GestureTapCancelCallback? onPawnTapCancel;

  const PlayerRow({
    super.key,
    required this.index,
    required this.name,
    required this.isActive,
    required this.isRigged,
    required this.pawnColors,
    this.onEdit,
    this.onPawnTapDown,
    this.onPawnTapUp,
    this.onPawnTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Pawn with long-press rig gesture
          GestureDetector(
            onTapDown: onPawnTapDown,
            onTapUp: onPawnTapUp,
            onTapCancel: onPawnTapCancel,
            child: SizedBox(
              width: 52,
              height: 62,
              child: PawnWidget(
                colors: isActive ? pawnColors : PawnColorSet.gray,
                showGlow: isRigged,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name pill
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFF9C9C9C),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.7),
                          blurRadius: 1,
                          offset: const Offset(0, -1),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF4A4A4A)
                            : Colors.white.withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive && onEdit != null)
                    GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        onEdit?.call();
                      },
                      child: Icon(
                        Icons.edit,
                        size: 18,
                        color: const Color(0xFF4A4A4A).withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main Setup Screen ─────────────────────────────────────────────────
class SetupScreen extends StatefulWidget {
  final GameMode mode;

  const SetupScreen({super.key, this.mode = GameMode.local});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _activePlayerCount = 2;
  late final List<PlayerConfig> _configs;
  int? _designatedWinnerId;
  Timer? _longPressTimer;

  static const _pawnActiveColors = [
    PawnColorSet.red,
    PawnColorSet.gold,
    PawnColorSet.green,
    PawnColorSet.blue,
  ];

  @override
  void initState() {
    super.initState();
    final bool isVsComputer = widget.mode == GameMode.vsComputer;
    _configs = [
      PlayerConfig(id: 0, color: PlayerColor.red, name: 'Player 1', type: PlayerType.human),
      PlayerConfig(id: 1, color: PlayerColor.green, name: 'Player 2', type: isVsComputer ? PlayerType.ai : PlayerType.human),
      PlayerConfig(id: 2, color: PlayerColor.blue, name: 'Player 3', type: isVsComputer ? PlayerType.ai : PlayerType.human),
      PlayerConfig(id: 3, color: PlayerColor.yellow, name: 'Player 4', type: isVsComputer ? PlayerType.ai : PlayerType.human),
    ];
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    // Active players are the first _activePlayerCount ones
    final activeConfigs = _configs.sublist(0, _activePlayerCount);

    // Validate non-empty names
    for (final c in activeConfigs) {
      if (c.name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All active players must have a name!')),
        );
        return;
      }
    }

    if (activeConfigs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start!')),
      );
      return;
    }

    var players = activeConfigs.map((c) => Player(
      id: c.id,
      name: c.name,
      type: c.type,
      color: c.color,
      difficulty: c.type == PlayerType.ai ? c.difficulty : null,
    )).toList();

    var gameState = GameState(
      players: players,
      designatedWinnerId: _designatedWinnerId,
      isRigged: _designatedWinnerId != null,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(gameState: gameState)),
    );
  }

  void _showRenameDialog(int index) {
    final controller = TextEditingController(text: _configs[index].name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Rename Player',
          style: TextStyle(
            color: Color(0xFF5A3A12),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF4A4A4A)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD89B2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD89B2A), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.tap();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8A6E3E)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD89B2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Haptics.medium();
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _configs[index].name = controller.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const headerContentHeight = 64.0;
    final totalHeaderHeight = statusBarHeight + headerContentHeight + 12; // +12 for rounded overshoot

    return Scaffold(
      body: Stack(
        children: [
          // ── CREAM BACKGROUND (full screen) ──────────────────────
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFFEFE1C6)),
          ),

          // ── BLUE HEADER (absolute, edge-to-edge) ───────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: totalHeaderHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3E7BFA), Color(0xFF2F5FD8)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2548AA).withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(top: statusBarHeight),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back button
                  Positioned(
                    left: 14,
                    child: GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFFFD98A), Color(0xFFE8A93A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  // Title
                  const Text(
                    'Local',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Color(0x40000000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BODY CONTENT (below header) ─────────────────────────
          Positioned(
            top: totalHeaderHeight + 2,
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
          TabSelector(
            activePlayerCount: _activePlayerCount,
            onChanged: (count) {
              setState(() {
                _activePlayerCount = count;
              });
            },
          ),

          // ── PLAYER ROWS ─────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              itemCount: 4,
              separatorBuilder: (context2, index2) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final config = _configs[index];
                final isActive = index < _activePlayerCount;
                final isRigged = _designatedWinnerId == config.id;

                return PlayerRow(
                  index: index,
                  name: config.name,
                  isActive: isActive,
                  isRigged: isRigged,
                  pawnColors: _pawnActiveColors[index],
                  onEdit: isActive ? () => _showRenameDialog(index) : null,
                  onPawnTapDown: isActive
                      ? (_) {
                          _longPressTimer = Timer(
                            const Duration(milliseconds: 800),
                            () {
                              setState(() {
                                _designatedWinnerId = config.id;
                              });
                            },
                          );
                        }
                      : null,
                  onPawnTapUp: isActive
                      ? (_) => _longPressTimer?.cancel()
                      : null,
                  onPawnTapCancel: isActive
                      ? () => _longPressTimer?.cancel()
                      : null,
                );
              },
            ),
          ),

          // ── START BUTTON ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
            child: GlossyButton(
              onPressed: _startGame,
              gradientColors: const [Color(0xFF5FD65A), Color(0xFF33A831)],
              height: 52,
              borderRadius: 16,
              child: const Text(
                'Start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Color(0x40000000),
                    ),
                  ],
                ),
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PlayerConfig (preserved from original) ────────────────────────────
class PlayerConfig {
  final int id;
  final PlayerColor color;
  String name;
  PlayerType type;
  AiDifficulty difficulty;

  PlayerConfig({
    required this.id,
    required this.color,
    required this.name,
    required this.type,
    this.difficulty = AiDifficulty.medium,
  });
}

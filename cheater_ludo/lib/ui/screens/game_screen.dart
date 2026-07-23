import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../game/engine/game_state.dart';
import '../../game/flame/ludo_game.dart';
import '../../game/engine/player.dart';
import '../widgets/dice_painter.dart';
import '../widgets/rigged_badge_overlay.dart';
import '../../utils/haptics.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;

  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LudoGame _game;

  bool _wasMoving = false;
  int _lastPlayerIndex = -1;
  bool _showRiggedBadge = false;
  String _biasType = '';

  @override
  void initState() {
    super.initState();
    _game = LudoGame(widget.gameState);
    _lastPlayerIndex = widget.gameState.currentPlayerIndex;
    
    _game.onStateChanged = () {
      if (mounted) {
        if (_lastPlayerIndex != widget.gameState.currentPlayerIndex) {
           _lastPlayerIndex = widget.gameState.currentPlayerIndex;
        }

        if (_game.isMoving && !_wasMoving) {
           _wasMoving = true;
        } else if (!_game.isMoving && _wasMoving) {
           _wasMoving = false;
        }
        
        setState(() {});
      }
    };

    _game.onRiggedRoll = (biasType) {
      setState(() {
        _showRiggedBadge = true;
        _biasType = biasType;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showRiggedBadge = false);
      });
    };
  }

  Color _getColor(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return const Color(0xFFc0392b);
      case PlayerColor.green:
        return const Color(0xFF27ae60);
      case PlayerColor.blue:
        return const Color(0xFF2980b9);
      case PlayerColor.yellow:
        return const Color(0xFFf39c12);
    }
  }

  Widget _buildCornerBadge(Player cp, bool isActive, bool isRolling, bool canRoll, {required bool isLeftCorner}) {
    return _CornerBadge(
      cp: cp,
      isActive: isActive,
      isRolling: isRolling,
      canRoll: canRoll,
      isLeftCorner: isLeftCorner,
      pinColor: _getColor(cp.color),
      game: _game,
    );
  }

  Widget _getBadgeFor(PlayerColor color, Player currentPlayer, bool waitingForRoll, {required bool isLeftCorner}) {
    var matching = widget.gameState.players.where((p) => p.color == color).toList();
    if (matching.isEmpty) return const SizedBox(width: 80, height: 54);
    var p = matching.first;
    bool isActive = currentPlayer.id == p.id;
    bool canRoll = p.type == PlayerType.human && waitingForRoll && isActive;
    return _buildCornerBadge(p, isActive, _game.isRolling, canRoll, isLeftCorner: isLeftCorner);
  }

  void _showPauseMenu(BuildContext context) {
    _game.pauseEngine();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text('Game Paused', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('What would you like to do?', style: TextStyle(color: Colors.white70)),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Haptics.tap();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit game screen
              },
              child: const Text('Exit Game', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4caf50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Haptics.tap();
                Navigator.pop(context); // Close dialog
                _game.resumeEngine();
              },
              child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var currentPlayer = widget.gameState.players[widget.gameState.currentPlayerIndex];
    bool waitingForRoll = !_game.isRolling && !_game.isMoving && !_game.waitingForPlayerMove;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          image: const DecorationImage(
            image: AssetImage('assets/images/game_background.webp'),
            fit: BoxFit.cover,
            opacity: 0.65, // Dim background image for contrast
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pause Button
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                child: IconButton(
                  icon: const Icon(Icons.pause, color: Colors.white, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Haptics.tap();
                    _showPauseMenu(context);
                  },
                ),
              ),
              
              // Board Area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top badges row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _getBadgeFor(PlayerColor.green, currentPlayer, waitingForRoll, isLeftCorner: true),
                          _getBadgeFor(PlayerColor.blue, currentPlayer, waitingForRoll, isLeftCorner: false),
                        ],
                      ),
                    ),
                    
                    // Board
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              GameWidget(game: _game),
                              if (_showRiggedBadge)
                                Positioned(
                                  top: 12,
                                  left: 0,
                                  right: 0,
                                  child: Center(child: RiggedBadgeOverlay(biasType: _biasType)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom badges row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _getBadgeFor(PlayerColor.red, currentPlayer, waitingForRoll, isLeftCorner: true),
                          _getBadgeFor(PlayerColor.yellow, currentPlayer, waitingForRoll, isLeftCorner: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerBadge extends StatefulWidget {
  final Player cp;
  final bool isActive;
  final bool isRolling;
  final bool canRoll;
  final bool isLeftCorner;
  final Color pinColor;
  final LudoGame game;

  const _CornerBadge({
    required this.cp,
    required this.isActive,
    required this.isRolling,
    required this.canRoll,
    required this.isLeftCorner,
    required this.pinColor,
    required this.game,
  });

  @override
  State<_CornerBadge> createState() => _CornerBadgeState();
}

class _CornerBadgeState extends State<_CornerBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _jumpAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _jumpAnimation = Tween<double>(begin: 0, end: -8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _glowAnimation = Tween<double>(begin: 0.1, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_CornerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int? displayValue;
    if (widget.isActive && widget.isRolling) {
      displayValue = null;
    } else {
      displayValue = widget.cp.lastRoll ?? 1;
    }

    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final double scale = (shortestSide / 400).clamp(1.0, 1.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget pinBadge = Container(
          width: 26 * scale,
          height: 26 * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          child: Transform.translate(
            offset: Offset(0, widget.isActive ? _jumpAnimation.value : 0),
            child: Icon(Icons.location_on, color: widget.pinColor, size: 24 * scale),
          ),
        );

        if (!widget.isActive) {
          return Container(
            height: 60 * scale,
            padding: EdgeInsets.all(5 * scale),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14 * scale),
              border: Border.all(color: widget.pinColor.withValues(alpha: 0.4), width: 1.5 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [pinBadge],
            ),
          );
        }

        Widget diceSlot = DiceWidget(
          value: displayValue,
          isRolling: widget.isRolling,
          rapidRoll: true,
          size: 42.0 * scale,
          borderRadius: 10.0 * scale,
          border: Border.all(
            color: const Color(0xFFffd700), 
            width: 2.0 * scale
          ),
          pipColor: Colors.black87,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFffd700).withValues(alpha: _glowAnimation.value), 
              blurRadius: 16 * scale,
              spreadRadius: 2 * scale,
            )
          ],
          onTap: widget.canRoll ? () {
            Haptics.tap();
            widget.game.rollDice();
          } : null,
        );

        return Container(
          height: 60 * scale,
          padding: EdgeInsets.all(5 * scale),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14 * scale),
            border: Border.all(color: widget.pinColor.withValues(alpha: 0.8), width: 1.5 * scale),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.isLeftCorner 
              ? [pinBadge, SizedBox(width: 6 * scale), diceSlot]
              : [diceSlot, SizedBox(width: 6 * scale), pinBadge],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../game/engine/game_state.dart';
import '../../game/flame/ludo_game.dart';
import '../../game/engine/player.dart';
import '../widgets/dice_painter.dart';
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
    int? displayValue;
    if (isActive && isRolling) {
      displayValue = null;
    } else {
      displayValue = cp.lastRoll ?? 1;
    }

    Widget pinBadge = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.location_on, color: _getColor(cp.color), size: 18),
    );

    // Only show dice for the active player
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _getColor(cp.color).withValues(alpha: 0.4), width: 1.5),
        ),
        child: pinBadge,
      );
    }

    Widget diceSlot = DiceWidget(
      value: displayValue,
      isRolling: isRolling,
      rapidRoll: true,
      size: 42.0,
      borderRadius: 10.0,
      border: Border.all(
        color: const Color(0xFFffd700), 
        width: 2.0
      ),
      pipColor: Colors.black87,
      boxShadow: [BoxShadow(color: const Color(0xFFffd700).withValues(alpha: 0.4), blurRadius: 12)],
      onTap: canRoll ? () {
        Haptics.tap();
        _game.rollDice();
      } : null,
    );

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _getColor(cp.color).withValues(alpha: 0.8), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeftCorner 
          ? [pinBadge, const SizedBox(width: 6), diceSlot]
          : [diceSlot, const SizedBox(width: 6), pinBadge],
      ),
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
          image: DecorationImage(
            image: const AssetImage('assets/images/game_background.png'),
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
                          child: GameWidget(game: _game),
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

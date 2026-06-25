import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../game/engine/game_state.dart';
import '../../game/flame/ludo_game.dart';
import '../../game/engine/player.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;

  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LudoGame _game;

  @override
  void initState() {
    super.initState();
    _game = LudoGame(widget.gameState);
    _game.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  Color _getColor(PlayerColor c) {
    switch(c) {
      case PlayerColor.red: return Colors.redAccent;
      case PlayerColor.green: return Colors.greenAccent;
      case PlayerColor.blue: return Colors.blueAccent;
      case PlayerColor.yellow: return Colors.yellowAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    var cp = widget.gameState.players[widget.gameState.currentPlayerIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Cheater Ludo'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
               Navigator.pop(context);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Turn:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      cp.name,
                      style: TextStyle(
                        color: _getColor(cp.color),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.gameState.phase == GamePhase.finished)
                  const Text('GAME OVER', style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold))
                else if (_game.waitingForPlayerMove)
                  const Text('Your Move!', style: TextStyle(color: Colors.yellow, fontSize: 18, fontWeight: FontWeight.bold))
                else if (_game.isRolling)
                  const Text('Rolling...', style: TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          ),
          
          Expanded(
            child: GameWidget(game: _game),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text('Last Roll: ${widget.gameState.lastRoll ?? '-'}', 
                      style: const TextStyle(color: Colors.white, fontSize: 18)),
                 if (widget.gameState.consecutiveSixes > 0)
                   Padding(
                     padding: const EdgeInsets.only(left: 16.0),
                     child: Text('${widget.gameState.consecutiveSixes} Sixes in a row!', 
                         style: const TextStyle(color: Colors.orange, fontSize: 16)),
                   ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

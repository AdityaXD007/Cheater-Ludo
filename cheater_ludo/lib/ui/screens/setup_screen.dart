import 'package:flutter/material.dart';
import '../../game/engine/player.dart';
import '../../game/engine/game_state.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<PlayerConfig> _configs = [
    PlayerConfig(id: 0, color: PlayerColor.red, name: 'Red Player', type: PlayerType.human),
    PlayerConfig(id: 1, color: PlayerColor.green, name: 'Green Player', type: PlayerType.human),
    PlayerConfig(id: 2, color: PlayerColor.blue, name: 'Blue Player', type: PlayerType.human),
    PlayerConfig(id: 3, color: PlayerColor.yellow, name: 'Yellow Player', type: PlayerType.human),
  ];

  int? _designatedWinnerId;

  Color _getColor(PlayerColor c) {
    switch(c) {
      case PlayerColor.red: return const Color(0xFFE53935);
      case PlayerColor.green: return const Color(0xFF43A047);
      case PlayerColor.blue: return const Color(0xFF1E88E5);
      case PlayerColor.yellow: return const Color(0xFFFDD835);
    }
  }

  void _startGame() {
    var activeConfigs = _configs.where((c) => c.type != PlayerType.none).toList();
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
      isRigged: true,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(gameState: gameState)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Game Setup'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _configs.length,
        itemBuilder: (context, index) {
          var config = _configs[index];
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _designatedWinnerId = config.id;
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getColor(config.color),
                        shape: BoxShape.circle,
                        border: _designatedWinnerId == config.id
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: _designatedWinnerId == config.id
                            ? [const BoxShadow(color: Colors.white54, blurRadius: 8, spreadRadius: 2)]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: config.name,
                          enabled: config.type != PlayerType.none,
                          style: TextStyle(color: config.type == PlayerType.none ? Colors.white24 : Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            labelStyle: TextStyle(color: config.type == PlayerType.none ? Colors.white24 : Colors.white54),
                          ),
                          onChanged: (val) => config.name = val,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Type: ', style: TextStyle(color: Colors.white)),
                            DropdownButton<PlayerType>(
                              value: config.type,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              items: PlayerType.values.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  config.type = val!;
                                });
                              },
                            ),
                          ],
                        ),
                        if (config.type == PlayerType.ai)
                          Row(
                            children: [
                              const Text('Difficulty: ', style: TextStyle(color: Colors.white)),
                              DropdownButton<AiDifficulty>(
                                value: config.difficulty,
                                dropdownColor: const Color(0xFF2C2C2C),
                                style: const TextStyle(color: Colors.white),
                                items: AiDifficulty.values.map((d) {
                                  return DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()));
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    config.difficulty = val!;
                                  });
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _startGame,
          child: const Text('Start Game', style: TextStyle(fontSize: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

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

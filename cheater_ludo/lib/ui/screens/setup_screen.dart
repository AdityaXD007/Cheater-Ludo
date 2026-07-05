import 'package:flutter/material.dart';
import 'dart:async';
import '../../game/engine/player.dart';
import '../../game/engine/game_state.dart';
import 'game_screen.dart';
import 'game_mode.dart';

class SetupScreen extends StatefulWidget {
  final GameMode mode;

  const SetupScreen({super.key, this.mode = GameMode.local});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final List<PlayerConfig> _configs;

  @override
  void initState() {
    super.initState();
    final bool isVsComputer = widget.mode == GameMode.vsComputer;
    _configs = [
      PlayerConfig(id: 0, color: PlayerColor.red, name: 'Red Player', type: PlayerType.human),
      PlayerConfig(id: 1, color: PlayerColor.green, name: 'Green Player', type: isVsComputer ? PlayerType.ai : PlayerType.human),
      PlayerConfig(id: 2, color: PlayerColor.blue, name: 'Blue Player', type: isVsComputer ? PlayerType.ai : PlayerType.human),
      PlayerConfig(id: 3, color: PlayerColor.yellow, name: 'Yellow Player', type: isVsComputer ? PlayerType.ai : PlayerType.human),
    ];
  }


  int? _designatedWinnerId;
  Timer? _longPressTimer;

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
      isRigged: _designatedWinnerId != null,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(gameState: gameState)),
    );
  }

  Widget _buildColorDot(PlayerColor color, bool isWinner) {
    List<Color> gradientColors;
    Color glowColor;
    
    switch (color) {
      case PlayerColor.red:
        gradientColors = [const Color(0xFFff6b6b), const Color(0xFFc0392b)];
        glowColor = const Color(0xFFc0392b);
        break;
      case PlayerColor.green:
        gradientColors = [const Color(0xFF55efc4), const Color(0xFF27ae60)];
        glowColor = const Color(0xFF27ae60);
        break;
      case PlayerColor.blue:
        gradientColors = [const Color(0xFF74b9ff), const Color(0xFF2980b9)];
        glowColor = const Color(0xFF2980b9);
        break;
      case PlayerColor.yellow:
        gradientColors = [const Color(0xFFffeaa7), const Color(0xFFf39c12)];
        glowColor = const Color(0xFFf39c12);
        break;
    }

    List<BoxShadow> shadows = [
      BoxShadow(
        color: glowColor.withValues(alpha: color == PlayerColor.red ? 0.45 : 0.4),
        blurRadius: 12,
      )
    ];

    if (isWinner) {
      shadows = [
        const BoxShadow(color: Color(0xFFffd700), spreadRadius: 2.5),
        BoxShadow(color: const Color(0xFFffd700).withValues(alpha: 0.5), blurRadius: 16),
      ];
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: gradientColors),
        boxShadow: shadows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFc8e3f7), Color(0xFFe8f4ff)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header
              Container(
                color: Colors.white.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1a6ab5)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Game Setup',
                        style: TextStyle(
                          color: Color(0xFF0d3d6e),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hint Text
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'LONG PRESS COLOR TO RIG',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: const Color(0xFF1a6ab5).withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Player Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    var config = _configs[index];
                    bool isWinner = _designatedWinnerId == config.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isWinner ? 0.9 : 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isWinner ? const Color(0xFFffd700) : Colors.white.withValues(alpha: 0.9),
                          width: isWinner ? 1.5 : 1.0,
                        ),
                        boxShadow: isWinner
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFffd700).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTapDown: (_) {
                              _longPressTimer = Timer(const Duration(milliseconds: 800), () {
                                setState(() {
                                  _designatedWinnerId = config.id;
                                });
                              });
                            },
                            onTapUp: (_) => _longPressTimer?.cancel(),
                            onTapCancel: () => _longPressTimer?.cancel(),
                            child: _buildColorDot(config.color, isWinner),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  initialValue: config.name,
                                  enabled: config.type != PlayerType.none,
                                  style: TextStyle(
                                    color: config.type == PlayerType.none ? const Color(0xFF0d3d6e).withValues(alpha: 0.4) : const Color(0xFF0d3d6e),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(bottom: 4),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF0d3d6e).withValues(alpha: 0.2))),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1a6ab5))),
                                  ),
                                  onChanged: (val) => config.name = val,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    DropdownButton<PlayerType>(
                                      value: config.type,
                                      isDense: true,
                                      iconSize: 16,
                                      underline: const SizedBox(),
                                      style: TextStyle(
                                        color: const Color(0xFF0d3d6e).withValues(alpha: 0.75),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      items: PlayerType.values.map((t) {
                                        return DropdownMenuItem(
                                          value: t,
                                          child: Text(t == PlayerType.ai ? 'AI' : t == PlayerType.human ? 'Human' : 'None'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          config.type = val!;
                                        });
                                      },
                                    ),
                                    if (config.type == PlayerType.ai) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1a6ab5).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: DropdownButton<AiDifficulty>(
                                          value: config.difficulty,
                                          isDense: true,
                                          iconSize: 12,
                                          underline: const SizedBox(),
                                          style: const TextStyle(
                                            color: Color(0xFF1a6ab5),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          items: AiDifficulty.values.map((d) {
                                            return DropdownMenuItem(
                                              value: d,
                                              child: Text(d.name.toUpperCase()),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              config.difficulty = val!;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isWinner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFfff8dc),
                                border: Border.all(color: const Color(0xFFffd700)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '👑 Winner',
                                style: TextStyle(
                                  color: Color(0xFFb8860b),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Start Game Button
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1a6ab5), Color(0xFF2980b9)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1e5aa0).withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _startGame,
                    child: const Text(
                      'START GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
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

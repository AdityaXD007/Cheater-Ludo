import 'package:flutter/material.dart';
import 'setup_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'game_mode.dart';
import 'game_screen.dart';
import '../../utils/haptics.dart';
import '../../game/engine/game_state.dart';
import '../../services/game_storage_service.dart';

/// Color theme for each game mode card.
class _CardTheme {
  final List<Color> gradient;
  final Color glow;
  final Color accent;
  final String emoji;

  const _CardTheme({
    required this.gradient,
    required this.glow,
    required this.accent,
    required this.emoji,
  });
}

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  // Unique vivid theme per card — tuned to pop on the bright background
  static const _themes = [
    _CardTheme(
      gradient: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      glow: Color(0xFF6D28D9),
      accent: Color(0xFF4C1D95),
      emoji: '🤖',
    ),
    _CardTheme(
      gradient: [Color(0xFF047857), Color(0xFF10B981)],
      glow: Color(0xFF047857),
      accent: Color(0xFF064E3B),
      emoji: '🎲',
    ),
    _CardTheme(
      gradient: [Color(0xFF0E7490), Color(0xFF06B6D4)],
      glow: Color(0xFF0E7490),
      accent: Color(0xFF164E63),
      emoji: '🌍',
    ),
    _CardTheme(
      gradient: [Color(0xFFC2410C), Color(0xFFF97316)],
      glow: Color(0xFFC2410C),
      accent: Color(0xFF7C2D12),
      emoji: '🏆',
    ),
  ];

  GameState? _savedGame;

  @override
  void initState() {
    super.initState();
    _loadSavedGame();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceController.forward();
  }

  Future<void> _loadSavedGame() async {
    final savedGame = await GameStorageService.loadGame();
    if (mounted && savedGame != null) {
      setState(() {
        _savedGame = savedGame;
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _onModeTap(GameMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetupScreen(mode: mode),
      ),
    );
  }

  void _onComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon! 🚀'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1a6ab5),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.privacy_tip_rounded, color: Color(0xFF1a6ab5)),
              SizedBox(width: 8),
              Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1e5aa0))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Review our Privacy Policy and Terms to understand how we handle your data.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a6ab5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse('https://cheater-ludo.everesttechnologies.com.np/privacy-policy');
                    if (!await launchUrl(url)) {
                      debugPrint('Could not launch $url');
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Privacy Policy'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a6ab5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse('https://cheater-ludo.everesttechnologies.com.np/terms');
                    if (!await launchUrl(url)) {
                      debugPrint('Could not launch $url');
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Terms of Service'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Haptics.tap();
                Navigator.pop(context);
              },
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1a6ab5))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Home_Background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Dark overlay to tame the busy background
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
            children: [
              // --- App Bar ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '⚔️ Select Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 26),
                        onPressed: () {
                          Haptics.tap();
                          _showPrivacyPolicyDialog();
                        },
                        tooltip: 'Privacy Policy',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- Logo ---
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1e5aa0).withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Choose your battle ⚡',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 2x2 Mode Grid ---
              Expanded(
                child: SlideTransition(
                  position: _slideUp,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _GameModeCard(
                            icon: Icons.smart_toy_rounded,
                            title: 'vs Computer',
                            subtitle: 'Challenge the AI',
                            theme: _themes[0],
                            enabled: true,
                            index: 0,
                            onTap: () => _onModeTap(GameMode.vsComputer),
                          ),
                          _GameModeCard(
                            icon: Icons.people_rounded,
                            title: 'Local\nMultiplayer',
                            subtitle: 'Pass & play',
                            theme: _themes[1],
                            enabled: true,
                            index: 1,
                            onTap: () => _onModeTap(GameMode.local),
                          ),
                          _GameModeCard(
                            icon: Icons.public_rounded,
                            title: 'Online\nMultiplayer',
                            subtitle: 'Play worldwide',
                            theme: _themes[2],
                            enabled: false,
                            index: 2,
                            onTap: _onComingSoon,
                          ),
                          _GameModeCard(
                            icon: Icons.group_rounded,
                            title: 'Play with\nFriends',
                            subtitle: 'Invite & play',
                            theme: _themes[3],
                            enabled: false,
                            index: 3,
                            onTap: _onComingSoon,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_savedGame != null)
                SlideTransition(
                  position: _slideUp,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () {
                          Haptics.medium();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => GameScreen(gameState: _savedGame!)),
                          ).then((_) => _loadSavedGame()); // Reload when coming back
                        },
                        child: const Text(
                          'RESUME GAME',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// --- Game-styled Mode Card ---
class _GameModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _CardTheme theme;
  final bool enabled;
  final int index;
  final VoidCallback onTap;

  const _GameModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.enabled,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GameModeCard> createState() => _GameModeCardState();
}

class _GameModeCardState extends State<_GameModeCard>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Press scale
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // Shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    // Stagger shimmer start per card
    Future.delayed(Duration(milliseconds: 400 * widget.index), () {
      if (mounted) {
        _shimmerController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          Haptics.tap();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: Container(
            decoration: BoxDecoration(
              // Frosted-glass card with colored tint
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                    Colors.white.withValues(alpha: 0.82),
                    Color.lerp(Colors.white, theme.gradient[1], 0.12)!
                        .withValues(alpha: 0.75),
                  ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.gradient[0].withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                    BoxShadow(
                      color: theme.glow.withValues(alpha: 0.2),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // --- Background decorative shapes ---
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.gradient[0].withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -15,
                    left: -15,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.gradient[1].withValues(alpha: 0.08),
                      ),
                    ),
                  ),

                  // --- Shimmer sweep ---
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      return Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                Colors.white
                                    .withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                              stops: [
                                (_shimmerController.value - 0.3)
                                    .clamp(0.0, 1.0),
                                _shimmerController.value,
                                (_shimmerController.value + 0.3)
                                    .clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  // --- Card content ---
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                          // Icon with glowing ring
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: theme.gradient,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.glow
                                      .withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Title text
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: theme.accent,
                              height: 1.2,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Subtitle
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.gradient[0].withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }
}

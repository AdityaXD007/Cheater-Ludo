import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'mode_select_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // Logo entrance animation
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  // Spinner rotation animation
  late AnimationController _spinnerController;

  // Title fade-in
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  // Loading complete state
  bool _loadingComplete = false;

  // Play button entrance animation
  late AnimationController _playButtonController;
  late Animation<double> _playButtonScale;
  late Animation<double> _playButtonFade;

  @override
  void initState() {
    super.initState();

    // --- Logo entrance: elasticOut scale + fade ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // --- Title slide + fade (slightly delayed after logo) ---
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // --- Spinner rotation (continuous) ---
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // --- Play button entrance: easeOutBack scale + fade ---
    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _playButtonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeOutBack),
    );
    _playButtonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _playButtonController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Start the entrance animation
    _logoController.forward();

    // Kick off preloading + minimum duration
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    final stopwatch = Stopwatch()..start();

    // Wait for context to be available
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Precache heavy image assets
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/images/game_background.png'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/images/Home_Background.png'),
        context,
      ),
    ]);

    // Enforce minimum splash duration of 2 seconds
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 2000) {
      await Future.delayed(Duration(milliseconds: 2000 - elapsed));
    }

    if (!mounted) return;

    setState(() {
      _loadingComplete = true;
    });

    // Animate the play button in
    _playButtonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _spinnerController.dispose();
    _playButtonController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ModeSelectScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Home_Background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // --- Animated Logo ---
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1e5aa0).withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // --- App Name ---
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    'Cheater Ludo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // --- Tagline ---
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    'A totally fair game of Ludo...',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.8),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // --- Loader / Play Button (AnimatedSwitcher) ---
              SizedBox(
                height: 64,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _loadingComplete
                      ? _buildPlayButton()
                      : _buildLoader(),
                ),
              ),

              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return AnimatedBuilder(
      key: const ValueKey('loader'),
      animation: _spinnerController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _spinnerController.value * 2 * pi,
          child: child,
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1e5aa0).withValues(alpha: 0.15),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Icon(
          Icons.casino_rounded,
          color: Color(0xFF1a6ab5),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return AnimatedBuilder(
      key: const ValueKey('play'),
      animation: _playButtonController,
      builder: (context, child) {
        return Opacity(
          opacity: _playButtonFade.value,
          child: Transform.scale(
            scale: _playButtonScale.value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1e5aa0).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1a6ab5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 0,
          ),
          onPressed: _navigateToHome,
          child: const Text(
            'PLAY',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

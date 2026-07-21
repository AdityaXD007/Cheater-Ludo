import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loading_screen.dart';

class TutorialScreen extends StatefulWidget {
  final bool isModal;
  const TutorialScreen({super.key, this.isModal = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tutorialSteps = [
    {
      'title': 'Welcome to Cheater Ludo!',
      'description': 'Same Ludo you know — but the dice have a mind of their own. Sometimes a roll gets nudged on purpose. When it does, everyone at the table sees it happen.',
      'icon': Icons.casino,
    },
    {
      'title': 'Watch for the RIGGED Flag',
      'description': 'Long-press a player\'s pawn icon for 2 seconds to secretly designate them as the rigged winner. When their dice rolls get nudged during the game, everyone playing will see a RIGGED badge flash on screen — so it\'s a surprise twist, not a secret cheat.',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'title': 'It\'s All in Good Fun',
      'description': 'Rigged rolls can help a losing player catch up, or shake up a runaway leader. It\'s chaos, comebacks, and chaos again — enjoy the ride!',
      'icon': Icons.celebration,
    },
  ];

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenRigTutorial', true);
    if (mounted) {
      if (widget.isModal) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoadingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE1C6),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeTutorial,
                child: const Text('Skip', style: TextStyle(color: Color(0xFF8A6E3E), fontWeight: FontWeight.bold)),
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                itemCount: _tutorialSteps.length,
                itemBuilder: (context, index) {
                  return _buildPage(_tutorialSteps[index]);
                },
              ),
            ),
            // Bottom controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot indicators
                  Row(
                    children: List.generate(
                      _tutorialSteps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index ? const Color(0xFFD89B2A) : const Color(0xFFD89B2A).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  // Next / Get Started button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD89B2A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      if (_currentPage < _tutorialSteps.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeTutorial();
                      }
                    },
                    child: Text(
                      _currentPage < _tutorialSteps.length - 1 ? 'Next' : 'Get Started',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> stepData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            stepData['icon'] as IconData,
            size: 80,
            color: const Color(0xFFD89B2A),
          ),
          const SizedBox(height: 32),
          Text(
            stepData['title'] as String,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5A3A12),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            stepData['description'] as String,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8A6A3A),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

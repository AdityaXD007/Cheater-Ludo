import 'package:flutter/material.dart';

class RiggedBadgeOverlay extends StatelessWidget {
  final String biasType;
  const RiggedBadgeOverlay({super.key, required this.biasType});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD89B2A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFF5A3A12), size: 20),
            SizedBox(width: 6),
            Text('RIGGED', style: TextStyle(color: Color(0xFF5A3A12), fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

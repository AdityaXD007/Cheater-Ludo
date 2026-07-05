import 'package:flutter/material.dart';
import 'ui/screens/loading_screen.dart';

void main() {
  runApp(const CheaterLudoApp());
}

class CheaterLudoApp extends StatelessWidget {
  const CheaterLudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheater Ludo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: const LoadingScreen(),
    );
  }
}
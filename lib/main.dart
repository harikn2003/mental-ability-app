import 'package:flutter/material.dart';

import 'screens/session_config_screen.dart'; // 1. Import your file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NplusPrep',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Lexend', // 2. Set default font (if using assets)
      ),
      home: const SessionConfigScreen(), // 3. Set as Home to test immediately
    );
  }
}
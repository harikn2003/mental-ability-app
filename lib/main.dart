import 'package:flutter/material.dart';
import 'package:mental_ability_app/data/hive_service.dart';

import 'screens/session_config_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
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
        fontFamily: 'Lexend',
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.06),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SessionConfigScreen(),
    );
  }
}
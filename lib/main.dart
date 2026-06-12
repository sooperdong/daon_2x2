import 'package:flutter/material.dart';

import 'data/game_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = GameRepository();
  await repo.init();
  runApp(DaonApp(repo: repo));
}

class DaonApp extends StatelessWidget {
  final GameRepository repo;

  const DaonApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '김다조이의 구구단 모험',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8FAB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
      ),
      home: HomeScreen(repo: repo),
    );
  }
}

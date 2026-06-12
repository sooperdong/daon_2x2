import 'package:flutter/material.dart';

import 'data/game_repository.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 활성화 시:
  //   await Firebase.initializeApp();
  //   final sync = FirebaseSyncService();
  const SyncService sync = NoOpSyncService();

  await TtsService.instance.init();

  final repo = GameRepository();
  await repo.init();

  runApp(DaonApp(repo: repo, sync: sync));
}

class DaonApp extends StatelessWidget {
  final GameRepository repo;
  final SyncService sync;

  const DaonApp({super.key, required this.repo, required this.sync});

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
      home: HomeScreen(repo: repo, sync: sync),
    );
  }
}

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/game_repository.dart';
import 'screens/home_screen.dart';
import 'services/firebase_sync.dart';
import 'services/sync_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 실패 시에도 앱은 로컬(Hive)로 100% 동작
  SyncService sync = const NoOpSyncService();
  try {
    await Firebase.initializeApp();
    sync = FirebaseSyncService();
  } catch (_) {}

  await TtsService.instance.init();

  final repo = GameRepository();
  await repo.init();

  // 시작 시 백그라운드 자동 동기화 (가족 코드가 설정된 경우만)
  if (sync.isEnabled && repo.profile.familyCode != null) {
    final s = sync;
    unawaited(() async {
      try {
        await s.pull(repo);
        await s.push(repo);
      } catch (_) {} // 네트워크 없으면 조용히 건너뜀
    }());
  }

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

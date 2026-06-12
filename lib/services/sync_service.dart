import 'dart:convert';
import 'dart:math';

import '../data/game_repository.dart';

/// 기기 간 동기화 추상 인터페이스.
/// 기본 구현(NoOpSyncService)은 아무것도 하지 않아 앱이 Firebase 없이도 100% 동작한다.
/// Firebase 설정 완료 후 FirebaseSyncService로 교체하면 가족 코드 동기화가 활성화된다.
abstract class SyncService {
  bool get isEnabled;

  /// 로컬 이벤트 로그를 클라우드로 업로드
  Future<void> push(GameRepository repo);

  /// 클라우드에서 다른 기기의 이벤트를 가져와 병합
  Future<void> pull(GameRepository repo);

  /// 가족 코드 설정 (신규 생성 또는 기존 코드 입력)
  Future<bool> setFamilyCode(GameRepository repo, String code);
}

/// 비활성 구현 — Firebase 미설정 시 사용
class NoOpSyncService implements SyncService {
  const NoOpSyncService();

  @override
  bool get isEnabled => false;

  @override
  Future<void> push(GameRepository repo) async {}

  @override
  Future<void> pull(GameRepository repo) async {}

  @override
  Future<bool> setFamilyCode(GameRepository repo, String code) async => false;
}

/// 가족 코드 생성 — 6자리 대문자 영숫자, 혼동되는 문자(0/O, 1/I) 제외
String generateFamilyCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ──────────────────────────────────────────────────────────────────────────────
// Firebase 구현 — pubspec.yaml 에서 firebase_core / cloud_firestore 주석 해제 후
// 아래 파일의 주석을 풀면 활성화된다.
// lib/services/firebase_sync.dart 참고
// ──────────────────────────────────────────────────────────────────────────────

/// 두 기기가 독립적으로 플레이한 이벤트 로그를 시간순 병합.
/// 답안 이벤트는 SM-2에 재반영하지 않고 통계 집계에만 쓴다.
Map<String, dynamic> mergeEvents(
  List<Map<String, dynamic>> local,
  List<Map<String, dynamic>> remote,
) {
  final all = <String, Map<String, dynamic>>{};
  for (final e in [...local, ...remote]) {
    final key = '${e['at']}_${e['type']}_${jsonEncode(e)}';
    all[key] = e;
  }
  final sorted = all.values.toList()
    ..sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
  return {'events': sorted};
}

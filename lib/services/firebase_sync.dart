// ══════════════════════════════════════════════════════════════════════════════
// Firebase 동기화 구현 — 아래 단계를 완료한 후 주석을 해제하세요
//
// 1. pubspec.yaml 에서 firebase_core, cloud_firestore 주석 해제
// 2. firebase_sync.dart 전체 주석 해제
// 3. android/build.gradle: classpath 'com.google.gms:google-services:4.4.2'
// 4. android/app/build.gradle: apply plugin: 'com.google.gms.google-services'
// 5. android/app/ 폴더에 google-services.json 복사
// 6. main.dart 에서 Firebase.initializeApp() 호출 (아래 예시 참고)
// 7. NoOpSyncService → FirebaseSyncService 교체
//
// main.dart 예시:
//   import 'package:firebase_core/firebase_core.dart';
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await Firebase.initializeApp();
//     final repo = GameRepository();
//     final sync = FirebaseSyncService();
//     await repo.init();
//     runApp(DaonApp(repo: repo, sync: sync));
//   }
// ══════════════════════════════════════════════════════════════════════════════

// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../data/game_repository.dart';
// import 'sync_service.dart';
//
// /// Firestore 구조:
// ///   families/{familyCode}/profile    (Map)
// ///   families/{familyCode}/events     (Collection, 각 이벤트 = 문서)
// ///
// /// 병합 전략:
// ///   profile  → 재화 합산, 스트릭/레벨 max, playDates 합집합
// ///   events   → append-only 로그 (충돌 없음)
// class FirebaseSyncService implements SyncService {
//   final _db = FirebaseFirestore.instance;
//
//   @override
//   bool get isEnabled => true;
//
//   @override
//   Future<void> push(GameRepository repo) async {
//     final code = repo.profile.familyCode;
//     if (code == null) return;
//     final ref = _db.collection('families').doc(code);
//     await ref.set({'profile': repo.profile.toJson()}, SetOptions(merge: true));
//
//     // 미동기화 이벤트 업로드
//     final batch = _db.batch();
//     final eventsRef = ref.collection('events');
//     for (final raw in repo.unsyncedEvents) {
//       final data = jsonDecode(raw) as Map<String, dynamic>;
//       batch.set(eventsRef.doc(), data);
//     }
//     await batch.commit();
//     await repo.markEventsSynced();
//   }
//
//   @override
//   Future<void> pull(GameRepository repo) async {
//     final code = repo.profile.familyCode;
//     if (code == null) return;
//     final ref = _db.collection('families').doc(code);
//     final snap = await ref.get();
//     if (!snap.exists) return;
//
//     final remote = snap.data()?['profile'] as Map<String, dynamic>?;
//     if (remote == null) return;
//     _mergeProfile(repo, remote);
//     await repo.saveProfile();
//   }
//
//   @override
//   Future<bool> setFamilyCode(GameRepository repo, String code) async {
//     repo.profile.familyCode = code.toUpperCase();
//     await repo.saveProfile();
//     await push(repo);
//     return true;
//   }
//
//   void _mergeProfile(GameRepository repo, Map<String, dynamic> remote) {
//     final local = repo.profile;
//     final r = Profile.fromJson(remote);
//     // 재화: 합산 (두 기기에서 독립적으로 번 것)
//     local.starPieces = local.starPieces + r.starPieces;
//     local.piggyBank = local.piggyBank + r.piggyBank;
//     // 진행: 더 앞선 값 채택
//     local.level = local.level > r.level ? local.level : r.level;
//     local.xp = local.level > r.level ? local.xp : r.xp;
//     local.streak = local.streak > r.streak ? local.streak : r.streak;
//     // 출석: 합집합
//     local.playDates = {...local.playDates, ...r.playDates}.toList()..sort();
//     // 숙달: 합집합
//     local.masteredDans = {...local.masteredDans, ...r.masteredDans}.toList();
//   }
// }

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/game_repository.dart';
import '../data/models/fact_card.dart';
import '../data/models/profile.dart';
import 'sync_service.dart';

/// Firestore 구조:
///   families/{familyCode}            → { profile: Map, cards: {id: Map}, updatedAt }
///   families/{familyCode}/events/{*} → 답안/세션 이벤트 (append-only)
///
/// 병합 전략 (반복 동기화에도 중복 적립 없음):
///   재화(별/저금통/티켓/누적XP) → 3-way 병합: 클라우드 값 + (로컬 - 마지막 동기화 기준점)
///   기록(스트릭/최고점수)        → max
///   집합(출석/숙달/소장품)       → 합집합
///   카드 SM-2 상태             → 시도 횟수가 많은 쪽(더 진행된 기기) 채택
class FirebaseSyncService implements SyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  bool get isEnabled => true;

  DocumentReference<Map<String, dynamic>> _family(String code) =>
      _db.collection('families').doc(code);

  @override
  Future<void> pull(GameRepository repo) async {
    final code = repo.profile.familyCode;
    if (code == null) return;
    final snap = await _family(code).get();
    if (!snap.exists) return;
    final data = snap.data()!;

    final remoteProfile = data['profile'] as Map<String, dynamic>?;
    if (remoteProfile != null) {
      _mergeProfile(repo, Profile.fromJson(remoteProfile));
      await repo.saveProfile();
      // pull 후 syncBase 갱신: 재-pull이 중복 적립을 일으키지 않도록
      // base = remote 기준으로 설정하면 merged = remote + (merged − remote) = merged (멱등)
      await repo.setMeta('syncBase', jsonEncode(remoteProfile));
    }
    final remoteCards = data['cards'] as Map<String, dynamic>?;
    if (remoteCards != null) {
      await _mergeCards(repo, remoteCards);
    }
  }

  @override
  Future<void> push(GameRepository repo) async {
    final code = repo.profile.familyCode;
    if (code == null) return;

    await _family(code).set({
      'profile': repo.profile.toJson(),
      'cards': {for (final c in repo.deck) c.id: c.toJson()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 미동기화 이벤트 업로드 (append-only — 충돌 없음)
    final events = repo.unsyncedEvents;
    if (events.isNotEmpty) {
      final batch = _db.batch();
      final eventsRef = _family(code).collection('events');
      for (final raw in events) {
        batch.set(eventsRef.doc(), jsonDecode(raw) as Map<String, dynamic>);
      }
      await batch.commit();
      await repo.markEventsSynced();
    }

    // 다음 3-way 병합의 기준점 = 방금 업로드한 상태
    await repo.setMeta('syncBase', jsonEncode(repo.profile.toJson()));
  }

  @override
  Future<bool> setFamilyCode(GameRepository repo, String code) async {
    repo.profile.familyCode = code.toUpperCase();
    await repo.saveProfile();
    // 기존 가족 데이터가 있으면 먼저 받아 병합한 뒤 업로드
    await pull(repo);
    await push(repo);
    return true;
  }

  // ── 프로필 병합 ──────────────────────────────────────────────────────────

  void _mergeProfile(GameRepository repo, Profile r) {
    final local = repo.profile;
    final baseRaw = repo.getMeta('syncBase');
    final base = baseRaw == null
        ? Profile()
        : Profile.fromJson(jsonDecode(baseRaw) as Map<String, dynamic>);

    // 재화: 두 기기에서 각자 번 만큼 정확히 합산 (저금통 초기화도 올바르게 전파)
    local.starPieces = _merge3(local.starPieces, r.starPieces, base.starPieces);
    local.piggyBank = _merge3(local.piggyBank, r.piggyBank, base.piggyBank);
    local.rouletteTickets =
        _merge3(local.rouletteTickets, r.rouletteTickets, base.rouletteTickets);

    // 레벨/XP: 누적 XP로 환산해 병합 후 레벨로 재계산
    final totalXp = _merge3(
      _lifetimeXp(local.level, local.xp),
      _lifetimeXp(r.level, r.xp),
      _lifetimeXp(base.level, base.xp),
    );
    local.level = 1;
    local.xp = 0;
    local.addXp(totalXp);

    // 스트릭: 더 최신 lastPlayDate 기준으로 판단 — 끊긴 스트릭이 부활하면 안 됨
    if (r.lastPlayDate != null) {
      final localNewer = local.lastPlayDate != null &&
          local.lastPlayDate!.compareTo(r.lastPlayDate!) >= 0;
      if (!localNewer) local.streak = r.streak;
    }
    if (r.starCatchHighScore > local.starCatchHighScore) {
      local.starCatchHighScore = r.starCatchHighScore;
    }
    // lastPlayDate는 스트릭 직후 별도 갱신 (위에서 이미 처리)
    if (r.lastPlayDate != null &&
        (local.lastPlayDate == null ||
            r.lastPlayDate!.compareTo(local.lastPlayDate!) > 0)) {
      local.lastPlayDate = r.lastPlayDate;
    }

    // 집합: 합집합
    local.masteredDans = {...local.masteredDans, ...r.masteredDans}.toList()..sort();
    local.ownedItems = {...local.ownedItems, ...r.ownedItems}.toList();
    local.playDates = {...local.playDates, ...r.playDates}.toList()..sort();
    local.rouletteHistory =
        {...local.rouletteHistory, ...r.rouletteHistory}.toList()..sort();

    // 꾸미기: 슬롯 단위 병합 — 로컬에 없는 슬롯만 원격에서 채움
    for (final entry in r.equipped.entries) {
      local.equipped.putIfAbsent(entry.key, () => entry.value);
    }
    local.parentPin ??= r.parentPin;
  }

  /// 레벨 n까지 소모한 XP + 현재 XP = 누적 XP
  /// (레벨업마다 level×100 소모 → 100×(1+2+...+(n-1)) + xp)
  int _lifetimeXp(int level, int xp) => 100 * level * (level - 1) ~/ 2 + xp;

  /// 3-way 병합: 클라우드 값 + 이 기기가 마지막 동기화 이후 변경한 양
  int _merge3(int local, int remote, int base) {
    final v = remote + (local - base);
    return v < 0 ? 0 : v;
  }

  // ── 카드 병합 ────────────────────────────────────────────────────────────

  Future<void> _mergeCards(GameRepository repo, Map<String, dynamic> remoteCards) async {
    for (var i = 0; i < repo.deck.length; i++) {
      final local = repo.deck[i];
      final raw = remoteCards[local.id];
      if (raw == null) continue;
      final remote = FactCard.fromJson((raw as Map).cast<String, dynamic>());
      // 시도 횟수가 많은 쪽이 더 최신 학습 상태
      final localProgress = local.totalCorrect + local.totalWrong;
      final remoteProgress = remote.totalCorrect + remote.totalWrong;
      if (remoteProgress > localProgress) {
        repo.deck[i] = remote;
        await repo.saveCard(remote);
      }
    }
  }
}

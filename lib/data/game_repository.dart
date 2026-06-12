import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/fact_card.dart';
import 'models/profile.dart';

/// 오프라인 우선 저장소.
/// - Hive 로컬 DB가 진실의 원천 — 네트워크 없이 100% 동작
/// - 모든 답안은 이벤트 로그로도 기록 → Phase 3 Firebase 동기화 시
///   기기 간 병합의 기반이 된다 (append-only, 충돌 없음)
class GameRepository {
  static const _cardsBox = 'cards';
  static const _profileBox = 'profile';
  static const _eventsBox = 'events';

  late Box<String> _cards;
  late Box<String> _profile;
  late Box<String> _events;

  List<FactCard> deck = [];
  Profile profile = Profile();

  Future<void> init() async {
    await Hive.initFlutter();
    _cards = await Hive.openBox<String>(_cardsBox);
    _profile = await Hive.openBox<String>(_profileBox);
    _events = await Hive.openBox<String>(_eventsBox);

    if (_cards.isEmpty) {
      deck = FactCard.buildDeck();
      await _saveAllCards();
    } else {
      deck = _cards.values
          .map((s) => FactCard.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    }

    final p = _profile.get('me');
    profile = p == null ? Profile() : Profile.fromJson(jsonDecode(p) as Map<String, dynamic>);
  }

  Future<void> saveCard(FactCard card) async {
    await _cards.put(card.id, jsonEncode(card.toJson()));
  }

  Future<void> _saveAllCards() async {
    for (final c in deck) {
      await _cards.put(c.id, jsonEncode(c.toJson()));
    }
  }

  Future<void> saveProfile() async {
    await _profile.put('me', jsonEncode(profile.toJson()));
  }

  /// 답안 이벤트 기록 — 동기화 병합용
  Future<void> logAnswer({
    required String cardId,
    required bool correct,
    required bool firstAttempt,
    required DateTime at,
  }) async {
    await _events.add(jsonEncode({
      'type': 'answer',
      'cardId': cardId,
      'correct': correct,
      'firstAttempt': firstAttempt,
      'at': at.toIso8601String(),
    }));
  }

  Future<void> logEvent(String type, Map<String, dynamic> data, DateTime at) async {
    await _events.add(jsonEncode({'type': type, ...data, 'at': at.toIso8601String()}));
  }

  // ── 동기화 지원 ─────────────────────────────────────────────────────────

  /// 마지막 동기화 이후 추가된 이벤트 (Hive auto-increment 키 기준)
  List<String> get unsyncedEvents {
    final upTo = int.tryParse(_profile.get('syncedUpTo') ?? '') ?? -1;
    return [
      for (final key in _events.keys)
        if ((key as int) > upTo) _events.get(key)!,
    ];
  }

  Future<void> markEventsSynced() async {
    if (_events.isEmpty) return;
    final maxKey = _events.keys.cast<int>().reduce((a, b) => a > b ? a : b);
    await _profile.put('syncedUpTo', '$maxKey');
  }

  /// 동기화 메타데이터 (3-way 병합 기준점 등)
  String? getMeta(String key) => _profile.get(key);
  Future<void> setMeta(String key, String value) => _profile.put(key, value);

  // ── 부모 리포트용 통계 집계 ────────────────────────────────────────────

  /// 단별 [총 시도, 총 정답] 집계 (첫 시도만 포함)
  Map<int, (int, int)> danStats() {
    final stats = <int, (int, int)>{};
    for (final card in deck) {
      final total = card.totalCorrect + card.totalWrong;
      if (total == 0) continue;
      final dan = card.homeDan;
      final prev = stats[dan] ?? (0, 0);
      stats[dan] = (prev.$1 + total, prev.$2 + card.totalCorrect);
    }
    return stats;
  }

  /// 전체 세션 수 (이벤트 로그 기반)
  int totalSessions() {
    var count = 0;
    for (final raw in _events.values) {
      final e = jsonDecode(raw) as Map<String, dynamic>;
      if (e['type'] == 'session') count++;
    }
    return count;
  }

  /// 전체 정답 수 (첫 시도 기준)
  int totalCorrectAll() => deck.fold(0, (s, c) => s + c.totalCorrect);

  /// 전체 시도 수 (첫 시도 기준)
  int totalAttemptedAll() => deck.fold(0, (s, c) => s + c.totalCorrect + c.totalWrong);
}

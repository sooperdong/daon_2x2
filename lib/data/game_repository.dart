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
}

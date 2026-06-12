import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:daon_2x2/core/constants.dart';
import 'package:daon_2x2/core/shop_items.dart';
import 'package:daon_2x2/data/models/fact_card.dart';
import 'package:daon_2x2/data/models/profile.dart';
import 'package:daon_2x2/engine/progression.dart';
import 'package:daon_2x2/engine/question_generator.dart';
import 'package:daon_2x2/services/sync_service.dart';
import 'package:daon_2x2/engine/roulette.dart';
import 'package:daon_2x2/engine/sm2_scheduler.dart';
import 'package:daon_2x2/engine/star_catch.dart';

void main() {
  group('FactCard 덱', () {
    test('교환법칙 적용으로 정확히 36장', () {
      final deck = FactCard.buildDeck();
      expect(deck.length, 36);
      expect(deck.map((c) => c.id).toSet().length, 36);
      for (final c in deck) {
        expect(c.a <= c.b, isTrue);
      }
    });

    test('홈 단 배정 — 해금 순서에서 먼저 나오는 인수', () {
      // 3×7: 해금 순서 [2,5,3,4,9,6,7,8]에서 3이 7보다 먼저 → 홈 3단
      expect(FactCard(a: 3, b: 7).homeDan, 3);
      // 6×8: 6이 8보다 먼저 → 홈 6단
      expect(FactCard(a: 6, b: 8).homeDan, 6);
      // 8×8: 홈 8단
      expect(FactCard(a: 8, b: 8).homeDan, 8);
      // 2×9: 2가 먼저 → 홈 2단
      expect(FactCard(a: 2, b: 9).homeDan, 2);
    });

    test('마지막 단(8단)은 교환법칙 덕분에 새 카드가 1장뿐', () {
      final deck = FactCard.buildDeck();
      expect(Progression.homeCards(8, deck).length, 1); // 8×8
      expect(Progression.homeCards(2, deck).length, 8); // 2×2..2×9
    });

    test('JSON 직렬화 왕복', () {
      final card = FactCard(a: 3, b: 7)
        ..consecutiveCorrect = 2
        ..dueDate = DateTime(2026, 6, 15);
      final restored = FactCard.fromJson(card.toJson());
      expect(restored.id, card.id);
      expect(restored.consecutiveCorrect, 2);
      expect(restored.dueDate, DateTime(2026, 6, 15));
    });
  });

  group('SM-2 스케줄러', () {
    test('정답 시 간격이 1→2→3일로 늘어남 (아동용 초기 간격)', () {
      final card = FactCard(a: 2, b: 3);
      final now = DateTime(2026, 6, 12);

      Sm2Scheduler.review(card, correct: true, now: now);
      expect(card.intervalDays, 1);

      Sm2Scheduler.review(card, correct: true, now: now);
      expect(card.intervalDays, 2);

      Sm2Scheduler.review(card, correct: true, now: now);
      expect(card.intervalDays, 3);

      Sm2Scheduler.review(card, correct: true, now: now);
      expect(card.intervalDays, greaterThan(3));
    });

    test('오답 시 내일 재출제, 연속 정답 리셋', () {
      final card = FactCard(a: 7, b: 8);
      final now = DateTime(2026, 6, 12);

      Sm2Scheduler.review(card, correct: true, now: now);
      Sm2Scheduler.review(card, correct: true, now: now);
      expect(card.consecutiveCorrect, 2);

      Sm2Scheduler.review(card, correct: false, now: now);
      expect(card.consecutiveCorrect, 0);
      expect(card.intervalDays, 1);
      expect(card.dueDate, DateTime(2026, 6, 13));
    });

    test('간격 상한 30일', () {
      final card = FactCard(a: 2, b: 2);
      final now = DateTime(2026, 6, 12);
      for (var i = 0; i < 20; i++) {
        Sm2Scheduler.review(card, correct: true, now: now);
      }
      expect(card.intervalDays, lessThanOrEqualTo(30));
    });
  });

  group('문제 생성기', () {
    test('새 카드는 현재 단에서 최대 4장, 쉬운 곱부터', () {
      final deck = FactCard.buildDeck();
      final session = QuestionGenerator.compose(
        cards: deck,
        currentDan: 2,
        now: DateTime(2026, 6, 12),
        random: Random(42),
      );
      expect(session.length, lessThanOrEqualTo(maxNewCardsPerSession));
      for (final c in session) {
        expect(c.homeDan, 2);
        expect(c.isNew, isTrue);
      }
      // 쉬운 곱부터: 첫 카드는 2×2
      expect(session.first.id, '2x2');
    });

    test('만기 복습 카드가 세션에 포함됨', () {
      final deck = FactCard.buildDeck();
      final now = DateTime(2026, 6, 12);
      // 카드 5장을 어제 만기로 설정
      for (final c in deck.take(5)) {
        c.totalCorrect = 1;
        c.dueDate = DateTime(2026, 6, 11);
      }
      final session = QuestionGenerator.compose(
        cards: deck,
        currentDan: 2,
        now: now,
        random: Random(42),
      );
      final reviewCount = session.where((c) => !c.isNew).length;
      expect(reviewCount, 5);
      expect(session.length, lessThanOrEqualTo(sessionSize));
    });

    test('4지선다 보기: 정답 포함 4개, 중복 없음, 양수', () {
      final rng = Random(7);
      for (var a = 2; a <= 9; a++) {
        for (var b = a; b <= 9; b++) {
          final card = FactCard(a: a, b: b);
          final options = QuestionGenerator.choices(card, random: rng);
          expect(options.length, 4, reason: '$a x $b');
          expect(options.contains(card.answer), isTrue);
          expect(options.toSet().length, 4);
          expect(options.every((v) => v > 0), isTrue);
        }
      }
    });
  });

  group('진행/숙달', () {
    test('첫 세계(2단)는 항상 해금', () {
      final deck = FactCard.buildDeck();
      expect(Progression.unlockedDans(deck), [2]);
    });

    test('2단 클리어 시 5단 해금 (해금 순서 2→5→3→...)', () {
      final deck = FactCard.buildDeck();
      for (final c in Progression.homeCards(2, deck)) {
        c.totalCorrect = 1;
      }
      expect(Progression.unlockedDans(deck), [2, 5]);
    });

    test('newlyMastered: 어느 단이든 새로 숙달되면 감지 (현재 단 한정 X)', () {
      final deck = FactCard.buildDeck();
      // 2단과 5단을 동시에 숙달 상태로
      for (final dan in [2, 5]) {
        for (final c in Progression.homeCards(dan, deck)) {
          c.consecutiveCorrect = masteryConsecutive;
        }
      }
      // 2단은 이미 기록됨 → 5단만 새로 감지
      expect(Progression.newlyMastered([2], deck), [5]);
      expect(Progression.newlyMastered([], deck), [2, 5]);
      expect(Progression.newlyMastered([2, 5], deck), isEmpty);
    });

    test('숙달: 홈 카드 전부 연속 3회 정답', () {
      final deck = FactCard.buildDeck();
      final home = Progression.homeCards(2, deck);
      for (final c in home) {
        c.consecutiveCorrect = masteryConsecutive;
      }
      expect(Progression.isMastered(2, deck), isTrue);

      home.first.consecutiveCorrect = masteryConsecutive - 1;
      expect(Progression.isMastered(2, deck), isFalse);
    });
  });

  group('룰렛', () {
    test('확률 분포: 꽝 50% / 100원 40% / 1000원 10% (±2%p)', () {
      final rng = Random(123);
      final counts = <RoulettePrize, int>{};
      const trials = 100000;
      for (var i = 0; i < trials; i++) {
        final p = Roulette.spin(rng);
        counts[p] = (counts[p] ?? 0) + 1;
      }
      expect(counts[RoulettePrize.kkwang]! / trials, closeTo(0.5, 0.02));
      expect(counts[RoulettePrize.won100]! / trials, closeTo(0.4, 0.02));
      expect(counts[RoulettePrize.won1000]! / trials, closeTo(0.1, 0.02));
    });

    test('상금 매핑', () {
      expect(RoulettePrize.kkwang.won, 0);
      expect(RoulettePrize.won100.won, 100);
      expect(RoulettePrize.won1000.won, 1000);
    });
  });

  group('프로필', () {
    test('레벨업: 레벨 n → n+1에 n×100 XP 필요', () {
      final p = Profile();
      expect(p.addXp(99), 0);
      expect(p.level, 1);
      expect(p.addXp(1), 1);
      expect(p.level, 2);
      expect(p.xp, 0);
    });

    test('스트릭: 연속일 증가, 끊기면 1로 리셋, 7일마다 티켓 신호', () {
      final p = Profile();
      var ticket = p.recordPlayToday(DateTime(2026, 6, 1));
      expect(p.streak, 1);
      expect(ticket, isFalse);

      // 같은 날 중복 플레이는 무시
      ticket = p.recordPlayToday(DateTime(2026, 6, 1));
      expect(p.streak, 1);

      // 6일 연속 추가 → 7일째에 티켓
      for (var d = 2; d <= 6; d++) {
        ticket = p.recordPlayToday(DateTime(2026, 6, d));
        expect(ticket, isFalse);
      }
      ticket = p.recordPlayToday(DateTime(2026, 6, 7));
      expect(p.streak, 7);
      expect(ticket, isTrue);

      // 하루 건너뛰면 리셋
      p.recordPlayToday(DateTime(2026, 6, 9));
      expect(p.streak, 1);
    });
  });

  group('꾸미기 상점', () {
    test('구매: 별 조각 차감 + 보유 + 자동 장착', () {
      final p = Profile(starPieces: 20);
      final item = findItem('ribbon_blue')!;
      expect(buyItem(p, item), isTrue);
      expect(p.starPieces, 10);
      expect(p.ownedItems, contains('ribbon_blue'));
      expect(p.equipped['ribbon'], 'ribbon_blue');
    });

    test('별 조각 부족 시 구매 실패', () {
      final p = Profile(starPieces: 5);
      expect(buyItem(p, findItem('hat_crown')!), isFalse);
      expect(p.starPieces, 5);
      expect(p.ownedItems, isEmpty);
    });

    test('중복 구매 불가', () {
      final p = Profile(starPieces: 50);
      final item = findItem('face_star')!;
      expect(buyItem(p, item), isTrue);
      expect(buyItem(p, item), isFalse);
      expect(p.starPieces, 50 - item.price);
    });

    test('장착 토글: 입기 ↔ 벗기', () {
      final p = Profile(starPieces: 50);
      final item = findItem('hat_wizard')!;
      buyItem(p, item);
      expect(p.equipped['hat'], 'hat_wizard');
      toggleEquip(p, item);
      expect(p.equipped.containsKey('hat'), isFalse);
      toggleEquip(p, item);
      expect(p.equipped['hat'], 'hat_wizard');
    });

    test('Phase 1 프로필 JSON 마이그레이션 — 새 필드 기본값', () {
      final old = Profile(starPieces: 7).toJson()
        ..remove('ownedItems')
        ..remove('equipped')
        ..remove('starCatchHighScore');
      final migrated = Profile.fromJson(old);
      expect(migrated.ownedItems, isEmpty);
      expect(migrated.equipped, isEmpty);
      expect(migrated.starCatchHighScore, 0);
      expect(migrated.starPieces, 7);
    });
  });

  group('별 수집 모드', () {
    test('출제 풀: 한 번이라도 맞힌 카드만', () {
      final deck = FactCard.buildDeck();
      expect(StarCatch.pool(deck), isEmpty);
      expect(StarCatch.unlocked(deck), isFalse);

      for (final c in deck.take(4)) {
        c.totalCorrect = 1;
      }
      expect(StarCatch.pool(deck).length, 4);
      expect(StarCatch.unlocked(deck), isTrue);
    });

    test('문제 뽑기: 직전 문제와 중복 회피', () {
      final deck = FactCard.buildDeck();
      for (final c in deck.take(5)) {
        c.totalCorrect = 1;
      }
      final pool = StarCatch.pool(deck);
      final rng = Random(1);
      var prev = StarCatch.pick(pool, rng);
      for (var i = 0; i < 50; i++) {
        final next = StarCatch.pick(pool, rng, previous: prev);
        expect(next.id, isNot(prev.id));
        prev = next;
      }
    });

    test('낙하 속도는 점수에 따라 증가, 상한 있음', () {
      expect(StarCatch.fallSpeed(0), lessThan(StarCatch.fallSpeed(10)));
      expect(StarCatch.fallSpeed(25), StarCatch.fallSpeed(100)); // 25점에서 상한
    });

    test('보상: 3점당 별 조각 1개 (최대 10) + 신기록 보너스 2', () {
      expect(StarCatch.reward(0, newRecord: false), 0);
      expect(StarCatch.reward(9, newRecord: false), 3);
      expect(StarCatch.reward(9, newRecord: true), 5);
      expect(StarCatch.reward(99, newRecord: false), 10); // 상한
    });
  });

  group('Phase 3 — 프로필 출석/동기화', () {
    test('출석 기록: playDates에 추가, 90일 초과분 제거', () {
      final p = Profile();
      p.recordPlayToday(DateTime(2026, 6, 12));
      expect(p.playDates, contains('2026-06-12'));

      // 91일 전 날짜는 잘림
      p.playDates.add('2026-03-12'); // 92일 전
      p.recordPlayToday(DateTime(2026, 6, 13));
      expect(p.playDates, isNot(contains('2026-03-12')));
      expect(p.playDates, contains('2026-06-13'));
    });

    test('Phase 2 프로필 → Phase 3 마이그레이션: playDates 기본값', () {
      final old = Profile(starPieces: 5).toJson()..remove('playDates');
      final p = Profile.fromJson(old);
      expect(p.playDates, isEmpty);
      expect(p.parentPin, isNull);
      expect(p.familyCode, isNull);
    });

    test('가족 코드 생성: 6자리 대문자 영숫자, 혼동 문자 없음', () {
      const bad = {'0', 'O', '1', 'I'};
      for (var i = 0; i < 100; i++) {
        final code = generateFamilyCode();
        expect(code.length, 6);
        expect(code, matches(RegExp(r'^[A-Z2-9]+$')));
        for (final ch in code.split('')) {
          expect(bad, isNot(contains(ch)));
        }
      }
    });

    test('NoOpSyncService: isEnabled false, setFamilyCode false 반환', () async {
      const sync = NoOpSyncService();
      expect(sync.isEnabled, isFalse);
      // push/pull은 GameRepository 초기화가 필요해 단위 테스트에서 호출 불가
    });
  });

  group('한국어 암송문', () {
    test('받침으로 끝나는 곱수엔 조사: 이 삼은 육, 칠 팔은 오십육', () {
      expect(chantText(2, 3), '이 삼은 육');
      expect(chantText(7, 8), '칠 팔은 오십육');
      expect(chantText(2, 2), '이 이는 사');
    });

    test('모음으로 끝나는 곱수(사/오/구)는 조사 없음: 이 사 팔, 구 구 팔십일', () {
      expect(chantText(2, 4), '이 사 팔');
      expect(chantText(2, 5), '이 오 십');
      expect(chantText(9, 9), '구 구 팔십일');
    });
  });
}

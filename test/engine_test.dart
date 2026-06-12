import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:daon_2x2/core/constants.dart';
import 'package:daon_2x2/data/models/fact_card.dart';
import 'package:daon_2x2/data/models/profile.dart';
import 'package:daon_2x2/engine/progression.dart';
import 'package:daon_2x2/engine/question_generator.dart';
import 'package:daon_2x2/engine/roulette.dart';
import 'package:daon_2x2/engine/sm2_scheduler.dart';

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

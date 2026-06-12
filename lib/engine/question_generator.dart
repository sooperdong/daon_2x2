import 'dart:math';

import '../core/constants.dart';
import '../data/models/fact_card.dart';

/// 한 세션의 문제 묶음.
/// 구성 원칙:
///  - 복습 카드(만기 도래) 우선 — 인출 연습 + 간격 반복
///  - 새 카드는 현재 단에서 최대 4장 — 블로킹(집중 학습)
///  - 새 카드는 앞쪽에 묶고, 복습 카드는 섞어서 뒤에 — 인터리빙
class QuestionGenerator {
  /// [cards] 전체 덱, [currentDan] 오늘 탐험하는 단.
  static List<FactCard> compose({
    required List<FactCard> cards,
    required int currentDan,
    required DateTime now,
    Random? random,
    int size = sessionSize,
  }) {
    final rng = random ?? Random();
    final today = DateTime(now.year, now.month, now.day);

    // 1) 만기 복습 카드 — 많이 늦은 것, 최근에 틀린 것 우선
    final due = cards
        .where((c) => c.dueDate != null && !c.dueDate!.isAfter(today))
        .toList()
      ..sort((x, y) {
        final lapsedX = x.consecutiveCorrect == 0 ? 0 : 1;
        final lapsedY = y.consecutiveCorrect == 0 ? 0 : 1;
        if (lapsedX != lapsedY) return lapsedX - lapsedY; // 틀렸던 카드 먼저
        return x.dueDate!.compareTo(y.dueDate!); // 더 오래 밀린 카드 먼저
      });

    // 2) 현재 단의 새 카드 (홈 단 기준 — 교환법칙으로 이미 배운 카드는 제외됨)
    final fresh = cards
        .where((c) => c.isNew && c.homeDan == currentDan)
        .toList()
      ..sort((x, y) => (x.a * x.b).compareTo(y.a * y.b)); // 쉬운 곱부터

    final newCount = min(maxNewCardsPerSession, fresh.length);
    final reviewCount = min(size - newCount, due.length);

    final reviews = due.take(reviewCount).toList()..shuffle(rng);
    final news = fresh.take(newCount).toList();

    // 새 카드(블로킹) → 복습 카드(인터리빙) 순서
    return [...news, ...reviews];
  }

  /// 4지선다 보기 생성 — 정답 + 그럴듯한 오답 3개 (인접 곱셈 결과)
  static List<int> choices(FactCard card, {Random? random}) {
    final rng = random ?? Random();
    final answer = card.answer;
    final pool = <int>{
      (card.a + 1) * card.b,
      (card.a - 1) * card.b,
      card.a * (card.b + 1),
      card.a * (card.b - 1),
      answer + 10,
      answer - 10,
      answer + 1,
      answer - 1,
    }..removeWhere((v) => v == answer || v <= 0 || v > 99);

    final distractors = pool.toList()..shuffle(rng);
    final options = [answer, ...distractors.take(3)]..shuffle(rng);
    return options;
  }
}

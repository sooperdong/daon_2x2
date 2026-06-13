import 'dart:math';

import '../data/models/fact_card.dart';
import 'progression.dart';

/// 러너 게이트 한 개 — 곱셈 사실 + 3개의 문(정답 1 + 그럴듯한 오답 2).
class RunnerGate {
  final FactCard card;
  final List<int> doors; // 길이 3, 셔플됨
  final int correctIndex; // doors 중 정답 위치

  const RunnerGate({
    required this.card,
    required this.doors,
    required this.correctIndex,
  });

  int get answer => card.answer;
  int get a => card.a;
  int get b => card.b;
}

/// 크라우드 러너 로직 — 곱셈이 곧 게임 메커니즘.
///
/// 설계 원칙:
///  - 곱셈은 "관문"이 아니라 군단을 불리는 행위 → 내재적 통합 (Habgood 연구)
///  - 어떤 사실을 낼지는 SM-2 두뇌가 정한다 (만기/약한 카드 우선)
///  - 해금된 단의 카드만 등장 → 아직 안 배운 곱셈은 안 나옴 (연구 기반 난이도 순서 유지)
///  - 항상 게이트가 나오도록(엔드리스) 폴백을 둔다
class RunnerEngine {
  /// 한 번의 달리기에 등장할 게이트 수
  static const int gatesPerRun = 12;

  /// 정답 시 군단(콤보 트레일) 증가
  static const int crowdGainPerCorrect = 2;

  /// 오답 시 군단 감소
  static const int crowdLossPerWrong = 1;

  /// 군단 표시 상한 (화면 정리용)
  static const int crowdCap = 30;

  /// 시작 군단 크기
  static const int startCrowd = 3;

  /// 다음 게이트 선택 — 해금된 단 안에서 학습 필요도에 따라 가중 추첨.
  static RunnerGate nextGate(
    List<FactCard> deck,
    DateTime now, {
    Random? random,
    String? avoidId,
  }) {
    final rng = random ?? Random();
    final unlocked = Progression.unlockedDans(deck).toSet();
    final today = DateTime(now.year, now.month, now.day);

    var pool = deck.where((c) => unlocked.contains(c.homeDan)).toList();
    if (pool.isEmpty) pool = List.of(deck); // 안전 폴백

    // 직전 게이트와 동일 카드는 피한다 (가능할 때만)
    if (avoidId != null && pool.length > 1) {
      final filtered = pool.where((c) => c.id != avoidId).toList();
      if (filtered.isNotEmpty) pool = filtered;
    }

    final card = _weightedPick(pool, today, rng);
    final doors = _doors(card, rng);
    return RunnerGate(
      card: card,
      doors: doors,
      correctIndex: doors.indexOf(card.answer),
    );
  }

  /// 학습 필요도 가중치: 틀렸던 카드 > 만기 복습 > 새 카드 > 익힌 카드
  static FactCard _weightedPick(List<FactCard> pool, DateTime today, Random rng) {
    int weightOf(FactCard c) {
      if (c.dueDate != null && !c.dueDate!.isAfter(today)) {
        return c.consecutiveCorrect == 0 ? 8 : 5; // 최근에 틀린 만기 카드 최우선
      }
      if (c.isNew) return 3; // 새 카드 점진적 도입
      return 1; // 이미 익힌 카드 — 가끔 복습
    }

    final weights = pool.map(weightOf).toList();
    final total = weights.fold(0, (s, w) => s + w);
    var roll = rng.nextInt(total);
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll < 0) return pool[i];
    }
    return pool.last;
  }

  /// 3개의 문 값 — 정답 + 그럴듯한 오답 2개 (인접 곱셈 결과).
  static List<int> _doors(FactCard card, Random rng) {
    final answer = card.answer;
    final pool = <int>{
      (card.a + 1) * card.b,
      (card.a - 1) * card.b,
      card.a * (card.b + 1),
      card.a * (card.b - 1),
      answer + card.a,
      answer - card.b,
    }..removeWhere((v) => v == answer || v <= 0 || v > 99);

    final distractors = pool.toList()..shuffle(rng);
    final doors = <int>[answer, ...distractors.take(2)];

    // 폴백: 후보가 부족하면 근처 값으로 채움
    var delta = 1;
    while (doors.length < 3) {
      for (final v in [answer + delta, answer - delta]) {
        if (v > 0 && v <= 99 && !doors.contains(v)) {
          doors.add(v);
          if (doors.length == 3) break;
        }
      }
      delta++;
    }

    doors.shuffle(rng);
    return doors;
  }
}

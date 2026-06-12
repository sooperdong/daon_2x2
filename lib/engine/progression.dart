import '../core/constants.dart';
import '../data/models/fact_card.dart';

/// 단 숙달 판정과 세계 해금 규칙
class Progression {
  /// 해당 단의 홈 카드들 (교환법칙으로 이 단에서 처음 배우는 카드만)
  static List<FactCard> homeCards(int dan, List<FactCard> deck) =>
      deck.where((c) => c.homeDan == dan).toList();

  /// 숙달: 홈 카드 전부 연속 정답 masteryConsecutive회 이상
  static bool isMastered(int dan, List<FactCard> deck) {
    final cards = homeCards(dan, deck);
    return cards.isNotEmpty && cards.every((c) => c.consecutiveCorrect >= masteryConsecutive);
  }

  /// 클리어(해금 조건): 홈 카드 전부 한 번 이상 맞힘
  static bool isCleared(int dan, List<FactCard> deck) {
    final cards = homeCards(dan, deck);
    return cards.isNotEmpty && cards.every((c) => c.totalCorrect >= 1);
  }

  /// 해금된 단 목록 — 첫 세계는 항상 열림, 이전 세계 클리어 시 다음 해금
  static List<int> unlockedDans(List<FactCard> deck) {
    final unlocked = <int>[danUnlockOrder.first];
    for (var i = 1; i < danUnlockOrder.length; i++) {
      if (isCleared(danUnlockOrder[i - 1], deck)) {
        unlocked.add(danUnlockOrder[i]);
      } else {
        break;
      }
    }
    return unlocked;
  }

  /// 단 진행률 0.0~1.0 (홈 카드 중 1회 이상 맞힌 비율)
  static double progress(int dan, List<FactCard> deck) {
    final cards = homeCards(dan, deck);
    if (cards.isEmpty) return 1.0;
    return cards.where((c) => c.totalCorrect >= 1).length / cards.length;
  }
}

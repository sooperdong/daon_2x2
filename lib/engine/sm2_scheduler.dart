import '../data/models/fact_card.dart';

/// 아동용으로 조정한 SM-2 간격 반복 스케줄러.
///
/// 연구 근거: 7-8세 아동은 4일 이상 간격에서 망각률이 급증하므로
/// 초기 간격을 1→2→3일로 짧게 잡고, 이후 easiness 배수로 늘린다.
class Sm2Scheduler {
  static const List<int> _earlyIntervals = [1, 2, 3];
  static const double _minEasiness = 1.3;
  static const int _maxIntervalDays = 30;

  /// 첫 시도 결과를 카드에 반영하고 다음 출제일을 계산한다.
  /// (세션 내 재도전 정답은 SM-2에 반영하지 않음 — 호출하지 말 것)
  static void review(FactCard card, {required bool correct, required DateTime now}) {
    if (correct) {
      card.totalCorrect++;
      card.consecutiveCorrect++;
      if (card.repetition < _earlyIntervals.length) {
        card.intervalDays = _earlyIntervals[card.repetition];
      } else {
        card.intervalDays = (card.intervalDays * card.easiness).round().clamp(1, _maxIntervalDays);
      }
      card.repetition++;
      // 정답이므로 easiness 소폭 상승 (SM-2 quality=5 근사)
      card.easiness = (card.easiness + 0.1).clamp(_minEasiness, 2.8);
    } else {
      card.totalWrong++;
      card.consecutiveCorrect = 0;
      card.repetition = 0;
      card.intervalDays = 1; // 내일 다시
      card.easiness = (card.easiness - 0.2).clamp(_minEasiness, 2.8);
    }
    card.dueDate = DateTime(now.year, now.month, now.day).add(Duration(days: card.intervalDays));
  }
}

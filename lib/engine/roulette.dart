import 'dart:math';

enum RoulettePrize { kkwang, won100, won500, won1000 }

extension RoulettePrizeInfo on RoulettePrize {
  String get label => switch (this) {
        RoulettePrize.kkwang => '꽝',
        RoulettePrize.won100 => '100원',
        RoulettePrize.won500 => '500원',
        RoulettePrize.won1000 => '1000원',
      };

  int get won => switch (this) {
        RoulettePrize.kkwang => 0,
        RoulettePrize.won100 => 100,
        RoulettePrize.won500 => 500,
        RoulettePrize.won1000 => 1000,
      };
}

/// 룰렛 확률: 꽝 50% / 100원 35% / 500원 10% / 1000원 5%
/// 가변 비율 강화 + "동정 보정(pity)" — 꽝이 연속될수록 다음 스핀의
/// 당첨 확률이 조금씩 올라간다. 계속 못 따서 아이가 포기하지 않도록.
class Roulette {
  static const double _baseKkwang = 0.5;
  static const double _baseWon100 = 0.35;
  static const double _baseWon500 = 0.10;
  static const double _baseWon1000 = 0.05;

  /// 연속 꽝 1회당 꽝 확률 5%p 감소, 최대 35%p까지 (꽝 최저 15%)
  static const double _pityStepPerLoss = 0.05;
  static const double _maxPityReduction = 0.35;

  /// [kkwangStreak]: 이번 스핀 이전까지 연속으로 나온 꽝 횟수.
  static RoulettePrize spin(Random random, {int kkwangStreak = 0}) {
    final reduction = min(kkwangStreak * _pityStepPerLoss, _maxPityReduction);
    final kkwang = _baseKkwang - reduction;

    // 감소분을 나머지 상금에 기존 비율대로 재분배
    const restBase = _baseWon100 + _baseWon500 + _baseWon1000;
    final won100 = _baseWon100 + reduction * (_baseWon100 / restBase);
    final won500 = _baseWon500 + reduction * (_baseWon500 / restBase);

    final r = random.nextDouble();
    if (r < kkwang) return RoulettePrize.kkwang;
    if (r < kkwang + won100) return RoulettePrize.won100;
    if (r < kkwang + won100 + won500) return RoulettePrize.won500;
    return RoulettePrize.won1000;
  }
}

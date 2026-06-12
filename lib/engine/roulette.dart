import 'dart:math';

enum RoulettePrize { kkwang, won100, won1000 }

extension RoulettePrizeInfo on RoulettePrize {
  String get label => switch (this) {
        RoulettePrize.kkwang => '꽝',
        RoulettePrize.won100 => '100원',
        RoulettePrize.won1000 => '1000원',
      };

  int get won => switch (this) {
        RoulettePrize.kkwang => 0,
        RoulettePrize.won100 => 100,
        RoulettePrize.won1000 => 1000,
      };
}

/// 룰렛 확률: 꽝 50% / 100원 40% / 1000원 10%
/// 가변 비율 강화 — 예측 불가능한 보상이 내재적 동기를 해치지 않으면서
/// 지속적 참여를 유도한다.
class Roulette {
  static RoulettePrize spin(Random random) {
    final r = random.nextDouble();
    if (r < 0.5) return RoulettePrize.kkwang;
    if (r < 0.9) return RoulettePrize.won100;
    return RoulettePrize.won1000;
  }
}

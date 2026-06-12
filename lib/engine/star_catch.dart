import 'dart:math';

import '../data/models/fact_card.dart';

/// 별 수집 모드의 규칙 (순수 로직 — 테스트 가능).
///
/// 설계 원칙:
///  - 아이가 스스로 선택하는 보너스 모드 — 기본 학습엔 시간 압박 없음
///  - 배운 카드만 출제 (인터리빙 복습 효과)
///  - 결과를 SM-2에 반영하지 않음 — 시간 압박 속 오답이
///    복습 스케줄을 망가뜨리면 안 된다
///  - 틀려도 잃는 것 없음, 점수만 안 오름
class StarCatch {
  static const int roundSeconds = 60;
  static const int maxRewardPieces = 10;

  /// 출제 풀: 한 번이라도 맞혀본 카드만
  static List<FactCard> pool(List<FactCard> deck) =>
      deck.where((c) => c.totalCorrect >= 1).toList();

  /// 모드 해금: 배운 카드 4장 이상 (보기 구성에 필요)
  static bool unlocked(List<FactCard> deck) => pool(deck).length >= 4;

  /// 다음 문제 뽑기 — 직전 문제와 중복 회피
  static FactCard pick(List<FactCard> learnedPool, Random rng, {FactCard? previous}) {
    assert(learnedPool.isNotEmpty);
    if (learnedPool.length == 1) return learnedPool.first;
    FactCard card;
    do {
      card = learnedPool[rng.nextInt(learnedPool.length)];
    } while (card.id == previous?.id);
    return card;
  }

  /// 낙하 속도 — 점수가 오를수록 빨라진다 (화면높이 비율/초)
  static double fallSpeed(int score) => 0.10 + 0.012 * min(score, 25);

  /// 보상 별 조각: 3점당 1개 (최대 10개) + 신기록 보너스 2개
  static int reward(int score, {required bool newRecord}) =>
      min(score ~/ 3, maxRewardPieces) + (newRecord ? 2 : 0);
}

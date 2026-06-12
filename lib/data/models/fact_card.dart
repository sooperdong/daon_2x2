import '../../core/constants.dart';

/// 구구단 카드 1장 — 교환법칙 적용: 3×7과 7×3은 같은 카드 (a ≤ b)
/// 2~9단 기준 36장 (C(8,2) + 8 = 36)
class FactCard {
  final int a; // 작은 인수
  final int b; // 큰 인수

  // SM-2 간격 반복 상태
  double easiness;
  int repetition; // 성공적 복습 횟수
  int intervalDays;
  DateTime? dueDate; // null = 아직 안 배움

  // 학습 통계
  int consecutiveCorrect;
  int totalCorrect;
  int totalWrong;

  FactCard({
    required this.a,
    required this.b,
    this.easiness = 2.5,
    this.repetition = 0,
    this.intervalDays = 0,
    this.dueDate,
    this.consecutiveCorrect = 0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
  }) : assert(a <= b);

  String get id => '${a}x$b';
  int get answer => a * b;
  bool get isNew => totalCorrect == 0 && totalWrong == 0;

  /// 이 카드의 "홈 단": 해금 순서에서 먼저 나오는 인수의 단.
  /// 예: 3×7 → 3단이 7단보다 먼저 해금 → 홈은 3단.
  /// 나중에 7단을 배울 땐 이미 아는 마법이 된다.
  int get homeDan {
    final ia = danUnlockOrder.indexOf(a);
    final ib = danUnlockOrder.indexOf(b);
    return ia <= ib ? a : b;
  }

  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        'easiness': easiness,
        'repetition': repetition,
        'intervalDays': intervalDays,
        'dueDate': dueDate?.toIso8601String(),
        'consecutiveCorrect': consecutiveCorrect,
        'totalCorrect': totalCorrect,
        'totalWrong': totalWrong,
      };

  factory FactCard.fromJson(Map<String, dynamic> json) => FactCard(
        a: json['a'] as int,
        b: json['b'] as int,
        easiness: (json['easiness'] as num).toDouble(),
        repetition: json['repetition'] as int,
        intervalDays: json['intervalDays'] as int,
        dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
        consecutiveCorrect: json['consecutiveCorrect'] as int,
        totalCorrect: json['totalCorrect'] as int,
        totalWrong: json['totalWrong'] as int,
      );

  /// 전체 덱 생성: 2~9단, a ≤ b 조합 36장
  static List<FactCard> buildDeck() {
    final deck = <FactCard>[];
    for (var a = 2; a <= 9; a++) {
      for (var b = a; b <= 9; b++) {
        deck.add(FactCard(a: a, b: b));
      }
    }
    return deck;
  }
}

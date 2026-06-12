/// 김다조이의 영구 진행 데이터 — 레벨, 재화, 스트릭, 룰렛
class Profile {
  int level;
  int xp;
  int starPieces; // 별 조각 (Phase 2 꾸미기 화폐)
  int piggyBank; // 저금통 누적 원화
  int streak; // 연속 학습 일수
  String? lastPlayDate; // yyyy-MM-dd
  int rouletteTickets;
  List<int> masteredDans;
  List<String> rouletteHistory; // "2026-06-12:won100" 형태

  Profile({
    this.level = 1,
    this.xp = 0,
    this.starPieces = 0,
    this.piggyBank = 0,
    this.streak = 0,
    this.lastPlayDate,
    this.rouletteTickets = 0,
    List<int>? masteredDans,
    List<String>? rouletteHistory,
  })  : masteredDans = masteredDans ?? [],
        rouletteHistory = rouletteHistory ?? [];

  int get xpForNextLevel => level * 100;

  /// XP 추가 후 레벨업 횟수 반환
  int addXp(int amount) {
    xp += amount;
    var levelUps = 0;
    while (xp >= xpForNextLevel) {
      xp -= xpForNextLevel;
      level++;
      levelUps++;
    }
    return levelUps;
  }

  /// 오늘 플레이 기록 → 스트릭 갱신. 7일 달성 시 true (룰렛 티켓 지급 신호)
  bool recordPlayToday(DateTime now) {
    final today = _dateKey(now);
    if (lastPlayDate == today) return false;
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    streak = (lastPlayDate == yesterday) ? streak + 1 : 1;
    lastPlayDate = today;
    return streak > 0 && streak % 7 == 0;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'level': level,
        'xp': xp,
        'starPieces': starPieces,
        'piggyBank': piggyBank,
        'streak': streak,
        'lastPlayDate': lastPlayDate,
        'rouletteTickets': rouletteTickets,
        'masteredDans': masteredDans,
        'rouletteHistory': rouletteHistory,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        level: json['level'] as int,
        xp: json['xp'] as int,
        starPieces: json['starPieces'] as int,
        piggyBank: json['piggyBank'] as int,
        streak: json['streak'] as int,
        lastPlayDate: json['lastPlayDate'] as String?,
        rouletteTickets: json['rouletteTickets'] as int,
        masteredDans: (json['masteredDans'] as List).cast<int>(),
        rouletteHistory: (json['rouletteHistory'] as List).cast<String>(),
      );
}

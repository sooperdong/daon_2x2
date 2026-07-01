import 'dart:typed_data';

/// 김다조이의 영구 진행 데이터 — 레벨, 재화, 스트릭, 룰렛
class Profile {
  int level;
  int xp;
  int starPieces;
  int piggyBank;
  int streak;
  String? lastPlayDate; // yyyy-MM-dd
  int rouletteTickets;
  List<int> masteredDans;
  List<String> rouletteHistory; // "2026-06-12:won100"
  List<String> ownedItems;
  Map<String, String> equipped; // 슬롯 → 아이템 ID
  int starCatchHighScore;

  // Phase 3
  String? parentPin;   // 4자리 숫자 — 부모 리포트 잠금
  String? familyCode;  // Firebase 가족 동기화 코드
  List<String> playDates; // 출석한 날 yyyy-MM-dd (최근 90일)

  // 기기 전용 — 절대 Firebase 동기화 안 됨. toJson에 포함되지 않는다.
  // 파일 경로 대신 바이트로 보관 → 모바일/웹 공통 코드로 동작
  Uint8List? photoBytes;

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
    List<String>? ownedItems,
    Map<String, String>? equipped,
    this.starCatchHighScore = 0,
    this.parentPin,
    this.familyCode,
    List<String>? playDates,
  })  : masteredDans = masteredDans ?? [],
        rouletteHistory = rouletteHistory ?? [],
        ownedItems = ownedItems ?? [],
        equipped = equipped ?? {},
        playDates = playDates ?? [];

  int get xpForNextLevel => level * 100;

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

  /// 오늘 플레이 기록 → 스트릭 + 출석 갱신. 7일 달성 시 true.
  bool recordPlayToday(DateTime now) {
    final today = _dateKey(now);
    if (lastPlayDate == today) return false;
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    streak = (lastPlayDate == yesterday) ? streak + 1 : 1;
    lastPlayDate = today;

    // 출석 기록 (최근 90일만 보관)
    if (!playDates.contains(today)) {
      playDates.add(today);
      final cutoff = _dateKey(now.subtract(const Duration(days: 90)));
      playDates.removeWhere((d) => d.compareTo(cutoff) < 0);
    }
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
        'ownedItems': ownedItems,
        'equipped': equipped,
        'starCatchHighScore': starCatchHighScore,
        'parentPin': parentPin,
        'familyCode': familyCode,
        'playDates': playDates,
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
        ownedItems: (json['ownedItems'] as List?)?.cast<String>(),
        equipped: (json['equipped'] as Map?)?.cast<String, String>(),
        starCatchHighScore: json['starCatchHighScore'] as int? ?? 0,
        parentPin: json['parentPin'] as String?,
        familyCode: json['familyCode'] as String?,
        playDates: (json['playDates'] as List?)?.cast<String>() ?? [],
      );
}

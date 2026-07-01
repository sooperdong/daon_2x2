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
  int rouletteKkwangStreak; // 연속 꽝 횟수 — 다음 스핀 동정 보정(pity)에 사용
  List<int> masteredDans;
  List<String> rouletteHistory; // "2026-06-12:won100"
  List<String> ownedItems;
  Map<String, String> equipped; // 슬롯 → 아이템 ID
  int starCatchHighScore;

  // Phase 3
  String? parentPin;   // 4자리 숫자 — 부모 리포트 잠금
  String? familyCode;  // Firebase 가족 동기화 코드
  List<String> playDates; // 출석한 날 yyyy-MM-dd (최근 90일)

  // 하루 달리기 횟수 제한 — 룰렛 보상이 실제 용돈으로 이어지므로
  // 무한 반복(용돈 벌이 목적 플레이)을 막기 위한 일일 한도
  int dailyRunCount;
  String? lastRunDate; // yyyy-MM-dd — dailyRunCount가 적용되는 날

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
    this.rouletteKkwangStreak = 0,
    List<int>? masteredDans,
    List<String>? rouletteHistory,
    List<String>? ownedItems,
    Map<String, String>? equipped,
    this.starCatchHighScore = 0,
    this.parentPin,
    this.familyCode,
    List<String>? playDates,
    this.dailyRunCount = 0,
    this.lastRunDate,
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
    final today = dateKey(now);
    if (lastPlayDate == today) return false;
    final yesterday = dateKey(now.subtract(const Duration(days: 1)));
    streak = (lastPlayDate == yesterday) ? streak + 1 : 1;
    lastPlayDate = today;

    // 출석 기록 (최근 90일만 보관)
    if (!playDates.contains(today)) {
      playDates.add(today);
      final cutoff = dateKey(now.subtract(const Duration(days: 90)));
      playDates.removeWhere((d) => d.compareTo(cutoff) < 0);
    }
    return streak > 0 && streak % 7 == 0;
  }

  /// 하루 최대 달리기 횟수 — 룰렛 티켓(→현금)이 무한정 반복 적립되는 것을 막는다.
  /// 이미 모은 티켓으로 룰렛을 돌리는 것은 한도와 무관하게 계속 가능하다.
  static const int maxRunsPerDay = 5;

  /// 오늘 남은 달리기 횟수 (자정이 지나면 자동으로 [maxRunsPerDay]로 복원됨)
  int remainingRunsToday(DateTime now) {
    final usedToday = lastRunDate == dateKey(now) ? dailyRunCount : 0;
    return (maxRunsPerDay - usedToday).clamp(0, maxRunsPerDay);
  }

  bool canStartRun(DateTime now) => remainingRunsToday(now) > 0;

  /// 달리기 시작 기록 — 날짜가 바뀌었으면 카운트를 리셋한 뒤 1 증가.
  void recordRunStart(DateTime now) {
    final today = dateKey(now);
    if (lastRunDate != today) {
      lastRunDate = today;
      dailyRunCount = 0;
    }
    dailyRunCount++;
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'level': level,
        'xp': xp,
        'starPieces': starPieces,
        'piggyBank': piggyBank,
        'streak': streak,
        'lastPlayDate': lastPlayDate,
        'rouletteTickets': rouletteTickets,
        'rouletteKkwangStreak': rouletteKkwangStreak,
        'masteredDans': masteredDans,
        'rouletteHistory': rouletteHistory,
        'ownedItems': ownedItems,
        'equipped': equipped,
        'starCatchHighScore': starCatchHighScore,
        'parentPin': parentPin,
        'familyCode': familyCode,
        'playDates': playDates,
        'dailyRunCount': dailyRunCount,
        'lastRunDate': lastRunDate,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        level: json['level'] as int,
        xp: json['xp'] as int,
        starPieces: json['starPieces'] as int,
        piggyBank: json['piggyBank'] as int,
        streak: json['streak'] as int,
        lastPlayDate: json['lastPlayDate'] as String?,
        rouletteTickets: json['rouletteTickets'] as int,
        rouletteKkwangStreak: json['rouletteKkwangStreak'] as int? ?? 0,
        masteredDans: (json['masteredDans'] as List).cast<int>(),
        rouletteHistory: (json['rouletteHistory'] as List).cast<String>(),
        ownedItems: (json['ownedItems'] as List?)?.cast<String>(),
        equipped: (json['equipped'] as Map?)?.cast<String, String>(),
        starCatchHighScore: json['starCatchHighScore'] as int? ?? 0,
        parentPin: json['parentPin'] as String?,
        familyCode: json['familyCode'] as String?,
        playDates: (json['playDates'] as List?)?.cast<String>() ?? [],
        dailyRunCount: json['dailyRunCount'] as int? ?? 0,
        lastRunDate: json['lastRunDate'] as String?,
      );
}

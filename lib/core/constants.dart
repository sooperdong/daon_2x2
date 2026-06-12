import 'package:flutter/material.dart';

/// 단 해금 순서 — 난이도 연구 기준 (2·5단 패턴 쉬움 → 9단 규칙 → 6·7·8단 최난관)
const List<int> danUnlockOrder = [2, 5, 3, 4, 9, 6, 7, 8];

class WorldInfo {
  final int dan;
  final String name;
  final String monster;
  final String emoji;
  final Color color;

  const WorldInfo({
    required this.dan,
    required this.name,
    required this.monster,
    required this.emoji,
    required this.color,
  });
}

const Map<int, WorldInfo> worlds = {
  2: WorldInfo(dan: 2, name: '무지개 숲', monster: '덧셈 고블린', emoji: '🌈', color: Color(0xFF7ED957)),
  5: WorldInfo(dan: 5, name: '사탕 성', monster: '설탕 마녀', emoji: '🍭', color: Color(0xFFFF8FAB)),
  3: WorldInfo(dan: 3, name: '구름 마을', monster: '구름 도깨비', emoji: '☁️', color: Color(0xFF87CEEB)),
  4: WorldInfo(dan: 4, name: '바닷속 왕국', monster: '문어 마왕', emoji: '🐙', color: Color(0xFF4FC3F7)),
  9: WorldInfo(dan: 9, name: '별빛 탑', monster: '수수께끼 마법사', emoji: '⭐', color: Color(0xFF9575CD)),
  6: WorldInfo(dan: 6, name: '화산 섬', monster: '불꽃 용', emoji: '🌋', color: Color(0xFFFF7043)),
  7: WorldInfo(dan: 7, name: '얼음 궁전', monster: '눈 결정 여왕', emoji: '❄️', color: Color(0xFF4DD0E1)),
  8: WorldInfo(dan: 8, name: '최종 성', monster: '수학 몬스터 왕', emoji: '🏰', color: Color(0xFFFFB300)),
};

/// XP 보상
const int xpPerCorrect = 10;
const int xpPerSession = 50;

/// 별 조각 보상
const int starPiecesPerSession = 3;
const int starPiecesConsolation = 2; // 룰렛 꽝 위로 선물

/// 세션 구성
const int sessionSize = 10;
const int maxNewCardsPerSession = 4;

/// 숙달 판정: 해당 단의 모든 카드 연속 정답 횟수
const int masteryConsecutive = 3;

/// 한국어 숫자 읽기 (구구단 암송용)
const List<String> _sino = ['영', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

String sinoReading(int n) {
  if (n < 10) return _sino[n];
  final tens = n ~/ 10;
  final ones = n % 10;
  final tensPart = tens == 1 ? '십' : '${_sino[tens]}십';
  return ones == 0 ? tensPart : '$tensPart${_sino[ones]}';
}

/// 전통 구구단 암송문: "이 삼은 육", "칠 팔은 오십육", "이 사 팔", "구 구 팔십일"
/// 조사 규칙: 곱하는 수가 받침으로 끝나면 '은'(일/삼/육/칠/팔), '이'는 '는', 나머지는 없음
String chantText(int a, int b) {
  const particles = {1: '은', 2: '는', 3: '은', 6: '은', 7: '은', 8: '은'};
  final particle = particles[b] ?? '';
  return '${_sino[a]} ${_sino[b]}$particle ${sinoReading(a * b)}';
}

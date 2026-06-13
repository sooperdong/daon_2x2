import 'package:flutter/material.dart';

import '../data/game_repository.dart';
import '../widgets/dajoy_character.dart';
import 'roulette_screen.dart';
import 'shop_screen.dart' show styleFromProfile;

/// 달리기 완료 화면 — 보상 요약과 룰렛 안내.
class ResultScreen extends StatelessWidget {
  final GameRepository repo;
  final int correct;
  final int total;
  final int score; // 모은 별가루 (정답 곱의 합)
  final int starsGained;
  final int xpGained;
  final int levelUps;
  final List<int> newMasteries;
  final bool streakTicket;
  final bool perfectTicket;

  const ResultScreen({
    super.key,
    required this.repo,
    required this.correct,
    required this.total,
    required this.score,
    required this.starsGained,
    required this.xpGained,
    required this.levelUps,
    required this.newMasteries,
    required this.streakTicket,
    required this.perfectTicket,
  });

  @override
  Widget build(BuildContext context) {
    final hasTicket = repo.profile.rouletteTickets > 0;
    final perfect = correct == total && total > 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                DajoyCharacter(
                  expression:
                      perfect ? DajoyExpression.jackpot : DajoyExpression.cheer,
                  size: 140,
                  style: styleFromProfile(repo.profile),
                ),
                const SizedBox(height: 12),
                Text(perfect ? '🏆 완벽한 질주!' : '🏁 도착!',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _rewardRow('🎯', '$total개 중 $correct개 정답'),
                _rewardRow('✨', '별가루 $score개 모음'),
                _rewardRow('⭐', '별 조각 +$starsGained'),
                _rewardRow('💫', 'XP +$xpGained'),
                if (levelUps > 0)
                  _rewardRow('🎉',
                      '레벨 업! 김다조이가 레벨 ${repo.profile.level}이 되었어!'),
                for (final masteredDan in newMasteries)
                  _rewardRow('👑', '$masteredDan단 마스터! 룰렛 티켓 +1'),
                if (perfectTicket)
                  _rewardRow('🌟', '한 문제도 안 틀렸어! 룰렛 티켓 +1'),
                if (streakTicket)
                  _rewardRow('🔥',
                      '${repo.profile.streak}일 연속 달리기! 룰렛 티켓 +1'),
                const SizedBox(height: 24),
                if (hasTicket)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => RouletteScreen(repo: repo)),
                    ),
                    icon: const Text('🎡', style: TextStyle(fontSize: 22)),
                    label: const Text('마법 룰렛 돌리기!',
                        style: TextStyle(fontSize: 18)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('집으로', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 17))),
        ],
      ),
    );
  }
}

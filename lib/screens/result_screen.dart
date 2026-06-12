import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/game_repository.dart';
import '../widgets/dajoy_character.dart';
import 'roulette_screen.dart';

/// 세션 완료 화면 — 보상 요약과 룰렛 안내
class ResultScreen extends StatelessWidget {
  final GameRepository repo;
  final int dan;
  final int correct;
  final int total;
  final int xpGained;
  final int levelUps;
  final bool newMastery;
  final bool streakTicket;

  const ResultScreen({
    super.key,
    required this.repo,
    required this.dan,
    required this.correct,
    required this.total,
    required this.xpGained,
    required this.levelUps,
    required this.newMastery,
    required this.streakTicket,
  });

  @override
  Widget build(BuildContext context) {
    final world = worlds[dan]!;
    final hasTicket = repo.profile.rouletteTickets > 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const DajoyCharacter(expression: DajoyExpression.cheer, size: 140),
                const SizedBox(height: 12),
                Text('${world.emoji} 스테이지 클리어!',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _rewardRow('🎯', '$total문제 중 $correct문제 정답'),
                _rewardRow('✨', 'XP +$xpGained'),
                _rewardRow('⭐', '별 조각 +$starPiecesPerSession'),
                if (levelUps > 0)
                  _rewardRow('🎉', '레벨 업! 김다조이가 레벨 ${repo.profile.level}이 되었어!'),
                if (newMastery) _rewardRow('👑', '$dan단 마스터! 룰렛 티켓 +1'),
                if (streakTicket)
                  _rewardRow('🔥', '${repo.profile.streak}일 연속 학습! 룰렛 티켓 +1'),
                const SizedBox(height: 24),
                if (hasTicket)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => RouletteScreen(repo: repo)),
                    ),
                    icon: const Text('🎡', style: TextStyle(fontSize: 22)),
                    label: const Text('마법 룰렛 돌리기!', style: TextStyle(fontSize: 18)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('지도로 돌아가기', style: TextStyle(fontSize: 16)),
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
          Text(text, style: const TextStyle(fontSize: 17)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/game_repository.dart';
import '../engine/progression.dart';
import '../engine/star_catch.dart';
import '../widgets/dajoy_character.dart';
import 'adventure_screen.dart';
import 'roulette_screen.dart';
import 'shop_screen.dart';
import 'star_catch_screen.dart';

/// 메인 화면 — 김다조이 + 세계 지도.
/// SDT 자율성 원칙: 어떤 세계에 갈지 아이가 직접 선택한다.
class HomeScreen extends StatefulWidget {
  final GameRepository repo;

  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameRepository get repo => widget.repo;

  @override
  Widget build(BuildContext context) {
    final unlocked = Progression.unlockedDans(repo.deck);
    final profile = repo.profile;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profile.level, profile.xp, profile.xpForNextLevel),
            _buildStats(),
            const SizedBox(height: 8),
            _buildModeButtons(),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final dan in danUnlockOrder)
                    _WorldCard(
                      info: worlds[dan]!,
                      unlocked: unlocked.contains(dan),
                      mastered: Progression.isMastered(dan, repo.deck),
                      progress: Progression.progress(dan, repo.deck),
                      onTap: () => _enterWorld(dan),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int level, int xp, int xpNext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          DajoyCharacter(
            expression: DajoyExpression.happy,
            size: 88,
            style: styleFromProfile(repo.profile),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('김다조이',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('레벨 $level 수학 마법사', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: xp / xpNext,
                    minHeight: 12,
                    backgroundColor: Colors.black12,
                    color: const Color(0xFFFFB300),
                  ),
                ),
                Text('$xp / $xpNext XP', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final p = repo.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(emoji: '⭐', label: '${p.starPieces}개'),
          _StatChip(emoji: '🐷', label: '${p.piggyBank}원'),
          _StatChip(emoji: '🔥', label: '${p.streak}일 연속'),
          GestureDetector(
            onTap: p.rouletteTickets > 0 ? _openRoulette : null,
            child: _StatChip(
              emoji: '🎡',
              label: '티켓 ${p.rouletteTickets}장',
              highlight: p.rouletteTickets > 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButtons() {
    final starCatchOpen = StarCatch.unlocked(repo.deck);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => _push(ShopScreen(repo: repo)),
              child: const Text('🛍️ 꾸미기 상점', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonal(
              onPressed: starCatchOpen ? () => _push(StarCatchScreen(repo: repo)) : null,
              child: Text(
                starCatchOpen ? '🌠 별 수집' : '🌠 별 수집 (마법 4개 배우면 열려!)',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    setState(() {});
  }

  Future<void> _enterWorld(int dan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdventureScreen(repo: repo, dan: dan)),
    );
    setState(() {});
  }

  Future<void> _openRoulette() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouletteScreen(repo: repo)),
    );
    setState(() {});
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool highlight;

  const _StatChip({required this.emoji, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFE082) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text('$emoji $label', style: const TextStyle(fontSize: 14)),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final WorldInfo info;
  final bool unlocked;
  final bool mastered;
  final double progress;
  final VoidCallback onTap;

  const _WorldCard({
    required this.info,
    required this.unlocked,
    required this.mastered,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? info.color.withValues(alpha: 0.25) : Colors.black12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mastered ? const Color(0xFFFFB300) : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(unlocked ? info.emoji : '🔒', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text('${info.dan}단 · ${info.name}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: unlocked ? Colors.black87 : Colors.black38,
                )),
            if (mastered)
              const Text('👑 마스터!', style: TextStyle(fontSize: 12, color: Color(0xFFE65100))),
            if (unlocked && !mastered) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    color: info.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

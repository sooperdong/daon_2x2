import 'package:flutter/material.dart';

import '../data/game_repository.dart';
import '../engine/progression.dart';
import '../services/sync_service.dart';
import '../widgets/dajoy_character.dart';
import 'parent_screen.dart';
import 'roulette_screen.dart';
import 'runner_screen.dart';
import 'shop_screen.dart';

/// 메인 화면 — 김다조이 + 달리기 시작.
/// 단순함이 핵심: 큰 버튼 하나로 바로 게임에 들어간다.
class HomeScreen extends StatefulWidget {
  final GameRepository repo;
  final SyncService sync;

  const HomeScreen({super.key, required this.repo, required this.sync});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameRepository get repo => widget.repo;

  // 레벨 뱃지 3번 탭 → 부모 화면 진입
  int _levelTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final profile = repo.profile;
    final unlocked = Progression.unlockedDans(repo.deck);
    final learning = unlocked.join(', ');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F6), Color(0xFFFFE3EC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(profile.level, profile.xp, profile.xpForNextLevel),
              const SizedBox(height: 8),
              _buildStats(),
              const Spacer(),
              // 탭하면 꾸미기 — 캐릭터에 대한 애착
              GestureDetector(
                onTap: _openShop,
                child: Column(
                  children: [
                    DajoyCharacter(
                      expression: DajoyExpression.happy,
                      size: 180,
                      style: styleFromProfile(profile),
                    ),
                    const Text('툭 누르면 꾸미기 ✨',
                        style: TextStyle(fontSize: 13, color: Colors.black45)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('지금 배우는 단: $learning단',
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startRun,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B5EA7),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('🏃 달리기 시작!',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int level, int xp, int xpNext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Text('김다조이',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _onLevelTap,
                  child: Text('레벨 $level 수학 마법사',
                      style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(emoji: '⭐', label: '${p.starPieces}개'),
          _StatChip(emoji: '🐷', label: '${p.piggyBank}원'),
          _StatChip(emoji: '🔥', label: '${p.streak}일'),
          GestureDetector(
            onTap: p.rouletteTickets > 0 ? _openRoulette : null,
            child: _StatChip(
              emoji: '🎡',
              label: '티켓 ${p.rouletteTickets}',
              highlight: p.rouletteTickets > 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRun() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RunnerScreen(repo: repo)),
    );
    setState(() {});
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopScreen(repo: repo)),
    );
    setState(() {});
  }

  Future<void> _openRoulette() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouletteScreen(repo: repo)),
    );
    setState(() {});
  }

  void _onLevelTap() {
    _levelTapCount++;
    if (_levelTapCount >= 3) {
      _levelTapCount = 0;
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => ParentScreen(repo: repo, sync: widget.sync)))
          .then((_) => setState(() {}));
    }
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool highlight;

  const _StatChip(
      {required this.emoji, required this.label, this.highlight = false});

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

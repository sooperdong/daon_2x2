import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/game_repository.dart';
import '../services/sync_service.dart';

/// 부모 리포트 — PIN 보호 화면.
/// 진입: 홈 화면 레벨 뱃지 3번 탭 (아이가 우연히 들어가기 어렵게)
class ParentScreen extends StatefulWidget {
  final GameRepository repo;
  final SyncService sync;

  const ParentScreen({super.key, required this.repo, required this.sync});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  bool _unlocked = false;
  String _pinInput = '';
  String? _error;

  // PIN 신규 설정: 2회 입력 확인 (오타로 영구 잠금 방지)
  String? _pinFirst; // 첫 번째 입력값 보관

  // 가족 코드 입력
  final _codeCtrl = TextEditingController();
  bool _syncBusy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍👩‍👧 부모 리포트'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _unlocked ? _buildReport() : _buildPin(),
      ),
    );
  }

  // ── PIN 잠금 화면 ─────────────────────────────────────────────────────

  Widget _buildPin() {
    final profile = widget.repo.profile;
    final hasPin = profile.parentPin != null;

    return Center(
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              hasPin
                  ? '부모님 PIN을 입력해주세요'
                  : (_pinFirst == null
                      ? 'PIN을 새로 설정해주세요 (4자리 숫자)'
                      : 'PIN을 한 번 더 입력해주세요'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // PIN 도트 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pinInput.length
                        ? const Color(0xFF7B5EA7)
                        : Colors.black12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            // 숫자 패드
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: [
                for (var d = 1; d <= 9; d++) _pinKey('$d'),
                _pinKey('', icon: Icons.backspace_outlined, onTap: _backspace),
                _pinKey('0'),
                _pinKey('', icon: Icons.check_circle_outline, onTap: _confirm),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinKey(String digit,
      {IconData? icon, VoidCallback? onTap}) {
    return OutlinedButton(
      onPressed: onTap ?? (digit.isEmpty ? null : () => _typePin(digit)),
      child: icon != null
          ? Icon(icon)
          : Text(digit, style: const TextStyle(fontSize: 22)),
    );
  }

  void _typePin(String digit) {
    if (_pinInput.length >= 4) return;
    setState(() {
      _pinInput += digit;
      _error = null;
    });
  }

  void _backspace() => setState(() {
        if (_pinInput.isNotEmpty) _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        _error = null;
      });

  Future<void> _confirm() async {
    if (_pinInput.length < 4) {
      setState(() => _error = '4자리를 모두 입력해주세요');
      return;
    }
    final profile = widget.repo.profile;
    if (profile.parentPin == null) {
      // 신규 PIN 설정 — 오타 방지를 위해 2회 입력 확인
      if (_pinFirst == null) {
        setState(() {
          _pinFirst = _pinInput;
          _pinInput = '';
          _error = null;
        });
        return;
      }
      if (_pinFirst != _pinInput) {
        setState(() {
          _pinFirst = null;
          _pinInput = '';
          _error = 'PIN이 일치하지 않아요. 처음부터 다시 입력해주세요';
        });
        return;
      }
      profile.parentPin = _pinInput;
      await widget.repo.saveProfile();
      setState(() => _unlocked = true);
    } else if (profile.parentPin == _pinInput) {
      setState(() => _unlocked = true);
    } else {
      setState(() {
        _error = 'PIN이 틀렸어요 다시 입력해주세요';
        _pinInput = '';
      });
    }
  }

  // ── 리포트 본문 ──────────────────────────────────────────────────────

  Widget _buildReport() {
    final repo = widget.repo;
    final profile = repo.profile;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('📊 전체 현황'),
        _buildSummaryCards(repo),
        const SizedBox(height: 20),
        _sectionTitle('📅 최근 30일 출석'),
        _AttendanceCalendar(playDates: profile.playDates),
        const SizedBox(height: 20),
        _sectionTitle('📈 단별 정답률'),
        _DanChart(stats: repo.danStats()),
        const SizedBox(height: 20),
        _sectionTitle('🐷 저금통'),
        _buildPiggyBank(profile),
        const SizedBox(height: 20),
        _sectionTitle('📱 기기 동기화'),
        _buildSyncSection(),
        const SizedBox(height: 20),
        _sectionTitle('⚙️ PIN 관리'),
        OutlinedButton(
          onPressed: _resetPin,
          child: const Text('PIN 변경'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _buildSummaryCards(GameRepository repo) {
    final profile = repo.profile;
    final total = repo.totalAttemptedAll();
    final correct = repo.totalCorrectAll();
    final rate = total == 0 ? 0 : (correct * 100 ~/ total);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard('레벨', '${profile.level}', '⭐'),
        _StatCard('연속 학습', '${profile.streak}일', '🔥'),
        _StatCard('총 세션', '${repo.totalSessions()}회', '📚'),
        _StatCard('정답률', '$rate%', '🎯'),
        _StatCard('마스터 단', '${profile.masteredDans.length}/8단', '👑'),
      ],
    );
  }

  Widget _buildPiggyBank(profile) {
    final history = (profile.rouletteHistory as List<String>).reversed.take(10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🐷', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 잔액',
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                  Text('${profile.piggyBank}원',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (history.isNotEmpty) ...[
          const Text('최근 당첨 내역', style: TextStyle(color: Colors.black54)),
          for (final h in history) ...[
            const SizedBox(height: 4),
            Text(_formatRouletteHistory(h), style: const TextStyle(fontSize: 14)),
          ],
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _resetPiggyBank,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('지급 완료 (저금통 초기화)'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
        ),
      ],
    );
  }

  Widget _buildSyncSection() {
    final profile = widget.repo.profile;

    if (!widget.sync.isEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Firebase 미설정', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'pubspec.yaml 의 firebase 주석을 해제하고\n'
              'google-services.json 을 추가하면\n'
              '태블릿 ↔ 폰 간 자동 동기화가 활성화됩니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.familyCode != null) ...[
          Row(
            children: [
              const Text('가족 코드: ', style: TextStyle(fontSize: 16)),
              Text(
                profile.familyCode!,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Color(0xFF7B5EA7)),
              ),
            ],
          ),
          const Text('다른 기기에서 같은 코드를 입력하면 동기화됩니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _syncNow,
            child: _syncBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('지금 동기화'),
          ),
        ] else ...[
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '가족 코드 입력 (다른 기기의 코드 입력)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: () => _setCode(_codeCtrl.text),
                child: const Text('코드 연결'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _newCode,
                child: const Text('새 코드 생성'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setCode(String code) async {
    if (code.length != 6) return;
    setState(() => _syncBusy = true);
    await widget.sync.setFamilyCode(widget.repo, code.toUpperCase());
    setState(() => _syncBusy = false);
  }

  Future<void> _newCode() async {
    final code = generateFamilyCode();
    await _setCode(code);
  }

  Future<void> _syncNow() async {
    setState(() => _syncBusy = true);
    var ok = true;
    try {
      // 먼저 받아서 병합한 뒤, 병합 결과를 업로드
      await widget.sync.pull(widget.repo);
      await widget.sync.push(widget.repo);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _syncBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '동기화 완료!' : '동기화 실패 — 인터넷 연결을 확인해주세요')),
    );
  }

  Future<void> _resetPiggyBank() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저금통 초기화'),
        content: Text('${widget.repo.profile.piggyBank}원을 김다조이에게 주셨나요?\n'
            '확인하면 저금통이 0원이 됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('주었어요!')),
        ],
      ),
    );
    if (ok != true) return;
    widget.repo.profile.piggyBank = 0;
    await widget.repo.saveProfile();
    setState(() {});
  }

  Future<void> _resetPin() async {
    setState(() {
      _unlocked = false;
      _pinInput = '';
      widget.repo.profile.parentPin = null;
    });
    await widget.repo.saveProfile();
  }

  String _formatRouletteHistory(String h) {
    // "2026-06-12T10:30:00.000:won100" → "6/12 — 100원 당첨"
    final parts = h.split(':');
    if (parts.length < 2) return h;
    final dateStr = parts.first.substring(5, 10).replaceAll('-', '/'); // MM/DD
    final prize = parts.last;
    final label = switch (prize) {
      'won100' => '100원 당첨 💰',
      'won1000' => '1000원 당첨 🎉',
      _ => '꽝',
    };
    return '$dateStr  $label';
  }
}

// ── 서브 위젯 ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String emoji;

  const _StatCard(this.title, this.value, this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// 30일 출석 달력 — 점 그리드
class _AttendanceCalendar extends StatelessWidget {
  final List<String> playDates;

  const _AttendanceCalendar({required this.playDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final Set<String> played = Set.from(playDates);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 30,
      itemBuilder: (_, i) {
        final day = now.subtract(Duration(days: 29 - i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final attended = played.contains(key);
        return Tooltip(
          message: '${day.month}/${day.day}',
          child: Container(
            decoration: BoxDecoration(
              color: attended ? const Color(0xFF7B5EA7) : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: attended
                ? const Center(
                    child: Text('⭐', style: TextStyle(fontSize: 10)))
                : null,
          ),
        );
      },
    );
  }
}

/// 단별 정답률 가로 막대 차트 — 외부 라이브러리 없이 CustomPainter
class _DanChart extends StatelessWidget {
  final Map<int, (int, int)> stats; // dan → (total, correct)

  const _DanChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('아직 학습 기록이 없어요. 탐험을 시작해봐요! 🌈',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return Column(
      children: [
        for (final dan in danUnlockOrder)
          if (stats.containsKey(dan)) _buildBar(dan, stats[dan]!),
      ],
    );
  }

  Widget _buildBar(int dan, (int, int) stat) {
    final total = stat.$1;
    final correct = stat.$2;
    final rate = total == 0 ? 0.0 : correct / total;
    final world = worlds[dan]!;
    final color = rate >= 0.8
        ? const Color(0xFF4CAF50) // 잘함
        : rate >= 0.5
            ? const Color(0xFFFFB300) // 보통
            : const Color(0xFFE57373); // 어려워함

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text('${world.emoji} $dan단',
                style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                    height: 22,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(6))),
                FractionallySizedBox(
                  widthFactor: rate.clamp(0.0, 1.0),
                  child: Container(
                    height: 22,
                    decoration:
                        BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text('${(rate * 100).round()}%',
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

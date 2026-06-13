import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/game_repository.dart';
import '../engine/progression.dart';
import '../engine/runner_engine.dart';
import '../engine/sm2_scheduler.dart';
import '../services/tts_service.dart';
import '../widgets/dajoy_character.dart';
import 'result_screen.dart';
import 'shop_screen.dart' show styleFromProfile;

// 정답/오답 시 출력되는 개그 텍스트
const _correctPhrases = [
  '우와앙 천재! 🤩', '완벽해! 🎊', '대박이야! 💥', '최고야! 👑', '눈부셔! ✨', '거의 신이야! 😍',
];
const _wrongPhrases = [
  '아이코! 🍌', '으아아! 😵', '삐용~ 🚨', '앗 미끄러짐!', '괜찮아! 다시! 💪',
];

/// 콤보 러너 — 곱셈이 곧 게임 메커니즘.
/// 연속 정답이 쌓이면 콤보가 올라가고 별가루 배율이 늘어난다.
/// 게이트가 빠르게 달려들수록 화면이 붉게 물들며 긴장감을 준다.
/// 틀려도 죽지 않는다(no-fail) — 콤보만 리셋된다.
class RunnerScreen extends StatefulWidget {
  final GameRepository repo;

  const RunnerScreen({super.key, required this.repo});

  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen>
    with TickerProviderStateMixin {
  final _rng = Random();

  // 게이트가 위에서 내려오는 연출 — Curves.easeIn 으로 마지막에 확 달려든다
  late final AnimationController _approach;
  late final CurvedAnimation _approachCurved;

  // 오답 시 캐릭터 흔들기
  late final AnimationController _shake;

  RunnerGate? _gate;
  int _gateNo = 0;
  int _combo = 0;      // 연속 정답 수 (틀리면 0 리셋)
  int _bestCombo = 0;
  int _score = 0;      // 획득한 별가루 합계
  int _correct = 0;
  int _wrong = 0;
  int _lastEarned = 0; // 마지막 답변으로 얻은 별가루

  int? _chosen;
  bool _showFeedback = false;
  bool _lastCorrect = false;
  bool _busy = false;

  bool _gateArrived = false;
  DateTime? _gateArrivalTime;

  String? _gagText;

  final Set<String> _firstSeen = {};

  DajoyExpression _expr = DajoyExpression.focus;

  @override
  void initState() {
    super.initState();
    _approach = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _approachCurved = CurvedAnimation(
      parent: _approach,
      curve: Curves.easeIn,
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _approach.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _gateArrived = true;
          _gateArrivalTime = DateTime.now();
        });
      }
    });
    _loadGate();
  }

  @override
  void dispose() {
    _approachCurved.dispose();
    _approach.dispose();
    _shake.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  void _loadGate() {
    final gate = RunnerEngine.nextGate(
      widget.repo.deck,
      DateTime.now(),
      random: _rng,
      avoidId: _gate?.card.id,
    );
    setState(() {
      _gate = gate;
      _chosen = null;
      _showFeedback = false;
      _gagText = null;
      _gateArrived = false;
      _gateArrivalTime = null;
      _expr = DajoyExpression.focus;
    });
    _approach
      ..reset()
      ..forward();
  }

  Future<void> _choose(int doorIndex) async {
    final gate = _gate;
    if (gate == null || _busy || _chosen != null) return;

    final correct = doorIndex == gate.correctIndex;
    final card = gate.card;
    final now = DateTime.now();

    if (!_firstSeen.contains(card.id)) {
      _firstSeen.add(card.id);
      Sm2Scheduler.review(card, correct: correct, now: now);
      await widget.repo.saveCard(card);
    }
    await widget.repo.logAnswer(
      cardId: card.id,
      correct: correct,
      firstAttempt: true,
      at: now,
    );

    if (correct) {
      final newCombo = _combo + 1;
      final mult = newCombo >= 5 ? 3 : (newCombo >= 3 ? 2 : 1);
      int earned = gate.answer * mult;

      // 번개 답변 보너스 (게이트 도착 후 1.5초 이내 정답)
      int speedBonus = 0;
      if (_gateArrived && _gateArrivalTime != null) {
        if (now.difference(_gateArrivalTime!).inMilliseconds < 1500) {
          speedBonus = gate.answer;
          earned += speedBonus;
        }
      }

      setState(() {
        _busy = true;
        _chosen = doorIndex;
        _lastCorrect = true;
        _showFeedback = true;
        _correct++;
        _combo = newCombo;
        if (_combo > _bestCombo) _bestCombo = _combo;
        _score += earned;
        _lastEarned = earned;
        _expr = DajoyExpression.cheer;
        _gagText = speedBonus > 0
            ? '⚡ 번개 답변! +$speedBonus'
            : _correctPhrases[_rng.nextInt(_correctPhrases.length)];
      });
    } else {
      setState(() {
        _busy = true;
        _chosen = doorIndex;
        _lastCorrect = false;
        _showFeedback = true;
        _wrong++;
        _combo = 0;
        _lastEarned = 0;
        _expr = DajoyExpression.silly;
        _gagText = _wrongPhrases[_rng.nextInt(_wrongPhrases.length)];
      });
      _shake.forward(from: 0);
      TtsService.instance.speak(
          '${card.a} 곱하기 ${card.b}${_eunNeun(card.b)} ${card.answer}');
    }

    await Future.delayed(Duration(milliseconds: correct ? 750 : 1700));
    if (!mounted) return;

    _gateNo++;
    if (_gateNo >= RunnerEngine.gatesPerRun) {
      await _finish();
    } else {
      setState(() => _busy = false);
      _loadGate();
    }
  }

  Future<void> _finish() async {
    final repo = widget.repo;
    final profile = repo.profile;
    final now = DateTime.now();

    final starsGained = _correct;
    final xpGained = _correct * xpPerCorrect + 20;
    final levelUps = profile.addXp(xpGained);
    profile.starPieces += starsGained;

    final streakTicket = profile.recordPlayToday(now);
    if (streakTicket) profile.rouletteTickets++;

    final perfectTicket = _wrong == 0 && _correct == RunnerEngine.gatesPerRun;
    if (perfectTicket) profile.rouletteTickets++;

    final newMasteries =
        Progression.newlyMastered(profile.masteredDans, repo.deck);
    profile.masteredDans.addAll(newMasteries);
    profile.rouletteTickets += newMasteries.length;

    await repo.saveProfile();
    await repo.logEvent('run', {
      'correct': _correct,
      'total': RunnerEngine.gatesPerRun,
      'score': _score,
    }, now);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(
        repo: repo,
        correct: _correct,
        total: RunnerEngine.gatesPerRun,
        score: _score,
        starsGained: starsGained,
        xpGained: xpGained,
        levelUps: levelUps,
        newMasteries: newMasteries,
        streakTicket: streakTicket,
        perfectTicket: perfectTicket,
      ),
    ));
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _approachCurved,
        builder: (ctx, child) {
          // 게이트가 가까워질수록 (0.65 이후) 배경이 붉게 변한다 — 긴장감
          final u = ((_approachCurved.value - 0.65) / 0.35).clamp(0.0, 1.0);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(const Color(0xFF3949AB), const Color(0xFF880E4F), u)!,
                  Color.lerp(const Color(0xFF7E57C2), const Color(0xFFC62828), u)!,
                  Color.lerp(const Color(0xFFFFB6C1), const Color(0xFFFF8A80), u)!,
                ],
              ),
            ),
            child: child!,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              Expanded(child: _buildTrack()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: '그만하기',
          ),
          const Spacer(),
          _hudChip('✨', '$_score'),
          if (_combo >= 2) ...[
            const SizedBox(width: 8),
            _hudChip('🔥', '×$_combo'),
          ],
          const SizedBox(width: 8),
          _hudChip('🚩',
              '${(_gateNo + 1).clamp(1, RunnerEngine.gatesPerRun)}/${RunnerEngine.gatesPerRun}'),
        ],
      ),
    );
  }

  Widget _hudChip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$emoji $label',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTrack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final decisionY = h * 0.30;
        final gate = _gate;

        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _LanePainter())),

            if (gate != null)
              AnimatedBuilder(
                animation: _approachCurved,
                builder: (context, child) {
                  final top = _lerp(-h * 0.32, decisionY, _approachCurved.value);
                  return Positioned(
                      top: top, left: 0, right: 0, child: child!);
                },
                child: _buildGate(gate, w),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: _buildRunner(),
            ),

            if (_showFeedback && gate != null)
              Positioned(
                top: decisionY - h * 0.14,
                left: 0,
                right: 0,
                child: Center(child: _buildFeedback(gate)),
              ),

            // 개그 텍스트 오버레이
            if (_gagText != null)
              Positioned(
                bottom: h * 0.26,
                left: 16,
                right: 16,
                child: Center(
                  child: Text(
                    _gagText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: _lastCorrect
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFFFFE082),
                      shadows: const [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(1, 2))
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGate(RunnerGate gate, double trackWidth) {
    return Column(
      children: [
        _buildArray(gate),
        const SizedBox(height: 6),
        // 게이트가 도착하면 문제 텍스트가 커지고 노란색으로 변해 시선을 잡는다
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: _gateArrived ? 46 : 40,
            fontWeight: FontWeight.bold,
            color: _gateArrived ? const Color(0xFFFFFF00) : Colors.white,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
          child: Text('${gate.a} × ${gate.b}'),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < gate.doors.length; i++)
              _buildDoor(i, gate.doors[i]),
          ],
        ),
      ],
    );
  }

  Widget _buildArray(RunnerGate gate) {
    const dot = 9.0;
    const gap = 3.0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < gate.b; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: gap / 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < gate.a; c++)
                    Container(
                      width: dot,
                      height: dot,
                      margin: const EdgeInsets.symmetric(horizontal: gap / 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD54F),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoor(int index, int value) {
    final chosen = _chosen == index;
    final isCorrect = _gate?.correctIndex == index;

    Color color = Colors.white;
    if (_showFeedback) {
      color = isCorrect
          ? const Color(0xFF66BB6A)
          : chosen
              ? const Color(0xFFEF9A9A)
              : Colors.white;
    }

    return GestureDetector(
      onTap: () => _choose(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 88,
        height: 76,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: Text('$value',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C))),
      ),
    );
  }

  Widget _buildRunner() {
    final comboGlow = _combo >= 3;
    final style = styleFromProfile(widget.repo.profile);

    return Column(
      children: [
        // 콤보 배지 (연속 2개 이상부터 표시)
        if (_combo >= 2)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: _combo >= 5
                  ? const Color(0xFFFF6F00)
                  : _combo >= 3
                      ? const Color(0xFFFFA000)
                      : const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(20),
              boxShadow: comboGlow
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
                        blurRadius: 14,
                        spreadRadius: 3,
                      )
                    ]
                  : null,
            ),
            child: Text(
              '🔥 ${_combo}연속!'
              '${_combo >= 5 ? " ×3 초대박!" : _combo >= 3 ? " ×2!" : ""}',
              style: TextStyle(
                color: _combo >= 3 ? Colors.white : const Color(0xFF4A148C),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        // 김다조이 — 오답 시 흔들기
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            return Transform.rotate(
              angle: sin(_shake.value * pi) * 0.28,
              child: child!,
            );
          },
          child: comboGlow
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFFD54F).withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: DajoyCharacter(
                    expression: _expr,
                    size: 84,
                    style: style,
                  ),
                )
              : DajoyCharacter(
                  expression: _expr,
                  size: 84,
                  style: style,
                ),
        ),
      ],
    );
  }

  Widget _buildFeedback(RunnerGate gate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _lastCorrect
            ? const Color(0xCC2E7D32)
            : const Color(0xCCC62828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lastCorrect
            ? '✨ ${gate.a}×${gate.b}=${gate.answer}${_combo >= 3 ? " ×${_combo >= 5 ? 3 : 2}" : ""}! +$_lastEarned'
            : '${gate.a}×${gate.b}=${gate.answer} 이야!',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 3개 레인 길 배경
class _LanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 3;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_LanePainter oldDelegate) => false;
}

/// 숫자 b에 맞는 조사 (은/는) — TTS용
String _eunNeun(int b) {
  const map = {1: '은', 2: '는', 3: '은', 6: '은', 7: '은', 8: '은'};
  return map[b] ?? '';
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

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

/// 별빛 군단 러너 — 곱셈이 곧 게임 메커니즘.
/// 김다조이 군단이 달리며 곱셈 게이트의 올바른 문을 통과하면
/// 별가루가 터지고 군단이 불어난다. 틀려도 죽지 않는다(no-fail).
class RunnerScreen extends StatefulWidget {
  final GameRepository repo;

  const RunnerScreen({super.key, required this.repo});

  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();

  late final AnimationController _approach; // 게이트가 위에서 내려오는 연출

  RunnerGate? _gate;
  int _gateNo = 0; // 지금까지 등장한 게이트 수
  int _crowd = RunnerEngine.startCrowd;
  int _score = 0; // 모은 별가루 (정답 곱의 합)
  int _correct = 0;
  int _wrong = 0;

  int? _chosen; // 선택한 문 (피드백 강조용)
  bool _showFeedback = false;
  bool _lastCorrect = false;
  bool _busy = false; // 피드백 중 입력 잠금

  // 한 번의 달리기에서 SM-2에 첫 시도로 반영한 카드 (중복 반영 방지)
  final Set<String> _firstSeen = {};

  DajoyExpression _expr = DajoyExpression.focus;

  @override
  void initState() {
    super.initState();
    _approach = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _loadGate();
  }

  @override
  void dispose() {
    _approach.dispose();
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
      _expr = DajoyExpression.focus;
    });
    _approach
      ..reset()
      ..forward(); // 끝나도 결정선에서 입력을 기다린다 (시간 압박 없음)
  }

  Future<void> _choose(int doorIndex) async {
    final gate = _gate;
    if (gate == null || _busy || _chosen != null) return;

    final correct = doorIndex == gate.correctIndex;
    final card = gate.card;
    final now = DateTime.now();

    // 첫 등장 시에만 SM-2에 반영 (한 달리기 안 중복 반영 방지)
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

    setState(() {
      _busy = true;
      _chosen = doorIndex;
      _lastCorrect = correct;
      _showFeedback = true;
      if (correct) {
        _correct++;
        _score += gate.answer;
        _crowd = (_crowd + RunnerEngine.crowdGainPerCorrect)
            .clamp(1, RunnerEngine.crowdCap);
        _expr = DajoyExpression.cheer;
      } else {
        _wrong++;
        _crowd = (_crowd - RunnerEngine.crowdLossPerWrong).clamp(1, RunnerEngine.crowdCap);
        _expr = DajoyExpression.focus;
        // 틀린 곱셈은 소리로 한 번 더 — 부호화 강화
        TtsService.instance.speak(
            '${card.a} 곱하기 ${card.b}${_eunNeun(card.b)} ${card.answer}');
      }
    });

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

    // 완벽한 질주 — 한 문제도 안 틀림
    final perfectTicket = _wrong == 0 && _correct == RunnerEngine.gatesPerRun;
    if (perfectTicket) profile.rouletteTickets++;

    final newMasteries = Progression.newlyMastered(profile.masteredDans, repo.deck);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3949AB), Color(0xFF7E57C2), Color(0xFFFFB6C1)],
          ),
        ),
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
          const SizedBox(width: 10),
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
        final decisionY = h * 0.30; // 게이트가 멈추는 결정선
        final gate = _gate;

        return Stack(
          children: [
            // 달리는 길 — 3개 레인
            Positioned.fill(child: CustomPaint(painter: _LanePainter())),

            // 게이트 (위 → 결정선으로 슬라이드, 끝나면 대기)
            if (gate != null)
              AnimatedBuilder(
                animation: _approach,
                builder: (context, child) {
                  final top = _lerp(-h * 0.32, decisionY, _approach.value);
                  return Positioned(top: top, left: 0, right: 0, child: child!);
                },
                child: _buildGate(gate, w),
              ),

            // 김다조이 + 군단 트레일 (바닥)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: _buildRunner(),
            ),

            // 피드백 오버레이
            if (_showFeedback && gate != null)
              Positioned(
                top: decisionY - h * 0.14,
                left: 0,
                right: 0,
                child: Center(child: _buildFeedback(gate)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGate(RunnerGate gate, double trackWidth) {
    return Column(
      children: [
        // 곱셈 배열 모델 — a열 × b행 점 (곱셈을 '넓이'로 보여줌)
        _buildArray(gate),
        const SizedBox(height: 6),
        Text('${gate.a} × ${gate.b}',
            style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
        const SizedBox(height: 10),
        // 3개의 문
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
    final cols = gate.a;
    final rows = gate.b;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: gap / 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < cols; c++)
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
    final isCorrectDoor = _gate?.correctIndex == index;

    Color color = Colors.white;
    if (_showFeedback) {
      if (isCorrectDoor) {
        color = const Color(0xFF66BB6A); // 정답 문은 항상 초록
      } else if (chosen) {
        color = const Color(0xFFEF9A9A); // 내가 고른 오답은 빨강
      }
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
                fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
      ),
    );
  }

  Widget _buildRunner() {
    final maxDots = min(_crowd, 14);
    return Column(
      children: [
        // 군단 트레일
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < maxDots; i++)
                Transform.translate(
                  offset: Offset((i - maxDots / 2) * 14, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: styleFromProfile(widget.repo.profile).ribbonColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        DajoyCharacter(
          expression: _expr,
          size: 84,
          style: styleFromProfile(widget.repo.profile),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('군단 $_crowd명',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFeedback(RunnerGate gate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _lastCorrect ? const Color(0xCC2E7D32) : const Color(0xCCC62828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lastCorrect
            ? '✨ ${gate.a}×${gate.b}=${gate.answer}! +${gate.answer}'
            : '${gate.a}×${gate.b}=${gate.answer} 이야!',
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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

/// 숫자 b에 맞는 조사 (은/는/없음) — TTS용
String _eunNeun(int b) {
  const map = {1: '은', 2: '는', 3: '은', 6: '은', 7: '은', 8: '은'};
  return map[b] ?? '';
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

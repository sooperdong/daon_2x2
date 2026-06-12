import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models/fact_card.dart';
import '../data/game_repository.dart';
import '../engine/question_generator.dart';
import '../engine/star_catch.dart';
import '../widgets/dajoy_character.dart';
import 'shop_screen.dart';

/// 별 수집 모드 — 선택형 보너스 게임.
/// 하늘에서 답이 적힌 별이 떨어진다. 문제를 보고 정답 별을 잡자!
/// 배운 카드만 섞여 나온다 (인터리빙 복습). SM-2 스케줄엔 영향 없음.
class StarCatchScreen extends StatefulWidget {
  final GameRepository repo;

  const StarCatchScreen({super.key, required this.repo});

  @override
  State<StarCatchScreen> createState() => _StarCatchScreenState();
}

class _FallingStar {
  final int value;
  final double x; // 0.0~1.0 (화면 폭 비율)
  double y; // 0.0~1.0 (화면 높이 비율)
  bool popped = false;

  _FallingStar({required this.value, required this.x, this.y = -0.1});
}

class _StarCatchScreenState extends State<StarCatchScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late final AnimationController _ticker;
  late final List<FactCard> _pool;

  FactCard? _question;
  List<_FallingStar> _stars = [];
  int _score = 0;
  int _secondsLeft = StarCatch.roundSeconds;
  DateTime _lastTick = DateTime.now();
  DateTime _roundStart = DateTime.now();
  bool _finished = false;
  bool _started = false;
  bool _wasNewRecord = false;
  int _lastReward = 0;

  @override
  void initState() {
    super.initState();
    _pool = StarCatch.pool(widget.repo.deck);
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _started = true;
      _finished = false;
      _score = 0;
      _secondsLeft = StarCatch.roundSeconds;
      _roundStart = DateTime.now();
      _lastTick = DateTime.now();
      _nextQuestion();
    });
    _ticker.forward(from: 0);
  }

  void _nextQuestion() {
    _question = StarCatch.pick(_pool, _rng, previous: _question);
    _spawnStars(_question!);
  }

  /// 별 3개 생성 (정답 1 + 오답 2) — 화면 혼잡 방지
  void _spawnStars(FactCard card) {
    final options = QuestionGenerator.choices(card, random: _rng);
    final values = <int>{card.answer, ...options.where((v) => v != card.answer).take(2)}.toList()
      ..shuffle(_rng);
    final xs = [0.18, 0.5, 0.82]..shuffle(_rng);
    _stars = [
      for (var i = 0; i < values.length; i++)
        _FallingStar(value: values[i], x: xs[i], y: -0.1 - i * 0.08),
    ];
  }

  void _onTick() {
    if (_finished) return;
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;

    final remaining = StarCatch.roundSeconds - now.difference(_roundStart).inSeconds;
    if (remaining <= 0) {
      _finish();
      return;
    }

    final speed = StarCatch.fallSpeed(_score);
    var allFallen = true;
    for (final star in _stars) {
      if (!star.popped) star.y += speed * dt;
      if (!star.popped && star.y < 1.1) allFallen = false;
    }
    // 모두 놓쳤으면 같은 문제로 다시 — 잃는 것 없음
    if (allFallen && _stars.isNotEmpty) {
      _spawnStars(_question!);
    }

    setState(() => _secondsLeft = remaining);
  }

  Future<void> _tapStar(_FallingStar star) async {
    if (_finished || star.popped) return;
    if (star.value == _question!.answer) {
      setState(() {
        _score++;
        _nextQuestion();
      });
    } else {
      setState(() => star.popped = true); // 오답 별만 터짐 — 패널티 없음
    }
  }

  Future<void> _finish() async {
    _ticker.stop();
    final repo = widget.repo;
    final profile = repo.profile;
    _wasNewRecord = _score > profile.starCatchHighScore;
    if (_wasNewRecord) profile.starCatchHighScore = _score;
    _lastReward = StarCatch.reward(_score, newRecord: _wasNewRecord);
    profile.starPieces += _lastReward;
    profile.recordPlayToday(DateTime.now()); // 별 수집도 출석으로 인정
    await repo.saveProfile();
    await repo.logEvent(
        'star_catch', {'score': _score, 'newRecord': _wasNewRecord}, DateTime.now());
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      appBar: AppBar(
        title: const Text('🌠 별 수집', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: !_started
            ? _buildIntro()
            : _finished
                ? _buildResult()
                : _buildGame(),
      ),
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DajoyCharacter(
            expression: DajoyExpression.cheer,
            size: 130,
            style: styleFromProfile(widget.repo.profile),
          ),
          const SizedBox(height: 16),
          const Text('떨어지는 별 중에 정답을 잡아줘!',
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('최고 기록: ${widget.repo.profile.starCatchHighScore}점',
              style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _start,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            ),
            child: const Text('시작!', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final q = _question!;
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            // 떨어지는 별들
            for (final star in _stars)
              if (!star.popped && star.y < 1.1)
                Positioned(
                  left: star.x * box.maxWidth - 36,
                  top: star.y * box.maxHeight,
                  child: GestureDetector(
                    onTap: () => _tapStar(star),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 60)),
                          Text('${star.value}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037))),
                        ],
                      ),
                    ),
                  ),
                ),
            // 상단 점수/시간
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('점수 $_score',
                      style: const TextStyle(
                          fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('⏱ $_secondsLeft초',
                      style: const TextStyle(fontSize: 20, color: Colors.white)),
                ],
              ),
            ),
            // 하단 문제
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${q.a} × ${q.b} = ?',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResult() {
    final profile = widget.repo.profile;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DajoyCharacter(
            expression: _wasNewRecord ? DajoyExpression.jackpot : DajoyExpression.happy,
            size: 130,
            style: styleFromProfile(profile),
          ),
          const SizedBox(height: 16),
          Text(_wasNewRecord ? '🏆 신기록! $_score점!' : '$_score점!',
              style: const TextStyle(
                  fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          Text('별 조각 +$_lastReward ⭐',
              style: const TextStyle(fontSize: 20, color: Color(0xFFFFD54F))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _start,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
            child: const Text('한 번 더!', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('돌아가기', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

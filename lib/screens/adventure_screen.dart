import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/models/fact_card.dart';
import '../data/game_repository.dart';
import '../engine/progression.dart';
import '../engine/question_generator.dart';
import '../engine/sm2_scheduler.dart';
import '../services/tts_service.dart';
import '../widgets/dajoy_character.dart';
import 'result_screen.dart';
import 'shop_screen.dart' show styleFromProfile;

/// 탐험 모드 — 핵심 학습 루프.
///
/// 학습 과학 원칙 적용:
///  - 타이머 없음 (시간 압박 → 수학 불안, Boaler 연구)
///  - 오답 무패널티: 몬스터가 방어막을 칠 뿐, 잃는 것 없음
///  - 틀린 문제는 잠시 후 재출제 → 즉시 재인출
///  - 새 카드는 암송 카드 먼저 (부호화) → 4지선다 → 직접 입력 (인출 강도 점증)
class AdventureScreen extends StatefulWidget {
  final GameRepository repo;
  final int dan;

  const AdventureScreen({super.key, required this.repo, required this.dan});

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

enum _Phase { chant, question, feedback }

class _AdventureScreenState extends State<AdventureScreen> {
  final _rng = Random();

  late List<FactCard> _queue;
  late int _monsterMaxHp;
  int _monsterHp = 0;
  int _correctFirstTry = 0;
  int _totalQuestions = 0;

  /// 이 세션에서 첫 시도를 이미 기록한 카드 (재도전은 SM-2 미반영)
  final Set<String> _attempted = {};

  /// 방어막 상태인 카드 (틀려서 재출제 대기 중)
  final Set<String> _shielded = {};

  _Phase _phase = _Phase.chant;
  FactCard? _current;
  List<int> _choices = [];
  String _typed = '';
  bool? _lastCorrect;
  bool _flipped = false; // 문제당 1회 결정 — build에서 재추첨하면 입력 중 화면이 바뀐다
  DajoyExpression _expression = DajoyExpression.focus;

  WorldInfo get _world => worlds[widget.dan]!;

  @override
  void initState() {
    super.initState();
    _queue = QuestionGenerator.compose(
      cards: widget.repo.deck,
      currentDan: widget.dan,
      now: DateTime.now(),
      random: _rng,
    );
    _totalQuestions = _queue.length;
    _monsterMaxHp = _queue.length;
    _monsterHp = _monsterMaxHp;
    if (_queue.isNotEmpty) _next();
  }

  void _next() {
    if (_queue.isEmpty) {
      _finish();
      return;
    }
    final card = _queue.removeAt(0);
    setState(() {
      _current = card;
      _typed = '';
      _lastCorrect = null;
      _flipped = card.a != card.b && _rng.nextBool(); // 교환법칙 노출: 절반 확률로 뒤집어 출제
      _expression = DajoyExpression.focus;
      // 처음 보는 카드는 암송 카드부터 (부호화 단계)
      if (card.isNew && !_attempted.contains(card.id) && !_shielded.contains(card.id)) {
        _phase = _Phase.chant;
      } else {
        _phase = _Phase.question;
        _choices = QuestionGenerator.choices(card, random: _rng);
      }
    });
  }

  void _startQuestion() {
    TtsService.instance.stop();
    setState(() {
      _phase = _Phase.question;
      _choices = QuestionGenerator.choices(_current!, random: _rng);
    });
  }

  /// 직접 입력 단계 여부: 연속 2회 이상 맞힌 카드는 숫자 패드로
  bool get _useInput => (_current?.consecutiveCorrect ?? 0) >= 2;

  Future<void> _answer(int value) async {
    if (_phase != _Phase.question) return; // 멀티터치 연타 방지
    final card = _current!;
    final correct = value == card.answer;
    final firstAttempt = !_attempted.contains(card.id);
    final now = DateTime.now();

    if (firstAttempt) {
      _attempted.add(card.id);
      Sm2Scheduler.review(card, correct: correct, now: now);
      await widget.repo.saveCard(card);
      if (correct) _correctFirstTry++;
    }
    await widget.repo.logAnswer(
      cardId: card.id,
      correct: correct,
      firstAttempt: firstAttempt,
      at: now,
    );

    setState(() {
      _lastCorrect = correct;
      _phase = _Phase.feedback;
      _expression = correct ? DajoyExpression.happy : DajoyExpression.cheer;
      if (correct) {
        _monsterHp = (_monsterHp - 1).clamp(0, _monsterMaxHp);
        _shielded.remove(card.id);
      } else {
        // 방어막: 잃는 것 없이 2문제 뒤 재출제
        _shielded.add(card.id);
        final insertAt = min(2, _queue.length);
        _queue.insert(insertAt, card);
      }
    });

    await Future.delayed(Duration(milliseconds: correct ? 900 : 2200));
    if (mounted) _next();
  }

  Future<void> _finish() async {
    final repo = widget.repo;
    final profile = repo.profile;

    final xpGained = _correctFirstTry * xpPerCorrect + xpPerSession;
    final levelUps = profile.addXp(xpGained);
    profile.starPieces += starPiecesPerSession;
    final streakTicket = profile.recordPlayToday(DateTime.now());
    if (streakTicket) profile.rouletteTickets++;

    // 단 마스터 신규 달성 체크 → 룰렛 티켓 (복습 카드로 다른 단이 숙달될 수도 있음)
    final newMasteries = Progression.newlyMastered(profile.masteredDans, repo.deck);
    profile.masteredDans.addAll(newMasteries);
    profile.rouletteTickets += newMasteries.length;

    await repo.saveProfile();
    await repo.logEvent('session', {
      'dan': widget.dan,
      'correct': _correctFirstTry,
      'total': _totalQuestions,
    }, DateTime.now());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          repo: repo,
          dan: widget.dan,
          correct: _correctFirstTry,
          total: _totalQuestions,
          xpGained: xpGained,
          levelUps: levelUps,
          newMasteries: newMasteries,
          streakTicket: streakTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 빈 세션: 복습 만기 카드도, 새 카드도 없음 — 보상 없이 안내만.
    // 그냥 완료 처리하면 클리어한 세계를 반복 탭해서 XP를 무한 파밍할 수 있다.
    if (_totalQuestions == 0) {
      return Scaffold(
        appBar: AppBar(title: Text('${_world.emoji} ${_world.name}')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DajoyCharacter(expression: DajoyExpression.happy, size: 120,
                  style: styleFromProfile(widget.repo.profile)),
              const SizedBox(height: 16),
              const Text('오늘은 여기서 복습할 마법이 없어!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('다른 세계를 탐험하거나 내일 다시 와줘 ✨',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('지도로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _current;
    if (card == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _world.color.withValues(alpha: 0.12),
      appBar: AppBar(
        title: Text('${_world.emoji} ${_world.name}'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonster(),
            const Spacer(),
            Expanded(
              flex: 6,
              child: switch (_phase) {
                _Phase.chant => _buildChantCard(card),
                _Phase.question => _buildQuestion(card),
                _Phase.feedback => _buildFeedback(card),
              },
            ),
            const Spacer(),
            DajoyCharacter(expression: _expression, size: 96,
                style: styleFromProfile(widget.repo.profile)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMonster() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(_world.monster, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('👾', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _monsterMaxHp == 0 ? 0 : _monsterHp / _monsterMaxHp,
                    minHeight: 16,
                    backgroundColor: Colors.black12,
                    color: const Color(0xFFE57373),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 암송 카드 — 부호화 단계 (한국식 구구단 읽기 + TTS 자동 발음)
  Widget _buildChantCard(FactCard card) {
    final chant = chantText(card.a, card.b);
    // 카드가 나타나는 순간 자동 발음 — WidgetsBinding으로 build 완료 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phase == _Phase.chant && _current?.id == card.id) {
        TtsService.instance.speakChant('${card.a} 곱하기 ${card.b}${_eunNeun(card.b)} ${card.answer}. $chant');
      }
    });

    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨ 새로운 마법이야! 따라 읽어봐', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text('${card.a} × ${card.b} = ${card.answer}',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('"$chant"',
                      style: const TextStyle(fontSize: 24, color: Color(0xFF7B5EA7))),
                  const SizedBox(width: 8),
                  // 다시 듣기 버튼
                  IconButton(
                    icon: const Text('🔊', style: TextStyle(fontSize: 22)),
                    tooltip: '다시 듣기',
                    onPressed: () => TtsService.instance.speakChant(
                        '${card.a} 곱하기 ${card.b}${_eunNeun(card.b)} ${card.answer}. $chant'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${card.b} × ${card.a}도 똑같이 ${card.answer}! 뒤집어도 같아 🔄',
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _startQuestion,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text('외웠어! 문제 풀기', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(FactCard card) {
    final left = _flipped ? card.b : card.a;
    final right = _flipped ? card.a : card.b;

    return Column(
      children: [
        if (_shielded.contains(card.id))
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('🛡️ 방어막을 깨자! 한 번 더!',
                style: TextStyle(fontSize: 16, color: Color(0xFF1565C0))),
          ),
        Text('$left × $right = ?',
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(child: _useInput ? _buildNumberPad(card) : _buildChoices()),
      ],
    );
  }

  Widget _buildChoices() {
    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final option in _choices)
          FilledButton.tonal(
            onPressed: () => _answer(option),
            child: Text('$option', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildNumberPad(FactCard card) {
    return Column(
      children: [
        Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26),
          ),
          child: Text(_typed.isEmpty ? ' ' : _typed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var d = 1; d <= 9; d++) _padKey('$d', () => _type('$d')),
              _padKey('지움', () => setState(() => _typed = '')),
              _padKey('0', () => _type('0')),
              _padKey('확인', _typed.isEmpty ? null : () => _answer(int.parse(_typed)), filled: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _padKey(String label, VoidCallback? onTap, {bool filled = false}) {
    return filled
        ? FilledButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 20)))
        : OutlinedButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 20)));
  }

  void _type(String digit) {
    if (_typed.length >= 2) return;
    setState(() => _typed += digit);
  }

  Widget _buildFeedback(FactCard card) {
    final correct = _lastCorrect ?? false;
    final praise = ['완벽해!', '천재인데?', '우와, 대단해!', '멋지다!'][_rng.nextInt(4)];
    // 문제와 같은 방향으로 정답 표시 — 방향이 바뀌면 아이가 헷갈린다
    final left = _flipped ? card.b : card.a;
    final right = _flipped ? card.a : card.b;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(correct ? '⚡ 공격 성공!' : '🛡️ 몬스터가 방어막을 쳤어!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('$left × $right = ${card.answer}',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: correct ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
              )),
          const SizedBox(height: 8),
          Text(
            correct ? '김다조이, $praise' : '괜찮아, 김다조이! 잠시 후 다시 도전하자!',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// 숫자 b에 맞는 조사 (은/는/없음) — TTS용
String _eunNeun(int b) {
  const map = {1: '은', 2: '는', 3: '은', 6: '은', 7: '은', 8: '은'};
  return map[b] ?? '';
}

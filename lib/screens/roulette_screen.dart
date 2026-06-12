import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/game_repository.dart';
import '../engine/roulette.dart';
import '../widgets/dajoy_character.dart';
import 'shop_screen.dart' show styleFromProfile;

/// 마법 룰렛 — 꽝 50% / 100원 40% / 1000원 10%.
/// 당첨금은 저금통에 쌓이고 부모가 실제 현금으로 전달한다.
/// 꽝이어도 별 조각 위로 선물 — "완전 꽝"은 없다.
class RouletteScreen extends StatefulWidget {
  final GameRepository repo;

  const RouletteScreen({super.key, required this.repo});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotation;
  final _rng = math.Random();

  RoulettePrize? _result;
  bool _spinning = false;
  double _baseAngle = 0; // 직전 스핀의 정지 각도 — 다음 스핀이 0도로 튕기지 않게

  // 휠 섹터: 꽝 180°(50%) / 100원 144°(40%) / 1000원 36°(10%)
  static const _sectors = [
    (RoulettePrize.kkwang, 0.5, Color(0xFFB0BEC5), '꽝'),
    (RoulettePrize.won100, 0.4, Color(0xFF81C784), '100원'),
    (RoulettePrize.won1000, 0.1, Color(0xFFFFB300), '1000원'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _rotation = const AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || widget.repo.profile.rouletteTickets <= 0) return;

    final prize = Roulette.spin(_rng);

    // 당첨 섹터 중앙 각도 계산 (포인터는 12시 방향)
    var start = 0.0;
    var target = 0.0;
    for (final (p, ratio, _, _) in _sectors) {
      if (p == prize) {
        // 섹터 내 임의 지점 (가장자리 피하려 10~90% 범위)
        target = start + ratio * (0.1 + _rng.nextDouble() * 0.8);
        break;
      }
      start += ratio;
    }
    final fullTurns = 5 + _rng.nextInt(3);
    final endAngle = fullTurns * 2 * math.pi + (1 - target) * 2 * math.pi;

    setState(() {
      _spinning = true;
      _result = null;
    });

    _rotation = Tween<double>(begin: _baseAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _controller.reset();
    await _controller.forward();
    _baseAngle = endAngle % (2 * math.pi);

    final repo = widget.repo;
    final profile = repo.profile;
    profile.rouletteTickets--;
    if (prize == RoulettePrize.kkwang) {
      profile.starPieces += starPiecesConsolation;
    } else {
      profile.piggyBank += prize.won;
    }
    profile.rouletteHistory.add('${DateTime.now().toIso8601String()}:${prize.name}');
    await repo.saveProfile();
    await repo.logEvent('roulette', {'prize': prize.name}, DateTime.now());

    setState(() {
      _spinning = false;
      _result = prize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.repo.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('🎡 마법 룰렛'), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text('티켓 ${profile.rouletteTickets}장 · 🐷 저금통 ${profile.piggyBank}원',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: 20,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, _) => Transform.rotate(
                            angle: _rotation.value,
                            child: CustomPaint(
                              size: const Size(260, 260),
                              painter: _WheelPainter(_sectors),
                            ),
                          ),
                        ),
                      ),
                      const Text('🔻', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DajoyCharacter(
                  expression: _result == RoulettePrize.won1000
                      ? DajoyExpression.jackpot
                      : (_spinning ? DajoyExpression.focus : DajoyExpression.happy),
                  size: 100,
                  style: styleFromProfile(widget.repo.profile),
                ),
                const SizedBox(height: 8),
                if (_result != null) _buildResult(_result!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: profile.rouletteTickets > 0 && !_spinning ? _spin : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  ),
                  child: Text(_spinning ? '두근두근...' : '돌려!', style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult(RoulettePrize prize) {
    final (text, color) = switch (prize) {
      RoulettePrize.kkwang => ('아쉽다! 위로 선물 별 조각 +$starPiecesConsolation ⭐', Colors.blueGrey),
      RoulettePrize.won100 => ('💰 100원 GET! 저금통에 쌓였어!', const Color(0xFF2E7D32)),
      RoulettePrize.won1000 => ('🎉 대박!! 1000원 당첨!! 김다조이 부자다!', const Color(0xFFE65100)),
    };
    return Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color));
  }
}

class _WheelPainter extends CustomPainter {
  final List<(RoulettePrize, double, Color, String)> sectors;

  _WheelPainter(this.sectors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    var startAngle = -math.pi / 2; // 12시 방향부터

    for (final (_, ratio, color, label) in sectors) {
      final sweep = ratio * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        Paint()..color = color,
      );

      // 라벨
      final midAngle = startAngle + sweep / 2;
      final labelPos = Offset(
        center.dx + radius * 0.6 * math.cos(midAngle),
        center.dy + radius * 0.6 * math.sin(midAngle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));

      startAngle += sweep;
    }

    // 테두리와 중심
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF7B5EA7),
    );
    canvas.drawCircle(center, 14, Paint()..color = const Color(0xFF7B5EA7));
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => false;
}

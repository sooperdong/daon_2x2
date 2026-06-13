import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum DajoyExpression {
  happy,   // 웃는 눈
  focus,   // 또렷한 눈 (집중)
  cheer,   // 윙크 (정답)
  jackpot, // 별 눈 (완벽)
  silly,   // X 눈 (오답 개그)
}

/// 꾸미기 장착 상태 — 상점 아이템이 캐릭터 외형을 바꾼다.
class DajoyStyle {
  final Color ribbonColor;
  final String? hatId;    // hat_wizard / hat_crown / hat_flower
  final String? faceId;   // face_glasses / face_star
  final String? photoPath; // 기기 로컬 사진 경로 (절대 동기화 안 됨)

  const DajoyStyle({
    this.ribbonColor = const Color(0xFFFF8FAB),
    this.hatId,
    this.faceId,
    this.photoPath,
  });
}

/// 김다조이 캐릭터.
/// photoPath가 있으면 실제 아이 얼굴 사진이 원형으로 표시되고
/// 머리/핀/모자는 그 위에 그려진다.
class DajoyCharacter extends StatefulWidget {
  final DajoyExpression expression;
  final double size;
  final DajoyStyle style;

  const DajoyCharacter({
    super.key,
    this.expression = DajoyExpression.happy,
    this.size = 160,
    this.style = const DajoyStyle(),
  });

  @override
  State<DajoyCharacter> createState() => _DajoyCharacterState();
}

class _DajoyCharacterState extends State<DajoyCharacter> {
  ui.Image? _faceImage;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(DajoyCharacter old) {
    super.didUpdateWidget(old);
    if (old.style.photoPath != widget.style.photoPath) _loadPhoto();
  }

  @override
  void dispose() {
    _faceImage?.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final path = widget.style.photoPath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        final old = _faceImage;
        setState(() { _faceImage = null; _loadedPath = null; });
        old?.dispose();
      }
      return;
    }
    if (path == _loadedPath) return;
    try {
      final bytes = await File(path).readAsBytes();
      // Stale check: path may have changed while awaiting I/O
      if (!mounted || widget.style.photoPath != path) return;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256, targetHeight: 256);
      if (!mounted || widget.style.photoPath != path) return;
      final frame = await codec.getNextFrame();
      if (mounted && widget.style.photoPath == path) {
        final old = _faceImage;
        setState(() { _faceImage = frame.image; _loadedPath = path; });
        old?.dispose();
      } else {
        frame.image.dispose(); // 이미 만료된 요청 — GPU 메모리 즉시 해제
      }
    } catch (_) {
      if (mounted && widget.style.photoPath == path) {
        setState(() { _faceImage = null; _loadedPath = null; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _DajoyPainter(widget.expression, widget.style, _faceImage),
    );
  }
}

class _DajoyPainter extends CustomPainter {
  final DajoyExpression expression;
  final DajoyStyle style;
  final ui.Image? facePhoto;

  _DajoyPainter(this.expression, this.style, this.facePhoto);

  static const _skin = Color(0xFFFFE0BD);
  static const _hair = Color(0xFF3B2B20);
  static const _blush = Color(0x55FF8FAB);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final faceR = w * 0.32;
    final faceCy = h * 0.45;

    final hairPaint = Paint()..color = _hair;
    final skinPaint = Paint()..color = _skin;

    // 양 갈래 머리 (좌우 큰 원)
    canvas.drawCircle(Offset(cx - faceR * 1.25, faceCy + faceR * 0.3), faceR * 0.55, hairPaint);
    canvas.drawCircle(Offset(cx + faceR * 1.25, faceCy + faceR * 0.3), faceR * 0.55, hairPaint);

    // 머리핀 리본
    final ribbonPaint = Paint()..color = style.ribbonColor;
    canvas.drawCircle(Offset(cx - faceR * 1.18, faceCy - faceR * 0.12), faceR * 0.16, ribbonPaint);
    canvas.drawCircle(Offset(cx + faceR * 1.18, faceCy - faceR * 0.12), faceR * 0.16, ribbonPaint);

    // 뒷머리
    canvas.drawCircle(Offset(cx, faceCy - faceR * 0.15), faceR * 1.1, hairPaint);

    // 얼굴 — 사진 또는 피부색
    if (facePhoto != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(
          Rect.fromCircle(center: Offset(cx, faceCy), radius: faceR)));
      final src = Rect.fromLTWH(
          0, 0, facePhoto!.width.toDouble(), facePhoto!.height.toDouble());
      final dst = Rect.fromCircle(center: Offset(cx, faceCy), radius: faceR);
      canvas.drawImageRect(facePhoto!, src, dst, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(Offset(cx, faceCy), faceR, skinPaint);
    }

    // 앞머리 (둥근 뱅)
    final bangs = Path()
      ..moveTo(cx - faceR, faceCy - faceR * 0.1)
      ..quadraticBezierTo(cx - faceR * 0.6, faceCy - faceR * 1.25, cx, faceCy - faceR * 1.05)
      ..quadraticBezierTo(cx + faceR * 0.6, faceCy - faceR * 1.25, cx + faceR, faceCy - faceR * 0.1)
      ..quadraticBezierTo(cx + faceR * 0.55, faceCy - faceR * 0.55, cx + faceR * 0.25, faceCy - faceR * 0.42)
      ..quadraticBezierTo(cx, faceCy - faceR * 0.7, cx - faceR * 0.25, faceCy - faceR * 0.42)
      ..quadraticBezierTo(cx - faceR * 0.55, faceCy - faceR * 0.55, cx - faceR, faceCy - faceR * 0.1)
      ..close();
    canvas.drawPath(bangs, hairPaint);

    // 볼터치 (사진 위에도 살짝 그려줌)
    final blushPaint = Paint()..color = _blush;
    canvas.drawCircle(Offset(cx - faceR * 0.55, faceCy + faceR * 0.3), faceR * 0.16, blushPaint);
    canvas.drawCircle(Offset(cx + faceR * 0.55, faceCy + faceR * 0.3), faceR * 0.16, blushPaint);

    _drawEyes(canvas, cx, faceCy, faceR);
    _drawMouth(canvas, cx, faceCy, faceR);
    _drawHat(canvas, cx, faceCy, faceR);
    _drawFaceAccessory(canvas, cx, faceCy, faceR);
  }

  void _drawHat(Canvas canvas, double cx, double cy, double r) {
    switch (style.hatId) {
      case 'hat_wizard':
        final hat = Paint()..color = const Color(0xFF7B5EA7);
        final cone = Path()
          ..moveTo(cx - r * 0.55, cy - r * 0.95)
          ..lineTo(cx, cy - r * 1.85)
          ..lineTo(cx + r * 0.55, cy - r * 0.95)
          ..close();
        canvas.drawPath(cone, hat);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy - r * 0.95), width: r * 1.5, height: r * 0.3),
          hat,
        );
        _drawStar(canvas, Offset(cx, cy - r * 1.4), r * 0.14,
            Paint()..color = const Color(0xFFFFD54F));
      case 'hat_crown':
        final gold = Paint()..color = const Color(0xFFFFB300);
        final crown = Path()
          ..moveTo(cx - r * 0.5, cy - r * 0.95)
          ..lineTo(cx - r * 0.5, cy - r * 1.35)
          ..lineTo(cx - r * 0.25, cy - r * 1.1)
          ..lineTo(cx, cy - r * 1.45)
          ..lineTo(cx + r * 0.25, cy - r * 1.1)
          ..lineTo(cx + r * 0.5, cy - r * 1.35)
          ..lineTo(cx + r * 0.5, cy - r * 0.95)
          ..close();
        canvas.drawPath(crown, gold);
      case 'hat_flower':
        final petal = Paint()..color = const Color(0xFFFF8FAB);
        final flowerCenter = Offset(cx + r * 0.5, cy - r * 0.95);
        for (var i = 0; i < 5; i++) {
          final angle = i * 2 * math.pi / 5;
          canvas.drawCircle(
            flowerCenter + Offset(math.cos(angle), math.sin(angle)) * r * 0.13,
            r * 0.1,
            petal,
          );
        }
        canvas.drawCircle(flowerCenter, r * 0.09, Paint()..color = const Color(0xFFFFD54F));
    }
  }

  void _drawFaceAccessory(Canvas canvas, double cx, double cy, double r) {
    switch (style.faceId) {
      case 'face_glasses':
        final frame = Paint()
          ..color = const Color(0xFF5D4037)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06;
        final eyeY = cy + r * 0.02;
        canvas.drawCircle(Offset(cx - r * 0.4, eyeY), r * 0.24, frame);
        canvas.drawCircle(Offset(cx + r * 0.4, eyeY), r * 0.24, frame);
        canvas.drawLine(
            Offset(cx - r * 0.16, eyeY), Offset(cx + r * 0.16, eyeY), frame);
      case 'face_star':
        _drawStar(canvas, Offset(cx + r * 0.62, cy + r * 0.12), r * 0.12,
            Paint()..color = const Color(0xFFFFB300));
    }
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final eyeY = cy + r * 0.02;
    final dx = r * 0.4;
    final dark = Paint()..color = const Color(0xFF2D2016);
    final stroke = Paint()
      ..color = const Color(0xFF2D2016)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case DajoyExpression.happy:
        for (final side in [-1, 1]) {
          final p = Path()
            ..moveTo(cx + side * dx - r * 0.14, eyeY + r * 0.05)
            ..quadraticBezierTo(cx + side * dx, eyeY - r * 0.14,
                cx + side * dx + r * 0.14, eyeY + r * 0.05);
          canvas.drawPath(p, stroke);
        }
      case DajoyExpression.focus:
        for (final side in [-1, 1]) {
          canvas.drawCircle(Offset(cx + side * dx, eyeY), r * 0.11, dark);
          canvas.drawCircle(Offset(cx + side * dx - r * 0.03, eyeY - r * 0.04),
              r * 0.035, Paint()..color = Colors.white);
        }
      case DajoyExpression.cheer:
        canvas.drawCircle(Offset(cx - dx, eyeY), r * 0.11, dark);
        canvas.drawCircle(
            Offset(cx - dx - r * 0.03, eyeY - r * 0.04),
            r * 0.035,
            Paint()..color = Colors.white);
        final wink = Path()
          ..moveTo(cx + dx - r * 0.14, eyeY)
          ..quadraticBezierTo(cx + dx, eyeY + r * 0.1, cx + dx + r * 0.14, eyeY);
        canvas.drawPath(wink, stroke);
      case DajoyExpression.jackpot:
        for (final side in [-1, 1]) {
          _drawStar(canvas, Offset(cx + side * dx, eyeY), r * 0.16,
              Paint()..color = const Color(0xFFFFB300));
        }
      case DajoyExpression.silly:
        // X 눈 — 만화 기절/미끄러짐 표현
        final xPaint = Paint()
          ..color = const Color(0xFF2D2016)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..strokeCap = StrokeCap.round;
        for (final side in [-1, 1]) {
          final center = Offset(cx + side * dx, eyeY);
          canvas.drawLine(
              center + Offset(-r * 0.12, -r * 0.12),
              center + Offset(r * 0.12, r * 0.12),
              xPaint);
          canvas.drawLine(
              center + Offset(-r * 0.12, r * 0.12),
              center + Offset(r * 0.12, -r * 0.12),
              xPaint);
        }
    }
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double r) {
    final mouthY = cy + r * 0.5;
    final stroke = Paint()
      ..color = const Color(0xFFB5552D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case DajoyExpression.happy || DajoyExpression.cheer:
        final p = Path()
          ..moveTo(cx - r * 0.22, mouthY - r * 0.05)
          ..quadraticBezierTo(cx, mouthY + r * 0.18, cx + r * 0.22, mouthY - r * 0.05);
        canvas.drawPath(p, stroke);
      case DajoyExpression.focus:
        final p = Path()
          ..moveTo(cx - r * 0.1, mouthY)
          ..lineTo(cx + r * 0.1, mouthY);
        canvas.drawPath(p, stroke);
      case DajoyExpression.jackpot:
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, mouthY), width: r * 0.4, height: r * 0.32),
          Paint()..color = const Color(0xFFB5552D),
        );
      case DajoyExpression.silly:
        // 삐뚤어진 물결 입
        final p = Path()
          ..moveTo(cx - r * 0.22, mouthY + r * 0.02)
          ..quadraticBezierTo(
              cx - r * 0.08, mouthY - r * 0.1, cx, mouthY + r * 0.05)
          ..quadraticBezierTo(
              cx + r * 0.08, mouthY + r * 0.18, cx + r * 0.22, mouthY + r * 0.06);
        canvas.drawPath(p, stroke);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = i * math.pi / points - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DajoyPainter oldDelegate) =>
      oldDelegate.expression != expression ||
      oldDelegate.style.ribbonColor != style.ribbonColor ||
      oldDelegate.style.hatId != style.hatId ||
      oldDelegate.style.faceId != style.faceId ||
      oldDelegate.style.photoPath != style.photoPath ||
      oldDelegate.facePhoto != facePhoto;
}

import 'package:flutter_tts/flutter_tts.dart';

/// 한국어 TTS 서비스 — 구구단 암송 카드에서 자동 발음.
/// 싱글턴으로 앱 전체에서 공유한다.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.42); // 아이가 따라 읽기 적당한 속도
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1); // 약간 높은 톤 — 친근하게
    _ready = true;
  }

  /// 구구단 암송문 읽기: "이 삼은 육"
  Future<void> speakChant(String text) async {
    if (!_ready) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// 임의 텍스트
  Future<void> speak(String text) async {
    if (!_ready) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async => _tts.stop();

  void dispose() => _tts.stop();
}

import 'package:flutter/material.dart';

/// 情绪检测结果
class EmotionResult {
  final String emotion;
  final double confidence;
  final bool isAttention;
  final double attentionScore;

  const EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.isAttention,
    required this.attentionScore,
  });

  factory EmotionResult.empty() {
    return const EmotionResult(
      emotion: 'neutral',
      confidence: 0.0,
      isAttention: false,
      attentionScore: 0.0,
    );
  }

  bool get isPositive =>
      emotion == 'happy' || emotion == 'surprised' || emotion == 'neutral';
  bool get isNegative =>
      emotion == 'sad' || emotion == 'angry' || emotion == 'fearful' || emotion == 'disgusted';

  String get comfortMessage {
    switch (emotion) {
      case 'sad': return '别难过啦~ 我在呢 💕';
      case 'angry': return '放松一下~ 深呼吸 🌿';
      case 'fearful': return '不怕不怕~ 我保护你 🛡️';
      case 'disgusted': return '是不是不开心？说给我听听 💭';
      case 'happy': return '看到你开心我也好开心！🥰';
      case 'surprised': return '哇！是不是有好事发生？✨';
      default: return '静静陪着你~ 🍃';
    }
  }
}

/// 视觉追踪服务（iOS 原生 Vision 框架，零外部依赖）
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  bool _isInitialized = false;

  void Function(EmotionResult result)? onEmotionDetected;
  void Function(String error)? onError;
  EmotionResult _lastResult = EmotionResult.empty();

  Future<bool> initialize() async {
    _isInitialized = true;
    debugPrint('📷 视觉追踪（占位模式）');
    return true;
  }

  void _updateResult(EmotionResult result) {
    _lastResult = result;
    onEmotionDetected?.call(result);
  }

  void _onError(String message) {
    debugPrint('❌ VisionService: $message');
    onError?.call(message);
  }

  EmotionResult getLastResult() => _lastResult;

  void dispose() {
    _isInitialized = false;
    debugPrint('📷 视觉追踪已释放');
  }

  bool get isInitialized => _isInitialized;
}

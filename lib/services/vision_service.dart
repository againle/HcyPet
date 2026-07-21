import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vision_ai/vision_ai.dart';

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
      case 'sad':
        return '别难过啦~ 我在呢 💕';
      case 'angry':
        return '放松一下~ 深呼吸 🌿';
      case 'fearful':
        return '不怕不怕~ 我保护你 🛡️';
      case 'disgusted':
        return '是不是不开心？说给我听听 💭';
      case 'happy':
        return '看到你开心我也好开心！🥰';
      case 'surprised':
        return '哇！是不是有好事发生？✨';
      default:
        return '静静陪着你~ 🍃';
    }
  }
}

/// 视觉追踪服务（基于 vision_ai 设备端 API）
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  VisionAi? _visionAi;
  StreamSubscription<VisionResult>? _resultSubscription;

  bool _isInitialized = false;

  void Function(EmotionResult result)? onEmotionDetected;
  void Function(String error)? onError;

  EmotionResult _lastResult = EmotionResult.empty();

  /// 初始化并启动视觉追踪
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _visionAi = VisionAi.face(
        config: const FaceConfig(
          detectEmotion: true,
          enableTracking: true,
        ),
      );

      await _visionAi!.start();

      _resultSubscription = _visionAi!.results.listen(
        _onVisionResult,
        onError: (error) {
          _onError('视觉结果流错误: $error');
        },
      );

      _isInitialized = true;
      debugPrint('📷 视觉追踪服务已启动');
      return true;
    } catch (e) {
      _onError('视觉追踪初始化失败: $e');
      return false;
    }
  }

  /// 处理每帧检测结果
  void _onVisionResult(VisionResult result) {
    final face = result.primaryFace;
    if (face == null) {
      _updateResult(EmotionResult.empty());
      return;
    }

    final emotion = face.emotion.name;
    final attentionScore = _calculateAttention(face);
    final isAttention = attentionScore > 60;

    final emotionResult = EmotionResult(
      emotion: emotion,
      confidence: face.emotionConfidence,
      isAttention: isAttention,
      attentionScore: attentionScore,
    );

    _updateResult(emotionResult);
  }

  /// 计算注意力评分
  double _calculateAttention(FaceResult face) {
    double score = 0.0;

    final headEulerY = face.headEulerAngleY;
    final headEulerX = face.headEulerAngleX;

    final yawScore = (1.0 - (headEulerY.abs() / 45.0).clamp(0.0, 1.0)) * 0.4;
    final pitchScore = (1.0 - (headEulerX.abs() / 30.0).clamp(0.0, 1.0)) * 0.3;
    score += yawScore + pitchScore;

    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;
    final eyeScore = ((leftEyeOpen + rightEyeOpen) / 2) * 0.3;
    score += eyeScore;

    return (score * 100).clamp(0.0, 100.0);
  }

  /// 更新检测结果
  void _updateResult(EmotionResult result) {
    _lastResult = result;
    onEmotionDetected?.call(result);
  }

  /// 错误处理
  void _onError(String message) {
    debugPrint('❌ VisionService Error: $message');
    onError?.call(message);
  }

  /// 获取最新检测结果
  EmotionResult getLastResult() => _lastResult;

  /// 释放资源
  void dispose() {
    _resultSubscription?.cancel();
    _visionAi?.stop();
    _visionAi?.dispose();
    _isInitialized = false;
    debugPrint('📷 视觉追踪服务已释放');
  }

  bool get isInitialized => _isInitialized;
}

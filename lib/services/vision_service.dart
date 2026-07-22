import 'package:flutter/services.dart';

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

  factory EmotionResult.empty() => const EmotionResult(
        emotion: 'neutral',
        confidence: 0.0,
        isAttention: false,
        attentionScore: 0.0,
      );

  factory EmotionResult.fromMap(Map<dynamic, dynamic> map) => EmotionResult(
        emotion: (map['emotion'] as String?) ?? 'neutral',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
        isAttention: (map['isAttention'] as bool?) ?? false,
        attentionScore: (map['attentionScore'] as num?)?.toDouble() ?? 0.0,
      );

  bool get isPositive =>
      emotion == 'happy' || emotion == 'surprised' || emotion == 'neutral';
  bool get isNegative =>
      emotion == 'sad' || emotion == 'angry' || emotion == 'fearful' || emotion == 'disgusted';

  String get comfortMessage => switch (emotion) {
        'sad'       => '别难过啦~ 我在呢',
        'angry'     => '放松一下~ 深呼吸',
        'fearful'   => '不怕不怕~ 我保护你',
        'disgusted' => '是不是不开心？说给我听听',
        'happy'     => '看到你开心我也好开心！',
        'surprised' => '哇！是不是有好事发生？',
        _           => '静静陪着你~',
      };
}

/// 视觉追踪服务 — iOS Apple Vision MethodChannel 桥接
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  static const _channelName = 'com.hcypet.vision';
  MethodChannel? _channel;

  bool _isRunning = false;

  void Function(EmotionResult result)? onEmotionDetected;
  void Function(String error)? onError;

  /// 初始化 MethodChannel
  Future<bool> initialize() async {
    _channel = const MethodChannel(_channelName);
    _channel?.setMethodCallHandler(_onMethodCall);
    return true;
  }

  /// 开始检测
  Future<bool> start() async {
    if (_channel == null) await initialize();
    try {
      final result = await _channel!.invokeMethod<bool>('startVision');
      _isRunning = result ?? false;
      return _isRunning;
    } catch (e) {
      onError?.call('启动失败: $e');
      return false;
    }
  }

  /// 停止检测
  Future<void> stop() async {
    if (_channel == null) return;
    try {
      await _channel!.invokeMethod('stopVision');
    } catch (_) {}
    _isRunning = false;
    // 清理回调防止泄漏
    onEmotionDetected = null;
    onError = null;
  }

  /// 检查是否可用
  Future<bool> isAvailable() async {
    if (_channel == null) return false;
    try {
      return await _channel!.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 处理原生回调
  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVisionResult':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          onEmotionDetected?.call(EmotionResult.fromMap(args));
        }
        break;
      case 'onVisionError':
        onError?.call(call.arguments as String? ?? '未知错误');
        break;
    }
  }

  EmotionResult getLastResult() => EmotionResult.empty();

  void dispose() {
    stop();
    _channel?.setMethodCallHandler(null);
  }

  bool get isRunning => _isRunning;
}

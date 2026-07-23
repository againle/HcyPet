import 'dart:convert';
import 'package:flutter/services.dart';

// ============================================================
// V3 视觉检测数据模型
// ============================================================

/// 学习场景分类
enum StudyScene {
  reading,     // 看书/写字
  computer,    // 电脑
  phone,       // 手机
  distracted,  // 分心
  noFace;      // 无人脸

  /// 是否为有效学习场景
  bool get isStudying {
    switch (this) {
      case StudyScene.reading:
      case StudyScene.computer:
        return true;
      default:
        return false;
    }
  }

  /// 中文标签
  String get label {
    switch (this) {
      case StudyScene.reading:    return '看书/写字';
      case StudyScene.computer:   return '电脑';
      case StudyScene.phone:      return '手机';
      case StudyScene.distracted: return '分心';
      case StudyScene.noFace:     return '未检测到';
    }
  }
}

/// 连续情绪谱（7维，每维 0~1）
class EmotionSpectrum {
  final double calm;        // 平静
  final double focused;     // 专注
  final double frustrated;  // 烦躁
  final double bored;       // 无聊
  final double happy;       // 开心
  final double anxious;     // 焦虑
  final double tired;       // 疲惫

  const EmotionSpectrum({
    this.calm = 0.5,
    this.focused = 0.5,
    this.frustrated = 0.0,
    this.bored = 0.0,
    this.happy = 0.0,
    this.anxious = 0.0,
    this.tired = 0.0,
  });

  factory EmotionSpectrum.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return EmotionSpectrum(
      calm: (map['calm'] as num).toDouble(),
      focused: (map['focused'] as num).toDouble(),
      frustrated: (map['frustrated'] as num).toDouble(),
      bored: (map['bored'] as num).toDouble(),
      happy: (map['happy'] as num).toDouble(),
      anxious: (map['anxious'] as num).toDouble(),
      tired: (map['tired'] as num).toDouble(),
    );
  }

  /// 主导情绪（最高分维度）
  String get dominantEmotion {
    final entries = {
      'calm': calm,
      'focused': focused,
      'frustrated': frustrated,
      'bored': bored,
      'happy': happy,
      'anxious': anxious,
      'tired': tired,
    };
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// 主导情绪强度
  double get dominantIntensity {
    return [calm, focused, frustrated, bored, happy, anxious, tired]
        .reduce((a, b) => a > b ? a : b);
  }

  /// 是否需要宠物干预（烦躁/无聊/疲惫/焦虑 任一 > 0.35）
  bool get needsIntervention =>
      frustrated > 0.35 || bored > 0.35 || tired > 0.35 || anxious > 0.35;

  /// 干预原因
  String get interventionReason {
    if (frustrated > 0.35) return '有点烦躁呢';
    if (tired > 0.35) return '看起来累了';
    if (bored > 0.35) return '好像无聊了';
    if (anxious > 0.35) return '在担心什么吗';
    return '';
  }

  static const empty = EmotionSpectrum();
}

/// V3 视觉检测结果（替代旧 EmotionResult）
class VisionResult {
  final StudyScene scene;
  final double focusScore;        // 0~1 专注度
  final EmotionSpectrum emotion;  // 连续情绪谱
  final bool isStudying;          // 是否处于学习状态
  final DateTime timestamp;

  const VisionResult({
    required this.scene,
    required this.focusScore,
    required this.emotion,
    required this.isStudying,
    required this.timestamp,
  });

  factory VisionResult.fromMap(Map<dynamic, dynamic> map) {
    final sceneStr = (map['scene'] as String?) ?? 'noFace';
    final scene = StudyScene.values.firstWhere(
      (s) => s.name == sceneStr,
      orElse: () => StudyScene.noFace,
    );
    final emotionJson = (map['emotionJson'] as String?) ?? '{}';
    return VisionResult(
      scene: scene,
      focusScore: (map['focusScore'] as num?)?.toDouble() ?? 0.0,
      emotion: EmotionSpectrum.fromJson(emotionJson),
      isStudying: (map['isStudying'] as bool?) ?? false,
      timestamp: DateTime.now(),
    );
  }

  factory VisionResult.empty() => VisionResult(
        scene: StudyScene.noFace,
        focusScore: 0.0,
        emotion: EmotionSpectrum.empty,
        isStudying: false,
        timestamp: DateTime.now(),
      );

  /// 兼容旧版 comfort message（基于主导情绪）
  String get comfortMessage => switch (emotion.dominantEmotion) {
        'frustrated' => '深呼吸，慢慢来~',
        'tired'      => '累了就歇会儿吧',
        'bored'      => '再坚持一下！',
        'anxious'    => '别担心，我在呢',
        'happy'      => '看到你开心我也开心！',
        'focused'    => '好专注！继续保持~',
        'calm'       => '静静陪着你~',
        _            => '加油！',
      };

  /// 根据专注度 + 情绪给出学习状态文本
  String get studyStatusText {
    if (!isStudying) return '未在学习';
    if (focusScore > 0.7) return '深度专注';
    if (focusScore > 0.45) return '学习中';
    if (focusScore > 0.25) return '有点走神';
    return '分心了';
  }
}

// ============================================================
// VisionService — V3 MethodChannel 桥接
// ============================================================

/// 视觉追踪服务 — iOS Apple Vision MethodChannel 桥接
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  static const _channelName = 'com.hcypet.vision';
  MethodChannel? _channel;

  bool _isRunning = false;

  void Function(VisionResult result)? onVisionResult;
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
    onVisionResult = null;
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
          onVisionResult?.call(VisionResult.fromMap(args));
        }
        break;
      case 'onVisionError':
        onError?.call(call.arguments as String? ?? '未知错误');
        break;
    }
  }

  VisionResult getLastResult() => VisionResult.empty();

  void dispose() {
    stop();
    _channel?.setMethodCallHandler(null);
  }

  bool get isRunning => _isRunning;
}

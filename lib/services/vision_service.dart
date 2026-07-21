import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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

  static const _channel = MethodChannel('com.hcypet/face_detector');

  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;
  DateTime _lastFrameTime = DateTime.now();

  void Function(EmotionResult result)? onEmotionDetected;
  void Function(String error)? onError;
  EmotionResult _lastResult = EmotionResult.empty();

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _onError('没有可用的摄像头');
        return false;
      }
      _cameraController = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      _isInitialized = true;
      debugPrint('📷 视觉追踪已启动 (Apple Vision)');

      // 使用图像流而不是 takePicture（避免磁盘 I/O）
      _cameraController!.startImageStream(_onFrame);
      return true;
    } catch (e) {
      _onError('视觉初始化失败: $e');
      return false;
    }
  }

  /// 摄像头帧回调（直接处理 CameraImage，无磁盘 I/O）
  void _onFrame(CameraImage cameraImage) {
    // 节流：最多 500ms 处理一帧
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 500) return;
    _lastFrameTime = now;

    if (_isProcessing) return;
    _isProcessing = true;

    _detectFace(cameraImage).then((_) {
      _isProcessing = false;
    });
  }

  Future<void> _detectFace(CameraImage image) async {
    try {
      // 从第一平面提取 bytes（通常为 YUV420 的 Y 平面或 BGRA）
      final plane = image.planes.first;
      final bytes = plane.bytes;

      final result = await _channel.invokeMethod<Map>('detectFace', {
        'imageData': Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
        'width': image.width,
        'height': image.height,
      });

      if (result != null) {
        _onNativeResult(result);
      }
    } catch (e) {
      // 静默处理单帧错误
    }
  }

  void _onNativeResult(Map result) {
    final hasFace = result['hasFace'] == true;
    if (!hasFace) {
      _updateResult(EmotionResult.empty());
      return;
    }

    final smileScore = (result['smileScore'] as num?)?.toDouble() ?? 0;
    final leftEyeOpen = (result['leftEyeOpen'] as num?)?.toDouble() ?? 0.5;
    final rightEyeOpen = (result['rightEyeOpen'] as num?)?.toDouble() ?? 0.5;
    final yaw = (result['yaw'] as num?)?.toDouble() ?? 0;
    final pitch = (result['pitch'] as num?)?.toDouble() ?? 0;
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.5;

    final emotion = smileScore > 0.5 ? 'happy' : 'neutral';

    final yawScore = (1.0 - (yaw.abs() / 45.0).clamp(0.0, 1.0)) * 0.4;
    final pitchScore = (1.0 - (pitch.abs() / 30.0).clamp(0.0, 1.0)) * 0.3;
    final eyeScore = ((leftEyeOpen + rightEyeOpen) / 2) * 0.3;
    final attentionScore = ((yawScore + pitchScore + eyeScore) * 100).clamp(0.0, 100.0);

    _updateResult(EmotionResult(
      emotion: emotion,
      confidence: confidence,
      isAttention: attentionScore > 60,
      attentionScore: attentionScore,
    ));
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
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _isInitialized = false;
    debugPrint('📷 视觉追踪已释放');
  }

  bool get isInitialized => _isInitialized;
}

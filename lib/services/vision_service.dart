import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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

/// 视觉追踪服务（基于 Google ML Kit 设备端 API）
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  FaceDetector? _faceDetector;
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;

  void Function(EmotionResult result)? onEmotionDetected;
  void Function(String error)? onError;

  EmotionResult _lastResult = EmotionResult.empty();

  /// 初始化摄像头 + 人脸检测
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

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
      _cameraController!.startImageStream(_processFrame);

      _isInitialized = true;
      debugPrint('📷 视觉追踪服务已启动 (ML Kit)');
      return true;
    } catch (e) {
      _onError('视觉追踪初始化失败: $e');
      return false;
    }
  }

  /// 处理每帧图像
  void _processFrame(CameraImage cameraImage) async {
    if (!_isInitialized || _isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      _processFaces(faces);
    } catch (e) {
      // 静默处理帧错误
    }
    _isProcessing = false;
  }

  /// 构建 ML Kit InputImage
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// 处理人脸检测结果
  void _processFaces(List<Face> faces) {
    if (faces.isEmpty) {
      _updateResult(EmotionResult.empty());
      return;
    }

    final face = faces.first;
    final attentionScore = _calculateAttention(face);

    _updateResult(EmotionResult(
      emotion: face.smilingProbability != null && face.smilingProbability! > 0.7 ? 'happy' : 'neutral',
      confidence: 0.8,
      isAttention: attentionScore > 60,
      attentionScore: attentionScore,
    ));
  }

  /// 计算注意力评分（基于头部姿态和眼睛状态）
  double _calculateAttention(Face face) {
    double score = 0.0;

    final headEulerY = face.headEulerAngleY ?? 0.0;
    final headEulerX = face.headEulerAngleZ ?? 0.0;

    final yawScore = (1.0 - (headEulerY.abs() / 45.0).clamp(0.0, 1.0)) * 0.4;
    final pitchScore = (1.0 - (headEulerX.abs() / 30.0).clamp(0.0, 1.0)) * 0.3;
    score += yawScore + pitchScore;

    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;
    final eyeScore = ((leftEyeOpen + rightEyeOpen) / 2) * 0.3;
    score += eyeScore;

    return (score * 100).clamp(0.0, 100.0);
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
    _faceDetector?.close();
    _isInitialized = false;
    debugPrint('📷 视觉追踪服务已释放');
  }

  bool get isInitialized => _isInitialized;
}

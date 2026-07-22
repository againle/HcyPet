import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shake_plus/shake_plus.dart';

/// 传感器服务 - 管理加速度和摇晃检测
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // 加速度计订阅
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // 摇晃检测器
  ShakeDetector? _shakeDetector;

  // 回调
  VoidCallback? onShake;
  void Function(double x, double y, double z)? onAccelerometerUpdate;

  bool _isListening = false;

  /// 开始监听传感器
  void startListening({
    VoidCallback? onShake,
    void Function(double x, double y, double z)? onAccelerometerUpdate,
  }) {
    if (_isListening) return;

    this.onShake = onShake;
    this.onAccelerometerUpdate = onAccelerometerUpdate;

    // ---- 1. 加速度计监听 ----
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        onAccelerometerUpdate?.call(event.x, event.y, event.z);
      },
      onError: (error) {
        debugPrint('加速度计错误: $error');
      },
    );

    // ---- 2. 摇晃检测 ----
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        onShake?.call();
      },
      shakeThresholdGravity: 2.0,
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
    );

    _isListening = true;
    debugPrint('Sensor service started');
  }

  /// 停止监听传感器
  void stopListening() {
    if (!_isListening) return;

    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    _shakeDetector?.stopListening();
    _shakeDetector = null;

    _isListening = false;
    debugPrint('Sensor service stopped');
  }

  /// 是否正在监听
  bool get isListening => _isListening;

  /// 释放资源
  void dispose() {
    stopListening();
  }
}

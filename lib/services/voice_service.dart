import 'package:flutter/services.dart';

/// ============================================================
/// 🎙️ 语音输入服务 — iOS AVAudioEngine + SFSpeechRecognizer
/// ============================================================
///
/// 用法：
///   final voice = VoiceService();
///   final text = await voice.listen(); // 开始录音，等待结果
///

class VoiceService {
  static const _channel = MethodChannel('com.hcypet.voice');

  Function(double amplitude)? onAmplitudeChanged;

  /// 检查语音识别是否可用
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isSpeechAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开始录音并返回识别文字（按住说话，松开返回）
  static Future<VoiceResult> listen() async {
    try {
      final result = await _channel.invokeMethod<Map>('startListening');
      if (result != null) {
        return VoiceResult(
          text: result['text'] as String? ?? '',
          success: result['success'] as bool? ?? false,
          error: result['error'] as String?,
        );
      }
    } catch (e) {
      return VoiceResult(text: '', success: false, error: e.toString());
    }
    return const VoiceResult(text: '', success: false, error: '未知错误');
  }

  /// 停止录音
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  /// 请求语音权限
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }
}

class VoiceResult {
  final String text;
  final bool success;
  final String? error;
  const VoiceResult({required this.text, required this.success, this.error});
}

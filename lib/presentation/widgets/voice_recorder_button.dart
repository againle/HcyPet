import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';

/// 语音录音按钮 - 长按录音，松开发送
class VoiceRecorderButton extends StatefulWidget {
  final VoidCallback? onRecordingStart;
  final void Function(String text)? onRecognized;
  final double size;
  final Color color;

  const VoiceRecorderButton({
    super.key,
    this.onRecordingStart,
    this.onRecognized,
    this.size = 48,
    this.color = const Color(0xFF4FC3F7),
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  Timer? _recordingTimer;
  int _recordingDuration = 0; // 秒

  // 是否支持语音识别
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _stopListening();
    super.dispose();
  }

  /// 初始化语音识别
  Future<void> _initSpeech() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          setState(() {
            _isAvailable = false;
          });
          _showToast('语音识别初始化失败: ${error.errorMsg}');
        },
        onStatus: (status) {
          // 状态变化回调
        },
      );
      setState(() {});
    } catch (e) {
      _isAvailable = false;
      _showToast('语音识别不可用');
    }
  }

  /// 开始录音
  void _startListening() async {
    if (!_isAvailable) {
      _showToast('语音识别不可用，请检查权限');
      return;
    }

    if (_isListening) return;

    final bool hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      _showToast('请授予麦克风权限（系统设置中开启）');
      return;
    }

    setState(() {
      _isListening = true;
      _text = '';
      _recordingDuration = 0;
    });

    // 开始录音计时
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });

    widget.onRecordingStart?.call();

    // 开始语音识别
    _speech.listen(
      onResult: (result) {
        setState(() {
          _text = result.recognizedWords;
        });
        // 实时更新到宠物气泡
        if (result.finalResult) {
          _onRecognized(_text);
        }
      },
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      onSoundLevelChange: (level) {
        // 可用来显示音量动画
      },
    );
  }

  /// 停止录音
  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      _recordingTimer?.cancel();
      setState(() {
        _isListening = false;
      });

      // 如果有识别结果，触发识别完成回调
      if (_text.isNotEmpty) {
        _onRecognized(_text);
      } else {
        _showToast('没有识别到语音');
      }
    }
  }

  /// 识别完成处理
  void _onRecognized(String text) {
    if (text.trim().isEmpty) return;

    // 触发 Bloc 事件
    final bloc = context.read<PetBloc>();
    bloc.add(PetTalkEvent(message: text));

    // 回调给父组件
    widget.onRecognized?.call(text);

    _showToast('"$text"');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4FC3F7),
          ),
        ),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF4FC3F7).withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _isListening ? null : _startListening,
      onLongPressEnd: _isListening ? (details) => _stopListening() : null,
      onLongPressUp: _isListening ? _stopListening : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isListening
              ? Colors.red.withOpacity(0.15)
              : widget.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isListening
                ? Colors.red.withOpacity(0.5)
                : widget.color.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 图标
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isListening
                  ? _buildRecordingIndicator()
                  : const Icon(
                      Icons.mic_outlined,
                      size: 22,
                      color: Color(0xFF4FC3F7),
                    ),
            ),
            // 录音时长（显示在按钮下方）
            if (_isListening && _recordingDuration > 0)
              Positioned(
                bottom: -20,
                child: Text(
                  '${_recordingDuration}s',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '录音中',
          style: TextStyle(
            fontSize: 9,
            color: Colors.red.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/debug_config.dart';
import '../../services/firebase_service.dart';

/// 调试信息条 - 在页面底部显示 Firebase 状态
class DebugBar extends StatefulWidget {
  const DebugBar({super.key});

  @override
  State<DebugBar> createState() => _DebugBarState();
}

class _DebugBarState extends State<DebugBar> {
  final FirebaseService _firebase = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DebugConfig.notifier,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: _firebase.changeNotifier,
          builder: (context, _, __) {
            return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: Colors.black87,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'DEBUG',
                    style: TextStyle(
                      color: Color(0xFFFFEB3B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      final log = 'Firebase:\n'
                          'step=${_firebase.debugStep}\n'
                          'msg=${_firebase.debugMessage}\n'
                          'init=${_firebase.isInitialized}\n'
                          'auth=${_firebase.isAuthenticated}\n'
                          'uid=${_firebase.currentUserId}';
                      Clipboard.setData(ClipboardData(text: log));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板', style: TextStyle(fontSize: 11)),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      '复制',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _row('Step', _firebase.debugStep,
                  _firebase.debugStep == 'done' ? Colors.green : Colors.orange),
              _row('Init', _firebase.isInitialized ? 'OK' : 'FAIL',
                  _firebase.isInitialized ? Colors.green : Colors.red),
              _row('Auth', _firebase.isAuthenticated ? 'OK' : 'NOT',
                  _firebase.isAuthenticated ? Colors.green : Colors.orange),
              _row('UID', _firebase.currentUserId ?? 'null', Colors.white38),
              if (_firebase.debugMessage.isNotEmpty)
                _row('Error', _firebase.debugMessage, Colors.redAccent),
            ],
          ),
        );
      },
    );
      },
    );
  }

  Widget _row(String label, String value, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: c, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

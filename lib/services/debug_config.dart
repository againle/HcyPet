import 'package:flutter/material.dart';

/// 调试配置（全局开关）
class DebugConfig {
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  static bool get debugEnabled => notifier.value;
  static set debugEnabled(bool v) => notifier.value = v;
}

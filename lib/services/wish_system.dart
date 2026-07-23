import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'deepseek_service.dart';
import 'memory_bank.dart';
import 'notification_service.dart';

/// ============================================================
/// 🍡 心愿系统 — 自主呼唤 + 生气逻辑
/// ============================================================
///
/// 每隔 2~4 小时，生成一个随机念头推送通知。
/// 无视超过 1 小时 → 下次打开 App 时"生气背对"。

class WishSystem {
  static Timer? _wishTimer;
  static Timer? _ignoreTimer;
  static bool _ignored = false;
  static final List<String> _cachedWishes = [];

  /// 本地备用心愿（无需 API）
  static const _fallbackWishes = [
    'Mochi 想你了，来摸摸它的头吧~',
    'Mochi 饿了，想要小饼干 🍪',
    'Mochi 一个人好无聊…来看看它？',
    'Mochi 想和你说说话~',
    'Mochi 困了，想让你拍拍它睡觉 😴',
    'Mochi 今天还没见到你呢…',
    'Mochi 好像有点孤单…',
  ];

  /// 启动心愿系统
  static void start() {
    _scheduleNextWish();
  }

  /// 停止
  static void stop() {
    _wishTimer?.cancel();
    _ignoreTimer?.cancel();
  }

  /// 用户打开了 App → 检查是否在生气
  static bool get isAngry => _ignored;
  static void clearAnger() => _ignored = false;

  /// 安排下一次心愿
  static void _scheduleNextWish() {
    _wishTimer?.cancel();
    final delay = Duration(minutes: 120 + DateTime.now().millisecond % 120);
    _wishTimer = Timer(delay, _fireWish);
  }

  static Future<void> _fireWish() async {
    // 尝试生成 AI 心愿
    String? wish;
    try {
      final memories = await MemoryBank.getRecent(5);
      wish = await DeepSeekService().generateWish(memories);
    } catch (_) {}

    // 失败则用缓存或备选
    if (wish == null || wish.isEmpty) {
      if (_cachedWishes.isNotEmpty) {
        wish = _cachedWishes.removeAt(0);
      } else {
        wish = (_fallbackWishes..shuffle()).first;
      }
    }

    // 发送本地通知
    await NotificationService().showNotification(
      id: 1001,
      title: '🍡 Mochi',
      body: wish!,
      payload: 'wish',
    );

    // 开始计时无视
    _ignoreTimer?.cancel();
    _ignored = false;
    _ignoreTimer = Timer(const Duration(hours: 1), () {
      _ignored = true;
    });

    _scheduleNextWish();
  }
}

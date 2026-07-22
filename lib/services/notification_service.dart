import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 初始化通知
  Future<void> initialize() async {
    if (_isInitialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
    debugPrint('🔔 通知服务已初始化');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 通知点击: ${response.payload}');
  }

  /// 显示通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'hcypet_channel',
      'HcyPet 消息',
      importance: Importance.max,
      priority: Priority.high,
      channelDescription: '接收来自伴侣的消息',
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 显示伴侣消息通知
  Future<void> showPartnerMessage(String message, String fromName) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await showNotification(
      id: id.toInt(),
      title: '$fromName',
      body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      payload: 'partner_message',
    );
  }

  /// 显示自习室完成通知
  Future<void> showStudyComplete(String message) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000 + 1;
    await showNotification(
      id: id.toInt(),
      title: '自习完成！',
      body: message,
      payload: 'study_complete',
    );
  }

  /// 取消通知
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}

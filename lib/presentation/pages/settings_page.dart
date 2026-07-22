import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../../services/debug_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoSleep = true;
  int _sleepDelayMinutes = 10;
  int _wakeIntervalMinutes = 30;
  bool _notificationsEnabled = true;
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSleep = prefs.getBool('auto_sleep') ?? true;
      _sleepDelayMinutes = prefs.getInt('sleep_delay') ?? 10;
      _wakeIntervalMinutes = prefs.getInt('wake_interval') ?? 30;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _debugMode = prefs.getBool('debug_mode') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PetBloc>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text('⚙️ 设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: const Color(0xFF4FC3F7).withOpacity(0.6))),
                ],
              ),
            ),
            const Divider(color: Color(0xFF4FC3F7), height: 0.5, thickness: 0.5),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  _buildSectionTitle('待机设置'),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: '自动休眠',
                    subtitle: '无互动 $_sleepDelayMinutes 分钟后进入休眠',
                    value: _autoSleep,
                    onChanged: (val) { setState(() => _autoSleep = val); _saveSetting('auto_sleep', val); },
                  ),
                  if (_autoSleep) ...[
                    _buildSliderTile(
                      title: '休眠延迟', value: _sleepDelayMinutes.toDouble(),
                      min: 5, max: 30, divisions: 5, label: '$_sleepDelayMinutes 分钟',
                      onChanged: (val) { setState(() => _sleepDelayMinutes = val.toInt()); _saveSetting('sleep_delay', val.toInt()); },
                    ),
                    _buildSliderTile(
                      title: '唤醒间隔', value: _wakeIntervalMinutes.toDouble(),
                      min: 15, max: 60, divisions: 9, label: '$_wakeIntervalMinutes 分钟',
                      onChanged: (val) { setState(() => _wakeIntervalMinutes = val.toInt()); _saveSetting('wake_interval', val.toInt()); },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSectionTitle('通知'),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: '消息通知', subtitle: '接收伴侣消息推送',
                    value: _notificationsEnabled,
                    onChanged: (val) { setState(() => _notificationsEnabled = val); _saveSetting('notifications_enabled', val); },
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('调试工具'),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: 'DEBUG 模式',
                    subtitle: '页面底部显示 Firebase 调试信息',
                    value: _debugMode,
                    onChanged: (val) {
                      setState(() => _debugMode = val);
                      _saveSetting('debug_mode', val);
                      DebugConfig.debugEnabled = val;
                    },
                  ),
                  _buildDebugButton('💤 进入休眠', () { bloc.add(PetSetActivityEvent(PetActivity.sleeping)); _showToast('💤 宠物已休眠'); }),
                  _buildDebugButton('👀 唤醒宠物', () { bloc.add(PetSetActivityEvent(PetActivity.idle)); _showToast('👀 宠物已唤醒'); }),
                  const SizedBox(height: 16),
                  _buildSectionTitle('应用信息'),
                  const SizedBox(height: 8),
                  _buildInfoTile('版本', '1.0.0'),
                  _buildInfoTile('平台', 'iOS (SideStore)'),
                  _buildInfoTile('宠物状态', bloc.state.isAwake ? '🟢 清醒' : '💤 休眠'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF4FC3F7).withOpacity(0.2), letterSpacing: 1));
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.03), width: 0.5)),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontSize: 13, color: const Color(0xFF4FC3F7).withOpacity(0.5))),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 10, color: const Color(0xFF4FC3F7).withOpacity(0.15))),
        value: value, onChanged: onChanged,
        activeColor: const Color(0xFF4FC3F7), activeTrackColor: const Color(0xFF4FC3F7).withOpacity(0.2),
        inactiveTrackColor: Colors.white.withOpacity(0.05), contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSliderTile({required String title, required double value, required double min, required double max, required int divisions, required String label, required ValueChanged<double> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.03), width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: const Color(0xFF4FC3F7).withOpacity(0.3))),
          Row(
            children: [
              Expanded(child: Slider(value: value, min: min, max: max, divisions: divisions, activeColor: const Color(0xFF4FC3F7), inactiveColor: const Color(0xFF4FC3F7).withOpacity(0.05), onChanged: onChanged)),
              SizedBox(width: 50, child: Text(label, style: TextStyle(fontSize: 10, color: const Color(0xFF4FC3F7).withOpacity(0.2)), textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.04), width: 0.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF4FC3F7).withOpacity(0.4))),
          Icon(Icons.chevron_right, size: 16, color: const Color(0xFF4FC3F7).withOpacity(0.1)),
        ]),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFF4FC3F7).withOpacity(0.2))),
        Text(value, style: TextStyle(fontSize: 12, color: const Color(0xFF4FC3F7).withOpacity(0.3))),
      ]),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF4FC3F7))), duration: const Duration(seconds: 1), backgroundColor: Colors.black.withOpacity(0.85), elevation: 0, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.1), width: 0.5))),
    );
  }
}

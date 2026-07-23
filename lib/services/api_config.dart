import 'package:shared_preferences/shared_preferences.dart';

/// API 密钥配置（SharedPreferences 持久化）
class ApiConfig {
  static const _keyDeepseek = 'api_key_deepseek';

  /// 获取已保存的 DeepSeek API Key
  static Future<String?> getDeepseekKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeepseek);
  }

  /// 保存 DeepSeek API Key
  static Future<void> setDeepseekKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeepseek, key.trim());
  }

  /// 是否已配置 API Key
  static Future<bool> hasKey() async {
    final key = await getDeepseekKey();
    return key != null && key.isNotEmpty;
  }
}

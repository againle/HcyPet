import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../presentation/pet/pet_painter.dart'; // EyeFlavor

/// ============================================================
/// 🍡 V4 — AI 韵律调节器 (AI Rhythm Tuner)
/// ============================================================
///
/// 每 10 分钟运行一次，调用 DeepSeek 获取 4 个韵律参数：
///   - moodBias:    性格倾向 (playful/clingy/lazy/aloof)
///   - actionBoost: 空闲动作频率倍率 (0.5~2.0)
///   - eyeFlavor:   推荐眼型 (normal/cheeky/wink)
///   - proactiveChance: 主动求关注概率 (0~1)
///
/// 规则引擎在 _onTick 时读取这些参数，调整宠物行为。

class AITuneResult {
  final String moodBias;
  final double actionBoost;
  final EyeFlavor eyeFlavor;
  final double proactiveChance;
  final DateTime timestamp;

  const AITuneResult({
    required this.moodBias,
    required this.actionBoost,
    required this.eyeFlavor,
    required this.proactiveChance,
    required this.timestamp,
  });

  /// 默认值（初始状态 / 重置用）
  static final defaultResult = AITuneResult(
    moodBias: 'playful',
    actionBoost: 1.0,
    eyeFlavor: EyeFlavor.normal,
    proactiveChance: 0.0,
    timestamp: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
        'moodBias': moodBias,
        'actionBoost': actionBoost,
        'eyeFlavor': eyeFlavor.name,
        'proactiveChance': proactiveChance,
        'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  factory AITuneResult.fromJson(Map<String, dynamic> json) {
    return AITuneResult(
      moodBias: json['moodBias'] ?? 'playful',
      actionBoost: (json['actionBoost'] as num?)?.toDouble() ?? 1.0,
      eyeFlavor: EyeFlavor.values.firstWhere(
        (e) => e.name == json['eyeFlavor'],
        orElse: () => EyeFlavor.normal,
      ),
      proactiveChance: (json['proactiveChance'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

class AITuner {
  static const _tuneInterval = Duration(minutes: 10);
  static const _storageKey = 'ai_tune_result';
  static const _highBoostKey = 'high_boost_streak';

  Timer? _timer;
  AITuneResult _current = AITuneResult.defaultResult;
  int _highBoostStreak = 0; // 连续高 boost 计数

  /// 外部注入的回调：获取当前宠物状态快照
  String Function()? onCollectContext;

  /// 外部注入的回调：AI 返回结果后通知 Bloc
  void Function(AITuneResult result)? onTuneUpdated;

  AITuneResult get current => _current;

  /// 启动定时器并立即执行第一次调参
  Future<void> start() async {
    await _loadFromCache();
    _timer?.cancel();
    _timer = Timer.periodic(_tuneInterval, (_) => _tune());
    // 立即触发第一次
    _tune();
  }

  /// 停止定时器
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 手动重置为默认值
  Future<void> reset() async {
    _current = AITuneResult.defaultResult;
    _highBoostStreak = 0;
    await _saveToCache(_current);
    await _saveHighBoostStreak();
    onTuneUpdated?.call(_current);
  }

  /// 从 SharedPreferences 加载缓存
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        _current = AITuneResult.fromJson(jsonDecode(jsonStr));
      }
      _highBoostStreak = prefs.getInt(_highBoostKey) ?? 0;
    } catch (_) {
      _current = AITuneResult.defaultResult;
    }
  }

  /// 保存到 SharedPreferences
  Future<void> _saveToCache(AITuneResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(result.toJson()));
    } catch (_) {}
  }

  /// 保存高 boost 连续计数
  Future<void> _saveHighBoostStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_highBoostKey, _highBoostStreak);
    } catch (_) {}
  }

  // ============================================================
  // 核心：调用 DeepSeek 获取韵律参数
  // ============================================================

  Future<void> _tune() async {
    final apiKey = await ApiConfig.getDeepseekKey();
    if (apiKey == null || apiKey.isEmpty) {
      // 无 API Key → 使用默认值
      return;
    }

    // 1. 收集上下文
    final context = onCollectContext?.call() ?? _buildFallbackContext();
    if (context.isEmpty) return;

    // 2. 构建 prompt（极简，约 50 tokens）
    final prompt = '''你是宠物性格调节器。根据宠物当前状态输出 JSON 调整今日性格。
$context
仅输出 JSON，不要其他文字。格式：
{"mood_bias":"playful","action_boost":1.2,"eye_flavor":"normal","proactive_chance":0.3}''';

    try {
      final response = await http.post(
        Uri.parse('https://api.deepseek.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 60,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            (data['choices']?[0]?['message']?['content'] as String?)?.trim() ?? '';

        if (content.isNotEmpty) {
          final parsed = _parseResponse(content);
          _applyWithLimits(parsed);
        }
      }
    } catch (_) {
      // API 失败 → 保持当前缓存值，不做任何修改
    }
  }

  /// 解析 AI 返回的 JSON（容错：提取第一个 { }）
  AITuneResult _parseResponse(String raw) {
    try {
      // 尝试直接解析
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _jsonToResult(json);
    } catch (_) {
      // 尝试提取 JSON 块
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
          return _jsonToResult(json);
        } catch (_) {}
      }
      return _current; // 解析失败 → 保持原值
    }
  }

  AITuneResult _jsonToResult(Map<String, dynamic> json) {
    return AITuneResult(
      moodBias: json['mood_bias'] ?? _current.moodBias,
      actionBoost: ((json['action_boost'] as num?)?.toDouble() ?? _current.actionBoost)
          .clamp(0.5, 2.0),
      eyeFlavor: _parseEyeFlavor(json['eye_flavor']),
      proactiveChance: ((json['proactive_chance'] as num?)?.toDouble() ?? _current.proactiveChance)
          .clamp(0.0, 1.0),
      timestamp: DateTime.now(),
    );
  }

  EyeFlavor _parseEyeFlavor(dynamic val) {
    if (val is String) {
      switch (val.toLowerCase()) {
        case 'cheeky':
          return EyeFlavor.cheeky;
        case 'wink':
          return EyeFlavor.wink;
        default:
          return EyeFlavor.normal;
      }
    }
    return EyeFlavor.normal;
  }

  /// 应用参数并执行防过载检查
  void _applyWithLimits(AITuneResult parsed) {
    var result = parsed;

    // 降温策略：连续 3 次 action_boost > 1.8 → 强制限制
    if (result.actionBoost > 1.8) {
      _highBoostStreak++;
      if (_highBoostStreak >= 3) {
        result = AITuneResult(
          moodBias: result.moodBias,
          actionBoost: 1.5, // 强制降速
          eyeFlavor: EyeFlavor.normal,
          proactiveChance: (result.proactiveChance * 0.5).clamp(0.0, 1.0),
          timestamp: result.timestamp,
        );
      }
    } else {
      _highBoostStreak = 0; // 恢复正常
    }
    _saveHighBoostStreak();

    _current = result;
    _saveToCache(result);
    onTuneUpdated?.call(_current);
  }

  /// 兜底：无外部回调时构建基础上下文
  String _buildFallbackContext() {
    final now = DateTime.now();
    final hour = now.hour;
    final timeLabel = hour < 6 ? '深夜' : hour < 9 ? '早晨' : hour < 12 ? '上午' : hour < 14 ? '中午' : hour < 18 ? '下午' : hour < 22 ? '晚上' : '深夜';
    return '现在是$timeLabel，这是新的一天。请根据时段推荐合适的宠物性格。';
  }
}

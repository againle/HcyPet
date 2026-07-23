import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// ============================================================
/// DeepSeek API 服务
/// ============================================================
///
/// 用法：
///   final svc = DeepSeekService();
///   final reply = await svc.chat('你好呀', memoryContext: [...]);
///

class DeepSeekService {
  static const _baseUrl = 'https://api.deepseek.com/v1';
  static const _model = 'deepseek-chat';
  static const _maxRetries = 2;

  /// 发送对话请求
  ///
  /// [message] 用户说的话
  /// [memoryContext] 最近记忆（最多 5 条）
  /// [systemPrompt] 系统角色提示
  Future<DeepSeekResult> chat(
    String message, {
    List<MemoryEntry>? memoryContext,
    String? systemPrompt,
  }) async {
    final apiKey = await ApiConfig.getDeepseekKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const DeepSeekResult.error('请先在设置中配置 DeepSeek API Key');
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': systemPrompt ??
            '你是一只名叫 Mochi（麻糬）的极简电子宠物，住在用户的手机里。'
                '你只有两个圆眼睛和偶尔出现的弧线嘴巴。'
                '你温暖、贴心、有点小脾气。回复要简短（20字以内），'
                '像朋友聊天一样自然。'
                '用户说的话如果包含情绪，你要敏锐察觉并回应。',
      },
    ];

    // 注入记忆上下文
    if (memoryContext != null && memoryContext.isNotEmpty) {
      final memText = memoryContext
          .map((m) => '[${m.timeLabel}] 用户说: "${m.userSaid}", 当时心情: ${m.mood}')
          .join('\n');
      messages.add({
        'role': 'system',
        'content': '以下是最近的互动记忆，请参考它们理解用户的状态：\n$memText',
      });
    }

    messages.add({'role': 'user', 'content': message});

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'max_tokens': 80,
            'temperature': 0.8,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content =
              data['choices']?[0]?['message']?['content'] as String? ?? '';
          return DeepSeekResult.success(content.trim());
        }

        if (response.statusCode == 401) {
          return const DeepSeekResult.error('API Key 无效，请在设置中检查');
        }

        // 其他错误，重试
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        } else {
          return DeepSeekResult.error('网络异常，请稍后重试');
        }
      }
    }

    return const DeepSeekResult.error('服务暂时不可用');
  }

  /// 生成每日日记摘要（调用一次 API，压缩 50 条记忆成 200 字）
  Future<String?> generateDiary(List<MemoryEntry> memories) async {
    final apiKey = await ApiConfig.getDeepseekKey();
    if (apiKey == null || apiKey.isEmpty || memories.isEmpty) return null;

    final memText = memories.map((m) => '- ${m.timeLabel}: ${m.userSaid}').join('\n');
    final prompt = '将以下宠物与主人的互动记录压缩成一段 100 字以内的温馨日记，'
        '以宠物的第一人称视角写：\n$memText';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices']?[0]?['message']?['content'] as String?)?.trim();
      }
    } catch (_) {}
    return null;
  }

  /// 生成宠物的随机念头（心愿系统用）
  Future<String?> generateWish(List<MemoryEntry> recentMemories) async {
    final apiKey = await ApiConfig.getDeepseekKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final memText = recentMemories.isNotEmpty
        ? '最近互动: ${recentMemories.map((m) => m.userSaid).join(", ")}'
        : '';

    final now = DateTime.now();
    final hourLabel = now.hour < 6 ? '深夜' : now.hour < 12 ? '上午' : now.hour < 18 ? '下午' : '晚上';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '你是一只电子宠物 Mochi。现在是$hourLabel。$memText\n'
                  '生成一句 15 字以内的可爱念头，表达你想和主人互动的心情。'
                  '比如"Mochi 想你了，想让你摸摸它的头"或"Mochi 饿了，想吃小饼干"。'
            },
            {'role': 'user', 'content': '给我一个念头'},
          ],
          'max_tokens': 40,
          'temperature': 1.0,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices']?[0]?['message']?['content'] as String?)?.trim();
      }
    } catch (_) {}
    return null;
  }
}

/// API 调用结果
class DeepSeekResult {
  final String text;
  final bool isError;
  const DeepSeekResult.success(this.text) : isError = false;
  const DeepSeekResult.error(this.text) : isError = true;
}

/// 记忆条目
class MemoryEntry {
  final String userSaid;
  final String mood;
  final String timeLabel;
  final DateTime timestamp;

  const MemoryEntry({
    required this.userSaid,
    required this.mood,
    required this.timeLabel,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'userSaid': userSaid,
        'mood': mood,
        'timeLabel': timeLabel,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
        userSaid: json['userSaid'] as String,
        mood: json['mood'] as String,
        timeLabel: json['timeLabel'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

import 'dart:math';
import '../models/pet_state.dart';
import '../models/user_action.dart';

/// ============================================================
/// AI 情感推理引擎 — 规则引擎 + 加权评分 + 上下文记忆
/// ============================================================
///
/// 核心理念：非对话式智能。
/// 根据用户行为推断情绪状态，输出宠物视觉/行为反应，
/// 而非生成文字对话。
///
class EmotionEngine {
  final Random _random = Random();

  // 短时上下文记忆（最近 5 条互动）
  final List<UserAction> _contextMemory = [];
  static const int _memorySize = 5;

  // 当前亲密度（由 PetBloc 外部注入）
  double _intimacy = 0.5;

  // 短时互动冷却：记录最近互动时间
  DateTime? _lastPetTime;
  DateTime? _lastFeedTime;

  // ============ 公开 API ============

  /// 处理用户行为，返回宠物反应
  PetReaction process(UserAction action, {required PetState currentState}) {
    _addToMemory(action);

    final reaction = switch (action.type) {
      UserActionType.pet      => _handlePet(action, currentState),
      UserActionType.feed     => _handleFeed(action, currentState),
      UserActionType.shake    => _handleShake(action, currentState),
      UserActionType.talk     => _handleTalk(action, currentState),
      UserActionType.studyStart => _handleStudyStart(action, currentState),
      UserActionType.studyStop  => _handleStudyStop(action, currentState),
      UserActionType.vision   => _handleVision(action, currentState),
      UserActionType.partner  => _handlePartner(action, currentState),
      UserActionType.idle     => _handleIdle(action, currentState),
    };

    return reaction;
  }

  /// 更新亲密度（外部注入）
  void updateIntimacy(double value) {
    _intimacy = value.clamp(0.0, 1.0);
  }

  /// 获取最近记忆
  List<UserAction> get recentMemory => List.unmodifiable(_contextMemory);

  /// 清空记忆
  void clearMemory() {
    _contextMemory.clear();
  }

  // ============ 记忆管理 ============

  void _addToMemory(UserAction action) {
    _contextMemory.add(action);
    while (_contextMemory.length > _memorySize) {
      _contextMemory.removeAt(0);
    }
  }

  // ============ 各行为处理器 ============

  /// 抚摸（变化率受控：短时重复收益递减）
  PetReaction _handlePet(UserAction action, PetState state) {
    final now = DateTime.now();
    final secondsSinceLast = _lastPetTime != null ? now.difference(_lastPetTime!).inSeconds : 999;
    _lastPetTime = now;
    // 30秒内重复抚摸，收益递减
    final freqMul = secondsSinceLast < 10 ? 0.2 : secondsSinceLast < 30 ? 0.5 : 1.0;

    final rawBonus = (0.01 + _intimacy * 0.02) * freqMul;
    final intimacyBonus = _applyDiminishing(rawBonus);
    final hints = <String>[
      '好舒服呀~',
      '再摸摸我~',
      '你的手好温暖',
      '好喜欢这样',
      '呼噜呼噜...',
    ];

    final shouldAnimate = _intimacy > 0.7 && _random.nextDouble() < 0.3;

    return PetReaction(
      targetMood: _intimacy > 0.5 ? PetMood.happy : PetMood.calm,
      systemHint: _pick(hints),
      intimacyDelta: intimacyBonus,
      happinessDelta: 0.02 * freqMul,
      energyDelta: 0.01 * freqMul,
      shouldAnimate: shouldAnimate,
      suggestedActivity: PetActivity.playing,
    );
  }

  /// 喂食
  PetReaction _handleFeed(UserAction action, PetState state) {
    final now = DateTime.now();
    final secondsSinceLast = _lastFeedTime != null ? now.difference(_lastFeedTime!).inSeconds : 999;
    _lastFeedTime = now;
    final freqMul = secondsSinceLast < 10 ? 0.3 : secondsSinceLast < 60 ? 0.6 : 1.0;
    final hints = <String>[
      '好好吃！',
      '谢谢你~',
      '吃饱了！',
      '好满足',
      '还想吃...',
    ];

    final isHungry = state.energy < 0.3;
    return PetReaction(
      targetMood: PetMood.happy,
      systemHint: isHungry ? '终于等到你喂我了！' : _pick(hints),
      intimacyDelta: _applyDiminishing(0.03 * freqMul),
      happinessDelta: 0.06 * freqMul,
      energyDelta: 0.12 * freqMul,
      shouldAnimate: isHungry,
      suggestedActivity: PetActivity.idle,
    );
  }

  /// 摇晃
  PetReaction _handleShake(UserAction action, PetState state) {
    final hints = <String>[
      '哇！地震了吗！？',
      '晕乎乎的...',
      '发生了什么？',
      '好晕好晕',
    ];

    return PetReaction(
      targetMood: PetMood.surprised,
      systemHint: _pick(hints),
      intimacyDelta: _applyDiminishing(0.01),
      happinessDelta: 0.01,
      energyDelta: -0.01,
      shouldAnimate: true,
      suggestedActivity: PetActivity.idle,
    );
  }

  /// 说话 — 关键词情感分析
  PetReaction _handleTalk(UserAction action, PetState state) {
    final text = action.text ?? '';
    final sentiment = _analyzeSentiment(text);
    final timeContext = _getTimeContext();

    // 综合推断情绪
    final mood = _inferMoodFromSentiment(sentiment, timeContext);

    // 生成系统提示
    final hint = _generateTalkHint(sentiment, timeContext);

    return PetReaction(
      targetMood: mood,
      systemHint: hint,
      intimacyDelta: _applyDiminishing(0.03 + (sentiment.isNegative ? 0.02 : 0.0)),
      happinessDelta: sentiment.isPositive ? 0.03 : -0.01,
      energyDelta: 0.0,
      shouldAnimate: sentiment.isNegative,
      suggestedActivity: PetActivity.thinking,
    );
  }

  /// 开始学习
  PetReaction _handleStudyStart(UserAction action, PetState state) {
    final timeContext = _getTimeContext();
    final hints = switch (timeContext) {
      TimeContext.morning   => '早安！一起加油~',
      TimeContext.night     => '这么晚还在学习，辛苦了',
      TimeContext.lateNight => '夜深了，注意身体哦',
      _                     => '陪你一起学习~',
    };

    return PetReaction(
      targetMood: PetMood.calm,
      systemHint: hints,
      intimacyDelta: _applyDiminishing(0.01),
      happinessDelta: 0.01,
      energyDelta: -0.01,
      shouldAnimate: false,
      suggestedActivity: PetActivity.studying,
    );
  }

  /// 结束学习
  PetReaction _handleStudyStop(UserAction action, PetState state) {
    final pomodoroCount = int.tryParse(action.text ?? '0') ?? 0;
    final hints = pomodoroCount >= 4
        ? '太厉害了！完成了${pomodoroCount}个番茄钟！'
        : '学习结束！你真棒！';

    return PetReaction(
      targetMood: PetMood.happy,
      systemHint: hints,
      intimacyDelta: _applyDiminishing(0.02),
      suggestedActivity: PetActivity.idle,
    );
  }

  /// 视觉检测
  PetReaction _handleVision(UserAction action, PetState state) {
    final emotion = action.detectedEmotion ?? 'neutral';
    final attention = action.attentionScore ?? 50;

    if (attention < 40) {
      return PetReaction(
        targetMood: PetMood.calm,
        systemHint: '专注点哦~ 我在这儿陪你',
        intimacyDelta: _applyDiminishing(0.005),
        suggestedActivity: PetActivity.watching,
      );
    }

    switch (emotion) {
      case 'sad':
        return PetReaction(
          targetMood: PetMood.sad,
          systemHint: '别难过，我在这儿陪你',
          intimacyDelta: _applyDiminishing(0.02),
          happinessDelta: -0.01,
          energyDelta: 0.0,
          shouldAnimate: true,
          suggestedActivity: PetActivity.watching,
        );
      case 'angry':
        return PetReaction(
          targetMood: PetMood.calm,
          systemHint: '深呼吸，放松一下~',
          intimacyDelta: _applyDiminishing(0.01),
          happinessDelta: -0.01,
          energyDelta: 0.0,
          shouldAnimate: false,
          suggestedActivity: PetActivity.watching,
        );
      case 'happy':
        return PetReaction(
          targetMood: PetMood.happy,
          systemHint: '看到你开心我也好开心！',
          intimacyDelta: _applyDiminishing(0.01),
          happinessDelta: 0.02,
          energyDelta: 0.01,
          shouldAnimate: true,
          suggestedActivity: PetActivity.watching,
        );
      default:
        return PetReaction(
          targetMood: PetMood.calm,
          systemHint: '认真陪伴中...',
          intimacyDelta: _applyDiminishing(0.005),
          happinessDelta: 0.0,
          energyDelta: 0.0,
          shouldAnimate: false,
          suggestedActivity: PetActivity.watching,
        );
    }
  }

  /// 伴侣消息
  PetReaction _handlePartner(UserAction action, PetState state) {
    final text = action.text ?? '';
    final sentiment = _analyzeSentiment(text);

    return PetReaction(
      targetMood: sentiment.isPositive ? PetMood.happy : PetMood.calm,
      systemHint: text,
      intimacyDelta: _applyDiminishing(0.05),
      happinessDelta: sentiment.isPositive ? 0.04 : 0.02,
      energyDelta: 0.01,
      shouldAnimate: true,
      suggestedActivity: PetActivity.idle,
    );
  }

  /// 空闲/时间流逝
  PetReaction _handleIdle(UserAction action, PetState state) {
    final idleMinutes = int.tryParse(action.text ?? '0') ?? 0;
    final idleHours = idleMinutes ~/ 60;

    // 长时间未互动 → 思念
    if (idleHours > 4 && state.mood != PetMood.missing) {
      return PetReaction(
        targetMood: PetMood.missing,
        systemHint: '你去了哪里...好想你',
        intimacyDelta: _applyDiminishing(-0.005),
        happinessDelta: -0.02,
        energyDelta: 0.0,
        shouldAnimate: true,
        suggestedActivity: PetActivity.idle,
      );
    }

    // 精力过低 → 困倦
    if (state.energy < 0.15) {
      return PetReaction(
        targetMood: PetMood.sleepy,
        systemHint: '好困呀...',
        intimacyDelta: 0.0,
        happinessDelta: -0.01,
        energyDelta: 0.0,
        shouldAnimate: true,
        suggestedActivity: PetActivity.idle,
      );
    }

    return PetReaction.passThrough(state.mood);
  }

  // ============ 情感分析 ============

  /// 简单关键词情感分析（丰富词库）
  SentimentResult _analyzeSentiment(String text) {
    final lower = text.toLowerCase();

    final positiveWords = [
      '开心', '快乐', '喜欢', '爱', '好', '棒', '厉害', '加油',
      '谢谢', '哈哈', '不错', 'nice', 'good', 'love', 'happy',
      'great', 'wonderful', 'awesome', '太棒了', '真好', '完美',
      '可爱', '好看', '漂亮', '帅', '成功', '赢了', '通过',
      '放假', '周末', '休息', '吃', '美食', '礼物', '惊喜',
    ];

    final negativeWords = [
      '累', '难过', '伤心', '烦', '无聊', '孤独', '郁闷', '痛苦',
      '压力', '疲惫', '不好', '不行', '失败', '讨厌', '生气',
      'sad', 'tired', 'angry', 'bad', 'hate',
      '困', '想哭', '崩溃', '焦虑', '紧张', '害怕', '担心',
      '不舒服', '头疼', '感冒', '生病', '加班', '熬夜',
    ];

    int posScore = 0;
    int negScore = 0;

    for (final w in positiveWords) {
      if (lower.contains(w)) posScore++;
    }
    for (final w in negativeWords) {
      if (lower.contains(w)) negScore++;
    }

    final isPositive = posScore > negScore;
    final isNegative = negScore > posScore;
    final intensity = ((posScore + negScore) / max(text.length, 1) * 10).clamp(0.0, 1.0);

    return SentimentResult(
      isPositive: isPositive, isNegative: isNegative, intensity: intensity,
      positiveScore: posScore, negativeScore: negScore,
    );
  }

  /// 根据情感推断情绪
  PetMood _inferMoodFromSentiment(SentimentResult sentiment, TimeContext timeContext) {
    if (sentiment.isNegative) {
      if (timeContext == TimeContext.lateNight) return PetMood.sleepy;
      return PetMood.sad;
    }
    if (sentiment.isPositive) return PetMood.happy;
    if (timeContext == TimeContext.lateNight && _intimacy > 0.6) return PetMood.sleepy;
    return PetMood.calm;
  }

  /// 生成对话提示
  String _generateTalkHint(SentimentResult sentiment, TimeContext timeContext) {
    if (sentiment.isNegative) {
      final comfortHints = <String>[
        '辛苦了，我一直在这里',
        '别担心，有我在呢',
        '累了就休息一下吧',
        '抱抱你...',
        '一切都会好起来的',
      ];
      return _pick(comfortHints);
    }

    if (sentiment.isPositive) {
      final joyHints = <String>[
        '看到你开心我也好开心！',
        '今天是个好日子~',
        '和你在一起真好',
        '嘻嘻~',
      ];
      return _pick(joyHints);
    }

    // 中性
    final neutralHints = <String>[
      '嗯，我在听呢',
      '继续说吧~',
      '我在认真听哦',
      '然后呢？',
    ];
    return _pick(neutralHints);
  }

  // ============ 时间上下文 ============

  TimeContext _getTimeContext() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return TimeContext.morning;
    if (hour >= 12 && hour < 18) return TimeContext.afternoon;
    if (hour >= 18 && hour < 23) return TimeContext.night;
    return TimeContext.lateNight; // 23-6
  }

  // ============ 工具方法 ============

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  /// 亲密度递减收益：越接近 100%，涨幅越小
  double _applyDiminishing(double raw) {
    if (_intimacy < 0.5) return raw;           // 50% 以下全额
    if (_intimacy < 0.75) return raw * 0.7;    // 50-75% 打七折
    if (_intimacy < 0.90) return raw * 0.4;    // 75-90% 打四折
    return raw * 0.15;                          // 90%+ 打一五折
  }
}

/// 情感分析结果
class SentimentResult {
  final bool isPositive;
  final bool isNegative;
  final double intensity;   // 0.0 ~ 1.0
  final int positiveScore;
  final int negativeScore;

  const SentimentResult({
    required this.isPositive,
    required this.isNegative,
    required this.intensity,
    required this.positiveScore,
    required this.negativeScore,
  });

  bool get isNeutral => !isPositive && !isNegative;
}

/// 时间上下文
enum TimeContext {
  morning,     // 6-12
  afternoon,   // 12-18
  night,       // 18-23
  lateNight,   // 23-6
}

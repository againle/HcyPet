import '../../models/pet_state.dart';

/// 用户行为输入（AI 情感引擎的输入）
class UserAction {
  final UserActionType type;
  final String? text;            // 用户输入的文字（若有）
  final String? detectedEmotion; // 视觉检测的情绪（若有）
  final double? attentionScore;  // 视觉检测的注意力分数
  final DateTime timestamp;

  const UserAction({
    required this.type,
    this.text,
    this.detectedEmotion,
    this.attentionScore,
    required this.timestamp,
  });

  /// 快捷构造
  factory UserAction.pet({String? text}) => UserAction(
        type: UserActionType.pet,
        text: text,
        timestamp: DateTime.now(),
      );

  factory UserAction.feed() => UserAction(
        type: UserActionType.feed,
        timestamp: DateTime.now(),
      );

  factory UserAction.shake() => UserAction(
        type: UserActionType.shake,
        timestamp: DateTime.now(),
      );

  factory UserAction.talk(String text) => UserAction(
        type: UserActionType.talk,
        text: text,
        timestamp: DateTime.now(),
      );

  factory UserAction.studyStart() => UserAction(
        type: UserActionType.studyStart,
        timestamp: DateTime.now(),
      );

  factory UserAction.studyStop({int? pomodoroCount}) => UserAction(
        type: UserActionType.studyStop,
        text: pomodoroCount?.toString(),
        timestamp: DateTime.now(),
      );

  factory UserAction.vision({required String emotion, required double attentionScore}) => UserAction(
        type: UserActionType.vision,
        detectedEmotion: emotion,
        attentionScore: attentionScore,
        timestamp: DateTime.now(),
      );

  factory UserAction.partnerMessage(String message) => UserAction(
        type: UserActionType.partner,
        text: message,
        timestamp: DateTime.now(),
      );

  factory UserAction.idle(Duration elapsed) => UserAction(
        type: UserActionType.idle,
        text: elapsed.inMinutes.toString(),
        timestamp: DateTime.now(),
      );

  @override
  String toString() => 'UserAction($type, text: $text, emotion: $detectedEmotion)';
}

/// 用户行为类型
enum UserActionType {
  pet,          // 抚摸
  feed,         // 喂食
  shake,        // 摇晃
  talk,         // 说话
  studyStart,   // 开始学习
  studyStop,    // 结束学习
  vision,       // 视觉检测
  partner,      // 伴侣消息
  idle,         // 空闲（时间流逝）
}

/// AI 情感引擎输出：宠物反应
class PetReaction {
  final PetMood targetMood;
  final String systemHint;
  final double intimacyDelta;     // -0.05 ~ +0.05
  final double happinessDelta;    // -0.03 ~ +0.03
  final double energyDelta;       // -0.03 ~ +0.03
  final bool shouldAnimate;       // 是否触发特殊动画
  final PetActivity suggestedActivity;

  const PetReaction({
    required this.targetMood,
    required this.systemHint,
    this.intimacyDelta = 0.0,
    this.happinessDelta = 0.0,
    this.energyDelta = 0.0,
    this.shouldAnimate = false,
    this.suggestedActivity = PetActivity.idle,
  });

  /// 无变化（穿透）
  static PetReaction passThrough(PetMood currentMood) => PetReaction(
        targetMood: currentMood,
        systemHint: '',
        shouldAnimate: false,
      );

  @override
  String toString() =>
      'PetReaction(mood: $targetMood, hint: $systemHint, intimacy: $intimacyDelta)';
}

import 'package:equatable/equatable.dart';
import 'pet_state.dart';

/// 所有宠物事件的基类
abstract class PetEvent extends Equatable {
  const PetEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化宠物（加载持久化数据）
class PetInitEvent extends PetEvent {}

/// 用户抚摸宠物
class PetPetEvent extends PetEvent {}

/// 用户与宠物说话（语音或文字）
class PetTalkEvent extends PetEvent {
  final String? message;
  final bool isVoice;
  const PetTalkEvent({this.message, this.isVoice = false});
}

/// 喂食宠物
class PetFeedEvent extends PetEvent {}

/// 摇晃手机触发互动
class PetShakeEvent extends PetEvent {}

/// 时间流逝（用于状态自然衰减）
class PetTickEvent extends PetEvent {
  final Duration elapsed;
  const PetTickEvent(this.elapsed);
}

/// 切换情绪（用于调试/预览）
class PetSetMoodEvent extends PetEvent {
  final PetMood mood;
  const PetSetMoodEvent(this.mood);
}

/// 切换活动状态
class PetSetActivityEvent extends PetEvent {
  final PetActivity activity;
  const PetSetActivityEvent(this.activity);
}

/// 用户开始学习
class PetStartStudyingEvent extends PetEvent {}

/// 用户结束学习
class PetStopStudyingEvent extends PetEvent {}

/// 更新亲密度
class PetUpdateIntimacyEvent extends PetEvent {
  final double amount;
  const PetUpdateIntimacyEvent(this.amount);
}

/// 重置宠物状态（用于测试）
class PetResetEvent extends PetEvent {}

/// 伴侣发送消息（对方用户互动触发）
class PetPartnerMessageEvent extends PetEvent {
  final String message;
  const PetPartnerMessageEvent(this.message);
}

/// 视觉检测结果（自习室专注/情绪检测）
class PetVisionEvent extends PetEvent {
  final String emotion;
  final double attentionScore;
  final dynamic visionResult; // V3: VisionResult (避免循环依赖)
  const PetVisionEvent({
    required this.emotion,
    required this.attentionScore,
    this.visionResult,
  });

  @override
  List<Object?> get props => [emotion, attentionScore];
}

/// 清除系统提示（内部事件）
class ClearThoughtEvent extends PetEvent {}

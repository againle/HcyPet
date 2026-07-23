import 'package:equatable/equatable.dart';

/// 宠物情绪枚举
enum PetMood {
  happy,      // 开心
  calm,       // 平静
  missing,    // 思念
  sleepy,     // 困倦
  sad,        // 难过
  surprised,  // 惊讶
}

/// 宠物活动状态
enum PetActivity {
  idle,       // 空闲
  watching,   // 注视
  playing,    // 玩耍
  studying,   // 陪伴学习
  sleeping,   // 睡觉
  thinking,   // 思考
  groggy,     // 半睡半醒/刚醒
  celebrating,// 庆祝
}

/// 宠物核心状态
class PetState extends Equatable {
  final String petName;
  final PetMood mood;
  final PetActivity activity;
  final double happiness;    // 0.0 - 1.0
  final double energy;       // 0.0 - 1.0
  final double intimacy;     // 0.0 - 1.0（亲密度）
  final bool isAwake;
  final DateTime lastInteraction;
  final String? thought;
  final double fullness;      // 饱腹度 0.0-1.0
  final DateTime? lastFedAt;  // 上次喂食时间
  final DateTime? lastSleepAt; // 上次入睡时间（用于计算睡眠质量）
  final int wakeAttempts;     // 早晨唤醒尝试次数     // 宠物内心独白（可选）

  const PetState({
    this.petName = '小宠物',
    this.mood = PetMood.calm,
    this.activity = PetActivity.idle,
    this.happiness = 0.7,
    this.energy = 0.8,
    this.intimacy = 0.5,
    this.isAwake = true,
    this.fullness = 0.5,
    this.lastFedAt,
    this.lastSleepAt,
    this.wakeAttempts = 0,
    required this.lastInteraction,
    this.thought,
  });

  /// 初始化状态
  factory PetState.initial() {
    return PetState(
      lastInteraction: DateTime.now(),
      thought: '你好呀~',
    );
  }

  /// 从 JSON 加载
  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      petName: json['petName'] ?? '小宠物',
      mood: PetMood.values.firstWhere(
        (e) => e.name == json['mood'],
        orElse: () => PetMood.calm,
      ),
      activity: PetActivity.values.firstWhere(
        (e) => e.name == json['activity'],
        orElse: () => PetActivity.idle,
      ),
      happiness: (json['happiness'] as num?)?.toDouble() ?? 0.7,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.8,
      intimacy: (json['intimacy'] as num?)?.toDouble() ?? 0.5,
      isAwake: json['isAwake'] ?? true,
      fullness: (json['fullness'] as num?)?.toDouble() ?? 0.5,
      lastFedAt: json['lastFedAt'] != null ? DateTime.parse(json['lastFedAt']) : null,
      lastSleepAt: json['lastSleepAt'] != null ? DateTime.parse(json['lastSleepAt']) : null,
      wakeAttempts: (json['wakeAttempts'] as num?)?.toInt() ?? 0,
      lastInteraction: DateTime.parse(
        json['lastInteraction'] ?? DateTime.now().toIso8601String(),
      ),
      thought: json['thought'],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'petName': petName,
      'mood': mood.name,
      'activity': activity.name,
      'happiness': happiness,
      'energy': energy,
      'intimacy': intimacy,
      'isAwake': isAwake,
      'fullness': fullness,
      'lastFedAt': lastFedAt?.toIso8601String(),
      'lastSleepAt': lastSleepAt?.toIso8601String(),
      'wakeAttempts': wakeAttempts,
      'lastInteraction': lastInteraction.toIso8601String(),
      'thought': thought,
    };
  }

  /// 复制并更新
  PetState copyWith({
    String? petName,
    PetMood? mood,
    PetActivity? activity,
    double? happiness,
    double? energy,
    double? intimacy,
    bool? isAwake,
    DateTime? lastInteraction,
    String? thought,
    double? fullness,
    DateTime? lastFedAt,
    DateTime? lastSleepAt,
    int? wakeAttempts,
  }) {
    return PetState(
      petName: petName ?? this.petName,
      mood: mood ?? this.mood,
      activity: activity ?? this.activity,
      happiness: happiness ?? this.happiness,
      energy: energy ?? this.energy,
      intimacy: intimacy ?? this.intimacy,
      isAwake: isAwake ?? this.isAwake,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      thought: thought ?? this.thought,
      fullness: fullness ?? this.fullness,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      lastSleepAt: lastSleepAt ?? this.lastSleepAt,
      wakeAttempts: wakeAttempts ?? this.wakeAttempts,
    );
  }

  @override
  List<Object?> get props => [
        petName,
        mood,
        activity,
        happiness,
        energy,
        intimacy,
        isAwake,
        lastInteraction,
        thought,
        fullness,
        lastFedAt,
        lastSleepAt,
        wakeAttempts,
      ];
}

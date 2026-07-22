import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 个人养成数据（本地存储，不与伴侣同步）
class GrowthState {
  final int level;          // 1-99
  final double experience;  // 0.0-1.0（当前等级进度）
  final int totalFeedCount;
  final int totalPetCount;
  final double totalStudyHours;
  final int pomodoroCompleted;
  final int partnerMessagesSent;
  final DateTime lastUpdated;

  // 每日经验上限追踪
  final int dailyPetCount;       // 今日抚摸次数
  final int dailyFeedCount;      // 今日喂食次数
  final int dailyPetDate;        // 记录日期 (day of year)

  static const _maxDailyPetExp = 5;
  static const _maxDailyFeedExp = 5;

  const GrowthState({
    this.level = 1,
    this.experience = 0.0,
    this.totalFeedCount = 0,
    this.totalPetCount = 0,
    this.totalStudyHours = 0.0,
    this.pomodoroCompleted = 0,
    this.partnerMessagesSent = 0,
    this.dailyPetCount = 0,
    this.dailyFeedCount = 0,
    this.dailyPetDate = 0,
    required this.lastUpdated,
  });

  factory GrowthState.initial() => GrowthState(
        lastUpdated: DateTime.now(),
      );

  /// 经验值计算：给宠物增加经验
  GrowthState addExperience(double amount) {
    var newExp = experience + amount;
    var newLevel = level;

    // 升级（每 1.0 经验升一级，最高 99）
    while (newExp >= 1.0 && newLevel < 99) {
      newExp -= 1.0;
      newLevel++;
    }
    if (newLevel >= 99) newExp = 1.0;

    return GrowthState(
      level: newLevel,
      experience: newExp.clamp(0.0, 1.0),
      totalFeedCount: totalFeedCount,
      totalPetCount: totalPetCount,
      totalStudyHours: totalStudyHours,
      pomodoroCompleted: pomodoroCompleted,
      partnerMessagesSent: partnerMessagesSent,
      dailyPetCount: dailyPetCount,
      dailyFeedCount: dailyFeedCount,
      dailyPetDate: dailyPetDate,
      lastUpdated: DateTime.now(),
    );
  }

  /// 喂食（每日经验上限 5 次）
  GrowthState recordFeed() {
    final today = DateTime.now().day + DateTime.now().month * 31;
    final isNewDay = today != dailyPetDate;
    final newDaily = isNewDay ? 1 : dailyFeedCount + 1;
    final capped = newDaily > _maxDailyFeedExp;
    return (capped ? this : addExperience(0.08)).copyWith(
      totalFeedCount: totalFeedCount + 1,
      dailyFeedCount: newDaily,
      dailyPetCount: isNewDay ? 0 : dailyPetCount,
      dailyPetDate: today,
    );
  }

  /// 抚摸（每日经验上限 5 次）
  GrowthState recordPet() {
    final today = DateTime.now().day + DateTime.now().month * 31;
    final isNewDay = today != dailyPetDate;
    final newDaily = isNewDay ? 1 : dailyPetCount + 1;
    final capped = newDaily > _maxDailyPetExp;
    return (capped ? this : addExperience(0.05)).copyWith(
      totalPetCount: totalPetCount + 1,
      dailyPetCount: newDaily,
      dailyFeedCount: isNewDay ? 0 : dailyFeedCount,
      dailyPetDate: today,
    );
  }

  /// 学习计时
  GrowthState recordStudy(double hours) {
    return addExperience(hours * 0.15).copyWith(
      totalStudyHours: totalStudyHours + hours,
    );
  }

  /// 番茄钟完成
  GrowthState recordPomodoro() {
    return addExperience(0.12).copyWith(
      pomodoroCompleted: pomodoroCompleted + 1,
    );
  }

  /// 伴侣消息
  GrowthState recordPartnerMessage() {
    return addExperience(0.06).copyWith(
      partnerMessagesSent: partnerMessagesSent + 1,
    );
  }

  /// 等级称号
  String get levelTitle {
    if (level >= 80) return '传说';
    if (level >= 60) return '大师';
    if (level >= 40) return '专家';
    if (level >= 25) return '达人';
    if (level >= 15) return '熟练';
    if (level >= 8) return '新手';
    if (level >= 3) return '入门';
    return '初识';
  }

  GrowthState copyWith({
    int? level,
    double? experience,
    int? totalFeedCount,
    int? totalPetCount,
    double? totalStudyHours,
    int? pomodoroCompleted,
    int? partnerMessagesSent,
    int? dailyPetCount,
    int? dailyFeedCount,
    int? dailyPetDate,
    DateTime? lastUpdated,
  }) {
    return GrowthState(
      level: level ?? this.level,
      experience: experience ?? this.experience,
      totalFeedCount: totalFeedCount ?? this.totalFeedCount,
      totalPetCount: totalPetCount ?? this.totalPetCount,
      totalStudyHours: totalStudyHours ?? this.totalStudyHours,
      pomodoroCompleted: pomodoroCompleted ?? this.pomodoroCompleted,
      partnerMessagesSent: partnerMessagesSent ?? this.partnerMessagesSent,
      dailyPetCount: dailyPetCount ?? this.dailyPetCount,
      dailyFeedCount: dailyFeedCount ?? this.dailyFeedCount,
      dailyPetDate: dailyPetDate ?? this.dailyPetDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'experience': experience,
        'totalFeedCount': totalFeedCount,
        'totalPetCount': totalPetCount,
        'totalStudyHours': totalStudyHours,
        'pomodoroCompleted': pomodoroCompleted,
        'partnerMessagesSent': partnerMessagesSent,
        'dailyPetCount': dailyPetCount,
        'dailyFeedCount': dailyFeedCount,
        'dailyPetDate': dailyPetDate,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory GrowthState.fromJson(Map<String, dynamic> json) => GrowthState(
        level: (json['level'] as num?)?.toInt() ?? 1,
        experience: (json['experience'] as num?)?.toDouble() ?? 0.0,
        totalFeedCount: (json['totalFeedCount'] as num?)?.toInt() ?? 0,
        totalPetCount: (json['totalPetCount'] as num?)?.toInt() ?? 0,
        totalStudyHours: (json['totalStudyHours'] as num?)?.toDouble() ?? 0.0,
        pomodoroCompleted: (json['pomodoroCompleted'] as num?)?.toInt() ?? 0,
        partnerMessagesSent: (json['partnerMessagesSent'] as num?)?.toInt() ?? 0,
        dailyPetCount: (json['dailyPetCount'] as num?)?.toInt() ?? 0,
        dailyFeedCount: (json['dailyFeedCount'] as num?)?.toInt() ?? 0,
        dailyPetDate: (json['dailyPetDate'] as num?)?.toInt() ?? 0,
        lastUpdated: DateTime.parse(
          json['lastUpdated'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );

  /// 本地持久化
  static const _storageKey = 'growth_state';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(toJson()));
  }

  static Future<GrowthState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_storageKey);
      if (str != null && str.isNotEmpty) {
        return GrowthState.fromJson(jsonDecode(str));
      }
    } catch (_) {}
    return GrowthState.initial();
  }
}

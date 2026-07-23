import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 专注度采样点
class FocusSample {
  final int elapsedSeconds; // 学习开始后第几秒
  final double focusScore;  // 0~1

  const FocusSample({required this.elapsedSeconds, required this.focusScore});

  Map<String, dynamic> toJson() => {
        'elapsedSeconds': elapsedSeconds,
        'focusScore': focusScore,
      };

  factory FocusSample.fromJson(Map<String, dynamic> json) => FocusSample(
        elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
        focusScore: (json['focusScore'] as num).toDouble(),
      );
}

/// 单次学习记录
class StudySession {
  final String dateKey;       // yyyy-MM-dd
  final DateTime startTime;
  final DateTime? endTime;    // null=进行中
  final String mode;          // "forward" / "countdown" / "pomodoro"
  final int totalSeconds;     // 总学习秒数
  final List<FocusSample> focusCurve; // 专注度采样曲线

  const StudySession({
    required this.dateKey,
    required this.startTime,
    this.endTime,
    required this.mode,
    required this.totalSeconds,
    this.focusCurve = const [],
  });

  /// 平均专注度
  double get avgFocus {
    if (focusCurve.isEmpty) return 0.0;
    return focusCurve.map((s) => s.focusScore).reduce((a, b) => a + b) /
        focusCurve.length;
  }

  /// 最高专注度
  double get maxFocus {
    if (focusCurve.isEmpty) return 0.0;
    return focusCurve.map((s) => s.focusScore).reduce((a, b) => a > b ? a : b);
  }

  /// 深度专注时长（focusScore > 0.7 的秒数）
  int get deepFocusSeconds {
    if (focusCurve.length < 2) return 0;
    int total = 0;
    for (int i = 0; i < focusCurve.length - 1; i++) {
      if (focusCurve[i].focusScore > 0.7) {
        total += focusCurve[i + 1].elapsedSeconds - focusCurve[i].elapsedSeconds;
      }
    }
    return total;
  }

  /// 模式中文标签
  String get modeLabel {
    switch (mode) {
      case 'forward':   return '正向计时';
      case 'countdown': return '倒计时';
      case 'pomodoro':  return '番茄钟';
      default:          return mode;
    }
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'mode': mode,
        'totalSeconds': totalSeconds,
        'focusCurve': focusCurve.map((s) => s.toJson()).toList(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        dateKey: json['dateKey'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        mode: json['mode'] as String,
        totalSeconds: (json['totalSeconds'] as num).toInt(),
        focusCurve: (json['focusCurve'] as List<dynamic>?)
                ?.map((s) => FocusSample.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  StudySession copyWith({
    DateTime? endTime,
    int? totalSeconds,
    List<FocusSample>? focusCurve,
  }) {
    return StudySession(
      dateKey: dateKey,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      mode: mode,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      focusCurve: focusCurve ?? this.focusCurve,
    );
  }
}

/// 学习历史存储服务
class StudyHistoryService {
  static final StudyHistoryService _instance = StudyHistoryService._internal();
  factory StudyHistoryService() => _instance;
  StudyHistoryService._internal();

  static const _storageKey = 'study_sessions_v3';
  List<StudySession> _sessions = [];
  bool _loaded = false;

  /// 当前进行中的 session（用于实时追加专注度采样）
  StudySession? _activeSession;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _sessions = list
          .map((s) => StudySession.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey,
        jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  /// 开始一次新学习
  Future<void> startSession({
    required String dateKey,
    required DateTime startTime,
    required String mode,
  }) async {
    await _ensureLoaded();
    _activeSession = StudySession(
      dateKey: dateKey,
      startTime: startTime,
      mode: mode,
      totalSeconds: 0,
    );
  }

  /// 追加专注度采样（学习过程中实时调用）
  Future<void> appendFocusSample(FocusSample sample) async {
    if (_activeSession == null) return;
    final updated = List<FocusSample>.from(_activeSession!.focusCurve)
      ..add(sample);
    _activeSession = _activeSession!.copyWith(
      totalSeconds: sample.elapsedSeconds,
      focusCurve: updated,
    );
  }

  /// 结束当前学习
  Future<StudySession> endSession(DateTime endTime) async {
    await _ensureLoaded();
    if (_activeSession == null) {
      // fallback: 创建一个空记录
      return StudySession(
        dateKey: _todayKey(),
        startTime: endTime.subtract(const Duration(minutes: 1)),
        endTime: endTime,
        mode: 'forward',
        totalSeconds: 60,
      );
    }
    final finished = _activeSession!.copyWith(endTime: endTime);
    _sessions.add(finished);
    _activeSession = null;
    await _save();
    return finished;
  }

  /// 获取某天的所有学习记录
  Future<List<StudySession>> getDaySessions(String dateKey) async {
    await _ensureLoaded();
    return _sessions.where((s) => s.dateKey == dateKey).toList();
  }

  /// 获取某天的总学习秒数
  Future<int> getDayTotalSeconds(String dateKey) async {
    final sessions = await getDaySessions(dateKey);
    int total = 0;
    for (final s in sessions) { total += s.totalSeconds; }
    return total;
  }

  /// 获取某月的每日学习秒数 Map<yyyy-MM-dd, seconds>
  Future<Map<String, int>> getMonthData(int year, int month) async {
    await _ensureLoaded();
    final result = <String, int>{};
    for (final s in _sessions) {
      final d = s.startTime;
      if (d.year == year && d.month == month) {
        result[s.dateKey] = (result[s.dateKey] ?? 0) + s.totalSeconds;
      }
    }
    return result;
  }

  /// 获取某天的专注度曲线（合并所有段的采样）
  Future<List<FocusSample>> getDayFocusCurve(String dateKey) async {
    final sessions = await getDaySessions(dateKey);
    if (sessions.isEmpty) return [];

    // 按开始时间排序
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 计算每段的偏移量，合并为全天曲线
    final allSamples = <FocusSample>[];
    int offsetSeconds = 0;
    for (final session in sessions) {
      for (final sample in session.focusCurve) {
        allSamples.add(FocusSample(
          elapsedSeconds: offsetSeconds + sample.elapsedSeconds,
          focusScore: sample.focusScore,
        ));
      }
      offsetSeconds += session.totalSeconds;
    }
    return allSamples;
  }

  /// 连续打卡天数
  Future<int> getStreak() async {
    await _ensureLoaded();
    if (_sessions.isEmpty) return 0;

    // 收集所有有记录的日期
    final dates = _sessions.map((s) => s.dateKey).toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // 降序

    final today = _todayKey();
    int streak = 0;
    var checkDate = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dates.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (key == today) {
        // 今天还没记录，继续往前检查
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// 所有有记录的日期集合
  Future<Set<String>> getAllRecordedDates() async {
    await _ensureLoaded();
    return _sessions.map((s) => s.dateKey).toSet();
  }

  /// 清除所有记录（调试用）
  Future<void> clearAll() async {
    _sessions.clear();
    _activeSession = null;
    await _save();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

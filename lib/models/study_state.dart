import 'package:equatable/equatable.dart';

/// 计时模式
enum TimerMode {
  forward,    // 正向计时
  countdown,  // 倒向计时
  pomodoro,   // 番茄钟
}

/// 计时状态
enum TimerStatus {
  idle,       // 空闲
  running,    // 运行中
  paused,     // 暂停
  completed,  // 完成
}

/// 自习室状态
class StudyState extends Equatable {
  final TimerMode mode;
  final TimerStatus status;
  final int elapsedSeconds;      // 已用秒数
  final int targetSeconds;       // 目标秒数（倒计时/番茄钟用）
  final int focusScore;          // 专注评分 0-100
  final bool isFocused;          // 是否专注
  final int pomodoroCount;       // 完成的番茄数

  const StudyState({
    this.mode = TimerMode.forward,
    this.status = TimerStatus.idle,
    this.elapsedSeconds = 0,
    this.targetSeconds = 0,
    this.focusScore = 100,
    this.isFocused = true,
    this.pomodoroCount = 0,
  });

  StudyState copyWith({
    TimerMode? mode,
    TimerStatus? status,
    int? elapsedSeconds,
    int? targetSeconds,
    int? focusScore,
    bool? isFocused,
    int? pomodoroCount,
  }) {
    return StudyState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      focusScore: focusScore ?? this.focusScore,
      isFocused: isFocused ?? this.isFocused,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
    );
  }

  /// 格式化时间显示
  String get timeDisplay {
    final totalSeconds = mode == TimerMode.forward
        ? elapsedSeconds
        : (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 进度百分比
  double get progress {
    if (mode == TimerMode.forward || targetSeconds == 0) {
      final maxDisplay = 5999; // 99分59秒
      return (elapsedSeconds / maxDisplay).clamp(0.0, 1.0);
    } else {
      return (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
    }
  }

  /// 获取当前阶段名称
  String get phaseLabel {
    if (mode == TimerMode.pomodoro) {
      if (status == TimerStatus.completed) return '🍅 休息时间';
      if (elapsedSeconds >= targetSeconds) return '🍅 完成！';
      return '🍅 专注中';
    }
    return mode == TimerMode.forward ? '⏱ 正向计时' : '⏱ 倒计时';
  }

  @override
  List<Object?> get props => [
    mode,
    status,
    elapsedSeconds,
    targetSeconds,
    focusScore,
    isFocused,
    pomodoroCount,
  ];
}

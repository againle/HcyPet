import 'package:equatable/equatable.dart';
import '../services/study_history_service.dart';

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

/// 番茄钟阶段
enum PomodoroPhase { work, rest }

/// 自习室状态 V3
class StudyState extends Equatable {
  final TimerMode mode;
  final TimerStatus status;
  final int elapsedSeconds;
  final int targetSeconds;
  final int focusScore;          // 当前专注评分 0-100
  final bool isFocused;
  final int pomodoroCount;
  final PomodoroPhase pomodoroPhase;

  // V3: 专注度曲线（实时采样）
  final List<FocusSample> focusCurve;

  // V3: 刚刚完成的学习记录（用于成就闪卡）
  final StudySession? completedSession;

  const StudyState({
    this.mode = TimerMode.forward,
    this.status = TimerStatus.idle,
    this.elapsedSeconds = 0,
    this.targetSeconds = 0,
    this.focusScore = 100,
    this.isFocused = true,
    this.pomodoroCount = 0,
    this.pomodoroPhase = PomodoroPhase.work,
    this.focusCurve = const [],
    this.completedSession,
  });

  StudyState copyWith({
    TimerMode? mode,
    TimerStatus? status,
    int? elapsedSeconds,
    int? targetSeconds,
    int? focusScore,
    bool? isFocused,
    int? pomodoroCount,
    PomodoroPhase? pomodoroPhase,
    List<FocusSample>? focusCurve,
    StudySession? completedSession,
  }) {
    return StudyState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      focusScore: focusScore ?? this.focusScore,
      isFocused: isFocused ?? this.isFocused,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      pomodoroPhase: pomodoroPhase ?? this.pomodoroPhase,
      focusCurve: focusCurve ?? this.focusCurve,
      completedSession: completedSession ?? this.completedSession,
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
      final maxDisplay = 5999;
      return (elapsedSeconds / maxDisplay).clamp(0.0, 1.0);
    } else {
      return (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
    }
  }

  /// 目标时长显示（分钟）
  String get targetMinutesDisplay {
    if (targetSeconds <= 0) return '';
    return '${targetSeconds ~/ 60} 分钟';
  }

  /// 阶段标签
  String get phaseLabel {
    if (mode == TimerMode.pomodoro) {
      if (status == TimerStatus.completed) {
        return pomodoroPhase == PomodoroPhase.work ? '专注完成！休息一下吧' : '休息结束';
      }
      return pomodoroPhase == PomodoroPhase.work ? '专注中...' : '休息中...';
    }
    if (mode == TimerMode.countdown) {
      return '剩余 $targetMinutesDisplay';
    }
    return '已过 ${elapsedSeconds ~/ 60} 分 ${elapsedSeconds % 60} 秒';
  }

  @override
  List<Object?> get props => [
    mode, status, elapsedSeconds, targetSeconds,
    focusScore, isFocused, pomodoroCount, pomodoroPhase,
  ];
}

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/study_state.dart';

/// 自习室事件
abstract class StudyEvent {
  const StudyEvent();
}

class StudyStartEvent extends StudyEvent {
  final TimerMode mode;
  final int? durationSeconds;
  const StudyStartEvent({required this.mode, this.durationSeconds});
}

class StudyPauseEvent extends StudyEvent {}
class StudyResumeEvent extends StudyEvent {}
class StudyStopEvent extends StudyEvent {}
class StudyTickEvent extends StudyEvent {}
class StudyFocusUpdateEvent extends StudyEvent {
  final bool isFocused;
  const StudyFocusUpdateEvent(this.isFocused);
}
class StudyResetEvent extends StudyEvent {}

/// 自习室 Bloc
class StudyBloc extends Bloc<StudyEvent, StudyState> {
  Timer? _timer;
  static const _tickInterval = Duration(seconds: 1);

  // 专注检测参数
  int _focusCheckCounter = 0;

  StudyBloc() : super(const StudyState()) {
    on<StudyStartEvent>(_onStart);
    on<StudyPauseEvent>(_onPause);
    on<StudyResumeEvent>(_onResume);
    on<StudyStopEvent>(_onStop);
    on<StudyTickEvent>(_onTick);
    on<StudyFocusUpdateEvent>(_onFocusUpdate);
    on<StudyResetEvent>(_onReset);
  }

  /// 开始计时
  void _onStart(StudyStartEvent event, Emitter<StudyState> emit) {
    _timer?.cancel();

    final targetSeconds = event.durationSeconds ??
        (event.mode == TimerMode.forward ? 0 : 25 * 60);

    if (state.status == TimerStatus.paused) {
      add(StudyResumeEvent());
      return;
    }

    emit(state.copyWith(
      mode: event.mode,
      status: TimerStatus.running,
      targetSeconds: targetSeconds,
      elapsedSeconds: 0,
      isFocused: true,
      focusScore: 100,
    ));

    _startTimer();
    _focusCheckCounter = 0;
  }

  /// 暂停
  void _onPause(StudyPauseEvent event, Emitter<StudyState> emit) {
    if (state.status == TimerStatus.running) {
      _timer?.cancel();
      emit(state.copyWith(status: TimerStatus.paused));
    }
  }

  /// 恢复
  void _onResume(StudyResumeEvent event, Emitter<StudyState> emit) {
    if (state.status == TimerStatus.paused) {
      emit(state.copyWith(status: TimerStatus.running));
      _startTimer();
    }
  }

  /// 停止
  void _onStop(StudyStopEvent event, Emitter<StudyState> emit) {
    _timer?.cancel();
    emit(state.copyWith(
      status: TimerStatus.idle,
      elapsedSeconds: 0,
    ));
  }

  /// 计时器滴答
  void _onTick(StudyTickEvent event, Emitter<StudyState> emit) {
    if (state.status != TimerStatus.running) return;

    final newElapsed = state.elapsedSeconds + 1;
    bool isCompleted = false;

    if (state.mode == TimerMode.countdown || state.mode == TimerMode.pomodoro) {
      if (newElapsed >= state.targetSeconds) {
        isCompleted = true;
      }
    }

    _focusCheckCounter++;
    if (_focusCheckCounter % 10 == 0) {
      final fluctuation = (DateTime.now().millisecond % 5) - 2;
      final newScore = (state.focusScore + fluctuation).clamp(60, 100);
      final isFocused = newScore > 70;

      emit(state.copyWith(
        elapsedSeconds: isCompleted ? state.targetSeconds : newElapsed,
        focusScore: newScore,
        isFocused: isFocused,
        status: isCompleted ? TimerStatus.completed : TimerStatus.running,
      ));

      if (isCompleted) {
        _timer?.cancel();
      }
      return;
    }

    emit(state.copyWith(
      elapsedSeconds: isCompleted ? state.targetSeconds : newElapsed,
      status: isCompleted ? TimerStatus.completed : TimerStatus.running,
    ));

    if (isCompleted) {
      _timer?.cancel();
    }
  }

  /// 专注状态更新
  void _onFocusUpdate(StudyFocusUpdateEvent event, Emitter<StudyState> emit) {
    if (state.status != TimerStatus.running) return;

    int newScore = state.focusScore;
    if (!event.isFocused) {
      newScore = (state.focusScore - 5).clamp(0, 100);
    } else {
      newScore = (state.focusScore + 2).clamp(0, 100);
    }

    emit(state.copyWith(
      isFocused: event.isFocused,
      focusScore: newScore,
    ));
  }

  /// 重置
  void _onReset(StudyResetEvent event, Emitter<StudyState> emit) {
    _timer?.cancel();
    emit(const StudyState());
  }

  /// 启动计时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (timer) {
      add(StudyTickEvent());
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

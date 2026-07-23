import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/study_state.dart';
import '../services/study_history_service.dart';

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

/// V3: 视觉专注度数据（替换旧的 StudyFocusUpdateEvent）
class StudyFocusDataEvent extends StudyEvent {
  final double focusScore; // 0~1 from vision
  const StudyFocusDataEvent(this.focusScore);
}

class StudyResetEvent extends StudyEvent {}

/// 自习室 Bloc V3
class StudyBloc extends Bloc<StudyEvent, StudyState> {
  Timer? _timer;
  static const _tickInterval = Duration(seconds: 1);

  final StudyHistoryService _history = StudyHistoryService();

  // 专注度采样间隔（每15秒采样一次）
  static const _sampleInterval = 15;
  int _ticksSinceLastSample = 0;

  // 当前视觉专注度（外部注入）
  double _currentVisionFocus = 0.5;

  StudyBloc() : super(const StudyState()) {
    on<StudyStartEvent>(_onStart);
    on<StudyPauseEvent>(_onPause);
    on<StudyResumeEvent>(_onResume);
    on<StudyStopEvent>(_onStop);
    on<StudyTickEvent>(_onTick);
    on<StudyFocusDataEvent>(_onFocusData);
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

    // V3: 开始历史记录
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _history.startSession(
      dateKey: dateKey,
      startTime: now,
      mode: event.mode.name,
    );

    emit(state.copyWith(
      mode: event.mode,
      status: TimerStatus.running,
      targetSeconds: targetSeconds,
      elapsedSeconds: 0,
      isFocused: true,
      focusScore: 100,
      focusCurve: [],
      completedSession: null,
    ));

    _startTimer();
    _ticksSinceLastSample = 0;
    _currentVisionFocus = 0.5;
  }

  void _onPause(StudyPauseEvent event, Emitter<StudyState> emit) {
    if (state.status == TimerStatus.running) {
      _timer?.cancel();
      emit(state.copyWith(status: TimerStatus.paused));
    }
  }

  void _onResume(StudyResumeEvent event, Emitter<StudyState> emit) {
    if (state.status == TimerStatus.paused) {
      emit(state.copyWith(status: TimerStatus.running));
      _startTimer();
    }
  }

  /// 停止
  Future<void> _onStop(StudyStopEvent event, Emitter<StudyState> emit) async {
    _timer?.cancel();
    // V3: 结束历史记录
    final session = await _history.endSession(DateTime.now());
    emit(state.copyWith(
      status: TimerStatus.idle,
      elapsedSeconds: 0,
      completedSession: session,
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

    // V3: 专注度计算（优先使用视觉数据）
    _ticksSinceLastSample++;
    List<FocusSample> newCurve = List.from(state.focusCurve);

    if (_ticksSinceLastSample >= _sampleInterval) {
      _ticksSinceLastSample = 0;
      // 使用视觉专注度或模拟值
      final visionScore = (_currentVisionFocus * 100).clamp(0, 100);
      newCurve.add(FocusSample(
        elapsedSeconds: newElapsed,
        focusScore: _currentVisionFocus,
      ));
      // 异步保存到历史
      _history.appendFocusSample(FocusSample(
        elapsedSeconds: newElapsed,
        focusScore: _currentVisionFocus,
      ));
    }

    // 综合专注评分
    final avgCurve = newCurve.isEmpty
        ? 100
        : (newCurve.map((s) => s.focusScore * 100).reduce((a, b) => a + b) /
                newCurve.length)
            .round();

    emit(state.copyWith(
      elapsedSeconds: isCompleted ? state.targetSeconds : newElapsed,
      focusScore: avgCurve,
      isFocused: avgCurve > 50,
      focusCurve: newCurve,
      status: isCompleted ? TimerStatus.completed : TimerStatus.running,
    ));

    if (isCompleted) {
      _timer?.cancel();
    }
  }

  /// V3: 接收视觉专注度数据
  void _onFocusData(StudyFocusDataEvent event, Emitter<StudyState> emit) {
    _currentVisionFocus = event.focusScore;
    if (state.status != TimerStatus.running) return;

    emit(state.copyWith(
      isFocused: event.focusScore > 0.4,
    ));
  }

  /// 重置
  void _onReset(StudyResetEvent event, Emitter<StudyState> emit) {
    _timer?.cancel();
    emit(const StudyState());
  }

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

import 'dart:collection';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/vision_service.dart';

// ============================================================
// V3 视觉状态 — 含趋势分析
// ============================================================

/// 视觉 Bloc 状态
class VisionState {
  final bool isInitialized;
  final bool isDetecting;
  final VisionResult? lastResult;

  /// 最近 10 个结果（用于趋势分析）
  final List<VisionResult> recentResults;

  /// 趋势快照
  final double focusTrend;       // 正=专注度上升, 负=下降
  final double frustrationTrend; // 正=烦躁加剧
  final double tiredTrend;       // 正=疲劳加剧
  final int distractionStreak;   // 连续分心帧数
  final int focusStreak;         // 连续专注帧数

  final bool isEnabled;
  final String? errorMessage;

  const VisionState({
    this.isInitialized = false,
    this.isDetecting = false,
    this.lastResult,
    this.recentResults = const [],
    this.focusTrend = 0.0,
    this.frustrationTrend = 0.0,
    this.tiredTrend = 0.0,
    this.distractionStreak = 0,
    this.focusStreak = 0,
    this.isEnabled = false,
    this.errorMessage,
  });

  VisionState copyWith({
    bool? isInitialized,
    bool? isDetecting,
    VisionResult? lastResult,
    List<VisionResult>? recentResults,
    double? focusTrend,
    double? frustrationTrend,
    double? tiredTrend,
    int? distractionStreak,
    int? focusStreak,
    bool? isEnabled,
    String? errorMessage,
  }) {
    return VisionState(
      isInitialized: isInitialized ?? this.isInitialized,
      isDetecting: isDetecting ?? this.isDetecting,
      lastResult: lastResult ?? this.lastResult,
      recentResults: recentResults ?? this.recentResults,
      focusTrend: focusTrend ?? this.focusTrend,
      frustrationTrend: frustrationTrend ?? this.frustrationTrend,
      tiredTrend: tiredTrend ?? this.tiredTrend,
      distractionStreak: distractionStreak ?? this.distractionStreak,
      focusStreak: focusStreak ?? this.focusStreak,
      isEnabled: isEnabled ?? this.isEnabled,
      errorMessage: errorMessage,
    );
  }

  /// 专注度颜色（根据分数+趋势）
  String get focusStatusLabel {
    if (!isDetecting) return '未开启';
    if (lastResult == null) return '检测中...';
    final s = lastResult!.focusScore;
    if (s > 0.7) return '深度专注';
    if (s > 0.45) return '专注中';
    if (s > 0.25) return '有点走神';
    return '分心了';
  }
}

// ============================================================
// 事件
// ============================================================

abstract class VisionEvent {}

class VisionInitEvent extends VisionEvent {}
class VisionStartEvent extends VisionEvent {}
class VisionStopEvent extends VisionEvent {}
class VisionDetectedEvent extends VisionEvent {
  final VisionResult result;
  VisionDetectedEvent(this.result);
}
class VisionErrorEvent extends VisionEvent {
  final String error;
  VisionErrorEvent(this.error);
}

// ============================================================
// VisionBloc V3 — 含趋势分析
// ============================================================

class VisionBloc extends Bloc<VisionEvent, VisionState> {
  final VisionService _service = VisionService();

  static const int _trendWindow = 10; // 趋势分析窗口大小

  VisionBloc() : super(const VisionState()) {
    on<VisionInitEvent>(_onInit);
    on<VisionStartEvent>(_onStart);
    on<VisionStopEvent>(_onStop);
    on<VisionDetectedEvent>(_onDetected);
    on<VisionErrorEvent>(_onError);
  }

  Future<void> _onInit(VisionInitEvent event, Emitter<VisionState> emit) async {
    final success = await _service.initialize();
    if (success) {
      emit(state.copyWith(isInitialized: true));
    } else {
      emit(state.copyWith(
        errorMessage: '视觉追踪初始化失败',
        isEnabled: false,
      ));
    }
  }

  Future<void> _onStart(VisionStartEvent event, Emitter<VisionState> emit) async {
    if (!state.isInitialized) {
      final ok = await _service.initialize();
      if (!ok) {
        emit(state.copyWith(errorMessage: '初始化失败'));
        return;
      }
      emit(state.copyWith(isInitialized: true));
    }

    _service.onVisionResult = (result) {
      if (!isClosed) add(VisionDetectedEvent(result));
    };
    _service.onError = (error) {
      if (!isClosed) add(VisionErrorEvent(error));
    };

    final started = await _service.start();
    emit(state.copyWith(
      isEnabled: started,
      isDetecting: started,
      recentResults: [],
      errorMessage: started ? null : '摄像头启动失败',
    ));
  }

  Future<void> _onStop(VisionStopEvent event, Emitter<VisionState> emit) async {
    await _service.stop();
    emit(state.copyWith(
      isEnabled: false,
      isDetecting: false,
      lastResult: null,
      recentResults: [],
    ));
  }

  void _onDetected(VisionDetectedEvent event, Emitter<VisionState> emit) {
    final result = event.result;

    // 维护滑动窗口
    final recent = Queue<VisionResult>.from(state.recentResults);
    recent.addLast(result);
    while (recent.length > _trendWindow) {
      recent.removeFirst();
    }

    // 计算趋势
    final focusTrend = _computeTrend(
      recent.toList().map((r) => r.focusScore).toList(),
    );
    final frustrationTrend = _computeTrend(
      recent.toList().map((r) => r.emotion.frustrated).toList(),
    );
    final tiredTrend = _computeTrend(
      recent.toList().map((r) => r.emotion.tired).toList(),
    );

    // 连续计数
    int distractionStreak = state.distractionStreak;
    int focusStreak = state.focusStreak;

    if (result.focusScore < 0.25) {
      distractionStreak++;
      focusStreak = 0;
    } else if (result.focusScore > 0.45) {
      focusStreak++;
      distractionStreak = 0;
    } else {
      // 中间地带，都不重置
    }

    emit(state.copyWith(
      lastResult: result,
      recentResults: recent.toList(),
      focusTrend: focusTrend,
      frustrationTrend: frustrationTrend,
      tiredTrend: tiredTrend,
      distractionStreak: distractionStreak,
      focusStreak: focusStreak,
    ));
  }

  void _onError(VisionErrorEvent event, Emitter<VisionState> emit) {
    emit(state.copyWith(errorMessage: event.error));
  }

  /// 简单线性趋势（正=上升, 负=下降, 范围约 -1~1）
  double _computeTrend(List<double> values) {
    if (values.length < 3) return 0.0;
    // 前半段 vs 后半段均值差
    final mid = values.length ~/ 2;
    final firstHalf = values.sublist(0, mid);
    final secondHalf = values.sublist(mid);
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    return (secondAvg - firstAvg).clamp(-1.0, 1.0);
  }

  @override
  Future<void> close() {
    _service.onVisionResult = null;
    _service.onError = null;
    _service.dispose();
    return super.close();
  }
}

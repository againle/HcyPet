import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/vision_service.dart';

/// 视觉状态
class VisionState {
  final bool isInitialized;
  final bool isDetecting;
  final EmotionResult? lastResult;
  final bool isEnabled;
  final String? errorMessage;

  const VisionState({
    this.isInitialized = false,
    this.isDetecting = false,
    this.lastResult,
    this.isEnabled = false,
    this.errorMessage,
  });

  VisionState copyWith({
    bool? isInitialized,
    bool? isDetecting,
    EmotionResult? lastResult,
    bool? isEnabled,
    String? errorMessage,
  }) {
    return VisionState(
      isInitialized: isInitialized ?? this.isInitialized,
      isDetecting: isDetecting ?? this.isDetecting,
      lastResult: lastResult ?? this.lastResult,
      isEnabled: isEnabled ?? this.isEnabled,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 视觉事件
abstract class VisionEvent {}

class VisionInitEvent extends VisionEvent {}
class VisionStartEvent extends VisionEvent {}
class VisionStopEvent extends VisionEvent {}
class VisionDetectedEvent extends VisionEvent {
  final EmotionResult result;
  VisionDetectedEvent(this.result);
}
class VisionErrorEvent extends VisionEvent {
  final String error;
  VisionErrorEvent(this.error);
}

/// 视觉 Bloc
class VisionBloc extends Bloc<VisionEvent, VisionState> {
  final VisionService _service = VisionService();

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
    // 确保已初始化
    if (!state.isInitialized) {
      final ok = await _service.initialize();
      if (!ok) {
        emit(state.copyWith(errorMessage: '初始化失败'));
        return;
      }
      emit(state.copyWith(isInitialized: true));
    }

    _service.onEmotionDetected = (result) {
      if (!isClosed) add(VisionDetectedEvent(result));
    };
    _service.onError = (error) {
      if (!isClosed) add(VisionErrorEvent(error));
    };

    final started = await _service.start();
    emit(state.copyWith(
      isEnabled: started,
      isDetecting: started,
      errorMessage: started ? null : '摄像头启动失败',
    ));
  }

  Future<void> _onStop(VisionStopEvent event, Emitter<VisionState> emit) async {
    await _service.stop();
    emit(state.copyWith(
      isEnabled: false,
      isDetecting: false,
      lastResult: null,
    ));
  }

  void _onDetected(VisionDetectedEvent event, Emitter<VisionState> emit) {
    emit(state.copyWith(lastResult: event.result));
  }

  void _onError(VisionErrorEvent event, Emitter<VisionState> emit) {
    emit(state.copyWith(errorMessage: event.error));
  }

  @override
  Future<void> close() {
    _service.onEmotionDetected = null;
    _service.onError = null;
    _service.dispose();
    return super.close();
  }
}

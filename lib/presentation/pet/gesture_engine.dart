import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ============================================================
/// 🍡 Mochi V3 — 7 种手势识别引擎
/// ============================================================
///
/// 封装全触屏交互检测，包括：
///   - 单指长按 (1.5s) → onLongPress
///   - 快速连击 (3s 内 >5 次) → onMultiTap
///   - 单指滑动 (抚摸) → onPanUpdate / onPanEnd
///   - 双击 → onDoubleTap
///   - 捏合 (双指) → onPinchUpdate / onPinchEnd
///   - 拖拽扔出 → onDragThrow
///   - 单指点击 → onTap
///
/// 用法：
/// ```dart
/// GestureEngine(
///   child: petWidget,
///   onLongPressStart: () => ...,
///   onMultiTap: () => ...,
///   ...
/// )
/// ```
///

/// 手势识别结果
class GestureResult {
  final GestureType type;
  final Offset? position;         // 触摸位置
  final Offset? delta;             // 滑动/拖拽增量
  final double? scale;             // 捏合比例
  final Offset? velocity;          // 拖拽释放速度
  final int tapCount;              // 连击次数

  const GestureResult({
    required this.type,
    this.position,
    this.delta,
    this.scale,
    this.velocity,
    this.tapCount = 0,
  });
}

enum GestureType {
  tap,
  doubleTap,
  longPressStart,
  longPressEnd,
  multiTap,       // 5+ 连击
  pan,            // 滑动抚摸
  dragThrow,      // 拖拽扔出
  pinch,          // 捏合
  shake,          // 摇晃（传感器触发）
}

/// 手势引擎 Widget
///
/// 包装宠物组件，自动识别所有手势并回调。
class GestureEngine extends StatefulWidget {
  final Widget child;
  final double longPressDuration; // 秒（默认 1.5）
  final int multiTapCount;        // 连击阈值（默认 5）
  final double multiTapWindow;    // 连击时间窗（默认 3.0 秒）

  // ── 回调 ──
  final void Function(GestureResult result)? onGesture;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onMultiTap;
  final void Function(Offset delta)? onPanUpdate;
  final void Function(Offset velocity)? onPanEnd;
  final void Function(double scale)? onPinchUpdate;
  final void Function()? onPinchEnd;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;
  final void Function(Offset velocity)? onDragThrow;

  const GestureEngine({
    super.key,
    required this.child,
    this.longPressDuration = 1.5,
    this.multiTapCount = 5,
    this.multiTapWindow = 3.0,
    this.onGesture,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onMultiTap,
    this.onPanUpdate,
    this.onPanEnd,
    this.onDoubleTap,
    this.onTap,
    this.onPinchUpdate,
    this.onPinchEnd,
    this.onDragThrow,
  });

  @override
  State<GestureEngine> createState() => _GestureEngineState();
}

class _GestureEngineState extends State<GestureEngine> {
  // ── 长按检测 ──
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  bool _longPressFired = false;

  // ── 连击检测 ──
  final List<DateTime> _tapTimestamps = [];
  Timer? _multiTapResetTimer;
  bool _multiTapFired = false;

  // ── 拖拽物理 ──
  Offset? _dragStart;
  Offset? _lastDragPosition;
  DateTime? _lastDragTime;

  // ── 捏合 ──
  double _initialPinchDistance = 0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _multiTapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }

  // ================================================================
  // 原始指针事件（用于长按 + 拖拽）
  // ================================================================

  void _onPointerDown(PointerDownEvent event) {
    _dragStart = event.position;
    _lastDragPosition = event.position;
    _lastDragTime = DateTime.now();
    _longPressFired = false;

    // 启动长按定时器
    _longPressTimer?.cancel();
    _longPressTimer = Timer(Duration(milliseconds: (widget.longPressDuration * 1000).round()), () {
      if (!_longPressFired && mounted) {
        _longPressFired = true;
        _isLongPressing = true;
        HapticFeedback.mediumImpact();
        widget.onLongPressStart?.call();
        widget.onGesture?.call(const GestureResult(type: GestureType.longPressStart));
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final now = DateTime.now();
    final delta = event.position - (_lastDragPosition ?? event.position);
    _lastDragPosition = event.position;
    _lastDragTime = now;

    // 如果移动距离超过阈值，取消长按
    if (_dragStart != null) {
      final distance = (event.position - _dragStart!).distance;
      if (distance > 12 && !_longPressFired) {
        _longPressTimer?.cancel();
      }
    }

    if (_isLongPressing) {
      // 长按中：持续抚摸效果
      widget.onPanUpdate?.call(delta);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();

    if (_isLongPressing) {
      _isLongPressing = false;
      widget.onLongPressEnd?.call();
      widget.onGesture?.call(const GestureResult(type: GestureType.longPressEnd));
    }

    // 拖拽扔出检测
    if (_dragStart != null && !_longPressFired) {
      final totalDelta = event.position - _dragStart!;
      final totalDistance = totalDelta.distance;
      if (totalDistance > 30) {
        // 有意义的拖拽 → 计算释放速度
        final now = DateTime.now();
        final dt = now.difference(_lastDragTime ?? now).inMilliseconds / 1000.0;
        final velocity = dt > 0 ? totalDelta / dt : Offset.zero;
        widget.onDragThrow?.call(velocity);
        widget.onGesture?.call(GestureResult(
          type: GestureType.dragThrow,
          velocity: velocity,
        ));
      }
    }

    _dragStart = null;
    _lastDragPosition = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _isLongPressing = false;
    _dragStart = null;
  }

  // ================================================================
  // GestureDetector 高级手势
  // ================================================================

  void _handleTap() {
    // 记录连击时间戳
    final now = DateTime.now();
    _tapTimestamps.add(now);

    // 清理过期的时间戳
    _tapTimestamps.removeWhere(
      (t) => now.difference(t).inMilliseconds > (widget.multiTapWindow * 1000),
    );

    // 检查是否达到连击阈值
    if (_tapTimestamps.length >= widget.multiTapCount && !_multiTapFired) {
      _multiTapFired = true;
      HapticFeedback.heavyImpact();
      widget.onMultiTap?.call();
      widget.onGesture?.call(GestureResult(
        type: GestureType.multiTap,
        tapCount: _tapTimestamps.length,
      ));

      // 重置连击检测
      _multiTapResetTimer?.cancel();
      _multiTapResetTimer = Timer(Duration(seconds: widget.multiTapWindow.round()), () {
        _multiTapFired = false;
        _tapTimestamps.clear();
      });
    }

    widget.onTap?.call();
    widget.onGesture?.call(const GestureResult(type: GestureType.tap));
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    widget.onDoubleTap?.call();
    widget.onGesture?.call(const GestureResult(type: GestureType.doubleTap));
  }

  // ── 捏合/缩放 ──

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      _initialPinchDistance = 100.0;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 && _initialPinchDistance > 0) {
      final scale = details.scale;

      HapticFeedback.selectionClick();
      widget.onPinchUpdate?.call(scale);
      widget.onGesture?.call(GestureResult(
        type: GestureType.pinch,
        scale: scale,
      ));
    } else if (details.pointerCount == 1) {
      // 单指滑动（抚摸）
      widget.onPanUpdate?.call(details.focalPointDelta);
      widget.onGesture?.call(GestureResult(
        type: GestureType.pan,
        delta: details.focalPointDelta,
        position: details.focalPoint,
      ));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_initialPinchDistance > 0) {
      widget.onPinchEnd?.call();
      _initialPinchDistance = 0;
    } else {
      widget.onPanEnd?.call(details.velocity.pixelsPerSecond);
    }
  }
}

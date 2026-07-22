import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/pet_state.dart';
import '../../theme/design_constants.dart';
import 'idle_behavior_scheduler.dart';
import 'pet_painter.dart';

/// 宠物组件 — V2 双轨动画系统（空闲行为 + 情绪过渡 + 呼吸）
class PetWidget extends StatefulWidget {
  final PetState state;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(DragUpdateDetails)? onPanUpdate;

  const PetWidget({
    super.key,
    required this.state,
    this.size = 200,
    this.onTap,
    this.onDoubleTap,
    this.onPanUpdate,
  });

  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget>
    with TickerProviderStateMixin {
  // 呼吸动画
  late AnimationController _breathController;

  // 情绪过渡动画
  AnimationController? _moodTransitionController;
  PetMood? _previousMood;

  // 空闲行为调度器
  final IdleBehaviorScheduler _idleScheduler = IdleBehaviorScheduler();
  Ticker? _idleTicker;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _idleScheduler.reset();
    _startIdleTicker();
  }

  void _startIdleTicker() {
    _idleTicker = createTicker((elapsed) {
      _idleScheduler.update(
        (elapsed.inMicroseconds - (_lastIdleElapsed?.inMicroseconds ?? elapsed.inMicroseconds)) / 1000000.0,
      );
      _lastIdleElapsed = elapsed;
      if (mounted) setState(() {}); // 触发重绘以更新空闲动画
    });
    _idleTicker?.start();
  }

  Duration? _lastIdleElapsed;

  @override
  void didUpdateWidget(covariant PetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测情绪变化 → 触发过渡动画
    if (oldWidget.state.mood != widget.state.mood) {
      _previousMood = oldWidget.state.mood;
      _moodTransitionController?.dispose();
      _moodTransitionController = AnimationController(
        vsync: this,
        duration: AnimDuration.moodTransition,
      );
      _moodTransitionController!.forward(from: 0.0).then((_) {
        if (mounted) {
          _previousMood = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _idleTicker?.stop();
    _idleTicker?.dispose();
    _breathController.dispose();
    _moodTransitionController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodProgress = _moodTransitionController?.value ?? 1.0;
    final breathScale = PetSize.breathScaleMin +
        _breathController.value *
            (PetSize.breathScaleMax - PetSize.breathScaleMin);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onPanUpdate: widget.onPanUpdate,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathController,
          if (_moodTransitionController != null) _moodTransitionController!,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: breathScale,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: PetPainter(
                state: widget.state,
                size: widget.size,
                previousMood: _previousMood,
                transitionProgress: moodProgress,
                idleBehavior: _idleScheduler.current,
              ),
            ),
          );
        },
      ),
    );
  }
}

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";
import "../../models/pet_state.dart";
import "../../theme/design_constants.dart";
import "idle_behavior_scheduler.dart";
import "mochi_physics.dart";
import "pet_painter.dart";

class PetWidget extends StatefulWidget {
  final PetState state;
  final double size;
  final VoidCallback? onTap, onDoubleTap, onLongPressStart, onLongPressEnd, onMultiTap;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final void Function(DragEndDetails)? onPanEnd;
  final void Function(double)? onPinchUpdate;
  const PetWidget({super.key, required this.state, this.size = 280, this.onTap, this.onDoubleTap, this.onLongPressStart, this.onLongPressEnd, this.onMultiTap, this.onPanUpdate, this.onPanEnd, this.onPinchUpdate});
  @override
  State<PetWidget> createState() => PetWidgetState();
}

class PetWidgetState extends State<PetWidget> with TickerProviderStateMixin {
  final PhysicsTracker _eye = PhysicsTracker(spring: MochiSpring.gentle, initialPosition: 1.0, target: 1.0);
  final PhysicsTracker _blush = PhysicsTracker(spring: MochiSpring.gentle);
  final PhysicsTracker _sq = PhysicsTracker(spring: MochiSpring.bounce);
  final IdleBehaviorScheduler _idl = IdleBehaviorScheduler();
  Ticker? _tk;
  Duration? _lt;
  MochiExpression _tgt = MochiExpression.calm;
  PetMood? _lm;
  double _ps = 1.0;

  @override
  void initState() {
    super.initState();
    _lm = widget.state.mood;
    _tgt = _m2e(widget.state.mood);
    _eye..setTarget(_tgt.eyelidOpen)..snap();
    _blush..setTarget(_tgt.blushOpacity)..snap();
    _idl.setBaseExpression(_tgt); _idl.reset();
    _startTk();
  }

  @override
  void didUpdateWidget(covariant PetWidget ow) {
    super.didUpdateWidget(ow);
    if (ow.state.mood != widget.state.mood) {
      _lm = widget.state.mood;
      _tgt = _m2e(widget.state.mood);
      _idl.setBaseExpression(_tgt);
      _eye.setTarget(_tgt.eyelidOpen);
      _blush.setTarget(_tgt.blushOpacity);
    }
  }

  @override
  void dispose() { _tk?.stop(); _tk?.dispose(); super.dispose(); }

  void _startTk() { _tk = createTicker((e) { final dt = _lt != null ? (e.inMicroseconds - _lt!.inMicroseconds) / 1000000.0 : 0.016; _lt = e; _tick(dt.clamp(0.001, 0.1)); }); _tk!.start(); }

  void _tick(double dt) {
    _eye.update(dt); _blush.update(dt); _sq.update(dt);
    _idl.setEnergy(widget.state.energy);
    _idl.setIsCalm(widget.state.mood == PetMood.calm);
    _idl.update(dt);
    if (mounted) setState(() {});
  }

  MochiExpression _m2e(PetMood m) => switch (m) {
    PetMood.happy => MochiExpression.happy, PetMood.calm => MochiExpression.calm,
    PetMood.surprised => MochiExpression.surprised, PetMood.sad => MochiExpression.sad,
    PetMood.sleepy => MochiExpression.sleepy, PetMood.missing => MochiExpression.missing,
  };

  void triggerHappyBounce() { _blush.setTarget(0.45, initialVelocity: 0.3); _eye.setTarget(0.5, initialVelocity: 0.3); HapticFeedback.lightImpact(); }
  void triggerStartle() { _eye.setTarget(1.0, initialVelocity: 0.5); HapticFeedback.heavyImpact(); }
  void applySquash(double a) => _sq.setTarget(a.clamp(-1.0, 1.0));
  void releaseSquash() { _sq.setTarget(0.0); HapticFeedback.mediumImpact(); }
  void setPinchScale(double s) { _ps = s.clamp(0.6, 1.4); if (mounted) setState(() {}); }
  void resetPinchScale() { _ps = 1.0; if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext ctx) {
    final idleE = _idl.getCurrentExpression();
    // 连续混合：跟踪器越接近目标，idleE 权重越高
    final eyeBlend = _eye.settled ? 1.0 : _blendFactor(_eye.position, _tgt.eyelidOpen);
    final blushBlend = _blush.settled ? 1.0 : _blendFactor(_blush.position, _tgt.blushOpacity);
    final blend = (eyeBlend + blushBlend) / 2.0;
    final finalE = MochiExpression(
      eyelidOpen: _lerp(_eye.position, idleE.eyelidOpen, blend),
      blushOpacity: _lerp(_blush.position, idleE.blushOpacity, blend),
      eyeShiftX: idleE.eyeShiftX,
    );
    final ps = widget.state;
    return Transform.scale(scale: _ps, child: CustomPaint(
      size: Size(widget.size, widget.size),
      painter: PetPainter(expression: finalE, size: widget.size,
        isSleeping: ps.activity == PetActivity.sleeping,
        showHearts: ps.mood == PetMood.missing,
        showZzz: ps.mood == PetMood.sleepy && ps.activity != PetActivity.sleeping,
        surpriseMouth: ps.mood == PetMood.surprised,
        squashStretch: _sq.position, allowArc: blend > 0.85),
    ));
  }

  /// 连续混合系数：当前值离目标越近越接近 1.0
  double _blendFactor(double current, double target) {
    if (target == current) return 1.0;
    final dist = (current - target).abs();
    // 距离 < 0.05 时开始混合，< 0.01 时接近完全混合
    return (1.0 - (dist / 0.05)).clamp(0.0, 1.0);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

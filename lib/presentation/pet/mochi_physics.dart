import "package:flutter/physics.dart";

class MochiSpring {
  MochiSpring._();
  static const bouncy = SpringDescription(mass: 1.0, stiffness: 180.0, damping: 15.0);
  static const gentle = SpringDescription(mass: 1.0, stiffness: 100.0, damping: 22.0);
  static const quick  = SpringDescription(mass: 1.0, stiffness: 300.0, damping: 34.0);
  static const wobble = SpringDescription(mass: 2.0, stiffness: 60.0, damping: 6.0);
  static const bounce = SpringDescription(mass: 3.0, stiffness: 120.0, damping: 8.0);
}

class MochiExpression {
  final double eyelidOpen;
  final double blushOpacity;
  final double eyeShiftX;
  const MochiExpression({this.eyelidOpen = 1.0, this.blushOpacity = 0.0, this.eyeShiftX = 0.0});
  static const calm     = MochiExpression();
  static const happy    = MochiExpression(eyelidOpen: 0.55, blushOpacity: 0.4);
  static const surprised = MochiExpression(eyelidOpen: 1.0);
  static const sad      = MochiExpression(eyelidOpen: 0.15);
  static const sleepy   = MochiExpression(eyelidOpen: 0.25);
  static const missing  = MochiExpression(eyelidOpen: 1.0, blushOpacity: 0.12);
  static const sleeping = MochiExpression(eyelidOpen: 0.0);
  MochiExpression lerp(MochiExpression o, double t) => MochiExpression(
    eyelidOpen: eyelidOpen + (o.eyelidOpen - eyelidOpen) * t,
    blushOpacity: blushOpacity + (o.blushOpacity - blushOpacity) * t,
    eyeShiftX: eyeShiftX + (o.eyeShiftX - eyeShiftX) * t,
  );
}

class PhysicsTracker {
  final SpringDescription spring;
  double _p, _v = 0, _t = 0;
  bool _s = true;
  PhysicsTracker({required this.spring, double initialPosition = 0.0, double target = 0.0}) : _p = initialPosition, _t = target;
  double get position => _p;
  bool get settled => _s;
  void setTarget(double t, {double initialVelocity = 0.0}) { _t = t; _v = initialVelocity; _s = false; }
  void update(double dt) {
    if (_s) return;
    final f = -spring.stiffness * (_p - _t) - spring.damping * _v;
    _v += f / spring.mass * dt;
    _p += _v * dt;
    if ((_p - _t).abs() < 0.0005 && _v.abs() < 0.001) { _p = _t; _v = 0; _s = true; }
  }
  void snap() { _p = _t; _v = 0; _s = true; }
}

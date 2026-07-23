import "dart:math";
import "mochi_physics.dart";

enum MicroState { idle, blinkQuick, lookLeft, lookRight, yawn }

class MicroDelta {
  final double eyelidDelta, blushDelta, eyeShiftDelta;
  const MicroDelta({this.eyelidDelta = 0.0, this.blushDelta = 0.0, this.eyeShiftDelta = 0.0});
  static const zero = MicroDelta();
  MochiExpression applyTo(MochiExpression b) => MochiExpression(
    eyelidOpen: (b.eyelidOpen + eyelidDelta).clamp(0.0, 1.0),
    blushOpacity: (b.blushOpacity + blushDelta).clamp(0.0, 1.0),
    eyeShiftX: (b.eyeShiftX + eyeShiftDelta).clamp(-1.0, 1.0),
  );
}

class IdleBehaviorScheduler {
  final Random _r = Random();
  MicroState _st = MicroState.idle;
  double _elapsed = 0, _duration = 0, _breath = 0;
  MochiExpression _base = MochiExpression.calm;
  double _energy = 0.8;
  bool _isCalm = true;
  double _smoothShift = 0; // 平滑眼平移（指数衰减回中）
  double _boost = 1.0;     // V4: AI 动作频率倍率 (0.5~2.0)

  static const _cfg = {
    MicroState.idle: (1.0, 3.5), MicroState.blinkQuick: (0.12, 0.18),
    MicroState.lookLeft: (1.1, 2.5), MicroState.lookRight: (1.1, 2.5),
    MicroState.yawn: (1.0, 2.0),
  };
  static const _baseTr = {
    MicroState.idle: {MicroState.blinkQuick: 48, MicroState.lookLeft: 12, MicroState.lookRight: 12, MicroState.yawn: 3},
    MicroState.blinkQuick: {MicroState.idle: 100},
    MicroState.lookLeft: {MicroState.idle: 100}, MicroState.lookRight: {MicroState.idle: 100},
    MicroState.yawn: {MicroState.idle: 100},
  };
  static const _baseIdleW = 40;

  MicroState get currentState => _st;
  double get stateProgress => _duration > 0 ? (_elapsed / _duration).clamp(0.0, 1.0) : 0.0;
  void setBaseExpression(MochiExpression e) { _base = e; }
  void setEnergy(double e) { _energy = e.clamp(0.0, 1.0); }
  void setIsCalm(bool calm) { _isCalm = calm; }
  /// V4: 设置 AI 动作频率倍率（影响空闲动作间隔）
  void setActionBoost(double boost) { _boost = boost.clamp(0.5, 2.0); }

  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _duration) _transition();
    _breath += dt * 0.55; // 更快的呼吸节奏
    if (_breath > 1.0) _breath -= 1.0;
  }

  MochiExpression getCurrentExpression() {
    final d = _compute();
    var e = d.applyTo(_base);
    // 指数平滑眼平移（丝滑出+回）
    _smoothShift += (e.eyeShiftX - _smoothShift) * 0.12; // 更慢更丝滑
    if ((e.eyeShiftX - _smoothShift).abs() < 0.002) _smoothShift = e.eyeShiftX;
    e = MochiExpression(eyelidOpen: e.eyelidOpen, blushOpacity: e.blushOpacity, eyeShiftX: _smoothShift);
    // 微笑不呼吸；其他表情叠加呼吸
    final isHappy = _base.eyelidOpen > 0.35 && _base.eyelidOpen < 0.75;
    if (_st == MicroState.idle && !isHappy) {
      final bv = 1.0 + sin(_breath * 2 * pi) * 0.12; // 柔和呼吸
      e = MochiExpression(eyelidOpen: (e.eyelidOpen * bv).clamp(0.0, 1.0), blushOpacity: e.blushOpacity, eyeShiftX: e.eyeShiftX);
    }
    return e;
  }

  void reset() { _st = MicroState.idle; _elapsed = 0; _breath = 0; _smoothShift = 0; _schedule(MicroState.idle); }

  void _transition() {
    final c = _baseTr[_st];
    if (c == null) { _schedule(MicroState.idle); return; }
    if (_st == MicroState.idle) {
      final eMul = (_energy - 0.5).clamp(0.0, 1.0); // 0→1
      final lookBonus = (eMul * 12).round();
      final idleW = _baseIdleW - (eMul * 8).round();
      final tr = Map<MicroState, int>.from(c);
      if (_isCalm) {
        tr[MicroState.lookLeft] = (tr[MicroState.lookLeft] ?? 12) + lookBonus;
        tr[MicroState.lookRight] = (tr[MicroState.lookRight] ?? 12) + lookBonus;
      } else {
        tr.remove(MicroState.lookLeft);
        tr.remove(MicroState.lookRight);
      }

      final tw = idleW + tr.values.fold<int>(0, (a, b) => a + b);
      var r = _r.nextInt(tw);
      if (r < idleW) { _schedule(MicroState.idle); return; }
      r -= idleW;
      for (final e in tr.entries) { r -= e.value; if (r < 0) { _schedule(e.key); return; } }
      _schedule(MicroState.idle);
    } else { _schedule(MicroState.idle); }
  }

  void _schedule(MicroState s) {
    _st = s;
    _elapsed = 0;
    final cfg = _cfg[s]!;
    // V4: boost 倍率影响持续时间（boost>1 → 更短间隔 → 更活泼）
    final scale = 1.0 / _boost;
    _duration = (cfg.$1 + _r.nextDouble() * (cfg.$2 - cfg.$1)) * scale;
  }

  MicroDelta _compute() {
    final p = stateProgress;
    switch (_st) {
      case MicroState.idle: return MicroDelta.zero;
      case MicroState.blinkQuick: return _blink(p);
      case MicroState.lookLeft: return MicroDelta(eyeShiftDelta: -_lookCurve(p) * 1.5, eyelidDelta: -0.04 * _sc(p));
      case MicroState.lookRight: return MicroDelta(eyeShiftDelta: _lookCurve(p) * 1.5, eyelidDelta: -0.04 * _sc(p));
      case MicroState.yawn: return _yawn(p);
    }
  }

  MicroDelta _blink(double p) {
    double c;
    if (p < 0.2) c = p / 0.2; else if (p < 0.6) c = 1.0; else c = 1.0 - (p - 0.6) / 0.4;
    return MicroDelta(eyelidDelta: -c);
  }

  MicroDelta _yawn(double p) {
    double ec; if (p < 0.25) ec = p / 0.25 * 0.7; else if (p < 0.6) ec = 0.7; else { final r = (p - 0.6) / 0.4; ec = 0.7 * (1.0 - r); }
    return MicroDelta(eyelidDelta: -ec);
  }

  static double _sc(double t) => (sin((t - 0.5) * pi) + 1) / 2;
  /// 张望曲线：0→0.25 滑出, 0.25→0.75 停留, 0.75→1 滑回
  static double _lookCurve(double t) {
    if (t < 0.25) return t / 0.25;
    if (t < 0.75) return 1.0;
    return 1.0 - (t - 0.75) / 0.25;
  }
}

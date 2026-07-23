import "dart:math";
import "vision_service.dart";

/// 视觉滤波：专注优先，烦躁需确凿证据才上报
class VisionFilter {
  double _sf = 0.6, _sc = 0.6, _sfc = 0.6, _sfr = 0.0, _sb = 0.0, _sh = 0.0, _sa = 0.0, _st = 0.0;
  static const _aFast = 0.12; // focus/calm 正常速度
  static const _aSlow = 0.04; // frustrated 很难涨
  double _inertia = 0.5; int _hf = 0; int _ff = 0;
  static const _ft = 0.55; static const _ffc = 240; // 需 ~4 秒
  DateTime? _ss; bool _init = false; late VisionResult _last;

  VisionResult process(VisionResult r, {bool isTouching = false, bool isStudying = false}) {
    if (!_init) {
      _init = true;
      _sf = max(r.focusScore, 0.5); // 起始不低于 50
      _sc = r.emotion.calm; _sfc = r.emotion.focused;
      _sfr = 0; _sb = 0; _sh = 0; _sa = 0; _st = 0; // 负面情绪从 0 开始
      _last = _build(r, _sf);
      return _last;
    }
    if ((r.focusScore - _sf).abs() < 0.03 && r.emotion.dominantIntensity < 0.5) return _last;

    _sf = _ef(_sf, r.focusScore); _sc = _ef(_sc, r.emotion.calm); _sfc = _ef(_sfc, r.emotion.focused);
    _sfr = _es(_sfr, r.emotion.frustrated); // 慢涨快跌
    _sb = _es(_sb, r.emotion.bored); _sh = _ef(_sh, r.emotion.happy);
    _sa = _es(_sa, r.emotion.anxious); _st = _es(_st, r.emotion.tired);

    if (_sf > 0.65) { _hf = min(_hf + 1, 300); } else if (_sf < 0.45) { _hf = max(_hf - 2, 0); }
    _inertia = (_hf / 150).clamp(0.0, 1.0);
    var ef = _sf; if (_inertia > 0.5) ef += (_inertia * 0.25).clamp(0.0, 1 - _sf);
    if (isStudying && r.scene == StudyScene.noFace) ef = max(ef, 0.60);

    var de = EmotionSpectrum(calm: _sc, focused: _sfc, frustrated: _sfr, bored: _sb, happy: _sh, anxious: _sa, tired: _st).dominantEmotion;
    if (de == "frustrated") { _ff++; } else { _ff = max(_ff - 5, 0); }
    if (_ff < _ffc) de = "focused"; // 未确认 → 强制专注
    if (isTouching && _inertia > 0.3) de = "focused";

    if (isStudying) { _ss ??= DateTime.now(); if (DateTime.now().difference(_ss!).inMinutes > 50) ef = (ef * 1.15).clamp(0.0, 1.0); } else { _ss = null; }

    final confirmed = _ff > _ffc;
    _last = _build(r, ef, confirmed ? _sfr : _sfr * 0.1, de);
    return _last;
  }

  VisionResult _build(VisionResult r, double ef, [double fr = 0, String de = "focused"]) {
    return VisionResult(scene: r.scene, focusScore: ef.clamp(0.0, 1.0),
      emotion: EmotionSpectrum(calm: _sc, focused: _sfc, frustrated: fr, bored: _sb * 0.1, happy: _sh, anxious: _sa * 0.1, tired: _st * 0.1),
      isStudying: r.isStudying, timestamp: DateTime.now());
  }

  double _ef(double p, double c) => _aFast * c + (1 - _aFast) * p;
  double _es(double p, double c) => c > p ? _aSlow * c + (1 - _aSlow) * p : _aFast * c + (1 - _aFast) * p; // 慢涨快跌
  void reset() { _init = false; _hf = 0; _ff = 0; _ss = null; }
}

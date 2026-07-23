import "dart:math";
import "vision_service.dart";

class VisionFilter {
  double _sf = 0.6, _sc = 0.6, _sfc = 0.6, _sfr = 0.0, _sb = 0.0, _sh = 0.0, _sa = 0.0, _st = 0.0;
  static const _a = 0.10;
  double _inertia = 0.5; int _hf = 0; int _ff = 0;
  static const _ft = 0.55; static const _ffc = 180;
  DateTime? _ss; bool _init = false; late VisionResult _last;

  VisionResult process(VisionResult r, {bool isTouching = false, bool isStudying = false}) {
    if (!_init) { _sf = r.focusScore; _sc = r.emotion.calm; _sfc = r.emotion.focused; _init = true; _last = r; return r; }
    if ((r.focusScore - _sf).abs() < 0.03 && r.emotion.dominantIntensity < 0.5) return _last;
    _sf = _e(_sf, r.focusScore); _sc = _e(_sc, r.emotion.calm); _sfc = _e(_sfc, r.emotion.focused);
    _sfr = _e(_sfr, r.emotion.frustrated); _sb = _e(_sb, r.emotion.bored);
    _sh = _e(_sh, r.emotion.happy); _sa = _e(_sa, r.emotion.anxious); _st = _e(_st, r.emotion.tired);
    if (_sf > 0.65) { _hf = min(_hf + 1, 300); } else if (_sf < 0.45) { _hf = max(_hf - 2, 0); }
    _inertia = (_hf / 150).clamp(0.0, 1.0);
    var ef = _sf; if (_inertia > 0.5) ef = _sf + (_inertia * 0.25).clamp(0.0, 1 - _sf);
    if (isStudying && r.scene == StudyScene.noFace) ef = max(ef, 0.60);
    var de = EmotionSpectrum(calm: _sc, focused: _sfc, frustrated: _sfr, bored: _sb, happy: _sh, anxious: _sa, tired: _st).dominantEmotion;
    if (_sfr > _ft && de == "frustrated") { _ff++; } else { _ff = max(_ff - 3, 0); }
    if (_ff < _ffc && de == "frustrated") de = "focused";
    if (de == "frustrated" && isTouching && _inertia > 0.3) de = "focused";
    if (isStudying) { _ss ??= DateTime.now(); if (DateTime.now().difference(_ss!).inMinutes > 50) ef = (ef * 1.15).clamp(0.0, 1.0); } else { _ss = null; }
    _last = VisionResult(scene: r.scene, focusScore: ef.clamp(0.0, 1.0), emotion: EmotionSpectrum(calm: _sc, focused: _sfc, frustrated: _ff > _ffc ? _sfr : _sfr * 0.2, bored: _sb, happy: _sh, anxious: _sa, tired: _st), isStudying: r.isStudying, timestamp: DateTime.now());
    return _last;
  }
  double _e(double p, double c) => _a * c + (1 - _a) * p;
  void reset() { _init = false; _hf = 0; _ff = 0; _ss = null; }
}

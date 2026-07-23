import 'dart:math';
import 'vision_service.dart';

/// ============================================================
/// V3 视觉滤波 — 深度平滑 + 专注优先 + 抗抖动
/// ============================================================
///
/// 设计理念：专注是常态，分心是例外。
/// 用户专注时不看屏幕 = 高专注度，而非"检测不到"。
///

class VisionFilter {
  double _smoothFocus = 0.5;
  double _smoothCalm = 0.5;
  double _smoothFocused = 0.5;
  double _smoothFrustrated = 0.0;
  double _smoothBored = 0.0;
  double _smoothHappy = 0.0;
  double _smoothAnxious = 0.0;
  double _smoothTired = 0.0;

  static const _alpha = 0.12; // 深度平滑（越低越稳）

  // 专注惯性：一旦建立高专注，不容易掉
  double _focusInertia = 0.5; // 0=无惯性, 1=完全锁定
  int _highFocusFrames = 0;

  // 烦躁需持续确认
  int _frustratedFrames = 0;
  static const _frustratedThreshold = 0.50; // 更高阈值
  static const _frustratedConfirmFrames = 120; // 需持续 ~2 秒（60fps）

  DateTime? _studyStart;
  bool _initialized = false;
  late VisionResult _last;

  VisionResult process(
    VisionResult raw, {
    bool isTouching = false,
    bool isStudying = false,
  }) {
    if (!_initialized) {
      _smoothFocus = raw.focusScore;
      _smoothCalm = raw.emotion.calm;
      _smoothFocused = raw.emotion.focused;
      _smoothFrustrated = raw.emotion.frustrated;
      _smoothBored = raw.emotion.bored;
      _smoothHappy = raw.emotion.happy;
      _smoothAnxious = raw.emotion.anxious;
      _smoothTired = raw.emotion.tired;
      _initialized = true;
      _last = raw;
      return raw;
    }

    // 抗抖动：变化 < 0.03 忽略
    final fxDelta = (raw.focusScore - _smoothFocus).abs();
    if (fxDelta < 0.03 && raw.emotion.dominantIntensity < 0.5) return _last;

    // EMA 深度平滑
    _smoothFocus = _ema(_smoothFocus, raw.focusScore);
    _smoothCalm = _ema(_smoothCalm, raw.emotion.calm);
    _smoothFocused = _ema(_smoothFocused, raw.emotion.focused);
    _smoothFrustrated = _ema(_smoothFrustrated, raw.emotion.frustrated);
    _smoothBored = _ema(_smoothBored, raw.emotion.bored);
    _smoothHappy = _ema(_smoothHappy, raw.emotion.happy);
    _smoothAnxious = _ema(_smoothAnxious, raw.emotion.anxious);
    _smoothTired = _ema(_smoothTired, raw.emotion.tired);

    // ── 专注惯性 ──
    if (_smoothFocus > 0.65) {
      _highFocusFrames = min(_highFocusFrames + 1, 300);
    } else if (_smoothFocus < 0.45) {
      _highFocusFrames = max(_highFocusFrames - 2, 0);
    }
    _focusInertia = (_highFocusFrames / 150).clamp(0.0, 1.0);

    var effectiveFocus = _smoothFocus;
    if (_focusInertia > 0.5) {
      // 惯性加持：高专注时即使短暂掉分也保持高位
      effectiveFocus = _smoothFocus + (_focusInertia * 0.2).clamp(0.0, 1.0 - _smoothFocus);
    }

    // ── 专注时不看屏幕 = 默认高专注 ──
    if (isStudying && raw.scene == StudyScene.noFace) {
      effectiveFocus = max(effectiveFocus, 0.60); // 学习中无脸 = 低头看书，默认专注
    }

    // ── 烦躁需持续确认 ──
    var dominantEmotion = EmotionSpectrum(
      calm: _smoothCalm, focused: _smoothFocused,
      frustrated: _smoothFrustrated, bored: _smoothBored,
      happy: _smoothHappy, anxious: _smoothAnxious, tired: _smoothTired,
    ).dominantEmotion;

    if (_smoothFrustrated > _frustratedThreshold && dominantEmotion == 'frustrated') {
      _frustratedFrames++;
    } else {
      _frustratedFrames = max(_frustratedFrames - 3, 0);
    }

    // 未达确认帧数 → 不理
    if (_frustratedFrames < _frustratedConfirmFrames && dominantEmotion == 'frustrated') {
      dominantEmotion = 'focused';
    }

    // 触摸中皱眉 → 果断忽略
    if (dominantEmotion == 'frustrated' && isTouching && _focusInertia > 0.3) {
      dominantEmotion = 'focused';
    }

    // ── 学习防疲劳 ──
    if (isStudying) {
      _studyStart ??= DateTime.now();
      final mins = DateTime.now().difference(_studyStart!).inMinutes;
      if (mins > 50) effectiveFocus = (effectiveFocus * 1.15).clamp(0.0, 1.0);
    } else {
      _studyStart = null;
    }

    _last = VisionResult(
      scene: raw.scene,
      focusScore: effectiveFocus.clamp(0.0, 1.0),
      emotion: EmotionSpectrum(calm: _smoothCalm, focused: _smoothFocused,
          frustrated: _frustratedFrames > _frustratedConfirmFrames ? _smoothFrustrated : _smoothFrustrated * 0.3,
          bored: _smoothBored, happy: _smoothHappy, anxious: _smoothAnxious, tired: _smoothTired),
      isStudying: raw.isStudying,
      timestamp: DateTime.now(),
    );
    return _last;
  }

  double _ema(double prev, double curr) => _alpha * curr + (1 - _alpha) * prev;
  void reset() { _initialized = false; _highFocusFrames = 0; _frustratedFrames = 0; _studyStart = null; }
}
    }

    _lastCleanResult = VisionResult(
      scene: raw.scene,
      focusScore: effectiveFocus,
      emotion: spectrum,
      isStudying: raw.isStudying,
      timestamp: DateTime.now(),
    );
    return _lastCleanResult;
  }

  late VisionResult _lastCleanResult;

  double _ema(double prev, double curr) => _alpha * curr + (1 - _alpha) * prev;

  /// 重置滤波状态
  void reset() {
    _initialized = false;
    _firstFrameTime = null;
    _frustratedStart = null;
    _studyStartTime = null;
  }
}

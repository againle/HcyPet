import 'vision_service.dart';

/// ============================================================
/// V3 视觉滤波 — EMA 平滑 + 误报消除
/// ============================================================
///
/// 用法：
///   final filter = VisionFilter();
///   final clean = filter.process(rawResult, isTouching: true);
///

class VisionFilter {
  // ── EMA 平滑 ──
  double _smoothFocus = 0.5;
  double _smoothCalm = 0.5;
  double _smoothFocused = 0.5;
  double _smoothFrustrated = 0.0;
  double _smoothBored = 0.0;
  double _smoothHappy = 0.0;
  double _smoothAnxious = 0.0;
  double _smoothTired = 0.0;

  static const _alpha = 0.25; // EMA 平滑系数（越低越平滑）

  // ── 误报消除 ──
  DateTime? _firstFrameTime;
  DateTime? _frustratedStart;
  DateTime? _studyStartTime;
  bool _initialized = false;

  /// 处理原始视觉结果 → 滤波输出
  ///
  /// [raw] 原始 VisionResult
  /// [isTouching] 用户是否正在触摸屏幕
  /// [isStudying] 是否处于学习状态
  VisionResult process(
    VisionResult raw, {
    bool isTouching = false,
    bool isStudying = false,
  }) {
    if (!_initialized) {
      _firstFrameTime = DateTime.now();
      _smoothFocus = raw.focusScore;
      _smoothCalm = raw.emotion.calm;
      _smoothFocused = raw.emotion.focused;
      _smoothFrustrated = raw.emotion.frustrated;
      _smoothBored = raw.emotion.bored;
      _smoothHappy = raw.emotion.happy;
      _smoothAnxious = raw.emotion.anxious;
      _smoothTired = raw.emotion.tired;
      _initialized = true;
      return raw;
    }

    // ── 规则 2：前 10 秒低置信度丢弃，复用上帧 ──
    final elapsed = DateTime.now().difference(_firstFrameTime!);
    if (elapsed.inSeconds < 10 && raw.emotion.dominantIntensity < 0.6) {
      return _lastCleanResult;
    }

    // ── EMA 低通滤波 ──
    _smoothFocus = _ema(_smoothFocus, raw.focusScore);
    _smoothCalm = _ema(_smoothCalm, raw.emotion.calm);
    _smoothFocused = _ema(_smoothFocused, raw.emotion.focused);
    _smoothFrustrated = _ema(_smoothFrustrated, raw.emotion.frustrated);
    _smoothBored = _ema(_smoothBored, raw.emotion.bored);
    _smoothHappy = _ema(_smoothHappy, raw.emotion.happy);
    _smoothAnxious = _ema(_smoothAnxious, raw.emotion.anxious);
    _smoothTired = _ema(_smoothTired, raw.emotion.tired);

    final spectrum = EmotionSpectrum(
      calm: _smoothCalm,
      focused: _smoothFocused,
      frustrated: _smoothFrustrated,
      bored: _smoothBored,
      happy: _smoothHappy,
      anxious: _smoothAnxious,
      tired: _smoothTired,
    );

    // ── 规则 1：烦躁误报消除 ──
    var effectiveFocus = _smoothFocus;
    var dominantEmotion = spectrum.dominantEmotion;

    if (dominantEmotion == 'frustrated' && isTouching) {
      // 用户正在打字/滑动 → 判定为"因专注而皱眉"
      _frustratedStart ??= DateTime.now();
      if (DateTime.now().difference(_frustratedStart!).inSeconds > 5) {
        dominantEmotion = 'focused';
        effectiveFocus = (effectiveFocus + 0.15).clamp(0.0, 1.0); // 补偿专注分数
      }
    } else {
      _frustratedStart = null;
    }

    // ── 规则 3：抗疲劳计时 ──
    if (isStudying) {
      _studyStartTime ??= DateTime.now();
      final studyMinutes = DateTime.now().difference(_studyStartTime!).inMinutes;
      if (studyMinutes > 45) {
        // 学习超过 45 分钟 → 敏感度降低 20%
        effectiveFocus = (effectiveFocus * 1.2).clamp(0.0, 1.0);
      }
    } else {
      _studyStartTime = null;
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

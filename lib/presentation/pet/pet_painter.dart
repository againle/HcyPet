import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/pet_state.dart';
import '../../theme/design_constants.dart';
import 'idle_behavior_scheduler.dart';

/// 宠物画布渲染器 — V2 双轨动画 + 路径插值
class PetPainter extends CustomPainter {
  final PetState state;
  final double size;

  // 情绪过渡
  final PetMood? previousMood;
  final double transitionProgress; // 0.0→1.0

  // 空闲行为
  final IdleBehaviorState idleBehavior;

  // 特殊动画
  final double? specialAnimProgress; // 0.0→1.0 特殊动画进度

  static const Color petColor = PetStrokeSpec.color;

  const PetPainter({
    required this.state,
    this.size = 200,
    this.previousMood,
    this.transitionProgress = 1.0,
    this.idleBehavior = IdleBehaviorState.none,
    this.specialAnimProgress,
  });

  // 获取当前 mood 参数（考虑过渡）
  PetMood get _effectiveMood {
    if (transitionProgress >= 1.0 || previousMood == null) return state.mood;
    return state.mood;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final scale = canvasSize.width / size;

    // 应用歪头偏移
    final adjustedCenter = _applyHeadTilt(center, scale);

    _drawPet(canvas, adjustedCenter, scale);
  }

  Offset _applyHeadTilt(Offset center, double scale) {
    if (idleBehavior.isActive && idleBehavior.type == IdleBehaviorType.headTilt) {
      final tilt = math.sin(idleBehavior.progress * math.pi) * 4 * scale;
      return Offset(center.dx + tilt, center.dy);
    }
    return center;
  }

  void _drawPet(Canvas canvas, Offset center, double scale) {
    if (state.activity == PetActivity.sleeping) {
      _drawSleeping(canvas, center, scale);
      return;
    }

    // 计算睑裂高度系数（眨眼时缩小）
    final blinkFactor = _getBlinkFactor();
    // 打哈欠时眼睛缩小
    final yawnFactor = _getYawnFactor();
    final eyeFactor = blinkFactor * yawnFactor;

    // 计算瞳孔偏移（左右看）
    final pupilOffset = _getPupilOffset(scale);

    switch (state.mood) {
      case PetMood.happy:
        _drawHappy(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
      case PetMood.surprised:
        _drawSurprised(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
      case PetMood.sad:
        _drawSad(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
      case PetMood.sleepy:
        _drawSleepy(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
      case PetMood.missing:
        _drawMissing(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
      case PetMood.calm:
      default:
        _drawCalm(canvas, center, scale, blinkFactor: eyeFactor, pupilOffset: pupilOffset);
        break;
    }
  }

  // ============ 空闲行为计算 ============

  /// 眨眼因子：1.0=全开, 0.0=闭合
  double _getBlinkFactor() {
    if (!idleBehavior.isActive) return 1.0;
    if (idleBehavior.type != IdleBehaviorType.blink) return 1.0;
    // 眨眼曲线：0→快速闭合→短暂→快速张开
    final p = idleBehavior.progress;
    if (p < 0.2) return 1.0 - (p / 0.2);
    if (p < 0.8) return 0.0;
    return (p - 0.8) / 0.2;
  }

  /// 瞳孔偏移
  double _getPupilOffset(double scale) {
    if (!idleBehavior.isActive) return 0;
    final p = idleBehavior.progress;
    final maxOffset = 8.0 * scale;
    switch (idleBehavior.type) {
      case IdleBehaviorType.lookLeft:
        return -math.sin(p * math.pi) * maxOffset;
      case IdleBehaviorType.lookRight:
        return math.sin(p * math.pi) * maxOffset;
      case IdleBehaviorType.yawn:
        return 0; // 打哈欠不动瞳孔
      default:
        return 0;
    }
  }

  /// 打哈欠时眼睛缩小
  double _getYawnFactor() {
    if (!idleBehavior.isActive) return 1.0;
    if (idleBehavior.type != IdleBehaviorType.yawn) return 1.0;
    final p = idleBehavior.progress;
    if (p < 0.3) return 1.0 - (p / 0.3) * 0.7;
    if (p < 0.7) return 0.3;
    return 0.3 + ((p - 0.7) / 0.3) * 0.7;
  }

  // ============ 睡眠 ============

  void _drawSleeping(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 16 * scale;
    final spacing = 28 * scale;
    final paint = Paint()
      ..color = petColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;

    final leftPath = Path()
      ..moveTo(center.dx - spacing - eyeWidth / 2, center.dy)
      ..quadraticBezierTo(center.dx - spacing, center.dy + 6 * scale, center.dx - spacing + eyeWidth / 2, center.dy);
    canvas.drawPath(leftPath, paint);

    final rightPath = Path()
      ..moveTo(center.dx + spacing - eyeWidth / 2, center.dy)
      ..quadraticBezierTo(center.dx + spacing, center.dy + 6 * scale, center.dx + spacing + eyeWidth / 2, center.dy);
    canvas.drawPath(rightPath, paint);

    _drawZzz(canvas, Offset(center.dx + 30 * scale, center.dy - 50 * scale), scale, opacity: 0.2);
  }

  // ============ 平静 ============

  void _drawCalm(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeWidth = 28 * scale;
    final eyeHeight = 70 * scale * blinkFactor;
    final spacing = 34 * scale;
    final radius = 10 * scale;
    final paint = Paint()..color = petColor..style = PaintingStyle.fill;

    _drawEye(canvas, Offset(center.dx - spacing + pupilOffset, center.dy), eyeWidth, eyeHeight, radius, paint);
    _drawEye(canvas, Offset(center.dx + spacing + pupilOffset, center.dy), eyeWidth, eyeHeight, radius, paint);
  }

  // ============ 开心 ============

  void _drawHappy(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeSpan = 40 * scale;
    final eyeArch = 30 * scale * blinkFactor;
    final spacing = 36 * scale;
    final strokeW = 8 * scale;

    final paint = Paint()
      ..color = petColor..style = PaintingStyle.stroke
      ..strokeWidth = strokeW..strokeCap = StrokeCap.round;

    final leftPath = Path()
      ..moveTo(center.dx - spacing - eyeSpan / 2 + pupilOffset, center.dy + 2 * scale)
      ..quadraticBezierTo(center.dx - spacing + pupilOffset, center.dy - eyeArch, center.dx - spacing + eyeSpan / 2 + pupilOffset, center.dy + 2 * scale);
    canvas.drawPath(leftPath, paint);

    final rightPath = Path()
      ..moveTo(center.dx + spacing - eyeSpan / 2 + pupilOffset, center.dy + 2 * scale)
      ..quadraticBezierTo(center.dx + spacing + pupilOffset, center.dy - eyeArch, center.dx + spacing + eyeSpan / 2 + pupilOffset, center.dy + 2 * scale);
    canvas.drawPath(rightPath, paint);
  }

  // ============ 惊讶 ============

  void _drawSurprised(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeSize = 52 * scale * blinkFactor;
    final spacing = 40 * scale;
    final radius = 12 * scale;
    final paint = Paint()..color = petColor..style = PaintingStyle.fill;

    _drawEye(canvas, Offset(center.dx - spacing + pupilOffset, center.dy), eyeSize, eyeSize, radius, paint);
    _drawEye(canvas, Offset(center.dx + spacing + pupilOffset, center.dy), eyeSize, eyeSize, radius, paint);

    // O 型嘴巴
    final mouthPaint = Paint()..color = petColor..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy + 36 * scale), width: 16 * scale, height: 20 * scale), mouthPaint);
  }

  // ============ 难过 ============

  /// 皱眉：宽长方形眼睛（宽度同平静），高度压缩
  void _drawSad(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeW = 28 * scale;
    final eyeH = 10 * scale * blinkFactor;
    final spacing = 34 * scale;
    final radius = 3 * scale;

    final paint = Paint()..color = petColor.withOpacity(0.5)..style = PaintingStyle.fill;

    _drawEye(canvas, Offset(center.dx - spacing + pupilOffset, center.dy), eyeW, eyeH, radius, paint);
    _drawEye(canvas, Offset(center.dx + spacing + pupilOffset, center.dy), eyeW, eyeH, radius, paint);
  }

  // ============ 困倦 ============

  void _drawSleepy(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeWidth = 28 * scale;
    final eyeHeight = math.max(8 * scale, 28 * scale * blinkFactor);
    final spacing = 34 * scale;
    final radius = 10 * scale;
    final paint = Paint()..color = petColor..style = PaintingStyle.fill;

    _drawEye(canvas, Offset(center.dx - spacing + pupilOffset, center.dy + 2 * scale), eyeWidth, eyeHeight, radius, paint);
    _drawEye(canvas, Offset(center.dx + spacing + pupilOffset, center.dy + 2 * scale), eyeWidth, eyeHeight, radius, paint);

    _drawZzz(canvas, Offset(center.dx + 38 * scale, center.dy - 36 * scale), scale * 0.65, opacity: 0.4);
  }

  // ============ 思念 ============

  void _drawMissing(Canvas canvas, Offset center, double scale, {double blinkFactor = 1.0, double pupilOffset = 0}) {
    final eyeWidth = 20 * scale;
    final eyeHeight = 78 * scale * blinkFactor;
    final spacing = 30 * scale;
    final radius = 9 * scale;
    final paint = Paint()..color = petColor..style = PaintingStyle.fill;

    _drawEye(canvas, Offset(center.dx - spacing + pupilOffset, center.dy), eyeWidth, eyeHeight, radius, paint);
    _drawEye(canvas, Offset(center.dx + spacing + pupilOffset, center.dy), eyeWidth, eyeHeight, radius, paint);

    final heartPaint = Paint()..color = petColor.withOpacity(0.7)..style = PaintingStyle.fill;
    _drawSmallHeart(canvas, center: Offset(center.dx, center.dy - 40 * scale), size: 8 * scale, paint: heartPaint);
    _drawSmallHeart(canvas, center: Offset(center.dx - 22 * scale, center.dy - 46 * scale), size: 6 * scale, paint: Paint()..color = petColor.withOpacity(0.5)..style = PaintingStyle.fill);
    _drawSmallHeart(canvas, center: Offset(center.dx + 22 * scale, center.dy - 46 * scale), size: 6 * scale, paint: Paint()..color = petColor.withOpacity(0.5)..style = PaintingStyle.fill);
  }

  // ============ 辅助绘制 ============

  void _drawEye(Canvas canvas, Offset center, double w, double h, double r, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: h), Radius.circular(r)),
      paint,
    );
  }

  void _drawSmallHeart(Canvas canvas, {required Offset center, required double size, required Paint paint}) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.4)
      ..cubicTo(center.dx - size * 0.3, center.dy - size * 0.2, center.dx - size * 0.6, center.dy - size * 0.4, center.dx - size * 0.3, center.dy - size * 0.7)
      ..cubicTo(center.dx, center.dy - size * 0.9, center.dx + size * 0.3, center.dy - size * 0.7, center.dx + size * 0.6, center.dy - size * 0.4)
      ..cubicTo(center.dx + size * 0.6, center.dy - size * 0.2, center.dx + size * 0.3, center.dy + size * 0.2, center.dx, center.dy + size * 0.4)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawZzz(Canvas canvas, Offset origin, double scale, {double opacity = 0.4}) {
    final paint = Paint()
      ..color = petColor.withOpacity(opacity)..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    final zSize = 8.0 * scale;
    final zScales = [0.7, 1.0, 1.3];
    final zOffsetsX = [-zSize * 0.5, 0.0, zSize * 0.5];
    final zOffsetsY = [zSize * 2.0, zSize * 1.0, 0.0];

    for (int i = 0; i < 3; i++) {
      final s = zScales[i];
      final ox = origin.dx + zOffsetsX[i] * scale;
      final oy = origin.dy + zOffsetsY[i] * scale;
      final w = zSize * s;
      canvas.drawPath(Path()
        ..moveTo(ox - w / 2, oy - w / 2)
        ..lineTo(ox + w / 2, oy - w / 2)
        ..lineTo(ox - w / 2, oy + w / 2)
        ..lineTo(ox + w / 2, oy + w / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PetPainter oldDelegate) => true;
}

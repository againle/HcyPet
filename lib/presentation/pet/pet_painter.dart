import 'package:flutter/material.dart';
import '../../models/pet_state.dart';

/// 宠物画布渲染器 - 浅蓝色简约风格
class PetPainter extends CustomPainter {
  final PetState state;
  final double size;

  // 浅蓝色调
  static const Color petColor = Color(0xFF4FC3F7);

  const PetPainter({
    required this.state,
    this.size = 200,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final scale = canvasSize.width / size;

    _drawPet(canvas, center, scale);
  }

  void _drawPet(Canvas canvas, Offset center, double scale) {
    if (state.activity == PetActivity.sleeping) {
      _drawSleeping(canvas, center, scale);
      return;
    }

    switch (state.mood) {
      case PetMood.happy:
        _drawHappy(canvas, center, scale);
        break;
      case PetMood.surprised:
        _drawSurprised(canvas, center, scale);
        break;
      case PetMood.sad:
        _drawSad(canvas, center, scale);
        break;
      case PetMood.sleepy:
        _drawSleepy(canvas, center, scale);
        break;
      case PetMood.missing:
        _drawMissing(canvas, center, scale);
        break;
      case PetMood.calm:
      default:
        _drawCalm(canvas, center, scale);
        break;
    }
  }

  /// 睡眠状态：闭眼 + Zzz
  void _drawSleeping(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 16 * scale;
    final spacing = 28 * scale;

    final paint = Paint()
      ..color = petColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;

    // 左眼闭眼弧线
    final leftPath = Path()
      ..moveTo(center.dx - spacing - eyeWidth / 2, center.dy)
      ..quadraticBezierTo(
        center.dx - spacing,
        center.dy + 6 * scale,
        center.dx - spacing + eyeWidth / 2,
        center.dy,
      );
    canvas.drawPath(leftPath, paint);

    // 右眼闭眼弧线
    final rightPath = Path()
      ..moveTo(center.dx + spacing - eyeWidth / 2, center.dy)
      ..quadraticBezierTo(
        center.dx + spacing,
        center.dy + 6 * scale,
        center.dx + spacing + eyeWidth / 2,
        center.dy,
      );
    canvas.drawPath(rightPath, paint);

    // Zzz 符号
    final textPainter = TextPainter(
      text: TextSpan(
        text: '💤',
        style: TextStyle(
          fontSize: 28 * scale,
          color: petColor.withOpacity(0.2),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + 30 * scale, center.dy - 50 * scale),
    );
  }

  /// 平静状态：两只竖立的圆角矩形眼睛
  void _drawCalm(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 16 * scale;
    final eyeHeight = 48 * scale;
    final spacing = 28 * scale;
    final radius = 6 * scale;

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    // 左眼
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - spacing, center.dy),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(leftRect, paint);

    // 右眼
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + spacing, center.dy),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rightRect, paint);
  }

  /// ============ 开心状态（简化版）============
  /// 每只眼睛是一条向上弯曲的粗弧线 ⌒
  void _drawHappy(Canvas canvas, Offset center, double scale) {
    final eyeSpan = 28 * scale;    // 弧线跨度（宽度）
    final eyeArch = 18 * scale;    // 向上拱起高度
    final spacing = 30 * scale;    // 两眼间距
    final strokeW = 6 * scale;     // 线条粗细

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    // 左眼：⌒ 向上弧
    final leftPath = Path()
      ..moveTo(center.dx - spacing - eyeSpan / 2, center.dy + 4 * scale)
      ..quadraticBezierTo(
        center.dx - spacing,
        center.dy - eyeArch,
        center.dx - spacing + eyeSpan / 2,
        center.dy + 4 * scale,
      );
    canvas.drawPath(leftPath, paint);

    // 右眼：⌒ 向上弧
    final rightPath = Path()
      ..moveTo(center.dx + spacing - eyeSpan / 2, center.dy + 4 * scale)
      ..quadraticBezierTo(
        center.dx + spacing,
        center.dy - eyeArch,
        center.dx + spacing + eyeSpan / 2,
        center.dy + 4 * scale,
      );
    canvas.drawPath(rightPath, paint);
  }

  /// 惊讶状态：眼睛放大 + O 型嘴巴
  void _drawSurprised(Canvas canvas, Offset center, double scale) {
    final eyeSize = 32 * scale; // 放大
    final spacing = 34 * scale;
    final radius = 8 * scale;

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    // 左眼（放大）
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - spacing, center.dy),
        width: eyeSize,
        height: eyeSize,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(leftRect, paint);

    // 右眼（放大）
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + spacing, center.dy),
        width: eyeSize,
        height: eyeSize,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rightRect, paint);

    // O 型嘴巴
    final mouthPaint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 36 * scale),
        width: 16 * scale,
        height: 20 * scale,
      ),
      mouthPaint,
    );
  }

  /// 难过状态：眼睛向内靠拢 + 略微下移，不画嘴巴
  void _drawSad(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 14 * scale;
    final eyeHeight = 40 * scale;
    final spacing = 18 * scale; // 靠拢
    final radius = 6 * scale;

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    // 左眼（向内靠拢，略微下移）
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - spacing, center.dy + 6 * scale),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(leftRect, paint);

    // 右眼（向内靠拢，略微下移）
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + spacing, center.dy + 6 * scale),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rightRect, paint);
  }

  /// 困倦状态：眼睛变短（高度压缩）+ 小 Zzz 符号
  void _drawSleepy(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 16 * scale;
    final eyeHeight = 16 * scale; // 大幅缩短
    final spacing = 28 * scale;
    final radius = 6 * scale;

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    // 左眼（缩短）
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - spacing, center.dy + 4 * scale),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(leftRect, paint);

    // 右眼（缩短）
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + spacing, center.dy + 4 * scale),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rightRect, paint);

    // Zzz 符号（小号）
    final textPainter = TextPainter(
      text: TextSpan(
        text: '💤',
        style: TextStyle(
          fontSize: 18 * scale,
          color: petColor.withOpacity(0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + 38 * scale, center.dy - 36 * scale),
    );
  }

  /// 思念状态：眼睛拉长 + 眯眯眼（宽度变窄）+ 上方冒爱心
  void _drawMissing(Canvas canvas, Offset center, double scale) {
    final eyeWidth = 10 * scale; // 变窄（眯眯眼）
    final eyeHeight = 56 * scale; // 拉长
    final spacing = 26 * scale;
    final radius = 5 * scale;

    final paint = Paint()
      ..color = petColor
      ..style = PaintingStyle.fill;

    // 左眼（拉长 + 变窄）
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - spacing, center.dy),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(leftRect, paint);

    // 右眼（拉长 + 变窄）
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + spacing, center.dy),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rightRect, paint);

    // 上方冒爱心（3颗小爱心飘出）
    final heartPaint = Paint()
      ..color = petColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // 爱心1（中间偏上）
    _drawSmallHeart(
      canvas,
      center: Offset(center.dx, center.dy - 40 * scale),
      size: 8 * scale,
      paint: heartPaint,
    );

    // 爱心2（左上方）
    _drawSmallHeart(
      canvas,
      center: Offset(center.dx - 22 * scale, center.dy - 46 * scale),
      size: 6 * scale,
      paint: Paint()
        ..color = petColor.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );

    // 爱心3（右上方）
    _drawSmallHeart(
      canvas,
      center: Offset(center.dx + 22 * scale, center.dy - 46 * scale),
      size: 6 * scale,
      paint: Paint()
        ..color = petColor.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );
  }

  /// 绘制小爱心
  void _drawSmallHeart(Canvas canvas, {required Offset center, required double size, required Paint paint}) {
    final path = Path();

    path.moveTo(center.dx, center.dy + size * 0.4);
    path.cubicTo(
      center.dx - size * 0.3,
      center.dy - size * 0.2,
      center.dx - size * 0.6,
      center.dy - size * 0.4,
      center.dx - size * 0.3,
      center.dy - size * 0.7,
    );
    path.cubicTo(
      center.dx,
      center.dy - size * 0.9,
      center.dx + size * 0.3,
      center.dy - size * 0.7,
      center.dx + size * 0.6,
      center.dy - size * 0.4,
    );
    path.cubicTo(
      center.dx + size * 0.6,
      center.dy - size * 0.2,
      center.dx + size * 0.3,
      center.dy + size * 0.2,
      center.dx,
      center.dy + size * 0.4,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PetPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}

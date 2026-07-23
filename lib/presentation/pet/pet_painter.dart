import "dart:math" as math;
import "package:flutter/material.dart";
import "../../theme/design_constants.dart";
import "mochi_physics.dart";

class PetPainter extends CustomPainter {
  final MochiExpression expression;
  final double size;
  final bool isSleeping, showHearts, showZzz, surpriseMouth, allowArc, forceArc, happyMood;
  final Color petColor;
  final double squashStretch;
  static const _dc = PetStrokeSpec.color;

  const PetPainter({required this.expression, this.size = 200, this.isSleeping = false, this.showHearts = false, this.showZzz = false, this.surpriseMouth = false, this.petColor = _dc, this.squashStretch = 0.0, this.allowArc = true, this.forceArc = false, this.happyMood = false});

  double get _op => isSleeping ? 0.3 : 1.0;

  double get _arcStrength {
    if (!allowArc || !happyMood) return 0.0; // 仅笑脸 mood 允许弧
    final e = expression.eyelidOpen;
    if (e <= 0.45 || e >= 0.65) return 0.0;
    return (1.0 - (e - 0.55).abs() / 0.10).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas c, Size s) {
    final sc = s.width / size;
    final ct = Offset(s.width / 2, s.height / 2);
    c.save();
    if (squashStretch != 0) { final sx = 1 + squashStretch * 0.15; final sy = 1 - squashStretch * 0.15; c.translate(ct.dx, ct.dy); c.scale(sx, sy); c.translate(-ct.dx, -ct.dy); }
    _blush(c, ct, sc);
    _eyes(c, ct, sc);
    if (surpriseMouth) _surpriseMouth(c, ct, sc);
    if (showZzz || isSleeping) _zzz(c, Offset(ct.dx + 38 * sc, ct.dy - 48 * sc), sc * 0.7);
    if (showHearts) _hearts(c, ct, sc);
    c.restore();
  }

  void _blush(Canvas c, Offset ct, double sc) {
    if (expression.blushOpacity <= 0) return;
    final cl = const Color(0xFFFF6B9D).withOpacity(expression.blushOpacity * 0.35);
    final p = Paint()..color = cl..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final sp = 30 * sc; final y = ct.dy + 18 * sc;
    c.drawOval(Rect.fromCenter(center: Offset(ct.dx - sp, y), width: 22 * sc, height: 12 * sc), p);
    c.drawOval(Rect.fromCenter(center: Offset(ct.dx + sp, y), width: 22 * sc, height: 12 * sc), p);
  }

  void _eyes(Canvas c, Offset ct, double sc) {
    if (expression.eyelidOpen <= 0.02) { _closed(c, ct, sc); return; }
    if (forceArc) {
      // 笑脸模式：只用弧形，眨眼即弧线压扁→弹起，永不出方块
      _arcEyes(c, ct, sc, 1.0);
      return;
    }
    final as = _arcStrength;
    final roundOpacity = 1.0 - as;
    final arcOpacity = as;
    if (roundOpacity > 0.005) _roundEyes(c, ct, sc, roundOpacity);
    if (arcOpacity > 0.005) _arcEyes(c, ct, sc, arcOpacity);
  }

  void _roundEyes(Canvas c, Offset ct, double sc, [double opacity = 1.0]) {
    final o = expression.eyelidOpen.clamp(0.04, 1.0);
    final ew = 28 * sc; final eh = 70 * sc * o; final sp = 34 * sc;
    final r = (14 * sc * o).clamp(3 * sc, 14 * sc);
    final sx = expression.eyeShiftX * 12 * sc; // 眼睛水平平移
    final p = Paint()..color = petColor.withOpacity(_op * opacity)..style = PaintingStyle.fill;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(ct.dx - sp + sx, ct.dy), width: ew, height: eh), Radius.circular(r)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(ct.dx + sp + sx, ct.dy), width: ew, height: eh), Radius.circular(r)), p);
  }

  void _arcEyes(Canvas c, Offset ct, double sc, [double opacity = 1.0]) {
    final o = expression.eyelidOpen.clamp(0.03, 0.55);
    final ah = o * 35 * sc; // 闭眼→0px, 开心→19px, 丝滑缩放
    final span = 40 * sc; final sp = 36 * sc;
    final sx = expression.eyeShiftX * 12 * sc;
    final p = Paint()..color = petColor.withOpacity(_op * opacity)..style = PaintingStyle.stroke..strokeWidth = 8 * sc..strokeCap = StrokeCap.round;
    c.drawPath(Path()..moveTo(ct.dx - sp - span / 2 + sx, ct.dy + 3 * sc)..quadraticBezierTo(ct.dx - sp + sx, ct.dy - ah, ct.dx - sp + span / 2 + sx, ct.dy + 3 * sc), p);
    c.drawPath(Path()..moveTo(ct.dx + sp - span / 2 + sx, ct.dy + 3 * sc)..quadraticBezierTo(ct.dx + sp + sx, ct.dy - ah, ct.dx + sp + span / 2 + sx, ct.dy + 3 * sc), p);
  }

  void _closed(Canvas c, Offset ct, double sc) {
    final lw = 18 * sc; final sp = 28 * sc; final sx = expression.eyeShiftX * 12 * sc;
    final p = Paint()..color = petColor.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2.5 * sc..strokeCap = StrokeCap.round;
    c.drawPath(Path()..moveTo(ct.dx - sp - lw / 2 + sx, ct.dy)..quadraticBezierTo(ct.dx - sp + sx, ct.dy + 6 * sc, ct.dx - sp + lw / 2 + sx, ct.dy), p);
    c.drawPath(Path()..moveTo(ct.dx + sp - lw / 2 + sx, ct.dy)..quadraticBezierTo(ct.dx + sp + sx, ct.dy + 6 * sc, ct.dx + sp + lw / 2 + sx, ct.dy), p);
  }

  void _surpriseMouth(Canvas c, Offset ct, double sc) {
    final p = Paint()..color = petColor.withOpacity(_op)..style = PaintingStyle.stroke..strokeWidth = 2.5 * sc;
    c.drawOval(Rect.fromCenter(center: Offset(ct.dx, ct.dy + 36 * sc), width: 14 * sc, height: 18 * sc), p);
  }

  void _zzz(Canvas c, Offset o, double sc) {
    final p = Paint()..color = petColor.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 2 * sc..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final z = 8 * sc; final scs = [0.7, 1.0, 1.3]; final ox = [-z * 0.5, 0.0, z * 0.5]; final oy = [z * 2.0, z * 1.0, 0.0];
    for (int i = 0; i < 3; i++) { final s = scs[i]; final x = o.dx + ox[i] * sc; final y = o.dy + oy[i] * sc; final w = z * s; c.drawPath(Path()..moveTo(x - w / 2, y - w / 2)..lineTo(x + w / 2, y - w / 2)..lineTo(x - w / 2, y + w / 2)..lineTo(x + w / 2, y + w / 2), p); }
  }

  void _hearts(Canvas c, Offset ct, double sc) {
    final mp = Paint()..color = petColor.withOpacity(0.6)..style = PaintingStyle.fill;
    final sp = Paint()..color = petColor.withOpacity(0.35)..style = PaintingStyle.fill;
    _h(c, Offset(ct.dx, ct.dy - 42 * sc), 9 * sc, mp);
    _h(c, Offset(ct.dx - 24 * sc, ct.dy - 48 * sc), 6 * sc, sp);
    _h(c, Offset(ct.dx + 24 * sc, ct.dy - 48 * sc), 6 * sc, sp);
  }
  void _h(Canvas c, Offset o, double s, Paint p) { c.drawPath(Path()..moveTo(o.dx, o.dy + s * 0.4)..cubicTo(o.dx - s * 0.3, o.dy - s * 0.2, o.dx - s * 0.6, o.dy - s * 0.4, o.dx - s * 0.3, o.dy - s * 0.7)..cubicTo(o.dx, o.dy - s * 0.9, o.dx + s * 0.3, o.dy - s * 0.7, o.dx + s * 0.6, o.dy - s * 0.4)..cubicTo(o.dx + s * 0.6, o.dy - s * 0.2, o.dx + s * 0.3, o.dy + s * 0.2, o.dx, o.dy + s * 0.4)..close(), p); }

  @override
  bool shouldRepaint(PetPainter o) => true;
}

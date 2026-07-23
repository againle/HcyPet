import "dart:math" as math;
import "package:flutter/material.dart";
import "../../theme/design_constants.dart";
import "mochi_physics.dart";

class PetPainter extends CustomPainter {
  final MochiExpression expression;
  final double size;
  final bool isSleeping, showHearts, showZzz, dazed, allowArc, forceArc, happyMood, backFacing;
  final Color petColor;
  final double squashStretch;
  final double spiralAngle;
  static const _dc = PetStrokeSpec.color;

  const PetPainter({required this.expression, this.size = 200, this.isSleeping = false, this.showHearts = false, this.showZzz = false, this.dazed = false, this.petColor = _dc, this.squashStretch = 0.0, this.allowArc = true, this.forceArc = false, this.happyMood = false, this.spiralAngle = 0.0, this.backFacing = false});

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
    if (showZzz || isSleeping) _zzz(c, Offset(ct.dx + 50 * sc, ct.dy - 60 * sc), sc * 0.8);
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
    if (backFacing) { _backEyes(c, ct, sc); return; }
    if (dazed) { _spiralEyes(c, ct, sc); return; }
    if (forceArc) { _arcEyes(c, ct, sc, 1.0); return; }
    final as = _arcStrength;
    final roundOpacity = 1.0 - as;
    final arcOpacity = as;
    if (roundOpacity > 0.005) _roundEyes(c, ct, sc, roundOpacity);
    if (arcOpacity > 0.005) _arcEyes(c, ct, sc, arcOpacity);
  }

  void _roundEyes(Canvas c, Offset ct, double sc, [double opacity = 1.0]) {
    final o = expression.eyelidOpen.clamp(0.04, 1.0);
    final ew = 56 * sc; final eh = 140 * sc * o; final sp = 68 * sc; // 2x 放大
    final r = (28 * sc * o).clamp(3 * sc, 28 * sc);
    final sx = expression.eyeShiftX * 18 * sc;
    final p = Paint()..color = petColor.withOpacity(_op * opacity)..style = PaintingStyle.fill;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(ct.dx - sp + sx, ct.dy), width: ew, height: eh), Radius.circular(r)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(ct.dx + sp + sx, ct.dy), width: ew, height: eh), Radius.circular(r)), p);
  }

  void _arcEyes(Canvas c, Offset ct, double sc, [double opacity = 1.0]) {
    final o = expression.eyelidOpen.clamp(0.03, 0.55);
    final ah = o * 60 * sc; final span = 72 * sc; final sp = 68 * sc;
    final sx = expression.eyeShiftX * 18 * sc;
    final p = Paint()..color = petColor.withOpacity(_op * opacity)..style = PaintingStyle.stroke..strokeWidth = 8 * sc..strokeCap = StrokeCap.round;
    c.drawPath(Path()..moveTo(ct.dx - sp - span / 2 + sx, ct.dy + 3 * sc)..quadraticBezierTo(ct.dx - sp + sx, ct.dy - ah, ct.dx - sp + span / 2 + sx, ct.dy + 3 * sc), p);
    c.drawPath(Path()..moveTo(ct.dx + sp - span / 2 + sx, ct.dy + 3 * sc)..quadraticBezierTo(ct.dx + sp + sx, ct.dy - ah, ct.dx + sp + span / 2 + sx, ct.dy + 3 * sc), p);
  }

  void _closed(Canvas c, Offset ct, double sc) {
    final lw = 28 * sc; final sp = 56 * sc; final sx = expression.eyeShiftX * 18 * sc;
    final p = Paint()..color = petColor.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 3 * sc..strokeCap = StrokeCap.round;
    c.drawPath(Path()..moveTo(ct.dx - sp - lw / 2 + sx, ct.dy)..quadraticBezierTo(ct.dx - sp + sx, ct.dy + 8 * sc, ct.dx - sp + lw / 2 + sx, ct.dy), p);
    c.drawPath(Path()..moveTo(ct.dx + sp - lw / 2 + sx, ct.dy)..quadraticBezierTo(ct.dx + sp + sx, ct.dy + 8 * sc, ct.dx + sp + lw / 2 + sx, ct.dy), p);
  }

  /// 旋转螺旋眼（棒棒糖旋涡）
  void _spiralEyes(Canvas c, Offset ct, double sc) {
    final sp = 68 * sc;
    for (int i = 0; i < 2; i++) {
      final dx = [-sp, sp][i];
      final cx = ct.dx + dx; final cy = ct.dy;
      final p = Paint()..color = petColor.withOpacity(_op)..style = PaintingStyle.stroke..strokeWidth = 3.5 * sc..strokeCap = StrokeCap.round;
      final path = Path();
      final maxR = 32 * sc;
      const turns = 2.5; const steps = 80;
      final a = 2 * sc;
      final b = (maxR - a) / (turns * 2 * math.pi);
      var first = true;
      for (int j = 0; j <= steps; j++) {
        final t = j / steps;
        final theta = spiralAngle - t * turns * 2 * math.pi;
        final r = a + b * (t * turns * 2 * math.pi);
        final x = cx + (i == 0 ? -1 : 1) * r * math.cos(theta); // 左眼镜像
        final y = cy + r * math.sin(theta);
        if (first) { path.moveTo(x, y); first = false; } else { path.lineTo(x, y); }
      }
      c.drawPath(path, p);
    }
  }

  /// 后脑勺生气：小眼远距 + 手绘生气符号
  void _backEyes(Canvas c, Offset ct, double sc) {
    final sp = 60 * sc;
    final r = 10 * sc;
    final peek = math.sin(DateTime.now().millisecondsSinceEpoch * 0.003) * 6 * sc;
    final p = Paint()..color = petColor.withOpacity(0.45)..style = PaintingStyle.fill;
    c.drawCircle(Offset(ct.dx - sp + peek, ct.dy), r, p);
    c.drawCircle(Offset(ct.dx + sp + peek, ct.dy), r, p);
    // 手绘生气符号 #
    _drawAngerMark(c, Offset(ct.dx, ct.dy - 35 * sc), 10 * sc);
  }

  void _drawAngerMark(Canvas c, Offset o, double s) {
    final p = Paint()..color = petColor.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final cx = o.dx; final cy = o.dy;
    c.drawLine(Offset(cx - s, cy - s), Offset(cx + s, cy + s), p);
    c.drawLine(Offset(cx + s, cy - s), Offset(cx - s, cy + s), p);
    // 四角小爆点
    for (final dx in [-s, s]) { for (final dy in [-s, s]) {
      c.drawLine(Offset(cx + dx, cy + dy - s * 0.3), Offset(cx + dx, cy + dy + s * 0.3), p);
      c.drawLine(Offset(cx + dx - s * 0.3, cy + dy), Offset(cx + dx + s * 0.3, cy + dy), p);
    }}
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

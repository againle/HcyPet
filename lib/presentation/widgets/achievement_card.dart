import 'package:flutter/material.dart';
import '../../services/study_history_service.dart';

/// 学习结束成就闪卡
class AchievementCard extends StatelessWidget {
  final StudySession session;
  const AchievementCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final mins = (session.totalSeconds / 60).toStringAsFixed(0);
    final avgFocus = (session.avgFocus * 100).toInt();
    final deepMin = (session.deepFocusSeconds / 60).toStringAsFixed(0);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉 学习完成！',
              style: TextStyle(fontSize: 20, color: Color(0xFF4FC3F7), fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),

          _statRow(Icons.timer_outlined, '学习时长', '$mins 分钟'),
          _statRow(Icons.auto_awesome, '平均专注', '$avgFocus%'),
          _statRow(Icons.star, '深度专注', '$deepMin 分钟'),
          _statRow(Icons.label_outline, '学习方式', session.modeLabel),

          const SizedBox(height: 16),

          // 专注度曲线
          if (session.focusCurve.length >= 2) ...[
            SizedBox(
              height: 80,
              child: CustomPaint(
                size: const Size(double.infinity, 80),
                painter: _AchievementCurvePainter(curve: session.focusCurve),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            _encouragement(avgFocus),
            style: TextStyle(fontSize: 13, color: const Color(0xFF4FC3F7).withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的！', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 15)),
          ),
        ]),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF4FC3F7).withOpacity(0.5)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)))),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _encouragement(int focus) {
    if (focus >= 85) return '太厉害了！你进入了深度专注状态 🔥';
    if (focus >= 65) return '表现不错！继续保持~';
    if (focus >= 45) return '还不错，下次可以更专注哦 💪';
    return '完成就是胜利！下次加油~ 🌟';
  }
}

class _AchievementCurvePainter extends CustomPainter {
  final List<FocusSample> curve;
  _AchievementCurvePainter({required this.curve});

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.length < 2) return;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final maxSec = curve.last.elapsedSeconds.toDouble();
    if (maxSec <= 0) return;

    final fillPath = Path();
    final linePath = Path();
    bool first = true;

    for (final s in curve) {
      final x = (s.elapsedSeconds / maxSec) * size.width;
      final y = size.height - s.focusScore * size.height * 0.85 - 8;
      if (first) { fillPath.moveTo(x, size.height); fillPath.lineTo(x, y); linePath.moveTo(x, y); first = false; }
      else { fillPath.lineTo(x, y); linePath.lineTo(x, y); }
    }
    final lx = (curve.last.elapsedSeconds / maxSec) * size.width;
    fillPath.lineTo(lx, size.height); fillPath.close();

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFF4FC3F7).withOpacity(0.2), const Color(0xFF4FC3F7).withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    paint.color = const Color(0xFF4FC3F7).withOpacity(0.7);
    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant _AchievementCurvePainter old) => old.curve != curve;
}

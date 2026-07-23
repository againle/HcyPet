import 'package:flutter/material.dart';

/// 自习室热力图日历（月视图）
class HeatmapCalendar extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, int> monthData;
  final void Function(String dateKey) onDayTap;

  const HeatmapCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.monthData,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.2))))))
              .toList(),
        ),
        const SizedBox(height: 2),
        ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: List.generate(7, (day) {
                final dayNum = week * 7 + day - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) return const Expanded(child: SizedBox());

                final dateKey = '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                final seconds = monthData[dateKey] ?? 0;
                final isToday = dateKey == todayKey;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(dateKey),
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: _heatColor(seconds),
                        borderRadius: BorderRadius.circular(3),
                        border: isToday ? Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.6), width: 1.2) : null,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Center(
                          child: Text('$dayNum', style: TextStyle(
                            fontSize: 9,
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                            color: isToday ? const Color(0xFF4FC3F7) : (seconds > 0 ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.2)),
                          )),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ]),
    );
  }

  Color _heatColor(int seconds) {
    final m = seconds / 60;
    if (m <= 0) return Colors.white.withOpacity(0.04);
    if (m <= 15) return const Color(0xFFE3F2FD).withOpacity(0.2);
    if (m <= 30) return const Color(0xFF90CAF9).withOpacity(0.35);
    if (m <= 60) return const Color(0xFF42A5F5).withOpacity(0.5);
    if (m <= 120) return const Color(0xFF1E88E5).withOpacity(0.65);
    return const Color(0xFF6A1B9A).withOpacity(0.8);
  }
}

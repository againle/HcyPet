import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../bloc/study_bloc.dart';
import '../../bloc/vision_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../../models/study_state.dart';
import '../../services/study_history_service.dart';
import '../../services/vision_service.dart';
import '../pet/pet_widget.dart';
import '../widgets/heatmap_calendar.dart';

/// 自习室页面 V3
class StudyPage extends StatefulWidget {
  const StudyPage({super.key});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  final TextEditingController _durationController = TextEditingController(text: '25');
  bool _visionEnabled = false;
  VisionResult? _lastVisionResult;
  double _focusTrend = 0.0;

  // 日历状态
  bool _calendarExpanded = false;
  bool _showYearView = false;
  AnimationController? _calendarAnim;
  Animation<double>? _calendarHeight;
  DateTime _calendarMonth = DateTime.now();
  int _calendarYear = DateTime.now().year;

  // 历史数据
  Map<String, int> _monthData = {};
  int _streak = 0;
  int _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    _calendarAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _calendarHeight = CurvedAnimation(parent: _calendarAnim!, curve: Curves.easeOutCubic);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _calendarAnim?.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    final h = StudyHistoryService();
    final now = DateTime.now();
    _monthData = await h.getMonthData(now.year, now.month);
    _streak = await h.getStreak();
    final tk = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _todayTotal = await h.getDayTotalSeconds(tk);
    if (mounted) setState(() {});
  }

  void _switchMode(int index, StudyBloc studyBloc) {
    setState(() => _selectedTabIndex = index);
    studyBloc.add(StudyResetEvent());
  }

  void _toggleCalendar() {
    setState(() {
      _calendarExpanded = !_calendarExpanded;
      if (_calendarExpanded) {
        _calendarMonth = DateTime.now();
        _calendarYear = DateTime.now().year;
        _showYearView = false;
        _calendarAnim?.forward();
      } else {
        _calendarAnim?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StudyBloc()),
        BlocProvider(create: (_) => VisionBloc()),
      ],
      child: Builder(
        builder: (ctx) {
          final studyBloc = ctx.read<StudyBloc>();
          return MultiBlocListener(
            listeners: [
              BlocListener<StudyBloc, StudyState>(
                listener: (context, state) {
                  final petBloc = context.read<PetBloc>();
                  if (state.status == TimerStatus.running) {
                    petBloc.add(PetStartStudyingEvent());
                    _visionEnabled = true;
                    context.read<VisionBloc>().add(VisionStartEvent());
                  } else if (state.status == TimerStatus.idle) {
                    petBloc.add(PetStopStudyingEvent());
                    _visionEnabled = false;
                    _lastVisionResult = null;
                    context.read<VisionBloc>().add(VisionStopEvent());
                    // 学习结束: 宠物庆祝表现
                    if (state.completedSession != null) {
                      _celebrateStudyEnd(petBloc, state.completedSession!);
                    }
                    _loadHistoryData();
                  }
                },
              ),
              BlocListener<VisionBloc, VisionState>(
                listenWhen: (p, c) => p.lastResult != c.lastResult,
                listener: (context, state) {
                  if (state.lastResult != null) _onVisionUpdate(context, state);
                },
              ),
            ],
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(children: [
                  const SizedBox(height: 4),
                  _buildCalendarPanel(),
                  _buildModeTabs(studyBloc),
                  Expanded(flex: 3, child: _buildTimerDisplay(studyBloc)),
                  Expanded(flex: 2, child: _buildPetCompanion()),
                  _buildControlButtons(studyBloc),
                  _buildVisionStatus(),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // 日历面板（下拉展开）
  // ================================================================

  Widget _buildCalendarPanel() {
    return Column(children: [
      // 收起时的摘要条
      GestureDetector(
        onTap: _toggleCalendar,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today, size: 12, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
            const SizedBox(width: 8),
            Text('今日 ${(_todayTotal / 60).toStringAsFixed(0)} 分',
                style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withOpacity(0.5))),
            const Spacer(),
            Text('连续 $_streak 天',
                style: TextStyle(fontSize: 10, color: const Color(0xFF4FC3F7).withOpacity(0.3))),
            const SizedBox(width: 4),
            Icon(_calendarExpanded ? Icons.expand_less : Icons.expand_more,
                size: 14, color: const Color(0xFF4FC3F7).withOpacity(0.3)),
          ]),
        ),
      ),

      // 展开的日历区域（限高防溢出）
      SizeTransition(
        sizeFactor: _calendarHeight ?? const AlwaysStoppedAnimation(0.0),
        axisAlignment: -1,
        child: _calendarExpanded
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(child: _buildExpandedCalendar()),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildExpandedCalendar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: _showYearView ? _buildYearView() : _buildMonthView(),
    );
  }

  // ---- 月视图 ----
  Widget _buildMonthView() {
    final monthLabel = '${_calendarMonth.year}年${_calendarMonth.month}月';
    return Column(children: [
      // 导航栏
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() {
              _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
              _loadMonthData(_calendarMonth.year, _calendarMonth.month);
            }),
            child: Icon(Icons.chevron_left, size: 16, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _showYearView = true;
                _calendarYear = _calendarMonth.year;
              }),
              child: Text(monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4FC3F7))),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
              _loadMonthData(_calendarMonth.year, _calendarMonth.month);
            }),
            child: Icon(Icons.chevron_right, size: 16, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      // 月历热力图
      HeatmapCalendar(
        year: _calendarMonth.year,
        month: _calendarMonth.month,
        monthData: _monthData,
        onDayTap: (dateKey) => _showDayDetail(dateKey),
      ),
      // 图例
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('少', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.2))),
          const SizedBox(width: 2),
          ...[0, 15, 30, 60, 120, 240].map((m) => Container(
            width: 9, height: 9, margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: _heatColor(m * 60), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(width: 2),
          Text('多', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.2))),
        ]),
      ),
    ]);
  }

  // ---- 年视图 ----
  Widget _buildYearView() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _calendarYear--),
            child: Icon(Icons.chevron_left, size: 16, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showYearView = false),
              child: Text('${_calendarYear}年', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4FC3F7))),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _calendarYear++),
            child: Icon(Icons.chevron_right, size: 16, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: List.generate(12, (i) {
            final m = i + 1;
            final days = _generateMonthMini(_calendarYear, m);
            return GestureDetector(
              onTap: () => setState(() {
                _calendarMonth = DateTime(_calendarYear, m);
                _showYearView = false;
                _loadMonthData(_calendarYear, m);
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(6)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$m月', style: TextStyle(fontSize: 9, color: const Color(0xFF4FC3F7).withOpacity(0.5))),
                  const SizedBox(height: 2),
                  Expanded(child: _MiniMonthGrid(days: days)),
                ]),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  List<double> _generateMonthMini(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (d) {
      final dk = '$year-${month.toString().padLeft(2, '0')}-${(d+1).toString().padLeft(2, '0')}';
      return (_monthData[dk] ?? 0) / 3600.0; // hours
    });
  }

  Future<void> _loadMonthData(int year, int month) async {
    final h = StudyHistoryService();
    _monthData = await h.getMonthData(year, month);
    if (mounted) setState(() {});
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

  // ================================================================
  // 学习结束 → 宠物庆祝
  // ================================================================

  void _celebrateStudyEnd(PetBloc petBloc, StudySession session) {
    final mins = (session.totalSeconds / 60).toStringAsFixed(0);
    final focus = (session.avgFocus * 100).toInt();
    String thought;
    if (focus >= 80) thought = '太厉害了！${mins}分钟深度专注';
    else if (focus >= 60) thought = '完成了${mins}分钟，做得不错';
    else thought = '${mins}分钟，完成了就是胜利';

    petBloc.add(PetStopStudyingEvent());
    // 延迟一帧让状态更新后再设置庆祝
    Future.microtask(() {
      petBloc.add(PetSetActivityEvent(PetActivity.celebrating));
      petBloc.add(PetSetMoodEvent(PetMood.happy));
    });
    // thought 通过 PetBloc 的内部机制设置
    final state = petBloc.state;
    petBloc.add(PetTalkEvent(message: thought));
  }

  // ================================================================
  // 日历格子点击 → 专注度曲线图
  // ================================================================

  Future<void> _showDayDetail(String dateKey) async {
    final h = StudyHistoryService();
    final sessions = await h.getDaySessions(dateKey);
    final curve = await h.getDayFocusCurve(dateKey);
    if (!mounted) return;

    final todayKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final isFuture = dateKey.compareTo(todayKey) > 0;
    final totalSec = sessions.fold<int>(0, (s, ss) => s + ss.totalSeconds);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _DayFocusChart(dateKey: dateKey, curve: curve, totalSec: totalSec,
          sessions: sessions, isFuture: isFuture),
    );
  }

  // ================================================================
  // 计时器 / 模式标签 / 宠物 / 按钮 / 视觉 (保持原有)
  // ================================================================

  Widget _buildModeTabs(StudyBloc studyBloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _buildTab('正向', 0, studyBloc), _buildTab('倒向', 1, studyBloc), _buildTab('番茄钟', 2, studyBloc),
        ]),
      ),
    );
  }

  Widget _buildTab(String label, int index, StudyBloc studyBloc) {
    final active = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchMode(index, studyBloc),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? const Color(0xFF4FC3F7).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? const Color(0xFF4FC3F7) : const Color(0xFF4FC3F7).withOpacity(0.25))),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(StudyBloc studyBloc) {
    return BlocBuilder<StudyBloc, StudyState>(
      builder: (context, state) {
        final isIdle = state.status == TimerStatus.idle;
        final isCompleted = state.status == TimerStatus.completed;
        final isRunning = state.status == TimerStatus.running;
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_selectedTabIndex == 0 && isIdle)
            const Padding(padding: EdgeInsets.only(bottom: 12),
                child: Text('正向计时（无目标限制）', style: TextStyle(fontSize: 11, color: Color(0x4D4FC3F7)))),
          if (_selectedTabIndex == 1 && isIdle) _buildDurationInput(),
          if (_selectedTabIndex == 2 && isIdle) _buildPomodoroPreset(),
          Text(state.timeDisplay, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w200,
              color: isCompleted ? Colors.green.withOpacity(0.5) : const Color(0xFF4FC3F7), letterSpacing: 6)),
          const SizedBox(height: 4),
          Text(state.phaseLabel, style: TextStyle(fontSize: 12, color: const Color(0xFF4FC3F7).withOpacity(0.35))),
          if (isRunning)
            Text('专注 ${state.focusScore}', style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withOpacity(0.25))),
          if (!isIdle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (_selectedTabIndex == 1 || _selectedTabIndex == 2) ? state.progress : (state.elapsedSeconds / 3600.0).clamp(0.0, 1.0),
                  minHeight: 2, backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4FC3F7).withOpacity(0.3)),
                ),
              ),
            ),
        ]);
      },
    );
  }

  Widget _buildDurationInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('倒计时 ', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
        SizedBox(width: 44,
            child: TextField(controller: _durationController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4FC3F7)),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.15))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.4)))))),
        const SizedBox(width: 4),
        const Text('分钟', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
      ]),
    );
  }

  Widget _buildPomodoroPreset() {
    final presets = [25, 45, 50, 90];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        const Text('番茄钟', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: presets.map((mins) {
              final sel = _durationController.text == '$mins';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _durationController.text = '$mins'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF4FC3F7).withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? const Color(0xFF4FC3F7).withOpacity(0.25) : const Color(0xFF4FC3F7).withOpacity(0.08)),
                    ),
                    child: Text('$mins min', style: TextStyle(fontSize: 11,
                        color: sel ? const Color(0xFF4FC3F7) : const Color(0xFF4FC3F7).withOpacity(0.3))),
                  ),
                ),
              );
            }).toList()),
      ]),
    );
  }

  Widget _buildPetCompanion() {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          PetWidget(state: petState, size: 100),
          if (petState.thought != null)
            Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(petState.thought!, style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withOpacity(0.25)))),
          BlocBuilder<StudyBloc, StudyState>(
            builder: (context, s) {
              if (s.status == TimerStatus.running)
                return Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(_getStudyStatusText(), style: TextStyle(fontSize: 10, color: _getStudyStatusColor())));
              return const SizedBox.shrink();
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildControlButtons(StudyBloc studyBloc) {
    return BlocBuilder<StudyBloc, StudyState>(
      builder: (context, state) {
        final isIdle = state.status == TimerStatus.idle;
        final isRunning = state.status == TimerStatus.running;
        final isPaused = state.status == TimerStatus.paused;
        final isCompleted = state.status == TimerStatus.completed;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (isIdle || isPaused)
              _buildBtn(isPaused ? '继续' : '开始', () {
                if (isIdle) {
                  final mode = _selectedTabIndex == 0 ? TimerMode.forward : _selectedTabIndex == 1 ? TimerMode.countdown : TimerMode.pomodoro;
                  studyBloc.add(StudyStartEvent(mode: mode, durationSeconds: (int.tryParse(_durationController.text) ?? 25) * 60));
                } else { studyBloc.add(StudyResumeEvent()); }
              }),
            if (isRunning) _buildBtn('暂停', () => studyBloc.add(StudyPauseEvent())),
            if (!isIdle) ...[
              const SizedBox(width: 12),
              _buildBtn(isCompleted ? '重置' : '停止', () {
                studyBloc.add(StudyStopEvent());
                Future.delayed(const Duration(milliseconds: 200), () => studyBloc.add(StudyResetEvent()));
              }, secondary: true),
            ],
          ]),
        );
      },
    );
  }

  Widget _buildBtn(String label, VoidCallback onTap, {bool secondary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
            color: secondary ? Colors.white.withOpacity(0.02) : const Color(0xFF4FC3F7).withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secondary ? Colors.white.withOpacity(0.05) : const Color(0xFF4FC3F7).withOpacity(0.1))),
        child: Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF4FC3F7).withOpacity(secondary ? 0.25 : 0.7))),
      ),
    );
  }

  String _getStudyStatusText() {
    final vr = _lastVisionResult;
    if (!_visionEnabled || vr == null) return '';
    if (vr.emotion.needsIntervention) return vr.emotion.interventionReason;
    return vr.studyStatusText;
  }

  Color _getStudyStatusColor() {
    final vr = _lastVisionResult;
    if (!_visionEnabled || vr == null) return const Color(0xFF4FC3F7).withOpacity(0.15);
    if (vr.emotion.needsIntervention) return Colors.amber.withOpacity(0.3);
    if (vr.focusScore > 0.7) return Colors.green.withOpacity(0.3);
    return const Color(0xFF4FC3F7).withOpacity(0.25);
  }

  Widget _buildVisionStatus() {
    return BlocBuilder<VisionBloc, VisionState>(
      builder: (context, state) {
        final hasError = state.errorMessage != null;
        final isRunning = state.isDetecting && !hasError;
        final vr = _lastVisionResult;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 4, height: 4,
                decoration: BoxDecoration(color: hasError ? Colors.red.withOpacity(0.3) : isRunning ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.15), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(hasError ? '无法启动' : isRunning && vr != null ? '${vr.scene.label}  ${(vr.focusScore*100).toInt()}%' : isRunning ? '视觉追踪中' : '已停止',
                style: TextStyle(fontSize: 9, color: hasError ? Colors.red.withOpacity(0.2) : const Color(0xFF4FC3F7).withOpacity(0.18))),
          ]),
          if (isRunning && vr != null) ...[const SizedBox(height: 3), _buildEmotionMiniBars(vr.emotion)],
        ]);
      },
    );
  }

  Widget _buildEmotionMiniBars(EmotionSpectrum e) {
    final items = [('静', e.calm, const Color(0xFF4FC3F7)), ('专', e.focused, const Color(0xFF42A5F5)),
      ('烦', e.frustrated, Colors.orange), ('闷', e.bored, Colors.grey), ('悦', e.happy, Colors.pink),
      ('虑', e.anxious, Colors.purple), ('疲', e.tired, Colors.red)];
    return Row(mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((item) {
          final (label, value, color) = item;
          final active = value > 0.25;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(children: [
                Container(width: 12, height: 3, decoration: BoxDecoration(color: color.withOpacity(active ? 0.6 : 0.1), borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 7, color: color.withOpacity(active ? 0.4 : 0.1))),
              ]));
        }).toList());
  }

  void _onVisionUpdate(BuildContext context, VisionState state) {
    final vr = state.lastResult!;
    _lastVisionResult = vr;
    _focusTrend = state.focusTrend;
    context.read<PetBloc>().add(PetVisionEvent(emotion: vr.emotion.dominantEmotion, attentionScore: vr.focusScore, visionResult: vr));
    context.read<StudyBloc>().add(StudyFocusDataEvent(vr.focusScore));
  }
}

// ================================================================
// 日详情：专注度折线图
// ================================================================

class _DayFocusChart extends StatelessWidget {
  final String dateKey;
  final List<FocusSample> curve;
  final int totalSec;
  final List<StudySession> sessions;
  final bool isFuture;

  const _DayFocusChart({required this.dateKey, required this.curve, required this.totalSec,
      required this.sessions, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(dateKey, style: const TextStyle(fontSize: 16, color: Color(0xFF4FC3F7))),
        const SizedBox(height: 4),
        Text(isFuture ? '暂无记录' : '累计 ${(totalSec / 60).toStringAsFixed(0)} 分钟',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
        if (!isFuture) ...[
          const SizedBox(height: 12),
          _buildChart(),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0:00', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25))),
            Text('24:00', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25))),
          ]),
        ],
        if (isFuture)
          Padding(padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('这一天还没到', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.2))))),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 160,
      child: CustomPaint(
        size: const Size(double.infinity, 160),
        painter: _FocusCurvePainter(curve: curve, showGrid: true),
      ),
    );
  }
}

// ================================================================
// 年视图迷你月网格
// ================================================================

class _MiniMonthGrid extends StatelessWidget {
  final List<double> days;
  const _MiniMonthGrid({required this.days});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = (constraints.maxWidth / 7).floor().clamp(4, 10);
      final rows = (days.length / cols).ceil();
      return Column(
        children: List.generate(rows, (r) {
          return Row(
            children: List.generate(cols, (c) {
              final idx = r * cols + c;
              if (idx >= days.length) return const Expanded(child: SizedBox());
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: _miniColor(days[idx]),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          );
        }),
      );
    });
  }

  Color _miniColor(double hours) {
    if (hours <= 0) return Colors.white.withOpacity(0.04);
    if (hours <= 0.25) return const Color(0xFF90CAF9).withOpacity(0.3);
    if (hours <= 0.5) return const Color(0xFF42A5F5).withOpacity(0.5);
    if (hours <= 1.0) return const Color(0xFF1E88E5).withOpacity(0.65);
    return const Color(0xFF6A1B9A).withOpacity(0.8);
  }
}

// ================================================================
// 专注度曲线绘制器
// ================================================================

class _FocusCurvePainter extends CustomPainter {
  final List<FocusSample> curve;
  final bool showGrid;
  final bool use24hScale; // true=固定24h, false=动态比例

  _FocusCurvePainter({required this.curve, this.showGrid = false, this.use24hScale = true});

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = Color(0xFF42A5F5);
    const daySeconds = 86400.0;

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    if (showGrid) {
      final gp = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5;
      for (int i = 1; i < 4; i++) canvas.drawLine(Offset(0, size.height*i/4), Offset(size.width, size.height*i/4), gp);
      canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2), Paint()..color=Colors.white.withOpacity(0.06)..strokeWidth=0.5);
    }

    if (curve.isEmpty) {
      final zp = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, size.height-6), Offset(size.width, size.height-6), zp);
      return;
    }

    if (curve.length < 2) {
      // 单点画小横线
      final s = curve.first;
      final x = (s.elapsedSeconds / (use24hScale ? daySeconds : (s.elapsedSeconds > 1 ? s.elapsedSeconds.toDouble() : 1.0))) * size.width;
      final y = size.height - (s.focusScore * size.height * 0.88) - 6;
      final dp = Paint()..color = lineColor.withOpacity(0.4)..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 3, dp);
      return;
    }

    final maxSec = use24hScale ? daySeconds : curve.last.elapsedSeconds.toDouble().clamp(1, daySeconds);

    final linePath = Path();
    bool first = true;
    double firstX = 0, firstY = 0, lastX = 0;
    for (final s in curve) {
      final x = (s.elapsedSeconds / maxSec) * size.width;
      final y = size.height - (s.focusScore * size.height * 0.88) - 6;
      if (first) { linePath.moveTo(x, y); firstX = x; firstY = y; first = false; }
      else { linePath.lineTo(x, y); }
      lastX = x;
    }

    // 填充仅在详细图表时绘制
    if (showGrid) {
      final fillPath = Path()..moveTo(firstX, firstY);
      for (int i = 1; i < curve.length; i++) {
        final s = curve[i];
        fillPath.lineTo((s.elapsedSeconds / maxSec) * size.width, size.height - (s.focusScore * size.height * 0.88) - 6);
      }
      fillPath.lineTo(lastX, size.height);
      fillPath.lineTo(firstX, size.height);
      fillPath.close();

      fillPaint.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.18), lineColor.withOpacity(0.0)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }
    paint.color = lineColor.withOpacity(0.6);
    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FocusCurvePainter old) => old.curve != curve;
}


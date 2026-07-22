import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../bloc/study_bloc.dart';
import '../../bloc/vision_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../../models/study_state.dart';
import '../../services/vision_service.dart';
import '../pet/pet_widget.dart';

/// 自习室页面
class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  int _selectedTabIndex = 0;
  final TextEditingController _durationController = TextEditingController(text: '25');
  bool _visionEnabled = false;
  String _lastEmotion = 'neutral';
  double _lastAttentionScore = 0;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  void _switchMode(int index, StudyBloc studyBloc) {
    setState(() => _selectedTabIndex = index);
    studyBloc.add(StudyResetEvent());
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
                    context.read<VisionBloc>().add(VisionStopEvent());
                  }
                },
              ),
              BlocListener<VisionBloc, VisionState>(
                listenWhen: (p, c) => p.lastResult != c.lastResult,
                listener: (context, state) {
                  if (state.lastResult != null) {
                    _onEmotionDetected(context, state.lastResult!);
                  }
                },
              ),
            ],
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildModeTabs(studyBloc),
                    Expanded(
                      flex: 3,
                      child: _buildTimerDisplay(studyBloc),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildPetCompanion(),
                    ),
                    _buildControlButtons(studyBloc),
                    _buildVisionStatus(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeTabs(StudyBloc studyBloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _buildTab('正向', 0, studyBloc),
            _buildTab('倒向', 1, studyBloc),
            _buildTab('番茄钟', 2, studyBloc),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, StudyBloc studyBloc) {
    final isActive = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchMode(index, studyBloc),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4FC3F7).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? const Color(0xFF4FC3F7)
                  : const Color(0xFF4FC3F7).withOpacity(0.25),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(StudyBloc studyBloc) {
    return BlocBuilder<StudyBloc, StudyState>(
      builder: (context, state) {
        final isRunning = state.status == TimerStatus.running;
        final isIdle = state.status == TimerStatus.idle;
        final isCompleted = state.status == TimerStatus.completed;
        final isForward = _selectedTabIndex == 0;
        final isCountdown = _selectedTabIndex == 1;
        final isPomodoro = _selectedTabIndex == 2;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 正向计时：目标输入 ---
            if (isForward && isIdle)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '正向计时（无目标限制）',
                  style: TextStyle(fontSize: 11, color: Color(0x4D4FC3F7)),
                ),
              ),

            // --- 倒计时：目标输入 ---
            if (isCountdown && isIdle)
              _buildDurationInput(),

            // --- 番茄钟：预设选择 ---
            if (isPomodoro && isIdle)
              _buildPomodoroPreset(),

            // --- 大时间显示 ---
            Text(
              state.timeDisplay,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w200,
                color: isCompleted
                    ? Colors.green.withOpacity(0.5)
                    : isPomodoro && state.pomodoroPhase == PomodoroPhase.rest
                        ? const Color(0xFF4FC3F7).withOpacity(0.5)
                        : const Color(0xFF4FC3F7),
                letterSpacing: 6,
              ),
            ),

            const SizedBox(height: 8),

            // --- 阶段标签 ---
            Text(
              state.phaseLabel,
              style: TextStyle(fontSize: 12, color: const Color(0xFF4FC3F7).withOpacity(0.35)),
            ),

            // --- 进度条 ---
            if (!isIdle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: isCountdown || isPomodoro ? 1.0 - (isIdle ? 0.0 : state.progress) : state.progress,
                    minHeight: 2,
                    backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPomodoro && state.pomodoroPhase == PomodoroPhase.rest
                          ? Colors.green.withOpacity(0.3)
                          : const Color(0xFF4FC3F7).withOpacity(0.3),
                    ),
                  ),
                ),
              ),

            // --- 番茄计数 ---
            if (isPomodoro && state.pomodoroCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    state.pomodoroCount > 8 ? 8 : state.pomodoroCount,
                    (i) => Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7).withOpacity(i == (state.pomodoroCount > 8 ? 7 : state.pomodoroCount - 1) ? 0.5 : 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

            // --- 完成后的操作 ---
            if (isCompleted && isPomodoro)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => _nextPomodoroPhase(studyBloc, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FC3F7).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.1)),
                    ),
                    child: Text(
                      state.pomodoroPhase == PomodoroPhase.work ? '开始休息' : '开始下一轮',
                      style: const TextStyle(fontSize: 12, color: Color(0x804FC3F7)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _nextPomodoroPhase(StudyBloc studyBloc, StudyState state) {
    studyBloc.add(StudyResetEvent());
  }

  Widget _buildDurationInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('倒计时 ', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
          SizedBox(
            width: 44,
            child: TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF4FC3F7)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.15)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text('分钟', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
        ],
      ),
    );
  }

  Widget _buildPomodoroPreset() {
    final presets = [25, 45, 50, 90];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          const Text('番茄钟', style: TextStyle(fontSize: 13, color: Color(0x4D4FC3F7))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: presets.map((mins) {
              final isSelected = _durationController.text == '$mins';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _durationController.text = '$mins'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4FC3F7).withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4FC3F7).withOpacity(0.25)
                            : const Color(0xFF4FC3F7).withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      '$mins min',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? const Color(0xFF4FC3F7)
                            : const Color(0xFF4FC3F7).withOpacity(0.3),
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCompanion() {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PetWidget(state: petState, size: 100),
              if (petState.thought != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    petState.thought!,
                    style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withOpacity(0.25)),
                  ),
                ),
              BlocBuilder<StudyBloc, StudyState>(
                builder: (context, studyState) {
                  if (studyState.status == TimerStatus.running) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _getStudyStatusText(),
                        style: TextStyle(fontSize: 10, color: _getStudyStatusColor()),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isIdle || isPaused)
                _buildBtn(
                  isPaused ? '继续' : '开始',
                  () {
                    if (isIdle) {
                      final mode = _selectedTabIndex == 0
                          ? TimerMode.forward
                          : _selectedTabIndex == 1
                              ? TimerMode.countdown
                              : TimerMode.pomodoro;
                      final mins = int.tryParse(_durationController.text) ?? 25;
                      studyBloc.add(StudyStartEvent(mode: mode, durationSeconds: mins * 60));
                    } else {
                      studyBloc.add(StudyResumeEvent());
                    }
                  },
                ),
              if (isRunning)
                _buildBtn('暂停', () => studyBloc.add(StudyPauseEvent())),
              if (!isIdle) ...[
                const SizedBox(width: 12),
                _buildBtn(isCompleted ? '重置' : '停止', () => studyBloc.add(StudyResetEvent()), secondary: true),
              ],
            ],
          ),
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
          border: Border.all(
            color: secondary ? Colors.white.withOpacity(0.05) : const Color(0xFF4FC3F7).withOpacity(0.1),
          ),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF4FC3F7).withOpacity(secondary ? 0.25 : 0.7))),
      ),
    );
  }

  String _getStudyStatusText() {
    if (_visionEnabled && _lastAttentionScore < 40) return '你走神了...';
    if (_visionEnabled && _lastEmotion == 'sad') return '别难过，我在这儿陪你';
    if (_visionEnabled && _lastEmotion == 'angry') return '深呼吸，放松一下~';
    return '认真陪伴中...';
  }

  Color _getStudyStatusColor() {
    if (_visionEnabled && _lastAttentionScore < 40) return Colors.orange.withOpacity(0.25);
    if (_visionEnabled && (_lastEmotion == 'sad' || _lastEmotion == 'angry')) return Colors.pink.withOpacity(0.25);
    return const Color(0xFF4FC3F7).withOpacity(0.15);
  }

  Widget _buildVisionStatus() {
    return BlocBuilder<VisionBloc, VisionState>(
      builder: (context, state) {
        final hasError = state.errorMessage != null;
        final isRunning = state.isEnabled && !hasError;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 4, height: 4, decoration: BoxDecoration(
              color: hasError
                  ? Colors.red.withOpacity(0.3)
                  : isRunning
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.15),
              shape: BoxShape.circle,
            )),
            const SizedBox(width: 5),
            Text(
              hasError
                  ? '无法启动'
                  : isRunning
                      ? '视觉追踪中'
                      : '已停止',
              style: TextStyle(
                fontSize: 8,
                color: hasError
                    ? Colors.red.withOpacity(0.15)
                    : const Color(0xFF4FC3F7).withOpacity(0.1),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onEmotionDetected(BuildContext context, EmotionResult result) {
    _lastEmotion = result.emotion;
    _lastAttentionScore = result.attentionScore;
    if (result.isNegative && result.confidence > 0.6) {
      context.read<PetBloc>().add(PetVisionEvent(
        emotion: result.emotion,
        attentionScore: result.attentionScore,
      ));
    }
    context.read<StudyBloc>().add(StudyFocusUpdateEvent(result.isAttention));
  }
}

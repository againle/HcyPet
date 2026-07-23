import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../../models/growth_state.dart';
import '../../services/sensor_service.dart';
import '../../theme/design_constants.dart';
import '../pet/gesture_engine.dart';
import '../pet/pet_widget.dart';
import '../pet/pet_painter.dart'; // EyeFlavor
import '../widgets/talk_button.dart';

/// ============================================================
/// 🍡 Mochi V3 主页 — 全触屏交互 + 弹簧物理
/// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SensorService _sensorService = SensorService();
  final GlobalKey<_PetWidgetWrapperState> _petKey = GlobalKey();
  final List<DateTime> _shakeTimes = [];
  static const _shakeWindow = Duration(seconds: 2);
  static const _minShakes = 3;

  @override
  void initState() {
    super.initState();
    _initSensor();
  }

  @override
  void dispose() {
    _sensorService.stopListening();
    super.dispose();
  }

  void _initSensor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sensorService.startListening(
          onShake: () {
            if (mounted) {
              final now = DateTime.now();
              _shakeTimes.removeWhere((t) => now.difference(t) > _shakeWindow);
              _shakeTimes.add(now);
              HapticFeedback.heavyImpact();
              context.read<PetBloc>().add(PetShakeEvent());
              _petKey.currentState?.triggerStartle();
              // 抖动越久晕越久：次数越多duration越长
              if (_shakeTimes.length >= _minShakes) {
                final extraMs = (_shakeTimes.length - _minShakes) * 300;
                // V4: lazy 性格 → 晕眩时间减半
                final moodBias = context.read<PetBloc>().aiMoodBias;
                final factor = moodBias == 'lazy' ? 0.5 : 1.0;
                final dazeMs = ((1500 + extraMs) * factor).toInt();
                _petKey.currentState?.triggerDazed(Duration(milliseconds: dazeMs));
                _shakeTimes.clear();
              }
            }
          },
          onAccelerometerUpdate: (x, y, z) {},
        );
      }
    });
  }

  // ============================================================
  // 手势处理
  // ============================================================

  void _onLongPressStart() {
    HapticFeedback.mediumImpact();
    // V4: 长按 = Cheeky → 平静
    _petKey.currentState?.triggerCheeky();
    context.read<PetBloc>().add(PetSetMoodEvent(PetMood.calm));
  }

  void _onLongPressEnd() {
    // 长按结束，恢复平静
  }

  void _onMultiTap() {
    HapticFeedback.heavyImpact();
    context.read<PetBloc>().add(PetPetEvent());
    // 连击 → 瞳孔地震 + 惊讶
    _petKey.currentState?.triggerStartle();
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    // V4: 双击 = 轻微挤压(预期动画) → Wink → 平静
    _petKey.currentState?.applySquash(0.3);
    Future.delayed(const Duration(milliseconds: 120), () {
      _petKey.currentState?.applySquash(0.0);
      _petKey.currentState?.triggerWink();
      context.read<PetBloc>().add(PetSetMoodEvent(PetMood.calm));
    });
  }

  bool _isSwiping = false;

  void _onPanUpdate(Offset delta) {
    // 橡皮拉伸：根据位移量挤压/拉伸眼睛
    final screenW = MediaQuery.of(context).size.width;
    final stretch = (delta.dx / screenW).clamp(-1.0, 1.0);
    _petKey.currentState?.applySquash(stretch);
    if (delta.distance > 3) {
      HapticFeedback.selectionClick();
      _isSwiping = true;
    }
  }

  void _onPanEnd(Offset velocity) {
    // 松手回弹（不再晕眩）
    _petKey.currentState?.applySquash(0.0);
    // V4: 滑动 = 抚摸，纯开心
    if (_isSwiping) {
      _isSwiping = false;
      context.read<PetBloc>().add(PetPetEvent());
      _petKey.currentState?.triggerHappyBounce();
    }
  }

  void _onDragThrow(Offset velocity) {
    HapticFeedback.mediumImpact();
    // 拖拽扔出 → 挤压形变（不再晕眩）
    final strength = velocity.distance.clamp(0.0, 2000.0) / 2000.0;
    _petKey.currentState?.applySquash(strength);
    Future.delayed(const Duration(milliseconds: 300), () {
      _petKey.currentState?.applySquash(0.0);
    });
    context.read<PetBloc>().add(PetShakeEvent());
  }

  void _onPinchUpdate(double scale) {
    _petKey.currentState?.setPinchScale(scale);
  }

  void _onPinchEnd() {
    _petKey.currentState?.resetPinchScale();
  }

  // ============================================================
  // 构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final bloc = context.read<PetBloc>();
        return SafeArea(
          child: Column(
            children: [
              // ── 极简状态条 ──
              _buildTopBar(state),

              // ── 宠物显示区域（全手势） ──
              Expanded(
                flex: 5,
                child: Center(
                  child: GestureEngine(
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                    onMultiTap: _onMultiTap,
                    onDoubleTap: _onDoubleTap,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onDragThrow: _onDragThrow,
                    onPinchUpdate: _onPinchUpdate,
                    onPinchEnd: _onPinchEnd,
                    onTap: () {},
                    child: _PetWidgetWrapper(
                      key: _petKey,
                      state: state,
                      aiBoost: bloc.aiBoost,
                    ),
                  ),
                ),
              ),

              // ── 系统提示 ──
              _buildSystemHint(state),

              const SizedBox(height: AppSpacing.md),

              // ── 快捷互动按钮 ──
              _buildInteractionButtons(context, bloc),

              const SizedBox(height: AppSpacing.xs),

              // ── 传感器微点指示 ──
              _buildSensorDot(),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 顶部状态条
  // ============================================================

  Widget _buildTopBar(PetState state) {
    final growth = (() {
      try {
        return context.read<PetBloc>().growth;
      } catch (_) {
        return GrowthState.initial();
      }
    })();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'Lv.${growth.level}',
            style: TextStyle(
              fontSize: 10,
              color: kAccentColor.withValues(alpha: 0.85),
              fontWeight: kFontMedium,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            growth.levelTitle,
            style: TextStyle(
              fontSize: 9,
              color: kAccentColor.withValues(alpha: 0.45),
              fontWeight: kFontThin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: growth.experience,
                minHeight: 2,
                backgroundColor: const Color(0x0AFF6B9D),
                valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildStatItem('心情', state.happiness),
                const SizedBox(width: 4),
                _buildStatItem('精力', state.energy),
                const SizedBox(width: 4),
                _buildStatItem('亲密', state.intimacy, isAccent: true),
                const SizedBox(width: 3),
                Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  state.isAwake ? '清醒' : '休眠',
                  style: TextStyle(
                    fontSize: 7.5,
                    color: state.isAwake
                        ? kPrimaryColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.18),
                    fontWeight: kFontThin,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, {bool isAccent = false}) {
    final color = isAccent ? kAccentColor : kPrimaryColor;
    return Text(
      '$label ${(value * 100).toInt()}%',
      style: TextStyle(
        fontSize: 8.5,
        color: color.withValues(alpha: 0.65),
        fontWeight: kFontRegular,
      ),
    );
  }

  // ============================================================
  // 系统提示
  // ============================================================

  Widget _buildSystemHint(PetState state) {
    if (state.thought == null || state.thought!.isEmpty) {
      return const SizedBox(height: SystemHintSpec.fontSize * 1.5);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Text(
        state.thought!,
        style: TextStyle(
          fontSize: SystemHintSpec.fontSize,
          color: SystemHintSpec.textColor
              .withValues(alpha: SystemHintSpec.textOpacity),
          fontWeight: kFontThin,
          letterSpacing: 0.8,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ============================================================
  // 互动按钮
  // ============================================================

  Widget _buildInteractionButtons(BuildContext context, PetBloc bloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextIconButton(
            icon: AppIcons.pet,
            label: '抚触',
            onTap: () {
              HapticFeedback.lightImpact();
              bloc.add(PetPetEvent());
              _petKey.currentState?.triggerHappyBounce();
            },
          ),
          SizedBox(width: InteractionButtonSpec.spacing + 8),
          _buildTextIconButton(
            icon: AppIcons.feed,
            label: '喂食',
            onTap: () {
              HapticFeedback.lightImpact();
              bloc.add(PetFeedEvent());
              _petKey.currentState?.triggerHappyBounce();
            },
          ),
          SizedBox(width: InteractionButtonSpec.spacing + 8),
          _buildTalkButton(context),
        ],
      ),
    );
  }

  Widget _buildTextIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: InteractionButtonSpec.iconSize,
              color: kPrimaryColor.withValues(
                alpha: InteractionButtonSpec.textOpacity,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: InteractionButtonSpec.fontSize,
                color: kPrimaryColor.withValues(
                  alpha: InteractionButtonSpec.textOpacity,
                ),
                fontWeight: kFontThin,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: InteractionButtonSpec.dotSize,
              height: InteractionButtonSpec.dotSize,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTalkButton(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TalkButton(
          size: InteractionButtonSpec.iconSize + 2,
          color: kPrimaryColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '说话',
          style: TextStyle(
            fontSize: InteractionButtonSpec.fontSize,
            color: kPrimaryColor.withValues(
              alpha: InteractionButtonSpec.textOpacity,
            ),
            fontWeight: kFontThin,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: InteractionButtonSpec.dotSize,
          height: InteractionButtonSpec.dotSize,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 传感器指示
  // ============================================================

  Widget _buildSensorDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
    );
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  void _showMoodSnackbar(BuildContext context, PetState state) {
    final moodText = switch (state.mood) {
      PetMood.happy => '😊 开心',
      PetMood.calm => '😌 平静',
      PetMood.sad => '😢 难过',
      PetMood.surprised => '😲 惊讶',
      PetMood.sleepy => '😴 困倦',
      PetMood.missing => '💭 思念',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$moodText — ${state.thought ?? "..."}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// ============================================================
/// PetWidget 包装器（暴露物理方法给 home_page）
/// ============================================================

class _PetWidgetWrapper extends StatefulWidget {
  final PetState state;
  final double aiBoost;

  const _PetWidgetWrapper({super.key, required this.state, this.aiBoost = 1.0});

  @override
  State<_PetWidgetWrapper> createState() => _PetWidgetWrapperState();
}

class _PetWidgetWrapperState extends State<_PetWidgetWrapper> {
  final GlobalKey<PetWidgetState> _innerKey = GlobalKey();

  void triggerHappyBounce() => _innerKey.currentState?.triggerHappyBounce();
  void triggerStartle() => _innerKey.currentState?.triggerStartle();
  void triggerDazed(Duration d) => _innerKey.currentState?.triggerDazed(d);
  void applySquash(double amount) => _innerKey.currentState?.applySquash(amount);
  void releaseSquash() => _innerKey.currentState?.releaseSquash();
  void setPinchScale(double s) => _innerKey.currentState?.setPinchScale(s);
  void resetPinchScale() => _innerKey.currentState?.resetPinchScale();
  /// V4: 触发 wink / cheeky 临时眼型
  void triggerWink() => _innerKey.currentState?.triggerWink();
  void triggerCheeky() => _innerKey.currentState?.triggerCheeky();

  @override
  Widget build(BuildContext context) {
    return PetWidget(
      key: _innerKey,
      state: widget.state,
      aiBoost: widget.aiBoost,
      size: PetSize.container,
    );
  }
}

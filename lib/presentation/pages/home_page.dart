import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../../services/sensor_service.dart';
import '../../theme/design_constants.dart';
import '../pet/pet_widget.dart';
import '../widgets/talk_button.dart';

/// 主页 — V2 极简风格
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SensorService _sensorService = SensorService();

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
              context.read<PetBloc>().add(PetShakeEvent());
            }
          },
          onAccelerometerUpdate: (x, y, z) {},
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final bloc = context.read<PetBloc>();
        return SafeArea(
          child: Column(
            children: [
              // --- 极简状态条（右对齐，纯文字）---
              _buildTopBar(state),

              // --- 宠物显示区域 ---
              Expanded(
                flex: 5,
                child: Center(
                  child: PetWidget(
                    state: state,
                    size: PetSize.container,
                    onTap: () => _showMoodSnackbar(context, state),
                    onDoubleTap: () => _randomMood(context),
                  ),
                ),
              ),

              // --- 系统提示（底部小字，无气泡）---
              _buildSystemHint(state),

              const SizedBox(height: AppSpacing.md),

              // --- 快捷互动按钮 ---
              _buildInteractionButtons(context, bloc),

              const SizedBox(height: AppSpacing.lg),

              // --- 状态进度条 ---
              _buildStatusIndicators(state),

              const SizedBox(height: AppSpacing.md),

              // --- 传感器微点指示 ---
              _buildSensorDot(),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  // ============ 顶部状态条（纯文字，无背景）============

  Widget _buildTopBar(PetState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 亲密度
          Text(
            '${(state.intimacy * 100).toInt()}%',
            style: TextStyle(
              fontSize: StatusBarSpec.fontSize,
              color: kAccentColor.withValues(alpha: 0.6),
              fontWeight: kFontRegular,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: StatusBarSpec.spacing),
          // 分隔微点
          Container(
            width: 2,
            height: 2,
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: StatusBarSpec.spacing),
          // 清醒/休息状态
          Text(
            state.isAwake ? '清醒' : '休息',
            style: TextStyle(
              fontSize: StatusBarSpec.fontSize,
              color: state.isAwake
                  ? kPrimaryColor.withValues(alpha: StatusBarSpec.textOpacity)
                  : Colors.white.withValues(alpha: 0.25),
              fontWeight: kFontRegular,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============ 系统提示（底部小字）============

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

  // ============ 互动按钮（纯图标 + 纯文字，无背景框）============

  Widget _buildInteractionButtons(BuildContext context, PetBloc bloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextIconButton(
            icon: AppIcons.pet,
            label: '抚触',
            onTap: () => bloc.add(PetPetEvent()),
          ),
          SizedBox(width: InteractionButtonSpec.spacing),
          _buildTextIconButton(
            icon: AppIcons.feed,
            label: '喂食',
            onTap: () => bloc.add(PetFeedEvent()),
          ),
          SizedBox(width: InteractionButtonSpec.spacing),
          // 说话按钮（保留 TalkButton 功能，样式统一）
          _buildTalkButton(context),
          SizedBox(width: InteractionButtonSpec.spacing),
          _buildTextIconButton(
            icon: AppIcons.shake,
            label: '摇一摇',
            onTap: () => bloc.add(PetShakeEvent()),
          ),
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
            // 微点指示器（激活态用）
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

  // ============ 状态进度条（2px 极细）============

  Widget _buildStatusIndicators(PetState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Row(
        children: [
          _buildProgressBar(
            label: '心情',
            value: state.happiness,
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildProgressBar(
            label: '精力',
            value: state.energy,
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildProgressBar(
            label: '亲密度',
            value: state.intimacy,
            highlightColor: kAccentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double value,
    Color? highlightColor,
  }) {
    final activeColor = highlightColor ?? ProgressBarSpec.activeColor;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ProgressBarSpec.labelFontSize,
              color: kPrimaryColor.withValues(
                alpha: ProgressBarSpec.labelOpacity,
              ),
              fontWeight: kFontThin,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(ProgressBarSpec.borderRadius),
            child: LinearProgressIndicator(
              value: value,
              minHeight: ProgressBarSpec.height,
              backgroundColor: ProgressBarSpec.bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 传感器微点 ============

  Widget _buildSensorDot() {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: _sensorService.isListening
            ? kPrimaryColor.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
    );
  }

  // ============ 调试交互 ============

  void _randomMood(BuildContext context) {
    final bloc = context.read<PetBloc>();
    final moods = PetMood.values;
    final randomIndex = DateTime.now().microsecond % moods.length;
    bloc.add(PetSetMoodEvent(moods[randomIndex]));
  }

  void _showMoodSnackbar(BuildContext context, PetState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${state.mood.name.toUpperCase()}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4FC3F7),
          ),
        ),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF4FC3F7).withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}

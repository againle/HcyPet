import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../pet/pet_widget.dart';

/// 主页（测试 G：无 SensorService、无 VoiceRecorderButton）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final bloc = context.read<PetBloc>();
        return SafeArea(
          child: Column(
            children: [
              // --- 顶部状态栏 ---
              _buildTopBar(state),

              // --- 宠物显示区域 ---
              Expanded(
                flex: 4,
                child: Center(
                  child: PetWidget(
                    state: state,
                    size: 300,
                    onTap: () => _showMoodSnackbar(context, state),
                    onDoubleTap: () => _randomMood(context),
                  ),
                ),
              ),

              // --- 宠物想法气泡 ---
              if (state.thought != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4FC3F7).withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    state.thought!,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF4FC3F7).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 12),

              // --- 快捷互动按钮 ---
              _buildInteractionButtons(context, bloc),

              const SizedBox(height: 16),

              // --- 状态指标 ---
              _buildStatusIndicators(state),

              const SizedBox(height: 20),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 顶部信息条：只保留状态信息
  Widget _buildTopBar(PetState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // 靠右对齐
        children: [
          _buildStatusChip(
            label: '❤️ ${(state.intimacy * 100).toInt()}%',
            color: Colors.pink.withOpacity(0.2),
            textColor: Colors.pink.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          _buildStatusChip(
            label: state.isAwake ? '● 清醒' : '● 休息',
            color: state.isAwake
                ? const Color(0xFF4FC3F7).withOpacity(0.12)
                : Colors.grey.withOpacity(0.12),
            textColor: state.isAwake
                ? const Color(0xFF4FC3F7).withOpacity(0.6)
                : Colors.grey.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color color,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textColor ?? Colors.white.withOpacity(0.6),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildInteractionButtons(BuildContext context, PetBloc bloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: '🤗',
            label: '抚摸',
            onTap: () => bloc.add(PetPetEvent()),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: '🍖',
            label: '喂食',
            onTap: () => bloc.add(PetFeedEvent()),
          ),
          const SizedBox(width: 16),
          // 语音按钮
          _buildActionButton(
            icon: '🎤',
            label: '说话',
            onTap: () => bloc.add(PetTalkEvent()),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: '📱',
            label: '摇晃',
            onTap: () {
              context.read<PetBloc>().add(PetShakeEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4FC3F7).withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF4FC3F7).withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(PetState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.03),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _buildIndicator(
            label: '😊 心情',
            value: state.happiness,
          ),
          const SizedBox(width: 16),
          _buildIndicator(
            label: '⚡ 精力',
            value: state.energy,
          ),
          const SizedBox(width: 16),
          _buildIndicator(
            label: '💕 亲密度',
            value: state.intimacy,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator({
    required String label,
    required double value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: const Color(0xFF4FC3F7).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                value > 0.7
                    ? const Color(0xFF4FC3F7)
                    : value > 0.3
                        ? const Color(0xFF4FC3F7).withOpacity(0.6)
                        : const Color(0xFF4FC3F7).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

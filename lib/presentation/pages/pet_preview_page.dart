import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../models/pet_state.dart';
import '../pet/pet_widget.dart';

/// 宠物预览页面 - 使用 Bloc 管理状态
class PetPreviewPage extends StatelessWidget {
  const PetPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PetBloc(),
      child: const _PetPreviewView(),
    );
  }
}

class _PetPreviewView extends StatelessWidget {
  const _PetPreviewView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PetBloc>();
    final moods = PetMood.values;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 宠物显示区域
            Expanded(
              flex: 3,
              child: Center(
                child: BlocBuilder<PetBloc, PetState>(
                  builder: (context, state) {
                    return PetWidget(
                      state: state,
                      size: 280,
                      onTap: () {
                        _showMoodSnackbar(context, state);
                      },
                      onDoubleTap: () {
                        _randomMood(context);
                      },
                    );
                  },
                ),
              ),
            ),

            // 状态信息显示
            BlocBuilder<PetBloc, PetState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Text(
                      state.mood.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF4FC3F7).withOpacity(0.5),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (state.thought != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.thought!,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF4FC3F7).withOpacity(0.3),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // 情绪切换按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: moods.map((mood) {
                  return BlocBuilder<PetBloc, PetState>(
                    builder: (context, state) {
                      final isActive = state.mood == mood;
                      return GestureDetector(
                        onTap: () {
                          bloc.add(PetSetMoodEvent(mood));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF4FC3F7).withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF4FC3F7)
                                  : const Color(0xFF4FC3F7).withOpacity(0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _getMoodDisplayName(mood),
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? const Color(0xFF4FC3F7)
                                  : const Color(0xFF4FC3F7).withOpacity(0.5),
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w300,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),

            // 交互按钮行（新增）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.pets,
                    label: '抚摸',
                    onTap: () => bloc.add(PetPetEvent()),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.restaurant_outlined,
                    label: '喂食',
                    onTap: () => bloc.add(PetFeedEvent()),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.menu_book_outlined,
                    label: '学习',
                    onTap: () => bloc.add(PetStartStudyingEvent()),
                  ),
                ],
              ),
            ),

            // 操作提示
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Text(
                '双击随机 · 点击查看状态',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF4FC3F7).withOpacity(0.2),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF4FC3F7).withOpacity(0.2),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: const Color(0xFF4FC3F7).withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF4FC3F7).withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMoodDisplayName(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return '开心';
      case PetMood.calm:
        return '平静';
      case PetMood.missing:
        return '思念';
      case PetMood.sleepy:
        return '困倦';
      case PetMood.sad:
        return '难过';
      case PetMood.surprised:
        return '惊讶';
    }
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
          '${state.petName} · ${_getMoodDisplayName(state.mood)}',
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

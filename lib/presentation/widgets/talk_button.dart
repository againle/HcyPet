import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';

/// 对话按钮 - 点击弹出文字输入框，替代语音输入
class TalkButton extends StatefulWidget {
  final double size;
  final Color color;

  const TalkButton({
    super.key,
    this.size = 48,
    this.color = const Color(0xFF4FC3F7),
  });

  @override
  State<TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<TalkButton> {
  void _showTalkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
          ),
        ),
        title: const Text(
          '💬 和宠物说说话吧',
          style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          decoration: InputDecoration(
            hintText: '输入想说的话...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.black38,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty && context.mounted) {
                context.read<PetBloc>().add(PetTalkEvent(message: text));
              }
            },
            child: const Text(
              '发送',
              style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showTalkDialog,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.1),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.chat_bubble_outline,
          color: widget.color.withValues(alpha: 0.7),
          size: widget.size * 0.45,
        ),
      ),
    );
  }
}

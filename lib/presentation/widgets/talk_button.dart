import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';
import '../../services/voice_service.dart';
import '../../theme/design_constants.dart';

/// 对话按钮 — 文字 + 语音
class TalkButton extends StatefulWidget {
  final double size;
  final Color color;
  const TalkButton({super.key, this.size = 22, this.color = kPrimaryColor});
  @override
  State<TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<TalkButton> {
  bool _recording = false;

  void _showTalkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: kBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.10), width: 0.5),
          ),
          title: Row(children: [
            Expanded(child: Text('和宠物说说话', style: TextStyle(color: kPrimaryColor.withValues(alpha: 0.8), fontSize: 14, fontWeight: kFontThin, letterSpacing: 1.5))),
            GestureDetector(
              onTapDown: (_) async { setDlg(() => _recording = true); VoiceService.startListening(); },
              onTapUp: (_) async {
                setDlg(() => _recording = false);
                final r = await VoiceService.stop();
                if (r.success && r.text.isNotEmpty) { controller.text = r.text; controller.selection = TextSelection.collapsed(offset: r.text.length); }
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _recording ? Colors.red.withOpacity(0.2) : kPrimaryColor.withOpacity(0.05), shape: BoxShape.circle),
                child: Icon(_recording ? Icons.mic : Icons.mic_none, size: 18, color: _recording ? Colors.red.withOpacity(0.7) : kPrimaryColor.withOpacity(0.4)),
              ),
            ),
          ]),
          content: TextField(
            controller: controller, autofocus: true, maxLines: 3,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
            decoration: InputDecoration(
              hintText: _recording ? '正在聆听...' : '输入想说的话…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.12), fontSize: 13),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.25))),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: kPrimaryColor.withValues(alpha: 0.25), fontSize: 12, fontWeight: kFontThin))),
            TextButton(onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty && context.mounted) {
                context.read<PetBloc>().add(PetTalkEvent(message: text, isVoice: _recording));
              }
            }, child: Text('发送', style: TextStyle(color: kPrimaryColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: kFontThin))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showTalkDialog,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        AppIcons.talk,
        color: widget.color.withValues(
          alpha: InteractionButtonSpec.textOpacity,
        ),
        size: widget.size,
      ),
    );
  }
}

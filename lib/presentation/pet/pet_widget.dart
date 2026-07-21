import 'package:flutter/material.dart';
import '../../models/pet_state.dart';
import 'pet_painter.dart';

/// 宠物组件（支持点击交互）
class PetWidget extends StatefulWidget {
  final PetState state;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(DragUpdateDetails)? onPanUpdate;

  const PetWidget({
    super.key,
    required this.state,
    this.size = 200,
    this.onTap,
    this.onDoubleTap,
    this.onPanUpdate,
  });

  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onPanUpdate: widget.onPanUpdate,
      child: AnimatedBuilder(
        animation: _breathController,
        builder: (context, child) {
          final breathScale = 1.0 + _breathController.value * 0.015;
          return Transform.scale(
            scale: breathScale,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: PetPainter(
                state: widget.state,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}

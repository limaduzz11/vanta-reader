import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';

/// Placeholder Skeleton Monocromático para Efeito de Carregamento
class NovaSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const NovaSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<NovaSkeleton> createState() => _NovaSkeletonState();
}

class _NovaSkeletonState extends State<NovaSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: NovaColors.surfaceSecondary.withValues(
              alpha: _animation.value,
            ),
            borderRadius: widget.borderRadius ?? NovaShapes.roundedSm,
            border: Border.all(color: NovaColors.borderSubtle, width: 0.5),
          ),
        );
      },
    );
  }
}

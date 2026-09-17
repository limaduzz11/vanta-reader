import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';

/// Card Canônico do NovaReader
class NovaCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool hasBorder;

  const NovaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: NovaShapes.roundedMd,
      side: hasBorder
          ? const BorderSide(color: NovaColors.border, width: 1.0)
          : BorderSide.none,
    );

    return Material(
      color: backgroundColor ?? NovaColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: NovaShapes.roundedMd,
        highlightColor: NovaColors.highlight,
        child: Padding(
          padding: padding ?? NovaSpacing.cardPadding,
          child: child,
        ),
      ),
    );
  }
}

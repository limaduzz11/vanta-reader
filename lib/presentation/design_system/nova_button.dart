import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';

/// Estilo de Botão
enum NovaButtonVariant { primary, secondary, outline, ghost }

/// Botão Canônico do NovaReader
class NovaButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final NovaButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticsLabel;
  final double minHeight;

  const NovaButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = NovaButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticsLabel,
    this.minHeight = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    BorderSide? border;

    switch (variant) {
      case NovaButtonVariant.primary:
        bgColor = NovaColors.textPrimary;
        fgColor = NovaColors.background;
        border = null;
        break;
      case NovaButtonVariant.secondary:
        bgColor = NovaColors.surfaceSecondary;
        fgColor = NovaColors.textPrimary;
        border = const BorderSide(color: NovaColors.border, width: 1.0);
        break;
      case NovaButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = NovaColors.textPrimary;
        border = const BorderSide(color: NovaColors.border, width: 1.0);
        break;
      case NovaButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = NovaColors.textSecondary;
        border = null;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: NovaSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: NovaSpacing.sm),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            text,
            style: NovaTypography.labelMedium.copyWith(color: fgColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final button = Material(
      color: onPressed == null
          ? NovaColors.surfaceSecondary.withValues(alpha: 0.5)
          : bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: NovaShapes.roundedMd,
        side: border ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: NovaShapes.roundedMd,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.md,
            vertical: NovaSpacing.sm,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: semanticsLabel ?? text,
      child: isFullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}

/// Botão de Ícone Canônico do NovaReader
class NovaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const NovaIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn = IconButton(
      icon: Icon(icon, size: size, color: color ?? NovaColors.textPrimary),
      onPressed: onPressed,
      splashRadius: 24.0,
      constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
      highlightColor: NovaColors.highlight,
    );
    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip ?? 'Botão',
      child: btn,
    );
  }
}

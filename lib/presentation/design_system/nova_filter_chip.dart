import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';

/// Chip de Filtro Monocromático
class NovaFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  const NovaFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? NovaColors.textPrimary
        : NovaColors.surfaceSecondary;
    final fgColor = isSelected
        ? NovaColors.background
        : NovaColors.textSecondary;
    final borderColor = isSelected ? NovaColors.textPrimary : NovaColors.border;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filtro $label, ${isSelected ? "selecionado" : "não selecionado"}',
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: NovaShapes.pill,
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        child: InkWell(
          onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
          borderRadius: NovaShapes.pill,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36.0, minWidth: 48.0),
            padding: const EdgeInsets.symmetric(
              horizontal: NovaSpacing.md - 2,
              vertical: NovaSpacing.xs + 2,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fgColor),
                  const SizedBox(width: NovaSpacing.xs),
                ],
                Text(
                  label,
                  style: NovaTypography.labelMedium.copyWith(
                    fontSize: 11,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

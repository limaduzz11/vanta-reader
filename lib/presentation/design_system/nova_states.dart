import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import 'nova_button.dart';

/// Estado de Carregamento Minimalista
class NovaLoadingState extends StatelessWidget {
  final String? message;

  const NovaLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(NovaColors.accent),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: NovaSpacing.md),
            Text(
              message!,
              style: NovaTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado Vazio (Empty State)
class NovaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const NovaEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: NovaSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: NovaColors.accentDark),
            const SizedBox(height: NovaSpacing.md),
            Text(
              title,
              style: NovaTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NovaSpacing.xs),
            Text(
              description,
              style: NovaTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NovaSpacing.lg),
              NovaButton(
                text: actionLabel!,
                onPressed: onAction,
                variant: NovaButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de Erro Estruturado
class NovaErrorState extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;

  const NovaErrorState({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: NovaSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: NovaColors.error,
            ),
            const SizedBox(height: NovaSpacing.md),
            Text(
              message,
              style: NovaTypography.titleMedium.copyWith(
                color: NovaColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: NovaSpacing.xs),
              Text(
                details!,
                style: NovaTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: NovaSpacing.lg),
              NovaButton(
                text: 'Tentar Novamente',
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                variant: NovaButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra de Progresso Canônica
class NovaProgressBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0
  final double height;
  final Color? color;

  const NovaProgressBar({
    super.key,
    required this.progress,
    this.height = 3.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: NovaColors.borderSubtle,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? NovaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

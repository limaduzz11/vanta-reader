import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/work.dart';

/// Componente Central para Renderização de Capas de Livros e Quadrinhos do VANTA Reader
class NovaCoverImage extends StatelessWidget {
  final Work work;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const NovaCoverImage({
    super.key,
    required this.work,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final coverPath = work.coverPath;
    Widget content;

    if (coverPath != null && coverPath.isNotEmpty) {
      if (coverPath.startsWith('assets/')) {
        content = Image.asset(
          coverPath,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      } else if (coverPath.startsWith('http://') ||
          coverPath.startsWith('https://')) {
        content = Image.network(
          coverPath,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: NovaColors.surfaceSecondary,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NovaColors.accent,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      } else {
        final file = File(coverPath);
        if (file.existsSync()) {
          content = Image.file(
            file,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } else {
          content = _buildFallback();
        }
      }
    } else {
      content = _buildFallback();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return content;
  }

  Widget _buildFallback() {
    final isBook = work.type == WorkType.book;
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: NovaColors.surfaceSecondary,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF222222), Color(0xFF141414)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NovaSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBook
                    ? Icons.auto_stories_rounded
                    : Icons.dashboard_customize_rounded,
                size: 32.0,
                color: NovaColors.accent,
              ),
              const SizedBox(height: NovaSpacing.xs),
              Text(
                work.title,
                style: NovaTypography.titleMedium.copyWith(fontSize: 11),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

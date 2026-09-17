import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_dimensions.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/work.dart';
import 'nova_cover_image.dart';
import 'nova_states.dart';

/// Card Especializado para Livros (Aspect Ratio 2:3)
class NovaBookCard extends StatelessWidget {
  final Work work;
  final double? progress; // 0.0 a 1.0
  final VoidCallback? onTap;
  final double? width;
  final String? heroTag;
  final bool enableHero;

  const NovaBookCard({
    super.key,
    required this.work,
    this.progress,
    this.onTap,
    this.width,
    this.heroTag,
    this.enableHero = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget coverContainer = AspectRatio(
      aspectRatio: NovaDimensions.bookCoverAspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: NovaColors.surfaceSecondary,
          borderRadius: NovaShapes.roundedMd,
          border: Border.all(color: NovaColors.border, width: 1.0),
        ),
        child: Stack(
          children: [
            // Conteúdo da Capa com Arte de Alta Fidelidade
            Positioned.fill(
              child: NovaCoverImage(
                work: work,
                borderRadius: NovaShapes.roundedMd,
              ),
            ),

            // Badge de Formato no topo direito
            if (work.editions.isNotEmpty)
              Positioned(
                top: NovaSpacing.xs,
                right: NovaSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NovaColors.background.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: NovaColors.borderSubtle),
                  ),
                  child: Text(
                    work.editions.first.format.label,
                    style: NovaTypography.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: NovaColors.textPrimary,
                    ),
                  ),
                ),
              ),

            // Badge de Download no topo esquerdo
            if (work.isDownloaded)
              Positioned(
                top: NovaSpacing.xs,
                left: NovaSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: NovaColors.background.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: NovaColors.borderSubtle),
                  ),
                  child: const Icon(
                    Icons.download_done_rounded,
                    size: 11,
                    color: NovaColors.success,
                  ),
                ),
              ),

            // Barra de Progresso inferior
            if (progress != null && progress! > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: NovaProgressBar(
                  progress: progress!,
                  height: 3.0,
                  color: NovaColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );

    if (enableHero) {
      final tag = heroTag ?? 'work_cover_${work.id}';
      coverContainer = Hero(tag: tag, child: coverContainer);
    }

    final formatLabel = work.editions.isNotEmpty
        ? work.editions.first.format.label
        : 'Livro';
    final progressLabel = (progress != null && progress! > 0)
        ? ' Progresso: ${(progress! * 100).toInt()}%. '
        : '';
    final downloadedLabel = work.isDownloaded ? ' Baixado localmente.' : '';

    Widget card = Semantics(
      button: true,
      enabled: onTap != null,
      label:
          '${work.title}, de ${work.author}. Formato $formatLabel.$progressLabel$downloadedLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: NovaShapes.roundedMd,
        highlightColor: NovaColors.highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            coverContainer,
            const SizedBox(height: NovaSpacing.xs),

            // Título
            Text(
              work.title,
              style: NovaTypography.titleMedium.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Autor
            Text(
              work.author,
              style: NovaTypography.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}

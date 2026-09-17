import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/download_item.dart';
import '../../injection.dart';
import '../blocs/downloads/downloads_bloc.dart';
import '../blocs/downloads/downloads_event.dart';
import '../blocs/downloads/downloads_state.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_states.dart';

/// Tela de Gerenciamento de Downloads do NovaReader (Fase H)
class DownloadsScreen extends StatelessWidget {
  final DownloadsBloc? bloc;

  const DownloadsScreen({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<DownloadsBloc>.value(
        value: bloc!,
        child: const _DownloadsView(),
      );
    }

    return BlocProvider<DownloadsBloc>(
      create: (_) => getIt<DownloadsBloc>()..add(const LoadDownloadsEvent()),
      child: const _DownloadsView(),
    );
  }
}

class _DownloadsView extends StatelessWidget {
  const _DownloadsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.cleaning_services_rounded,
              color: NovaColors.textSecondary,
            ),
            tooltip: 'Limpar Concluídos',
            onPressed: () {
              context.read<DownloadsBloc>().add(
                const ClearCompletedDownloadsEvent(),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DownloadsBloc, DownloadsState>(
        builder: (context, state) {
          if (state is DownloadsLoading || state is DownloadsInitial) {
            return const Center(
              child: NovaLoadingState(
                message: 'Carregando fila de downloads...',
              ),
            );
          }

          if (state is DownloadsError) {
            return Center(
              child: NovaErrorState(
                message: state.message,
                onRetry: () => context.read<DownloadsBloc>().add(
                  const LoadDownloadsEvent(),
                ),
              ),
            );
          }

          final loaded = state as DownloadsLoaded;

          if (loaded.downloads.isEmpty) {
            return const Padding(
              padding: NovaSpacing.pagePadding,
              child: NovaEmptyState(
                icon: Icons.download_done_rounded,
                title: 'Nenhum Download Ativo',
                description:
                    'As transferências e arquivos baixados aparecerão aqui.',
              ),
            );
          }

          return ListView.separated(
            padding: NovaSpacing.pagePadding,
            itemCount: loaded.downloads.length,
            separatorBuilder: (_, _) => const SizedBox(height: NovaSpacing.md),
            itemBuilder: (context, index) {
              final item = loaded.downloads[index];
              final snapshot = loaded.progressMap[item.id];
              return _buildDownloadCard(context, item, snapshot);
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadCard(
    BuildContext context,
    DownloadItem item,
    dynamic snapshot,
  ) {
    final isDownloading = item.status == DownloadStatus.downloading;
    final isCompleted = item.status == DownloadStatus.completed;
    final isPaused = item.status == DownloadStatus.paused;
    final isQueued = item.status == DownloadStatus.queued;
    final isFailed = item.status == DownloadStatus.failed;
    final isCancelled = item.status == DownloadStatus.cancelled;

    final downloadedBytes = snapshot?.downloadedBytes ?? item.downloadedBytes;
    final totalBytes = snapshot?.totalBytes ?? item.totalBytes;
    final progress = totalBytes > 0
        ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();

    final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    String statusSubtitle;
    if (isCompleted) {
      statusSubtitle = '$totalMb MB • Concluído';
    } else if (isDownloading) {
      final speed = snapshot?.speedFormatted ?? 'Calculando...';
      final eta = snapshot?.etaFormatted ?? '--';
      statusSubtitle =
          '$downloadedMb MB de $totalMb MB • $progressPercent% • $speed • ETA: $eta';
    } else if (isPaused) {
      statusSubtitle =
          '$downloadedMb MB de $totalMb MB • Pausado ($progressPercent%)';
    } else if (isQueued) {
      statusSubtitle = '$totalMb MB • Aguardando na fila...';
    } else if (isFailed) {
      statusSubtitle = 'Falha no download • Toque para tentar novamente';
    } else {
      statusSubtitle = 'Cancelado';
    }

    return NovaCard(
      padding: NovaSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: NovaColors.surfaceSecondary,
                  borderRadius: NovaShapes.roundedSm,
                  border: Border.all(color: NovaColors.borderSubtle),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_outline_rounded
                      : (isPaused
                            ? Icons.pause_circle_outline_rounded
                            : (isFailed
                                  ? Icons.error_outline_rounded
                                  : (isQueued
                                        ? Icons.hourglass_top_rounded
                                        : Icons.downloading_rounded))),
                  color: isCompleted
                      ? NovaColors.success
                      : (isFailed ? NovaColors.error : NovaColors.accent),
                  size: 20,
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: NovaTypography.titleMedium.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: NovaSpacing.xxs),
                    Text(
                      statusSubtitle,
                      style: NovaTypography.bodySmall.copyWith(
                        color: isFailed
                            ? NovaColors.error
                            : NovaColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Botões de Ação
              if (isDownloading) ...[
                IconButton(
                  icon: const Icon(
                    Icons.pause_rounded,
                    color: NovaColors.textSecondary,
                  ),
                  tooltip: 'Pausar',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      PauseDownloadEvent(item.id),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: NovaColors.textMuted,
                  ),
                  tooltip: 'Cancelar',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      CancelDownloadEvent(item.id),
                    );
                  },
                ),
              ] else if (isPaused) ...[
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: NovaColors.textPrimary,
                  ),
                  tooltip: 'Retomar',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      ResumeDownloadEvent(item.id),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: NovaColors.textMuted,
                  ),
                  tooltip: 'Cancelar',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      CancelDownloadEvent(item.id),
                    );
                  },
                ),
              ] else if (isFailed || isCancelled) ...[
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: NovaColors.textPrimary,
                  ),
                  tooltip: 'Tentar Novamente',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      RetryDownloadEvent(item.id),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: NovaColors.textMuted,
                  ),
                  tooltip: 'Excluir',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      DeleteDownloadEvent(item.id, deleteFile: true),
                    );
                  },
                ),
              ] else if (isCompleted) ...[
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: NovaColors.textMuted,
                  ),
                  tooltip: 'Excluir',
                  onPressed: () {
                    context.read<DownloadsBloc>().add(
                      DeleteDownloadEvent(item.id, deleteFile: true),
                    );
                  },
                ),
              ],
            ],
          ),
          if (!isCompleted && !isFailed && !isCancelled) ...[
            const SizedBox(height: NovaSpacing.sm),
            NovaProgressBar(
              progress: progress,
              height: 3.0,
              color: isPaused ? NovaColors.accentDark : NovaColors.textPrimary,
            ),
          ],
        ],
      ),
    );
  }
}

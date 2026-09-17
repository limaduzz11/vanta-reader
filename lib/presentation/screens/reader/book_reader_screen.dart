import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/nova_colors.dart';
import '../../../core/theme/nova_spacing.dart';
import '../../../core/theme/nova_typography.dart';
import '../../../domain/entities/work.dart';
import '../../../injection.dart';
import '../../../core/reader/book_models.dart';
import '../../blocs/book_reader/book_reader_bloc.dart';
import '../../blocs/book_reader/book_reader_event.dart';
import '../../blocs/book_reader/book_reader_state.dart';
import '../../design_system/nova_states.dart';

/// Tela do Leitor de Livros Digital (Book Reader Engine) — Fase F
class BookReaderScreen extends StatelessWidget {
  final Work work;
  final WorkEdition edition;
  final BookReaderBloc? bloc;

  const BookReaderScreen({
    super.key,
    required this.work,
    required this.edition,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<BookReaderBloc>.value(
        value: bloc!,
        child: const _BookReaderView(),
      );
    }

    return BlocProvider<BookReaderBloc>(
      create: (_) =>
          getIt<BookReaderBloc>()
            ..add(OpenBookEvent(work: work, edition: edition)),
      child: const _BookReaderView(),
    );
  }
}

class _BookReaderView extends StatefulWidget {
  const _BookReaderView();

  @override
  State<_BookReaderView> createState() => _BookReaderViewState();
}

class _BookReaderViewState extends State<_BookReaderView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _resolveBackgroundColor(String mode) {
    switch (mode) {
      case 'kindle':
        return const Color(0xFFFFFFFF);
      case 'sepia':
        return const Color(0xFF24201B);
      case 'night':
        return const Color(0xFF1E1E1E);
      case 'oled_dark':
      default:
        return NovaColors.background;
    }
  }

  Color _resolveTextColor(String mode) {
    switch (mode) {
      case 'kindle':
        return const Color(0xFF111111);
      case 'sepia':
        return const Color(0xFFD8CFC4);
      case 'night':
        return const Color(0xFFC0C0C0);
      case 'oled_dark':
      default:
        return NovaColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookReaderBloc, BookReaderState>(
      builder: (context, state) {
        if (state is BookReaderLoading || state is BookReaderInitial) {
          return Scaffold(
            backgroundColor: NovaColors.background,
            body: const Center(
              child: NovaLoadingState(message: 'Carregando livro...'),
            ),
          );
        }

        if (state is BookReaderError) {
          return Scaffold(
            backgroundColor: NovaColors.background,
            appBar: AppBar(title: const Text('Leitor de Livros')),
            body: Center(
              child: NovaErrorState(
                message: state.message,
                onRetry: () {
                  final bloc = context.read<BookReaderBloc>();
                  if (bloc.state is BookReaderLoaded) {
                    final loaded = bloc.state as BookReaderLoaded;
                    bloc.add(
                      OpenBookEvent(work: loaded.work, edition: loaded.edition),
                    );
                  }
                },
              ),
            ),
          );
        }

        final loaded = state as BookReaderLoaded;
        final bgColor = _resolveBackgroundColor(loaded.typography.themeMode);
        final textColor = _resolveTextColor(loaded.typography.themeMode);

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Stack(
              children: [
                // 1. Área de Conteúdo de Texto e Gestos
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final startPage = _calculateStartPageForChapter(
                        loaded.content,
                        loaded.currentChapterIndex,
                      );
                      final pageInChapter = loaded.currentPage - startPage;
                      final isFirstPageOfChapter = pageInChapter <= 0;
                      final pageContent = _getPageSlice(loaded);

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) =>
                            _handleTap(context, details, constraints.maxWidth),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth >= 720
                                ? 80.0
                                : NovaSpacing.lg,
                            vertical: NovaSpacing.xxl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: NovaSpacing.xl),
                              if (isFirstPageOfChapter) ...[
                                Text(
                                  loaded.currentChapter.title,
                                  style: NovaTypography.displayMedium.copyWith(
                                    color: textColor,
                                    fontFamily: loaded.typography.fontFamily,
                                  ),
                                ),
                                const SizedBox(height: NovaSpacing.lg),
                              ] else ...[
                                Text(
                                  '${loaded.currentChapter.title} — continuação',
                                  style: NovaTypography.caption.copyWith(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontFamily: loaded.typography.fontFamily,
                                  ),
                                ),
                                const SizedBox(height: NovaSpacing.md),
                              ],
                              // Corpo do Texto da Página Atual
                              Text(
                                pageContent,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: loaded.typography.fontSize,
                                  height: loaded.typography.lineHeight,
                                  fontFamily: loaded.typography.fontFamily,
                                ),
                              ),
                              const SizedBox(height: NovaSpacing.xl),
                              Center(
                                child: Text(
                                  'Página ${loaded.currentPage} de ${loaded.totalPages}  •  ${(loaded.percentage * 100).toInt()}%',
                                  style: NovaTypography.caption.copyWith(
                                    color: textColor.withValues(alpha: 0.45),
                                    fontSize: 11,
                                    fontFamily: loaded.typography.fontFamily,
                                  ),
                                ),
                              ),
                              const SizedBox(height: NovaSpacing.xxl * 2),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Barra Superior Retrátil (Modo Imersivo)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  top: loaded.areControlsVisible ? 0 : -100.0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 56.0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: NovaSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.surface.withValues(alpha: 0.95),
                      border: const Border(
                        bottom: BorderSide(
                          color: NovaColors.border,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Voltar para detalhes da obra',
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: NovaColors.textPrimary,
                            ),
                            tooltip: 'Voltar',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loaded.work.title,
                                style: NovaTypography.titleMedium.copyWith(
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                loaded.currentChapter.title,
                                style: NovaTypography.caption.copyWith(
                                  color: NovaColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (loaded.session != null &&
                            loaded.session!.isStreaming) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            margin: const EdgeInsets.only(right: 4.0),
                            decoration: BoxDecoration(
                              color: NovaColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(100.0),
                              border: Border.all(
                                color: NovaColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_outlined,
                                  size: 10,
                                  color: NovaColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  loaded.session!.isLocal
                                      ? 'SALVO'
                                      : 'STREAMING',
                                  style: NovaTypography.caption.copyWith(
                                    fontSize: 10,
                                    color: NovaColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!loaded.session!.isLocal)
                            Semantics(
                              button: true,
                              label: 'Salvar obra offline na Biblioteca',
                              child: IconButton(
                                icon: loaded.isPromotingToLocal
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: NovaColors.accent,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.download_for_offline_outlined,
                                        color: NovaColors.accent,
                                      ),
                                tooltip: 'Salvar offline na Biblioteca',
                                onPressed: loaded.isPromotingToLocal
                                    ? null
                                    : () {
                                        context.read<BookReaderBloc>().add(
                                          const PromoteBookToLocalEvent(),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Obra promovida e salva para leitura offline!',
                                            ),
                                            backgroundColor:
                                                NovaColors.surfaceSecondary,
                                          ),
                                        );
                                      },
                              ),
                            ),
                        ],
                        Semantics(
                          button: true,
                          label: 'Sumário e lista de capítulos',
                          child: IconButton(
                            icon: const Icon(
                              Icons.list_alt_rounded,
                              color: NovaColors.textSecondary,
                            ),
                            tooltip: 'Sumário',
                            onPressed: () =>
                                _openTableOfContents(context, loaded),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Ajustes tipográficos e de tema',
                          child: IconButton(
                            icon: const Icon(
                              Icons.format_size_rounded,
                              color: NovaColors.textSecondary,
                            ),
                            tooltip: 'Ajustes Tipográficos',
                            onPressed: () =>
                                _openTypographySettings(context, loaded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Barra Inferior Retrátil (Progresso e Navegação)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  bottom: loaded.areControlsVisible ? 0 : -160.0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NovaSpacing.md,
                      vertical: NovaSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.surface.withValues(alpha: 0.95),
                      border: const Border(
                        top: BorderSide(color: NovaColors.border, width: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Página ${loaded.currentPage} de ${loaded.totalPages}',
                              style: NovaTypography.caption.copyWith(
                                color: NovaColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${(loaded.percentage * 100).toStringAsFixed(0)}%',
                              style: NovaTypography.caption.copyWith(
                                color: NovaColors.accent,
                              ),
                            ),
                          ],
                        ),
                        Semantics(
                          slider: true,
                          label: 'Controle deslizante de progresso',
                          value:
                              'Página ${loaded.currentPage} de ${loaded.totalPages}, ${(loaded.percentage * 100).toInt()}%',
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              activeTrackColor: NovaColors.accent,
                              inactiveTrackColor: NovaColors.surfaceSecondary,
                              thumbColor: NovaColors.textPrimary,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12.0,
                              ),
                            ),
                            child: Slider(
                              value: loaded.currentPage.toDouble().clamp(
                                1.0,
                                loaded.totalPages.toDouble(),
                              ),
                              min: 1.0,
                              max: loaded.totalPages.toDouble() > 1.0
                                  ? loaded.totalPages.toDouble()
                                  : 2.0,
                              onChanged: (val) {
                                context.read<BookReaderBloc>().add(
                                  JumpToPageEvent(val.toInt()),
                                );
                              },
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Semantics(
                              button: true,
                              enabled: loaded.currentPage > 1,
                              label: 'Voltar para a página anterior',
                              child: TextButton.icon(
                                onPressed: loaded.currentPage > 1
                                    ? () {
                                        context.read<BookReaderBloc>().add(
                                          const PreviousPageEvent(),
                                        );
                                        _scrollController.jumpTo(0);
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 18,
                                ),
                                label: const Text('Anterior'),
                                style: TextButton.styleFrom(
                                  foregroundColor: NovaColors.textSecondary,
                                  minimumSize: const Size(80, 48),
                                ),
                              ),
                            ),
                            Semantics(
                              button: true,
                              enabled: loaded.currentPage < loaded.totalPages,
                              label: 'Avançar para a próxima página',
                              child: TextButton.icon(
                                onPressed:
                                    loaded.currentPage < loaded.totalPages
                                    ? () {
                                        context.read<BookReaderBloc>().add(
                                          const NextPageEvent(),
                                        );
                                        _scrollController.jumpTo(0);
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                                label: const Text('Próxima'),
                                style: TextButton.styleFrom(
                                  foregroundColor: NovaColors.textPrimary,
                                  minimumSize: const Size(80, 48),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details, double maxWidth) {
    final x = details.localPosition.dx;
    final leftBound = maxWidth * 0.25;
    final rightBound = maxWidth * 0.75;

    if (x < leftBound) {
      // Toque à esquerda: Página anterior
      context.read<BookReaderBloc>().add(const PreviousPageEvent());
      _scrollController.jumpTo(0);
    } else if (x > rightBound) {
      // Toque à direita: Próxima página
      context.read<BookReaderBloc>().add(const NextPageEvent());
      _scrollController.jumpTo(0);
    } else {
      // Terço central: Alterna controles (Modo Imersivo)
      context.read<BookReaderBloc>().add(const ToggleControlsEvent());
    }
  }

  void _openTableOfContents(BuildContext context, BookReaderLoaded state) {
    final bloc = context.read<BookReaderBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaShapes.radiusMd),
        ),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: NovaSpacing.cardPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sumário', style: NovaTypography.titleLarge),
                    Text(
                      '${state.content.chapters.length} seções',
                      style: NovaTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(color: NovaColors.border, height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: state.content.chapters.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: NovaColors.borderSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final chapter = state.content.chapters[index];
                    final isCurrent = index == state.currentChapterIndex;

                    return ListTile(
                      leading: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? NovaColors.accent
                              : NovaColors.surfaceSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? NovaColors.background
                                : NovaColors.textSecondary,
                          ),
                        ),
                      ),
                      title: Text(
                        chapter.title,
                        style: NovaTypography.bodyMedium.copyWith(
                          color: isCurrent
                              ? NovaColors.accent
                              : NovaColors.textPrimary,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '~${chapter.estimatedPages} páginas estimadas',
                        style: NovaTypography.caption.copyWith(
                          color: NovaColors.textMuted,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        bloc.add(JumpToChapterEvent(index));
                        _scrollController.jumpTo(0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTypographySettings(BuildContext context, BookReaderLoaded state) {
    final bloc = context.read<BookReaderBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaShapes.radiusMd),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final typography = state.typography;

            return Padding(
              padding: NovaSpacing.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustes Tipográficos',
                    style: NovaTypography.titleLarge,
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 1. Tamanho da Fonte (com suporte a 22pt, 24pt e seletores rapidos)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tamanho do Texto',
                        style: NovaTypography.bodyMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NovaSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NovaColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: NovaColors.border),
                        ),
                        child: Text(
                          '${typography.fontSize.toInt()} pt',
                          style: NovaTypography.bodyMedium.copyWith(
                            color: NovaColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  Slider(
                    value: typography.fontSize.clamp(12.0, 32.0),
                    min: 12.0,
                    max: 32.0,
                    divisions: 10,
                    activeColor: NovaColors.accent,
                    onChanged: (val) {
                      setModalState(() {});
                      bloc.add(UpdateTypographyEvent(fontSize: val));
                    },
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 28.0].map((
                        size,
                      ) {
                        final isSelected =
                            (typography.fontSize - size).abs() < 0.5;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {});
                              bloc.add(UpdateTypographyEvent(fontSize: size));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? NovaColors.accent
                                    : NovaColors.surfaceSecondary,
                                borderRadius: NovaShapes.roundedSm,
                                border: Border.all(
                                  color: isSelected
                                      ? NovaColors.accent
                                      : NovaColors.border,
                                ),
                              ),
                              child: Text(
                                '${size.toInt()} pt',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : NovaColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 2. Altura de Linha
                  Text(
                    'Espaçamento entre Linhas',
                    style: NovaTypography.bodyMedium,
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  Row(
                    children: [
                      _buildLineHeightButton(
                        bloc,
                        typography.lineHeight,
                        1.3,
                        'Compacto',
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      _buildLineHeightButton(
                        bloc,
                        typography.lineHeight,
                        1.6,
                        'Normal',
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      _buildLineHeightButton(
                        bloc,
                        typography.lineHeight,
                        2.0,
                        'Amplo',
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 3. Tema de Fundo (Kindle: branco/preto, OLED: preto/branco, Sépia, Noite)
                  Text('Tema de Leitura', style: NovaTypography.bodyMedium),
                  const SizedBox(height: NovaSpacing.xs),
                  Row(
                    children: [
                      _buildThemeButton(
                        bloc,
                        typography.themeMode,
                        'kindle',
                        'Kindle',
                        const Color(0xFFFFFFFF),
                        const Color(0xFF111111),
                      ),
                      const SizedBox(width: NovaSpacing.xs),
                      _buildThemeButton(
                        bloc,
                        typography.themeMode,
                        'oled_dark',
                        'OLED Preto',
                        NovaColors.background,
                        NovaColors.textPrimary,
                      ),
                      const SizedBox(width: NovaSpacing.xs),
                      _buildThemeButton(
                        bloc,
                        typography.themeMode,
                        'sepia',
                        'Sépia',
                        const Color(0xFF24201B),
                        const Color(0xFFD8CFC4),
                      ),
                      const SizedBox(width: NovaSpacing.xs),
                      _buildThemeButton(
                        bloc,
                        typography.themeMode,
                        'night',
                        'Noite',
                        const Color(0xFF1E1E1E),
                        const Color(0xFFC0C0C0),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLineHeightButton(
    BookReaderBloc bloc,
    double current,
    double target,
    String label,
  ) {
    final isSelected = (current - target).abs() < 0.05;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? NovaColors.surfaceSecondary
              : Colors.transparent,
          side: BorderSide(
            color: isSelected ? NovaColors.accent : NovaColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: NovaShapes.roundedSm),
        ),
        onPressed: () => bloc.add(UpdateTypographyEvent(lineHeight: target)),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? NovaColors.textPrimary
                : NovaColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton(
    BookReaderBloc bloc,
    String currentMode,
    String targetMode,
    String label,
    Color pageColor,
    Color textColor,
  ) {
    final isSelected = currentMode == targetMode;
    return Expanded(
      child: InkWell(
        onTap: () => bloc.add(UpdateTypographyEvent(themeMode: targetMode)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: NovaSpacing.sm,
            horizontal: 2,
          ),
          decoration: BoxDecoration(
            color: pageColor,
            borderRadius: NovaShapes.roundedSm,
            border: Border.all(
              color: isSelected
                  ? NovaColors.accent
                  : (pageColor == const Color(0xFFFFFFFF)
                        ? const Color(0xFFD0D0D0)
                        : NovaColors.border),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected && pageColor != const Color(0xFFFFFFFF)
                      ? NovaColors.accent
                      : textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected && pageColor != const Color(0xFFFFFFFF)
                      ? NovaColors.accent
                      : textColor.withValues(alpha: isSelected ? 1.0 : 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateStartPageForChapter(BookContent content, int chapterIndex) {
    int page = 1;
    for (int i = 0; i < chapterIndex && i < content.chapters.length; i++) {
      page += content.chapters[i].estimatedPages;
    }
    return page;
  }

  String _getPageSlice(BookReaderLoaded loaded) {
    final chapter = loaded.currentChapter;
    if (chapter.estimatedPages <= 1) {
      return chapter.content;
    }

    final startPage = _calculateStartPageForChapter(
      loaded.content,
      loaded.currentChapterIndex,
    );
    final pageInChapter = (loaded.currentPage - startPage).clamp(
      0,
      chapter.estimatedPages - 1,
    );

    final paragraphs = chapter.content
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.length <= 1) {
      final charsPerPage = (chapter.content.length / chapter.estimatedPages)
          .ceil()
          .clamp(300, 3000);
      final start = (pageInChapter * charsPerPage).clamp(
        0,
        chapter.content.length,
      );
      final end = ((pageInChapter + 1) * charsPerPage).clamp(
        0,
        chapter.content.length,
      );
      return chapter.content.substring(start, end).trim();
    }

    final parasPerPage = (paragraphs.length / chapter.estimatedPages)
        .ceil()
        .clamp(1, paragraphs.length);
    final start = (pageInChapter * parasPerPage).clamp(0, paragraphs.length);
    final end = ((pageInChapter + 1) * parasPerPage).clamp(
      0,
      paragraphs.length,
    );

    if (start >= paragraphs.length) {
      return paragraphs.last;
    }
    return paragraphs.sublist(start, end).join('\n\n');
  }
}

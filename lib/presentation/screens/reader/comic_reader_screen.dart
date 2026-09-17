import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/reader/comic_content_parser.dart';
import '../../../core/reader/comic_models.dart';
import '../../../core/theme/nova_colors.dart';
import '../../../core/theme/nova_spacing.dart';
import '../../../core/theme/nova_typography.dart';
import '../../../domain/entities/work.dart';
import '../../../injection.dart';
import '../../blocs/comic_reader/comic_reader_bloc.dart';
import '../../blocs/comic_reader/comic_reader_event.dart';
import '../../blocs/comic_reader/comic_reader_state.dart';
import '../../design_system/nova_states.dart';

/// Tela do Leitor de Quadrinhos, Mangás e HQs (Comic Reader Engine) — Fase G
class ComicReaderScreen extends StatelessWidget {
  final Work work;
  final WorkEdition edition;
  final ComicReaderBloc? bloc;

  const ComicReaderScreen({
    super.key,
    required this.work,
    required this.edition,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<ComicReaderBloc>.value(
        value: bloc!,
        child: const _ComicReaderView(),
      );
    }

    return BlocProvider<ComicReaderBloc>(
      create: (_) =>
          getIt<ComicReaderBloc>()
            ..add(OpenComicEvent(work: work, edition: edition)),
      child: const _ComicReaderView(),
    );
  }
}

class _ComicReaderView extends StatefulWidget {
  const _ComicReaderView();

  @override
  State<_ComicReaderView> createState() => _ComicReaderViewState();
}

class _ComicReaderViewState extends State<_ComicReaderView> {
  late PageController _pageController;
  final ScrollController _webtoonScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _webtoonScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ComicReaderBloc, ComicReaderState>(
      listener: (context, state) {
        if (state is ComicReaderLoaded && _pageController.hasClients) {
          if (_pageController.page?.round() != state.currentPageIndex) {
            _pageController.jumpToPage(state.currentPageIndex);
          }
        }
      },
      builder: (context, state) {
        if (state is ComicReaderLoading || state is ComicReaderInitial) {
          return const Scaffold(
            backgroundColor: NovaColors.background,
            body: Center(
              child: NovaLoadingState(message: 'Carregando quadrinho...'),
            ),
          );
        }

        if (state is ComicReaderError) {
          return Scaffold(
            backgroundColor: NovaColors.background,
            appBar: AppBar(title: const Text('Leitor de Quadrinhos')),
            body: Center(
              child: NovaErrorState(
                message: state.message,
                onRetry: () {
                  final bloc = context.read<ComicReaderBloc>();
                  if (bloc.state is ComicReaderLoaded) {
                    final loaded = bloc.state as ComicReaderLoaded;
                    bloc.add(
                      OpenComicEvent(
                        work: loaded.work,
                        edition: loaded.edition,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }

        final loaded = state as ComicReaderLoaded;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // 1. Motor de Visualização de Imagem
                Positioned.fill(
                  child: loaded.settings.readingMode == ComicReadingMode.webtoon
                      ? _buildWebtoonView(loaded)
                      : _buildPageView(loaded),
                ),

                // 2. Barra Superior Retrátil (AppBar)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  top: loaded.areControlsVisible ? 0 : -110.0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80.0,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + NovaSpacing.xs,
                      left: NovaSpacing.sm,
                      right: NovaSpacing.sm,
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
                                style: NovaTypography.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Página ${loaded.pageNumber} de ${loaded.totalPages}',
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
                              label: 'Salvar quadrinho offline na Biblioteca',
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
                                        context.read<ComicReaderBloc>().add(
                                          const PromoteComicToLocalEvent(),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Quadrinho promovido e salvo para leitura offline!',
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
                          label: 'Grade de páginas e miniaturas',
                          child: IconButton(
                            icon: const Icon(
                              Icons.grid_view_rounded,
                              color: NovaColors.textSecondary,
                            ),
                            tooltip: 'Grade de Páginas',
                            onPressed: () => _openPagesGrid(context, loaded),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Ajustes de leitura do quadrinho',
                          child: IconButton(
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: NovaColors.textSecondary,
                            ),
                            tooltip: 'Ajustes de Leitura',
                            onPressed: () =>
                                _openReaderSettings(context, loaded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Barra Inferior Retrátil (Slider de Navegação e Botões)
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
                              'Página ${loaded.pageNumber} de ${loaded.totalPages}',
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
                          label: 'Controle deslizante de páginas do quadrinho',
                          value:
                              'Página ${loaded.pageNumber} de ${loaded.totalPages}, ${(loaded.percentage * 100).toInt()}%',
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
                              value: loaded.pageNumber.toDouble().clamp(
                                1.0,
                                loaded.totalPages.toDouble(),
                              ),
                              min: 1.0,
                              max: loaded.totalPages.toDouble() > 1.0
                                  ? loaded.totalPages.toDouble()
                                  : 2.0,
                              onChanged: (val) {
                                context.read<ComicReaderBloc>().add(
                                  JumpToComicPageEvent(val.toInt() - 1),
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
                              enabled: loaded.currentPageIndex > 0,
                              label:
                                  'Voltar para a página anterior do quadrinho',
                              child: TextButton.icon(
                                onPressed: loaded.currentPageIndex > 0
                                    ? () => context.read<ComicReaderBloc>().add(
                                        const PreviousComicPageEvent(),
                                      )
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
                              enabled:
                                  loaded.currentPageIndex <
                                  loaded.totalPages - 1,
                              label:
                                  'Avançar para a próxima página do quadrinho',
                              child: TextButton.icon(
                                onPressed:
                                    loaded.currentPageIndex <
                                        loaded.totalPages - 1
                                    ? () => context.read<ComicReaderBloc>().add(
                                        const NextComicPageEvent(),
                                      )
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

  /// Modo Página por Página (com Pinch-to-zoom e Toques Laterais)
  Widget _buildPageView(ComicReaderLoaded loaded) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) =>
              _handleTap(context, details, constraints.maxWidth),
          child: PageView.builder(
            controller: _pageController,
            reverse: loaded.settings.readRightToLeft,
            itemCount: loaded.totalPages,
            onPageChanged: (index) {
              context.read<ComicReaderBloc>().add(JumpToComicPageEvent(index));
            },
            itemBuilder: (context, index) {
              final page = loaded.content.pages[index];
              return _ZoomableComicPage(
                work: loaded.work,
                edition: loaded.edition,
                page: page,
                fitMode: loaded.settings.fitMode,
              );
            },
          ),
        );
      },
    );
  }

  /// Modo Webtoon (Rolagem Vertical Contínua)
  Widget _buildWebtoonView(ComicReaderLoaded loaded) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () =>
          context.read<ComicReaderBloc>().add(const ToggleComicControlsEvent()),
      child: ListView.builder(
        controller: _webtoonScrollController,
        padding: EdgeInsets.zero,
        itemCount: loaded.totalPages,
        itemBuilder: (context, index) {
          final page = loaded.content.pages[index];
          return _ComicImageLoader(
            work: loaded.work,
            edition: loaded.edition,
            page: page,
            fitMode: loaded.settings.fitMode,
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details, double maxWidth) {
    final x = details.localPosition.dx;
    final leftBound = maxWidth * 0.25;
    final rightBound = maxWidth * 0.75;

    final bloc = context.read<ComicReaderBloc>();
    final isRtl = (bloc.state as ComicReaderLoaded).settings.readRightToLeft;

    if (x < leftBound) {
      // Esquerda: se RTL avança, senão volta
      bloc.add(
        isRtl ? const NextComicPageEvent() : const PreviousComicPageEvent(),
      );
    } else if (x > rightBound) {
      // Direita: se RTL volta, senão avança
      bloc.add(
        isRtl ? const PreviousComicPageEvent() : const NextComicPageEvent(),
      );
    } else {
      // Centro: Modo Imersivo
      bloc.add(const ToggleComicControlsEvent());
    }
  }

  void _openPagesGrid(BuildContext context, ComicReaderLoaded state) {
    final bloc = context.read<ComicReaderBloc>();

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
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: NovaSpacing.cardPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Páginas do Quadrinho',
                      style: NovaTypography.titleLarge,
                    ),
                    Text(
                      '${state.totalPages} páginas',
                      style: NovaTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(color: NovaColors.border, height: 1),
              Expanded(
                child: GridView.builder(
                  padding: NovaSpacing.cardPadding,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: state.totalPages,
                  itemBuilder: (context, index) {
                    final isCurrent = index == state.currentPageIndex;
                    return InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        bloc.add(JumpToComicPageEvent(index));
                      },
                      borderRadius: NovaShapes.roundedSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? NovaColors.accent
                              : NovaColors.surfaceSecondary,
                          borderRadius: NovaShapes.roundedSm,
                          border: Border.all(
                            color: isCurrent
                                ? NovaColors.accent
                                : NovaColors.borderSubtle,
                            width: isCurrent ? 2.0 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? NovaColors.background
                                : NovaColors.textPrimary,
                          ),
                        ),
                      ),
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

  void _openReaderSettings(BuildContext context, ComicReaderLoaded state) {
    final bloc = context.read<ComicReaderBloc>();

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
            final settings = (bloc.state as ComicReaderLoaded).settings;

            return Padding(
              padding: NovaSpacing.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustes do Leitor de HQs',
                    style: NovaTypography.titleLarge,
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 1. Modo de Leitura
                  Text(
                    'Modo de Visualização',
                    style: NovaTypography.bodyMedium,
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Página Única'),
                          selected:
                              settings.readingMode == ComicReadingMode.page,
                          onSelected: (selected) {
                            if (selected) {
                              bloc.add(
                                const ChangeReadingModeEvent(
                                  ComicReadingMode.page,
                                ),
                              );
                              setModalState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Webtoon (Vertical)'),
                          selected:
                              settings.readingMode == ComicReadingMode.webtoon,
                          onSelected: (selected) {
                            if (selected) {
                              bloc.add(
                                const ChangeReadingModeEvent(
                                  ComicReadingMode.webtoon,
                                ),
                              );
                              setModalState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 2. Modo de Enquadramento
                  Text(
                    'Enquadramento da Imagem',
                    style: NovaTypography.bodyMedium,
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Largura'),
                        selected: settings.fitMode == ComicFitMode.fitWidth,
                        onSelected: (selected) {
                          if (selected) {
                            bloc.add(
                              const ChangeFitModeEvent(ComicFitMode.fitWidth),
                            );
                            setModalState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      ChoiceChip(
                        label: const Text('Tela'),
                        selected: settings.fitMode == ComicFitMode.fitScreen,
                        onSelected: (selected) {
                          if (selected) {
                            bloc.add(
                              const ChangeFitModeEvent(ComicFitMode.fitScreen),
                            );
                            setModalState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      ChoiceChip(
                        label: const Text('Altura'),
                        selected: settings.fitMode == ComicFitMode.fitHeight,
                        onSelected: (selected) {
                          if (selected) {
                            bloc.add(
                              const ChangeFitModeEvent(ComicFitMode.fitHeight),
                            );
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.md),

                  // 3. Modo Mangá (RTL)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Leitura da Direita para a Esquerda (Mangá)',
                    ),
                    value: settings.readRightToLeft,
                    activeThumbColor: NovaColors.accent,
                    onChanged: (_) {
                      bloc.add(const ToggleRtlEvent());
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: NovaSpacing.md),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Página individual com suporte a Pinch-to-zoom e Double-tap zoom
class _ZoomableComicPage extends StatefulWidget {
  final Work work;
  final WorkEdition edition;
  final ComicPage page;
  final ComicFitMode fitMode;

  const _ZoomableComicPage({
    required this.work,
    required this.edition,
    required this.page,
    required this.fitMode,
  });

  @override
  State<_ZoomableComicPage> createState() => _ZoomableComicPageState();
}

class _ZoomableComicPageState extends State<_ZoomableComicPage> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.2, 2.2, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: _ComicImageLoader(
            work: widget.work,
            edition: widget.edition,
            page: widget.page,
            fitMode: widget.fitMode,
          ),
        ),
      ),
    );
  }
}

/// Carregador sob demanda dos bytes da página com cache LRU
class _ComicImageLoader extends StatelessWidget {
  final Work work;
  final WorkEdition edition;
  final ComicPage page;
  final ComicFitMode fitMode;

  const _ComicImageLoader({
    required this.work,
    required this.edition,
    required this.page,
    required this.fitMode,
  });

  BoxFit _resolveBoxFit() {
    switch (fitMode) {
      case ComicFitMode.fitWidth:
        return BoxFit.fitWidth;
      case ComicFitMode.fitHeight:
        return BoxFit.fitHeight;
      case ComicFitMode.fitScreen:
        return BoxFit.contain;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parser = getIt<ComicContentParser>();

    return FutureBuilder<Uint8List>(
      future: parser.loadPageBytes(work: work, edition: edition, page: page),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            height: 400,
            alignment: Alignment.center,
            color: NovaColors.surfaceSecondary,
            child: const NovaLoadingState(message: 'Carregando página...'),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            height: 400,
            alignment: Alignment.center,
            color: NovaColors.surfaceSecondary,
            child: const Icon(
              Icons.broken_image_rounded,
              color: NovaColors.error,
              size: 48,
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: _resolveBoxFit(),
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

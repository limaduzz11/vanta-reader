import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_dimensions.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/work.dart';
import '../../domain/repositories/i_library_repository.dart';
import '../../domain/usecases/downloads/download_usecases.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';
import '../../core/providers/provider_registry.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../../injection.dart';
import '../design_system/nova_button.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_cover_image.dart';
import 'reader/book_reader_screen.dart';
import 'reader/comic_reader_screen.dart';

/// Tela de Detalhes Canônica da Obra (Livro ou Quadrinho)
class WorkDetailsScreen extends StatefulWidget {
  final Work work;

  /// Identidade da edição selecionada (rastreável de ponta a ponta).
  /// Quando informada, a tela seleciona essa edição em vez da primeira.
  final String? editionId;
  final String? heroTag;
  final bool enableHero;

  const WorkDetailsScreen({
    super.key,
    required this.work,
    this.editionId,
    this.heroTag,
    this.enableHero = true,
  });

  @override
  State<WorkDetailsScreen> createState() => _WorkDetailsScreenState();
}

class _WorkDetailsScreenState extends State<WorkDetailsScreen> {
  bool _isFavorite = false;
  bool _isInLibrary = false;
  late WorkEdition _selectedEdition;
  String? _enrichedDescription;
  int? _enrichedPages;
  String? _enrichedPublisher;
  String? _enrichedYear;

  @override
  void initState() {
    super.initState();
    final requestedEdition = widget.editionId != null
        ? widget.work.editions
              .where((e) => e.id == widget.editionId)
              .firstOrNull
        : null;
    // D-05: escolhe a edição mais rica (local > URL válida > páginas >
    // tamanho > formato conhecido) em vez de sempre a 1ª (OL metadata-only
    // sem páginas/conteúdo era selecionada por padrão).
    _selectedEdition =
        requestedEdition ??
        (widget.work.editions.isNotEmpty
            ? _richestEdition(widget.work.editions)
            : WorkEdition(
                id: 'default-ed',
                workId: widget.work.id,
                format: widget.work.type == WorkType.book
                    ? WorkFormat.epub
                    : WorkFormat.cbz,
              ));
    _checkStatus();
    _enrichFromProvider();
  }

  static WorkEdition _richestEdition(List<WorkEdition> editions) {
    var best = editions.first;
    var bestScore = _editionScore(best);
    for (final ed in editions.skip(1)) {
      final score = _editionScore(ed);
      if (score > bestScore) {
        best = ed;
        bestScore = score;
      }
    }
    return best;
  }

  static int _editionScore(WorkEdition ed) {
    var score = 0;
    if (ed.hasValidLocalAsset) score += 1000;
    if (ed.isLocal) score += 500;
    final url = ed.primaryContentAsset?.remoteUrl ?? ed.downloadUrl ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) score += 200;
    if (ed.pageCount > 0) score += 100;
    if (ed.fileSize > 0) score += 10;
    if (ed.format != WorkFormat.unknown) score += 5;
    return score;
  }

  /// G-04: enriquecimento sob demanda via `getDetails` do provider da edição.
  /// Somente leitura (sem persistência): preenche sinopse/páginas/editora/ano
  /// quando o agregado local está esparso. Nunca inventa metadata.
  Future<void> _enrichFromProvider() async {
    final edition = _selectedEdition;
    final needsDescription =
        (widget.work.description == null ||
            widget.work.description!.trim().isEmpty) &&
        _enrichedDescription == null;
    final needsPages = edition.pageCount <= 0 && _enrichedPages == null;
    final needsPublisher =
        (widget.work.publisher == null || widget.work.publisher!.isEmpty) &&
        _enrichedPublisher == null;
    if (!needsDescription && !needsPages && !needsPublisher) return;
    final providerId = edition.providerId;
    final externalId = edition.externalId;
    if (providerId == null || externalId == null || externalId.isEmpty) return;
    try {
      if (!getIt.isRegistered<ProviderRegistry>()) return;
      final provider = getIt<ProviderRegistry>().getProvider(providerId);
      if (provider == null) return;
      final details = await provider.getDetails(externalId);
      if (details == null || !mounted) return;
      setState(() {
        if (needsDescription &&
            details.description != null &&
            details.description!.trim().isNotEmpty) {
          _enrichedDescription = details.description;
        }
        if (needsPages && details.pageCount > 0) {
          _enrichedPages = details.pageCount;
        }
        if (needsPublisher && details.publisher != null) {
          _enrichedPublisher = details.publisher;
        }
        if (details.publishedDate != null) {
          _enrichedYear = details.publishedDate;
        }
      });
    } catch (_) {}
  }

  Future<void> _checkStatus() async {
    try {
      if (getIt.isRegistered<ILibraryRepository>()) {
        final repo = getIt<ILibraryRepository>();
        final fav = await repo.isFavorite(widget.work.id);
        final existing = await repo.getWorkById(widget.work.id);
        if (mounted) {
          setState(() {
            _isFavorite = fav;
            _isInLibrary = existing != null;
          });
        }
      }
    } catch (_) {}
  }

  // REGRA de integridade de conteúdo: ações LER/BAIXAR só são oferecidas
  // quando existe conteúdo real associado à edição selecionada (asset local,
  // asset remoto HTTP validável). Metadata sozinha NÃO habilita ações.
  bool get _selectedEditionHasContent {
    final ed = _selectedEdition;
    if (ed.hasValidLocalAsset) {
      return true;
    }
    final url = ed.primaryContentAsset?.remoteUrl ?? ed.downloadUrl ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool get _selectedEditionCanDownload {
    if (_selectedEdition.isLocal) return false;
    final url =
        _selectedEdition.primaryContentAsset?.remoteUrl ??
        _selectedEdition.downloadUrl ??
        '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String get _contentAvailabilityLabel {
    final ed = _selectedEdition;
    if (ed.isLocal && ed.filePath != null && ed.filePath!.isNotEmpty) {
      return 'Arquivo local no dispositivo (leitura 100% offline)';
    }
    if (ed.contentAssets.any((a) => a.isLocalDownloaded)) {
      return 'Conteúdo baixado disponível offline';
    }
    final url = ed.downloadUrl ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return 'Conteúdo disponível para leitura online ou download';
    }
    return 'Apenas destaques de catálogo (metadata). Conteúdo real disponível em outras fontes.';
  }

  @override
  Widget build(BuildContext context) {
    final isBook = widget.work.type == WorkType.book;
    final aspectRatio = isBook
        ? NovaDimensions.bookCoverAspectRatio
        : NovaDimensions.comicCoverAspectRatio;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.work.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Semantics(
            button: true,
            label: _isFavorite
                ? 'Remover dos Favoritos'
                : 'Adicionar aos Favoritos',
            child: IconButton(
              icon: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isFavorite ? NovaColors.error : NovaColors.textPrimary,
              ),
              tooltip: _isFavorite
                  ? 'Remover dos Favoritos'
                  : 'Adicionar aos Favoritos',
              onPressed: () async {
                // G-03: caminho único via ToggleFavoriteUseCase + refresh
                // reativo da LibraryBloc (sem bypass direto do repositório).
                final newFav = await getIt<ToggleFavoriteUseCase>().execute(
                  widget.work.id,
                );
                if (getIt.isRegistered<LibraryBloc>()) {
                  getIt<LibraryBloc>().add(const LoadLibraryEvent());
                }
                if (mounted) {
                  setState(() {
                    _isFavorite = newFav;
                  });
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newFav
                            ? 'Adicionado aos Favoritos'
                            : 'Removido dos Favoritos',
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: NovaColors.surfaceSecondary,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: NovaSpacing.pagePadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 720;
            if (isTablet) {
              return _buildTabletLayout(aspectRatio, isBook);
            }
            return _buildMobileLayout(aspectRatio, isBook);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(double aspectRatio, bool isBook) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildCoverHeader(aspectRatio, isBook, width: 170.0)),
        const SizedBox(height: NovaSpacing.lg),
        _buildTitleSection(),
        const SizedBox(height: NovaSpacing.md),
        _buildActionButtons(),
        const SizedBox(height: NovaSpacing.lg),
        _buildMetadataCard(),
        const SizedBox(height: NovaSpacing.lg),
        _buildDescriptionSection(),
      ],
    );
  }

  Widget _buildTabletLayout(double aspectRatio, bool isBook) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda: Capa + Ações Principais
        SizedBox(
          width: 260.0,
          child: Column(
            children: [
              _buildCoverHeader(aspectRatio, isBook, width: 220.0),
              const SizedBox(height: NovaSpacing.lg),
              _buildActionButtons(),
            ],
          ),
        ),
        const SizedBox(width: NovaSpacing.xl),

        // Coluna Direita: Metadados Detalhados + Sinopse
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleSection(),
              const SizedBox(height: NovaSpacing.lg),
              _buildMetadataCard(),
              const SizedBox(height: NovaSpacing.lg),
              _buildDescriptionSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoverHeader(
    double aspectRatio,
    bool isBook, {
    required double width,
  }) {
    final height = width / aspectRatio;

    Widget cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NovaColors.surfaceSecondary,
        borderRadius: NovaShapes.roundedMd,
        border: Border.all(color: NovaColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16.0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: NovaShapes.roundedMd,
        child: NovaCoverImage(
          work: widget.work,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );

    if (widget.enableHero) {
      final tag = widget.heroTag ?? 'work_cover_${widget.work.id}';
      return Hero(tag: tag, child: cover);
    }
    return cover;
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.work.title, style: NovaTypography.displayMedium),
        if (widget.work.subtitle != null) ...[
          const SizedBox(height: NovaSpacing.xxs),
          Text(
            widget.work.subtitle!,
            style: NovaTypography.titleMedium.copyWith(
              color: NovaColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: NovaSpacing.xs),
        Text('Por ${widget.work.author}', style: NovaTypography.bodyMedium),
        const SizedBox(height: NovaSpacing.sm),
        Row(
          children: [
            _buildBadge(widget.work.primaryLanguage, Icons.language_rounded),
            const SizedBox(width: NovaSpacing.sm),
            _buildBadge(
              widget.work.type.label,
              widget.work.type == WorkType.book
                  ? Icons.book_outlined
                  : Icons.collections_outlined,
            ),
            if (widget.work.volume != null) ...[
              const SizedBox(width: NovaSpacing.sm),
              _buildBadge(
                'Vol. ${widget.work.volume}',
                Icons.filter_none_rounded,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: NovaColors.surfaceSecondary,
        borderRadius: NovaShapes.pill,
        border: Border.all(color: NovaColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: NovaColors.accent),
          const SizedBox(width: NovaSpacing.xs),
          Text(
            label,
            style: NovaTypography.caption.copyWith(
              color: NovaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (widget.work.editions.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('EDIÇÕES DISPONÍVEIS', style: NovaTypography.caption),
          ),
          const SizedBox(height: NovaSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.work.editions.map((ed) {
                final isSelected = ed.id == _selectedEdition.id;
                final sizeMb = ed.fileSize > 0
                    ? ' (${(ed.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)'
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(right: NovaSpacing.xs),
                  child: FilterChip(
                    label: Text('${ed.format.label}$sizeMb'),
                    selected: isSelected,
                    selectedColor: NovaColors.accent,
                    backgroundColor: NovaColors.surfaceSecondary,
                    labelStyle: NovaTypography.bodySmall.copyWith(
                      color: isSelected
                          ? NovaColors.background
                          : NovaColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedEdition = ed;
                      });
                      _enrichFromProvider();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: NovaButton(
                text: 'LER AGORA',
                icon: Icons.play_arrow_rounded,
                variant: NovaButtonVariant.primary,
                semanticsLabel: 'Iniciar leitura de ${widget.work.title}',
                onPressed: _selectedEditionHasContent
                    ? () {
                        if (widget.work.type == WorkType.book) {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => BookReaderScreen(
                                work: widget.work,
                                edition: _selectedEdition,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => ComicReaderScreen(
                                work: widget.work,
                                edition: _selectedEdition,
                              ),
                            ),
                          );
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: NovaSpacing.sm),
            Expanded(
              child: NovaButton(
                text: 'BAIXAR',
                icon: Icons.download_rounded,
                variant: NovaButtonVariant.secondary,
                semanticsLabel:
                    'Baixar edição ${_selectedEdition.format.label} de ${widget.work.title}',
                onPressed: _selectedEditionCanDownload
                    ? () async {
                        try {
                          final enqueue = getIt<EnqueueDownloadUseCase>();
                          await enqueue(
                            work: widget.work,
                            edition: _selectedEdition,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Download de "${widget.work.title}" enfileirado!',
                                ),
                                backgroundColor: NovaColors.surfaceSecondary,
                              ),
                            );
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Download indisponível: $error'),
                                backgroundColor: NovaColors.surfaceSecondary,
                              ),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: NovaSpacing.xs),
        Row(
          children: [
            Icon(
              _selectedEdition.isLocal
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 13,
              color: _selectedEdition.isLocal
                  ? NovaColors.accent
                  : NovaColors.textMuted,
            ),
            const SizedBox(width: NovaSpacing.xs),
            Expanded(
              child: Text(
                _contentAvailabilityLabel,
                style: NovaTypography.caption.copyWith(
                  fontSize: 11,
                  color: _selectedEdition.isLocal
                      ? NovaColors.textPrimary
                      : NovaColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: NovaSpacing.sm),
        _isInLibrary
            ? NovaButton(
                text: 'REMOVER DA BIBLIOTECA',
                icon: Icons.delete_outline_rounded,
                variant: NovaButtonVariant.secondary,
                isFullWidth: true,
                semanticsLabel: 'Remover ${widget.work.title} da biblioteca',
                onPressed: () async {
                  await getIt<ILibraryRepository>().deleteWork(widget.work.id);
                  if (getIt.isRegistered<LibraryBloc>()) {
                    getIt<LibraryBloc>().add(const LoadLibraryEvent());
                  }
                  if (mounted) {
                    setState(() => _isInLibrary = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${widget.work.title}" removido da biblioteca.',
                        ),
                        backgroundColor: NovaColors.surfaceSecondary,
                      ),
                    );
                  }
                },
              )
            : NovaButton(
                text: 'ADICIONAR À BIBLIOTECA',
                icon: Icons.bookmark_add_outlined,
                variant: NovaButtonVariant.outline,
                isFullWidth: true,
                semanticsLabel: 'Adicionar ${widget.work.title} à biblioteca',
                onPressed: () async {
                  await getIt<ILibraryRepository>().saveWork(widget.work);
                  if (getIt.isRegistered<LibraryBloc>()) {
                    getIt<LibraryBloc>().add(const LoadLibraryEvent());
                  }
                  if (mounted) {
                    setState(() => _isInLibrary = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${widget.work.title}" salvo na biblioteca!',
                        ),
                        backgroundColor: NovaColors.surfaceSecondary,
                      ),
                    );
                  }
                },
              ),
      ],
    );
  }

  Widget _buildMetadataCard() {
    return NovaCard(
      padding: NovaSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('METADADOS DA OBRA', style: NovaTypography.caption),
          const SizedBox(height: NovaSpacing.md),
          if (widget.work.series != null)
            _buildMetaRow('Série', widget.work.series!),
          if (widget.work.publisher != null)
            _buildMetaRow('Editora', widget.work.publisher!)
          else if (_enrichedPublisher != null)
            _buildMetaRow('Editora', _enrichedPublisher!),
          if (widget.work.publishedDate != null)
            _buildMetaRow('Publicação', widget.work.publishedDate!)
          else if (_enrichedYear != null)
            _buildMetaRow('Publicação', _enrichedYear!),
          if (widget.work.isbn != null)
            _buildMetaRow('ISBN', widget.work.isbn!),
          _buildMetaRow('Formato Principal', _selectedEdition.format.label),
          if (_selectedEdition.pageCount > 0)
            _buildMetaRow('Páginas', '${_selectedEdition.pageCount} págs')
          else if (_enrichedPages != null)
            _buildMetaRow('Páginas', '$_enrichedPages págs'),
          if (_selectedEdition.fileSize > 0)
            _buildMetaRow(
              'Tamanho',
              '${(_selectedEdition.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
            ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NovaTypography.bodySmall),
          Text(
            value,
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SINOPSE', style: NovaTypography.caption),
        const SizedBox(height: NovaSpacing.sm),
        Text(
          widget.work.description ?? _enrichedDescription ?? 'Sinopse não disponível.',
          style: NovaTypography.bodyMedium.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

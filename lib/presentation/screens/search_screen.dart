import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_dimensions.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/work.dart';
import '../../injection.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_cover_image.dart';
import '../design_system/nova_filter_chip.dart';
import '../design_system/nova_states.dart';
import 'work_details_screen.dart';

/// Tela de Busca e Catálogo Unificado (Fase J)
class SearchScreen extends StatelessWidget {
  final SearchBloc? bloc;

  const SearchScreen({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<SearchBloc>.value(
        value: bloc!,
        child: const _SearchView(),
      );
    }

    return BlocProvider<SearchBloc>(
      create: (_) => getIt<SearchBloc>(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // G-08: paginação infinita a 200 px do fim.
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<SearchBloc>().add(const LoadMoreSearchResultsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: NovaTypography.bodyLarge,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Pesquisar obras, autores, séries...',
            hintStyle: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textMuted,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: NovaColors.textSecondary,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: NovaColors.textMuted,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      context.read<SearchBloc>().add(const ClearSearchEvent());
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (text) {
            setState(() {});
            context.read<SearchBloc>().add(SearchQueryChangedEvent(text));
          },
          onSubmitted: (text) {
            context.read<SearchBloc>().add(SearchSubmittedEvent(text));
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(context),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state is SearchLoading) {
                  return const Center(
                    child: NovaLoadingState(
                      message: 'Pesquisando no catálogo unificado...',
                    ),
                  );
                }

                if (state is SearchError) {
                  return Center(
                    child: NovaErrorState(
                      message: state.message,
                      onRetry: () {
                        context.read<SearchBloc>().add(
                          SearchSubmittedEvent(state.query),
                        );
                      },
                    ),
                  );
                }

                if (state is SearchEmpty) {
                  return Center(
                    child: Padding(
                      padding: NovaSpacing.pagePadding,
                      child: NovaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhuma Obra Encontrada',
                        description:
                            'Não encontramos resultados para "${state.query}". Tente termos mais genéricos ou altere os filtros.',
                      ),
                    ),
                  );
                }

                if (state is SearchSuccess) {
                  return _buildSearchResults(context, state);
                }

                // SearchInitial
                final initial = state as SearchInitial;
                return _buildInitialSuggestions(context, initial);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        WorkType? currentType;
        String? currentLang;
        WorkFormat? currentFormat;
        SearchSortBy currentSort = SearchSortBy.relevance;

        if (state is SearchSuccess) {
          currentType = state.typeFilter;
          currentLang = state.languageFilter;
          currentFormat = state.formatFilter;
          currentSort = state.sortBy;
        } else if (state is SearchInitial) {
          currentType = state.typeFilter;
          currentLang = state.languageFilter;
          currentFormat = state.formatFilter;
        }

        final isAll =
            currentType == null && currentLang == null && currentFormat == null;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.md,
            vertical: NovaSpacing.xs,
          ),
          child: Row(
            children: [
              NovaFilterChip(
                label: 'Todos',
                isSelected: isAll,
                onSelected: (_) {
                  context.read<SearchBloc>().add(
                    const SearchFilterChangedEvent(),
                  );
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              NovaFilterChip(
                label: 'Livros',
                icon: Icons.auto_stories_rounded,
                isSelected: currentType == WorkType.book,
                onSelected: (selected) {
                  context.read<SearchBloc>().add(
                    SearchFilterChangedEvent(
                      typeFilter: selected ? WorkType.book : null,
                      languageFilter: currentLang,
                      formatFilter: currentFormat,
                    ),
                  );
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              NovaFilterChip(
                label: 'Quadrinhos',
                icon: Icons.collections_bookmark_rounded,
                isSelected: currentType == WorkType.comic,
                onSelected: (selected) {
                  context.read<SearchBloc>().add(
                    SearchFilterChangedEvent(
                      typeFilter: selected ? WorkType.comic : null,
                      languageFilter: currentLang,
                      formatFilter: currentFormat,
                    ),
                  );
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              NovaFilterChip(
                label: 'pt-BR',
                icon: Icons.language_rounded,
                isSelected: currentLang == 'pt-BR',
                onSelected: (selected) {
                  context.read<SearchBloc>().add(
                    SearchFilterChangedEvent(
                      typeFilter: currentType,
                      languageFilter: selected ? 'pt-BR' : null,
                      formatFilter: currentFormat,
                    ),
                  );
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              NovaFilterChip(
                label: 'Inglês',
                icon: Icons.translate_rounded,
                isSelected: currentLang == 'en',
                onSelected: (selected) {
                  context.read<SearchBloc>().add(
                    SearchFilterChangedEvent(
                      typeFilter: currentType,
                      languageFilter: selected ? 'en' : null,
                      formatFilter: currentFormat,
                    ),
                  );
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              for (final format in const [
                WorkFormat.epub,
                WorkFormat.pdf,
                WorkFormat.cbz,
              ]) ...[
                NovaFilterChip(
                  label: format.label,
                  isSelected: currentFormat == format,
                  onSelected: (selected) {
                    context.read<SearchBloc>().add(
                      SearchFilterChangedEvent(
                        typeFilter: currentType,
                        languageFilter: currentLang,
                        formatFilter: selected ? format : null,
                      ),
                    );
                  },
                ),
                const SizedBox(width: NovaSpacing.sm),
              ],
              PopupMenuButton<SearchSortBy>(
                tooltip: 'Ordenar por',
                initialValue: currentSort,
                icon: const Icon(
                  Icons.sort_rounded,
                  color: NovaColors.textSecondary,
                  size: 20,
                ),
                onSelected: (sortBy) {
                  context.read<SearchBloc>().add(
                    SearchFilterChangedEvent(
                      typeFilter: currentType,
                      languageFilter: currentLang,
                      formatFilter: currentFormat,
                      sortBy: sortBy,
                    ),
                  );
                },
                itemBuilder: (_) => SearchSortBy.values
                    .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitialSuggestions(BuildContext context, SearchInitial state) {
    return Padding(
      padding: NovaSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NovaSpacing.md),
          Text(
            'SUGESTÕES DE BUSCA',
            style: NovaTypography.caption.copyWith(
              color: NovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: state.recentSearches.map((term) {
              return ActionChip(
                label: Text(term),
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: NovaTypography.bodySmall,
                onPressed: () {
                  _searchController.text = term;
                  context.read<SearchBloc>().add(SearchSubmittedEvent(term));
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const Spacer(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.manage_search_rounded,
                  size: 64,
                  color: NovaColors.textMuted,
                ),
                const SizedBox(height: NovaSpacing.md),
                Text(
                  'Explore o Catálogo Unificado',
                  style: NovaTypography.titleMedium,
                ),
                const SizedBox(height: NovaSpacing.xs),
                Text(
                  'Pesquise por títulos, autores ou temas para descobrir novas leituras.',
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchSuccess state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.md,
            vertical: NovaSpacing.xs,
          ),
          child: Text(
            '${state.works.length} obra(s) encontrada(s)',
            style: NovaTypography.caption.copyWith(
              color: NovaColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: NovaSpacing.pagePadding,
            itemCount: state.works.length + (state.hasReachedMax ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(height: NovaSpacing.md),
            itemBuilder: (context, index) {
              if (index >= state.works.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: NovaSpacing.md),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final work = state.works[index];
              return _buildSearchResultCard(context, work);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(BuildContext context, Work work) {
    final isBook = work.type == WorkType.book;
    final aspectRatio = isBook
        ? NovaDimensions.bookCoverAspectRatio
        : NovaDimensions.comicCoverAspectRatio;

    return NovaCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WorkDetailsScreen(work: work)),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capa real com fallback (G-05: antes era só ícone).
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: NovaCoverImage(
              work: work,
              width: 70.0,
              height: 70.0 / aspectRatio,
            ),
          ),
          const SizedBox(width: NovaSpacing.md),
          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.title,
                  style: NovaTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (work.subtitle != null) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    work.subtitle!,
                    style: NovaTypography.caption.copyWith(
                      color: NovaColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: NovaSpacing.xxs),
                Text(
                  work.author,
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: NovaSpacing.sm),
                // Badges de Idioma e Formatos Disponíveis (G-02: sem
                // "Desconhecido"/"und" crus; metadata-only vira "Catálogo").
                Wrap(
                  spacing: NovaSpacing.xs,
                  runSpacing: NovaSpacing.xs,
                  children: [
                    if (work.primaryLanguage != 'und')
                      _buildMiniBadge(work.primaryLanguage, NovaColors.accent),
                    ...work.editions
                        .map((e) => e.format)
                        .where((f) => f != WorkFormat.unknown)
                        .toSet()
                        .map(
                          (f) => _buildMiniBadge(
                            f.label,
                            NovaColors.textSecondary,
                          ),
                        ),
                    if (work.editions.every(
                      (e) => e.format == WorkFormat.unknown,
                    ))
                      _buildMiniBadge('Catálogo', NovaColors.textSecondary),
                    if (work.isDownloaded)
                      _buildMiniBadge('Baixado', NovaColors.success),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: NovaColors.textMuted,
            size: 20.0,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: NovaColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: NovaTypography.caption.copyWith(
          fontSize: 10.0,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

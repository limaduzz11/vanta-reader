import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/work.dart';
import '../../../domain/usecases/profile/get_user_profile_usecase.dart';
import '../../../domain/usecases/search_online_catalog_usecase.dart';
import 'search_event.dart';
import 'search_state.dart';

/// BLoC para Busca Online, Catálogo Unificado e Filtros Avançados (Fase J)
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchOnlineCatalogUseCase searchCatalog;
  final GetUserProfileUseCase? getUserProfile;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  String? _activeLanguage;

  SearchBloc({
    required this.searchCatalog,
    this.getUserProfile,
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : super(const SearchInitial()) {
    on<SearchQueryChangedEvent>(_onQueryChanged);
    on<SearchSubmittedEvent>(_onSearchSubmitted);
    on<SearchFilterChangedEvent>(_onFilterChanged);
    on<ClearSearchEvent>(_onClearSearch);
    on<LoadMoreSearchResultsEvent>(_onLoadMore);
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  void _onQueryChanged(
    SearchQueryChangedEvent event,
    Emitter<SearchState> emit,
  ) {
    final cleanQuery = event.query.trim();

    if (cleanQuery.isEmpty) {
      _debounceTimer?.cancel();
      final current = state;
      WorkType? currentType;
      String? currentLang;
      WorkFormat? currentFormat;

      if (current is SearchSuccess) {
        currentType = current.typeFilter;
        currentLang = current.languageFilter;
        currentFormat = current.formatFilter;
      } else if (current is SearchInitial) {
        currentType = current.typeFilter;
        currentLang = current.languageFilter;
        currentFormat = current.formatFilter;
      }

      emit(
        SearchInitial(
          typeFilter: currentType,
          languageFilter: currentLang,
          formatFilter: currentFormat,
        ),
      );
      return;
    }

    if (debounceDuration == Duration.zero) {
      _performSearch(cleanQuery, emit);
      return;
    }

    _debounceTimer?.cancel();
    final completer = Completer<void>();
    _debounceTimer = Timer(debounceDuration, () {
      add(SearchSubmittedEvent(cleanQuery));
      completer.complete();
    });
  }

  Future<void> _onSearchSubmitted(
    SearchSubmittedEvent event,
    Emitter<SearchState> emit,
  ) async {
    _debounceTimer?.cancel();
    await _performSearch(event.query.trim(), emit);
  }

  Future<void> _performSearch(String query, Emitter<SearchState> emit) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Regra de proteção: consultas com 1 caractere geram catálogo inteiro com
    // ruído/bytecost. Sem resultados para query curta.
    if (trimmed.length < 2) {
      emit(SearchEmpty(query: trimmed));
      return;
    }

    final current = state;
    WorkType? currentType;
    String? currentLang;
    WorkFormat? currentFormat;
    SearchSortBy currentSort = SearchSortBy.relevance;

    if (current is SearchSuccess) {
      currentType = current.typeFilter;
      currentLang = current.languageFilter;
      currentFormat = current.formatFilter;
      currentSort = current.sortBy;
    } else if (current is SearchInitial) {
      currentType = current.typeFilter;
      currentLang = current.languageFilter;
      currentFormat = current.formatFilter;
    }

    String? userPrefLang;
    if (getUserProfile != null) {
      try {
        final profile = await getUserProfile!();
        userPrefLang = profile.preferredLanguage;
      } catch (_) {}
    }
    userPrefLang ??= 'pt-BR';
    _activeLanguage = userPrefLang;

    emit(
      SearchLoading(
        query: query,
        typeFilter: currentType,
        languageFilter: currentLang,
        formatFilter: currentFormat,
      ),
    );

    try {
      final results = await searchCatalog(
        query,
        type: currentType,
        language: currentLang,
        preferredLanguage: userPrefLang,
        page: 1,
        pageSize: 20,
      );

      if (results.isEmpty) {
        emit(
          SearchEmpty(
            query: query,
            typeFilter: currentType,
            languageFilter: currentLang,
            formatFilter: currentFormat,
          ),
        );
        return;
      }

      final filtered = _applyFormatFilterAndSorting(
        results,
        currentFormat,
        currentSort,
      );

      emit(
        SearchSuccess(
          query: query,
          works: filtered,
          allWorks: results,
          typeFilter: currentType,
          languageFilter: currentLang,
          formatFilter: currentFormat,
          sortBy: currentSort,
          page: 1,
          hasReachedMax: results.length < 20,
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.provider,
        'Erro ao executar busca por "$query": $e',
        e,
        stack,
      );
      emit(
        SearchError(
          query: query,
          message: 'Ocorreu um erro ao buscar obras. Tente novamente.',
        ),
      );
    }
  }

  Future<void> _onFilterChanged(
    SearchFilterChangedEvent event,
    Emitter<SearchState> emit,
  ) async {
    final current = state;

    if (current is SearchSuccess) {
      final newType = event.typeFilter;
      final newLang = event.languageFilter;
      final newFormat = event.formatFilter;
      final newSort = event.sortBy ?? current.sortBy;

      // Se o filtro de tipo ou idioma mudou, refaz a busca remota
      if (newType != current.typeFilter || newLang != current.languageFilter) {
        emit(
          SearchLoading(
            query: current.query,
            typeFilter: newType,
            languageFilter: newLang,
            formatFilter: newFormat,
          ),
        );

        try {
          final results = await searchCatalog(
            current.query,
            type: newType,
            language: newLang,
            preferredLanguage: _activeLanguage,
            page: 1,
            pageSize: 20,
          );

          if (results.isEmpty) {
            emit(
              SearchEmpty(
                query: current.query,
                typeFilter: newType,
                languageFilter: newLang,
                formatFilter: newFormat,
              ),
            );
            return;
          }

          final filtered = _applyFormatFilterAndSorting(
            results,
            newFormat,
            newSort,
          );

          emit(
            SearchSuccess(
              query: current.query,
              works: filtered,
              allWorks: results,
              typeFilter: newType,
              languageFilter: newLang,
              formatFilter: newFormat,
              sortBy: newSort,
              page: 1,
              hasReachedMax: results.length < 20,
            ),
          );
        } catch (e) {
          emit(
            SearchError(
              query: current.query,
              message: 'Falha ao aplicar filtros.',
            ),
          );
        }
      } else {
        // Apenas filtro de formato ou ordenação em memória
        final filtered = _applyFormatFilterAndSorting(
          current.allWorks,
          newFormat,
          newSort,
        );
        emit(
          current.copyWith(
            works: filtered,
            formatFilter: newFormat,
            sortBy: newSort,
            resetFormatFilter: newFormat == null,
          ),
        );
      }
    } else if (current is SearchInitial) {
      emit(
        SearchInitial(
          typeFilter: event.typeFilter,
          languageFilter: event.languageFilter,
          formatFilter: event.formatFilter,
        ),
      );
    }
  }

  void _onClearSearch(ClearSearchEvent event, Emitter<SearchState> emit) {
    _debounceTimer?.cancel();
    final current = state;
    WorkType? currentType;
    String? currentLang;
    WorkFormat? currentFormat;

    if (current is SearchSuccess) {
      currentType = current.typeFilter;
      currentLang = current.languageFilter;
      currentFormat = current.formatFilter;
    }

    emit(
      SearchInitial(
        typeFilter: currentType,
        languageFilter: currentLang,
        formatFilter: currentFormat,
      ),
    );
  }

  Future<void> _onLoadMore(
    LoadMoreSearchResultsEvent event,
    Emitter<SearchState> emit,
  ) async {
    final current = state;
    if (current is! SearchSuccess || current.hasReachedMax) return;

    final nextPage = current.page + 1;

    try {
      final moreResults = await searchCatalog(
        current.query,
        type: current.typeFilter,
        language: current.languageFilter,
        preferredLanguage: _activeLanguage,
        page: nextPage,
        pageSize: 20,
      );

      if (moreResults.isEmpty) {
        emit(current.copyWith(hasReachedMax: true));
        return;
      }

      // Paginação NÃO pode reintroduzir duplicatas: rededuplica por workKey.
      final knownKeys = current.allWorks.map((w) => w.workKey).toSet();
      final uniqueMore = moreResults
          .where((w) => !knownKeys.contains(w.workKey))
          .toList();
      if (uniqueMore.isEmpty) {
        emit(current.copyWith(hasReachedMax: true));
        return;
      }

      final combined = List<Work>.from(current.allWorks)..addAll(uniqueMore);
      final filtered = _applyFormatFilterAndSorting(
        combined,
        current.formatFilter,
        current.sortBy,
      );

      emit(
        current.copyWith(
          page: nextPage,
          works: filtered,
          allWorks: combined,
          hasReachedMax: uniqueMore.length < 20,
        ),
      );
    } catch (e) {
      // Falha de paginação silenciosa, mantém estado atual
      AppLogger.warn(
        LogCategory.provider,
        'Falha ao carregar mais resultados de busca: $e',
      );
    }
  }

  List<Work> _applyFormatFilterAndSorting(
    List<Work> works,
    WorkFormat? formatFilter,
    SearchSortBy sortOrder,
  ) {
    var list = works;

    if (formatFilter != null) {
      list = list.where((work) {
        return work.editions.any((e) => e.format == formatFilter);
      }).toList();
    } else {
      list = List.of(list);
    }

    switch (sortOrder) {
      case SearchSortBy.titleAsc:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SearchSortBy.newest:
        list.sort(
          (a, b) => (b.publishedDate ?? '').compareTo(a.publishedDate ?? ''),
        );
        break;
      case SearchSortBy.relevance:
        // Mantém ordem natural calculada pelo ProviderManager
        break;
    }

    return list;
  }
}

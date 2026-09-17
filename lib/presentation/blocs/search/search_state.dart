import 'package:equatable/equatable.dart';
import '../../../domain/entities/work.dart';

/// Opções de Ordenação dos Resultados de Busca
enum SearchSortBy {
  relevance('Relevância'),
  newest('Mais Recentes'),
  titleAsc('Título (A-Z)');

  final String label;
  const SearchSortBy(this.label);
}

/// Estados do SearchBloc
abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

/// Estado Inicial: aguardando digitação do usuário ou exibindo histórico/sugestões
class SearchInitial extends SearchState {
  final WorkType? typeFilter;
  final String? languageFilter;
  final WorkFormat? formatFilter;
  final List<String> recentSearches;

  const SearchInitial({
    this.typeFilter,
    this.languageFilter,
    this.formatFilter,
    this.recentSearches = const [
      'Duna',
      'Clean Code',
      'Watchmen',
      'Akira',
      'Neuromancer',
      'Fundação',
    ],
  });

  @override
  List<Object?> get props => [
    typeFilter,
    languageFilter,
    formatFilter,
    recentSearches,
  ];
}

/// Estado de Carregamento da Busca
class SearchLoading extends SearchState {
  final String query;
  final WorkType? typeFilter;
  final String? languageFilter;
  final WorkFormat? formatFilter;
  final List<Work> previousWorks;

  const SearchLoading({
    required this.query,
    this.typeFilter,
    this.languageFilter,
    this.formatFilter,
    this.previousWorks = const [],
  });

  @override
  List<Object?> get props => [
    query,
    typeFilter,
    languageFilter,
    formatFilter,
    previousWorks,
  ];
}

/// Estado de Sucesso com Resultados Encontrados
class SearchSuccess extends SearchState {
  final String query;
  final List<Work> works;
  final List<Work> allWorks;
  final WorkType? typeFilter;
  final String? languageFilter;
  final WorkFormat? formatFilter;
  final SearchSortBy sortBy;
  final int page;
  final bool hasReachedMax;

  const SearchSuccess({
    required this.query,
    required this.works,
    required this.allWorks,
    this.typeFilter,
    this.languageFilter,
    this.formatFilter,
    this.sortBy = SearchSortBy.relevance,
    this.page = 1,
    this.hasReachedMax = false,
  });

  SearchSuccess copyWith({
    String? query,
    List<Work>? works,
    List<Work>? allWorks,
    WorkType? typeFilter,
    String? languageFilter,
    WorkFormat? formatFilter,
    SearchSortBy? sortBy,
    int? page,
    bool? hasReachedMax,
    bool resetTypeFilter = false,
    bool resetLanguageFilter = false,
    bool resetFormatFilter = false,
  }) {
    return SearchSuccess(
      query: query ?? this.query,
      works: works ?? this.works,
      allWorks: allWorks ?? this.allWorks,
      typeFilter: resetTypeFilter ? null : (typeFilter ?? this.typeFilter),
      languageFilter: resetLanguageFilter
          ? null
          : (languageFilter ?? this.languageFilter),
      formatFilter: resetFormatFilter
          ? null
          : (formatFilter ?? this.formatFilter),
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [
    query,
    works,
    allWorks,
    typeFilter,
    languageFilter,
    formatFilter,
    sortBy,
    page,
    hasReachedMax,
  ];
}

/// Estado de Busca Concluída mas Sem Resultados
class SearchEmpty extends SearchState {
  final String query;
  final WorkType? typeFilter;
  final String? languageFilter;
  final WorkFormat? formatFilter;

  const SearchEmpty({
    required this.query,
    this.typeFilter,
    this.languageFilter,
    this.formatFilter,
  });

  @override
  List<Object?> get props => [query, typeFilter, languageFilter, formatFilter];
}

/// Estado de Erro na Busca
class SearchError extends SearchState {
  final String query;
  final String message;

  const SearchError({required this.query, required this.message});

  @override
  List<Object?> get props => [query, message];
}

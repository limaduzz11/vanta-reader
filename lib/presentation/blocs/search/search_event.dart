import 'package:equatable/equatable.dart';
import '../../../domain/entities/work.dart';
import 'search_state.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Evento disparado quando o usuário digita na barra de busca (sujeito a debounce)
class SearchQueryChangedEvent extends SearchEvent {
  final String query;

  const SearchQueryChangedEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Evento disparado quando o usuário submete a busca explicitamente (tecla Enter)
class SearchSubmittedEvent extends SearchEvent {
  final String query;

  const SearchSubmittedEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Evento para alteração de filtros de catálogo (tipo, idioma, formato, ordenação)
class SearchFilterChangedEvent extends SearchEvent {
  final WorkType? typeFilter;
  final String? languageFilter;
  final WorkFormat? formatFilter;
  final SearchSortBy? sortBy;

  const SearchFilterChangedEvent({
    this.typeFilter,
    this.languageFilter,
    this.formatFilter,
    this.sortBy,
  });

  @override
  List<Object?> get props => [typeFilter, languageFilter, formatFilter, sortBy];
}

/// Evento para limpar o campo de busca
class ClearSearchEvent extends SearchEvent {
  const ClearSearchEvent();
}

/// Evento de paginação infinita (carregar mais resultados)
class LoadMoreSearchResultsEvent extends SearchEvent {
  const LoadMoreSearchResultsEvent();
}

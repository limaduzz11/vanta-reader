import 'package:equatable/equatable.dart';
import '../../../domain/entities/work.dart';

/// Eventos do BLoC de Biblioteca
abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega ou recarrega as obras da biblioteca aplicando filtros opcionais
class LoadLibraryEvent extends LibraryEvent {
  final WorkType? filterType;
  final String? language;
  final bool onlyFavorites;
  final bool onlyDownloaded;
  final String? searchQuery;

  const LoadLibraryEvent({
    this.filterType,
    this.language,
    this.onlyFavorites = false,
    this.onlyDownloaded = false,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [
    filterType,
    language,
    onlyFavorites,
    onlyDownloaded,
    searchQuery,
  ];
}

/// Alterna o status de favorito de uma obra
class ToggleFavoriteEvent extends LibraryEvent {
  final String workId;

  const ToggleFavoriteEvent(this.workId);

  @override
  List<Object?> get props => [workId];
}

/// Busca rápida local
class SearchLibraryLocalEvent extends LibraryEvent {
  final String query;

  const SearchLibraryLocalEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Importa um arquivo do armazenamento local do dispositivo
class ImportWorkEvent extends LibraryEvent {
  final String filePath;

  const ImportWorkEvent(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

/// Remove uma obra da biblioteca local e do banco SQLite
class RemoveWorkFromLibraryEvent extends LibraryEvent {
  final String workId;

  const RemoveWorkFromLibraryEvent(this.workId);

  @override
  List<Object?> get props => [workId];
}

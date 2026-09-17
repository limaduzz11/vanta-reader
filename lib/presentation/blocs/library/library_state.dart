import 'package:equatable/equatable.dart';
import '../../../domain/entities/work.dart';

/// Estados do BLoC de Biblioteca
abstract class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  final List<Work> works;
  final Set<String> favoriteWorkIds;
  final WorkType? currentFilter;
  final bool onlyFavorites;
  final bool onlyDownloaded;
  final String? searchQuery;
  final String? lastImportedTitle;

  const LibraryLoaded({
    required this.works,
    required this.favoriteWorkIds,
    this.currentFilter,
    this.onlyFavorites = false,
    this.onlyDownloaded = false,
    this.searchQuery,
    this.lastImportedTitle,
  });

  bool isFavorite(String workId) => favoriteWorkIds.contains(workId);

  LibraryLoaded copyWith({
    List<Work>? works,
    Set<String>? favoriteWorkIds,
    WorkType? currentFilter,
    bool? onlyFavorites,
    bool? onlyDownloaded,
    String? searchQuery,
    String? lastImportedTitle,
  }) {
    return LibraryLoaded(
      works: works ?? this.works,
      favoriteWorkIds: favoriteWorkIds ?? this.favoriteWorkIds,
      currentFilter: currentFilter ?? this.currentFilter,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      onlyDownloaded: onlyDownloaded ?? this.onlyDownloaded,
      searchQuery: searchQuery ?? this.searchQuery,
      lastImportedTitle: lastImportedTitle,
    );
  }

  @override
  List<Object?> get props => [
    works,
    favoriteWorkIds,
    currentFilter,
    onlyFavorites,
    onlyDownloaded,
    searchQuery,
    lastImportedTitle,
  ];
}

class LibraryError extends LibraryState {
  final String message;

  const LibraryError(this.message);

  @override
  List<Object?> get props => [message];
}

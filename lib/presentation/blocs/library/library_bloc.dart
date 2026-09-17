import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/repositories/i_library_repository.dart';
import '../../../domain/usecases/get_library_works_usecase.dart';
import '../../../domain/usecases/import_work_usecase.dart';
import '../../../domain/usecases/search_local_library_usecase.dart';
import '../../../domain/usecases/toggle_favorite_usecase.dart';
import 'library_event.dart';
import 'library_state.dart';

/// Gerenciador de Estado BLoC para a Biblioteca Local
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final GetLibraryWorksUseCase getLibraryWorks;
  final ToggleFavoriteUseCase toggleFavorite;
  final SearchLocalLibraryUseCase searchLocalLibrary;
  final ImportWorkUseCase? importWork;
  final ILibraryRepository? libraryRepository;

  LibraryBloc({
    required this.getLibraryWorks,
    required this.toggleFavorite,
    required this.searchLocalLibrary,
    this.importWork,
    this.libraryRepository,
  }) : super(const LibraryInitial()) {
    on<LoadLibraryEvent>(_onLoadLibrary);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<SearchLibraryLocalEvent>(_onSearchLibraryLocal);
    on<ImportWorkEvent>(_onImportWork);
    on<RemoveWorkFromLibraryEvent>(_onRemoveWorkFromLibrary);
  }

  Future<void> _onLoadLibrary(
    LoadLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    try {
      final works = await getLibraryWorks(
        filterType: event.filterType,
        language: event.language,
        onlyFavorites: event.onlyFavorites,
        onlyDownloaded: event.onlyDownloaded,
      );

      final favorites = <String>{};
      for (final work in works) {
        if (await toggleFavorite.isFavorite(work.id)) {
          favorites.add(work.id);
        }
      }

      emit(
        LibraryLoaded(
          works: works,
          favoriteWorkIds: favorites,
          currentFilter: event.filterType,
          onlyFavorites: event.onlyFavorites,
          onlyDownloaded: event.onlyDownloaded,
          searchQuery: event.searchQuery,
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao carregar biblioteca local: $e',
        e,
        stack,
      );
      emit(LibraryError('Erro ao carregar acervo local: $e'));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    try {
      final isNowFavorite = await toggleFavorite.execute(event.workId);

      if (currentState is LibraryLoaded) {
        final updatedFavorites = Set<String>.from(currentState.favoriteWorkIds);
        if (isNowFavorite) {
          updatedFavorites.add(event.workId);
        } else {
          updatedFavorites.remove(event.workId);
        }

        // Se o filtro atual for "apenas favoritos" e foi desfavoritado, remove da lista
        var updatedWorks = currentState.works;
        if (currentState.onlyFavorites && !isNowFavorite) {
          updatedWorks = currentState.works
              .where((w) => w.id != event.workId)
              .toList();
        }

        emit(
          currentState.copyWith(
            works: updatedWorks,
            favoriteWorkIds: updatedFavorites,
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao alternar favorito obra ${event.workId}: $e',
        e,
        stack,
      );
    }
  }

  Future<void> _onSearchLibraryLocal(
    SearchLibraryLocalEvent event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    try {
      final works = await searchLocalLibrary(event.query);
      final favorites = <String>{};
      for (final work in works) {
        if (await toggleFavorite.isFavorite(work.id)) {
          favorites.add(work.id);
        }
      }

      emit(
        LibraryLoaded(
          works: works,
          favoriteWorkIds: favorites,
          searchQuery: event.query,
        ),
      );
    } catch (e, stack) {
      AppLogger.error(LogCategory.app, 'Falha na busca local: $e', e, stack);
      emit(LibraryError('Erro na busca local: $e'));
    }
  }

  Future<void> _onImportWork(
    ImportWorkEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final useCase = importWork;
    if (useCase == null) {
      AppLogger.warn(
        LogCategory.app,
        'ImportWorkUseCase não fornecido ao LibraryBloc.',
      );
      return;
    }

    try {
      final importedWork = await useCase(event.filePath);

      // Recarrega a biblioteca completa para exibir a nova obra
      final works = await getLibraryWorks();
      final favorites = <String>{};
      for (final work in works) {
        if (await toggleFavorite.isFavorite(work.id)) {
          favorites.add(work.id);
        }
      }

      emit(
        LibraryLoaded(
          works: works,
          favoriteWorkIds: favorites,
          lastImportedTitle: importedWork.title,
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao importar obra do arquivo ${event.filePath}: $e',
        e,
        stack,
      );
      emit(LibraryError('Erro ao importar obra: $e'));
    }
  }

  Future<void> _onRemoveWorkFromLibrary(
    RemoveWorkFromLibraryEvent event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    try {
      if (libraryRepository != null) {
        // G-01 fim-a-fim: remover da Biblioteca também apaga os arquivos
        // físicos das edições locais (antes ficavam órfãos no aparelho).
        try {
          final work = await libraryRepository!.getWorkById(event.workId);
          if (work != null) {
            for (final edition in work.editions) {
              final path = edition.filePath;
              if (path != null && path.isNotEmpty) {
                try {
                  final file = File(path);
                  if (await file.exists()) await file.delete();
                } catch (_) {}
                try {
                  final part = File('$path.part');
                  if (await part.exists()) await part.delete();
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
        await libraryRepository!.deleteWork(event.workId);
      }
      if (currentState is LibraryLoaded) {
        final updatedWorks = currentState.works
            .where((w) => w.id != event.workId)
            .toList();
        final updatedFavorites = Set<String>.from(currentState.favoriteWorkIds)
          ..remove(event.workId);
        emit(
          currentState.copyWith(
            works: updatedWorks,
            favoriteWorkIds: updatedFavorites,
          ),
        );
      } else {
        add(const LoadLibraryEvent());
      }
      AppLogger.info(
        LogCategory.app,
        'Obra ${event.workId} removida da biblioteca com sucesso.',
      );
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao remover obra ${event.workId}: $e',
        e,
        stack,
      );
    }
  }
}

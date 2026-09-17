import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/repositories/i_library_repository.dart';
import '../../../domain/usecases/get_reading_progress_usecase.dart';
import '../../../domain/usecases/save_reading_progress_usecase.dart';
import '../../../domain/usecases/toggle_favorite_usecase.dart';
import 'work_details_event.dart';
import 'work_details_state.dart';

/// Gerenciador de Estado BLoC para a tela de Detalhes da Obra
class WorkDetailsBloc extends Bloc<WorkDetailsEvent, WorkDetailsState> {
  final ILibraryRepository libraryRepository;
  final ToggleFavoriteUseCase toggleFavorite;
  final GetReadingProgressUseCase getProgress;
  final SaveReadingProgressUseCase saveProgress;

  WorkDetailsBloc({
    required this.libraryRepository,
    required this.toggleFavorite,
    required this.getProgress,
    required this.saveProgress,
  }) : super(const WorkDetailsInitial()) {
    on<LoadWorkDetailsEvent>(_onLoadWorkDetails);
    on<ToggleDetailsFavoriteEvent>(_onToggleDetailsFavorite);
    on<UpdateDetailsProgressEvent>(_onUpdateDetailsProgress);
  }

  Future<void> _onLoadWorkDetails(
    LoadWorkDetailsEvent event,
    Emitter<WorkDetailsState> emit,
  ) async {
    emit(const WorkDetailsLoading());
    try {
      final work = await libraryRepository.getWorkById(event.workId);
      if (work == null) {
        emit(const WorkDetailsError('Obra não encontrada no banco local.'));
        return;
      }

      final isFav = await toggleFavorite.isFavorite(event.workId);
      final progress = await getProgress(event.workId);

      emit(
        WorkDetailsLoaded(work: work, isFavorite: isFav, progress: progress),
      );
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao carregar detalhes da obra: $e',
        e,
        stack,
      );
      emit(WorkDetailsError('Erro ao carregar detalhes: $e'));
    }
  }

  Future<void> _onToggleDetailsFavorite(
    ToggleDetailsFavoriteEvent event,
    Emitter<WorkDetailsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WorkDetailsLoaded) return;

    try {
      final newStatus = await toggleFavorite.execute(event.workId);
      emit(currentState.copyWith(isFavorite: newStatus));
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao alternar favorito em detalhes: $e',
        e,
        stack,
      );
    }
  }

  Future<void> _onUpdateDetailsProgress(
    UpdateDetailsProgressEvent event,
    Emitter<WorkDetailsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WorkDetailsLoaded) return;

    try {
      await saveProgress(event.progress);
      emit(currentState.copyWith(progress: event.progress));
    } catch (e, stack) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao atualizar progresso de leitura: $e',
        e,
        stack,
      );
    }
  }
}

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/download/download_progress_snapshot.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/usecases/downloads/download_usecases.dart';
import 'downloads_event.dart';
import 'downloads_state.dart';

/// Gerenciador de Estado BLoC para a Fila e Tela de Downloads (Fase H)
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  final GetDownloadsUseCase getDownloads;
  final PauseDownloadUseCase pauseDownload;
  final ResumeDownloadUseCase resumeDownload;
  final CancelDownloadUseCase cancelDownload;
  final RetryDownloadUseCase retryDownload;
  final DeleteDownloadUseCase deleteDownload;
  final ClearCompletedDownloadsUseCase clearCompletedDownloads;

  StreamSubscription? _listSubscription;
  StreamSubscription? _progressSubscription;

  DownloadsBloc({
    required this.getDownloads,
    required this.pauseDownload,
    required this.resumeDownload,
    required this.cancelDownload,
    required this.retryDownload,
    required this.deleteDownload,
    required this.clearCompletedDownloads,
    DownloadsState initialState = const DownloadsInitial(),
  }) : super(initialState) {
    on<LoadDownloadsEvent>(_onLoadDownloads);
    on<DownloadsUpdatedEvent>(_onDownloadsUpdated);
    on<DownloadProgressUpdatedEvent>(_onDownloadProgressUpdated);
    on<PauseDownloadEvent>(_onPauseDownload);
    on<ResumeDownloadEvent>(_onResumeDownload);
    on<CancelDownloadEvent>(_onCancelDownload);
    on<RetryDownloadEvent>(_onRetryDownload);
    on<DeleteDownloadEvent>(_onDeleteDownload);
    on<ClearCompletedDownloadsEvent>(_onClearCompletedDownloads);

    // Conecta às streams do DownloadManager
    _listSubscription = getDownloads.listStream.listen((items) {
      add(DownloadsUpdatedEvent(items));
    });

    _progressSubscription = getDownloads.progressStream.listen((snapshot) {
      add(DownloadProgressUpdatedEvent(snapshot));
    });
  }

  Future<void> _onLoadDownloads(
    LoadDownloadsEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    emit(const DownloadsLoading());

    try {
      final items = await getDownloads.getAll();
      emit(DownloadsLoaded(downloads: items));
    } catch (e, st) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao carregar lista de downloads: $e',
        e,
        st,
      );
      emit(DownloadsError('Não foi possível carregar os downloads: $e'));
    }
  }

  void _onDownloadsUpdated(
    DownloadsUpdatedEvent event,
    Emitter<DownloadsState> emit,
  ) {
    final current = state;
    if (current is DownloadsLoaded) {
      emit(current.copyWith(downloads: event.downloads));
    } else {
      emit(DownloadsLoaded(downloads: event.downloads));
    }
  }

  void _onDownloadProgressUpdated(
    DownloadProgressUpdatedEvent event,
    Emitter<DownloadsState> emit,
  ) {
    final current = state;
    if (current is! DownloadsLoaded) return;

    final updatedMap = Map<String, DownloadProgressSnapshot>.from(
      current.progressMap,
    );
    updatedMap[event.snapshot.downloadId] = event.snapshot;

    emit(current.copyWith(progressMap: updatedMap));
  }

  Future<void> _onPauseDownload(
    PauseDownloadEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await pauseDownload(event.downloadId);
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao pausar download ${event.downloadId}: $e',
      );
    }
  }

  Future<void> _onResumeDownload(
    ResumeDownloadEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await resumeDownload(event.downloadId);
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao retomar download ${event.downloadId}: $e',
      );
    }
  }

  Future<void> _onCancelDownload(
    CancelDownloadEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await cancelDownload(event.downloadId);
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao cancelar download ${event.downloadId}: $e',
      );
    }
  }

  Future<void> _onRetryDownload(
    RetryDownloadEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await retryDownload(event.downloadId);
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao reiniciar download ${event.downloadId}: $e',
      );
    }
  }

  Future<void> _onDeleteDownload(
    DeleteDownloadEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await deleteDownload(event.downloadId, deleteFile: event.deleteFile);
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao excluir download ${event.downloadId}: $e',
      );
    }
  }

  Future<void> _onClearCompletedDownloads(
    ClearCompletedDownloadsEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    try {
      await clearCompletedDownloads();
    } catch (e) {
      AppLogger.error(
        LogCategory.database,
        'Erro ao limpar downloads concluídos: $e',
      );
    }
  }

  @override
  Future<void> close() {
    _listSubscription?.cancel();
    _progressSubscription?.cancel();
    return super.close();
  }
}

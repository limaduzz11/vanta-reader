import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/reader/comic_content_parser.dart';
import '../../../core/reader/reading_session.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/work.dart';
import '../../../domain/usecases/get_reading_progress_usecase.dart';
import '../../../domain/usecases/prepare_reading_session_usecase.dart';
import '../../../domain/usecases/promote_reading_session_usecase.dart';
import '../../../domain/usecases/save_reading_progress_usecase.dart';
import 'comic_reader_event.dart';
import 'comic_reader_state.dart';

/// Gerenciador de Estado BLoC para o Leitor de Quadrinhos (Comic Reader Engine)
class ComicReaderBloc extends Bloc<ComicReaderEvent, ComicReaderState> {
  final ComicContentParser contentParser;
  final GetReadingProgressUseCase getProgress;
  final SaveReadingProgressUseCase saveProgress;
  final PrepareReadingSessionUseCase? prepareSession;
  final PromoteReadingSessionUseCase? promoteSession;

  ComicReaderBloc({
    required this.contentParser,
    required this.getProgress,
    required this.saveProgress,
    this.prepareSession,
    this.promoteSession,
    ComicReaderState initialState = const ComicReaderInitial(),
  }) : super(initialState) {
    on<OpenComicEvent>(_onOpenComic);
    on<NextComicPageEvent>(_onNextComicPage);
    on<PreviousComicPageEvent>(_onPreviousComicPage);
    on<JumpToComicPageEvent>(_onJumpToComicPage);
    on<ToggleComicControlsEvent>(_onToggleComicControls);
    on<ChangeReadingModeEvent>(_onChangeReadingMode);
    on<ChangeFitModeEvent>(_onChangeFitMode);
    on<ToggleDoublePageEvent>(_onToggleDoublePage);
    on<ToggleRtlEvent>(_onToggleRtl);
    on<PromoteComicToLocalEvent>(_onPromoteToLocal);
  }

  Future<void> _onOpenComic(
    OpenComicEvent event,
    Emitter<ComicReaderState> emit,
  ) async {
    emit(const ComicReaderLoading('Abrindo quadrinho...'));

    try {
      ReadingSession? session;
      WorkEdition effectiveEdition = event.edition;

      if (prepareSession != null) {
        emit(const ComicReaderLoading('Preparando streaming do quadrinho...'));
        session = await prepareSession!(
          work: event.work,
          edition: event.edition,
        );
        effectiveEdition = event.edition.copyWith(
          filePath: session.resolvedFilePath,
        );
      }

      final content = await contentParser.parse(
        work: event.work,
        edition: effectiveEdition,
      );

      final totalPages = content.totalPages > 0 ? content.totalPages : 1;

      // Recupera marco prévio no SQLite
      final savedProgress = await getProgress(event.work.id);

      int initialPageIndex = 0;
      double percentage = 0.0;

      if (savedProgress != null && savedProgress.currentPage > 0) {
        initialPageIndex = (savedProgress.currentPage - 1).clamp(
          0,
          totalPages - 1,
        );
        percentage = (initialPageIndex + 1) / totalPages;
      }

      AppLogger.info(
        LogCategory.reader,
        'Quadrinho "${content.title}" carregado. Início na pág. ${initialPageIndex + 1}/$totalPages (${percentage.toStringAsFixed(1)}%) - Origem: ${session?.source.label ?? 'Direto'}',
      );

      emit(
        ComicReaderLoaded(
          work: event.work,
          edition: effectiveEdition,
          content: content,
          currentPageIndex: initialPageIndex,
          totalPages: totalPages,
          percentage: percentage,
          session: session,
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        LogCategory.reader,
        'Erro ao abrir quadrinho para leitura: ${event.work.title}',
        e,
        st,
      );
      emit(ComicReaderError('Não foi possível carregar o quadrinho: $e'));
    }
  }

  Future<void> _onPromoteToLocal(
    PromoteComicToLocalEvent event,
    Emitter<ComicReaderState> emit,
  ) async {
    final current = state;
    if (current is! ComicReaderLoaded || current.session == null) return;
    if (promoteSession == null) return;

    try {
      emit(current.copyWith(isPromotingToLocal: true));
      final promotedEdition = await promoteSession!(current.session!);
      final updatedSession = ReadingSession(
        work: current.work,
        edition: promotedEdition,
        source: ReadingSource.local,
        resolvedFilePath: promotedEdition.filePath!,
        isTemporaryCache: false,
        fileSize: promotedEdition.fileSize,
        providerName: current.session!.providerName,
      );
      emit(
        current.copyWith(
          edition: promotedEdition,
          session: updatedSession,
          isPromotingToLocal: false,
        ),
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.reader,
        'Falha ao promover quadrinho para local',
        e,
      );
      emit(current.copyWith(isPromotingToLocal: false));
    }
  }

  Future<void> _onNextComicPage(
    NextComicPageEvent event,
    Emitter<ComicReaderState> emit,
  ) async {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    if (current.currentPageIndex < current.totalPages - 1) {
      final newIndex = current.currentPageIndex + 1;
      final newPercentage = (newIndex + 1) / current.totalPages;

      await _persistProgress(current, newIndex + 1, newPercentage);

      emit(
        current.copyWith(currentPageIndex: newIndex, percentage: newPercentage),
      );
    }
  }

  Future<void> _onPreviousComicPage(
    PreviousComicPageEvent event,
    Emitter<ComicReaderState> emit,
  ) async {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    if (current.currentPageIndex > 0) {
      final newIndex = current.currentPageIndex - 1;
      final newPercentage = (newIndex + 1) / current.totalPages;

      await _persistProgress(current, newIndex + 1, newPercentage);

      emit(
        current.copyWith(currentPageIndex: newIndex, percentage: newPercentage),
      );
    }
  }

  Future<void> _onJumpToComicPage(
    JumpToComicPageEvent event,
    Emitter<ComicReaderState> emit,
  ) async {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    final targetIndex = event.pageIndex.clamp(0, current.totalPages - 1);
    final newPercentage = (targetIndex + 1) / current.totalPages;

    await _persistProgress(current, targetIndex + 1, newPercentage);

    emit(
      current.copyWith(
        currentPageIndex: targetIndex,
        percentage: newPercentage,
      ),
    );
  }

  void _onToggleComicControls(
    ToggleComicControlsEvent event,
    Emitter<ComicReaderState> emit,
  ) {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    emit(current.copyWith(areControlsVisible: !current.areControlsVisible));
  }

  void _onChangeReadingMode(
    ChangeReadingModeEvent event,
    Emitter<ComicReaderState> emit,
  ) {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    emit(
      current.copyWith(
        settings: current.settings.copyWith(readingMode: event.readingMode),
      ),
    );
  }

  void _onChangeFitMode(
    ChangeFitModeEvent event,
    Emitter<ComicReaderState> emit,
  ) {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    emit(
      current.copyWith(
        settings: current.settings.copyWith(fitMode: event.fitMode),
      ),
    );
  }

  void _onToggleDoublePage(
    ToggleDoublePageEvent event,
    Emitter<ComicReaderState> emit,
  ) {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    emit(
      current.copyWith(
        settings: current.settings.copyWith(
          isDoublePageInLandscape: !current.settings.isDoublePageInLandscape,
        ),
      ),
    );
  }

  void _onToggleRtl(ToggleRtlEvent event, Emitter<ComicReaderState> emit) {
    final current = state;
    if (current is! ComicReaderLoaded) return;

    emit(
      current.copyWith(
        settings: current.settings.copyWith(
          readRightToLeft: !current.settings.readRightToLeft,
        ),
      ),
    );
  }

  Future<void> _persistProgress(
    ComicReaderLoaded state,
    int pageNumber,
    double percentage,
  ) async {
    try {
      await saveProgress(
        ReadingProgress(
          workId: state.work.id,
          editionId: state.edition.id,
          currentPage: pageNumber,
          totalPages: state.totalPages,
          percentage: percentage,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      AppLogger.warn(
        LogCategory.reader,
        'Aviso ao persistir progresso do quadrinho: $e',
      );
    }
  }
}

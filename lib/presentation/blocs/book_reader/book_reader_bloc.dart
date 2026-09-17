import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/reader/book_content_parser.dart';
import '../../../core/reader/reading_session.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/work.dart';
import '../../../domain/usecases/get_reading_progress_usecase.dart';
import '../../../domain/usecases/prepare_reading_session_usecase.dart';
import '../../../domain/usecases/promote_reading_session_usecase.dart';
import '../../../domain/usecases/save_reading_progress_usecase.dart';
import 'book_reader_event.dart';
import 'book_reader_state.dart';

/// Gerenciador de Estado BLoC para o Leitor de Livros (Book Reader Engine)
class BookReaderBloc extends Bloc<BookReaderEvent, BookReaderState> {
  final BookContentParser contentParser;
  final GetReadingProgressUseCase getProgress;
  final SaveReadingProgressUseCase saveProgress;
  final PrepareReadingSessionUseCase? prepareSession;
  final PromoteReadingSessionUseCase? promoteSession;

  BookReaderBloc({
    required this.contentParser,
    required this.getProgress,
    required this.saveProgress,
    this.prepareSession,
    this.promoteSession,
    BookReaderState initialState = const BookReaderInitial(),
  }) : super(initialState) {
    on<OpenBookEvent>(_onOpenBook);
    on<NextPageEvent>(_onNextPage);
    on<PreviousPageEvent>(_onPreviousPage);
    on<JumpToChapterEvent>(_onJumpToChapter);
    on<JumpToPageEvent>(_onJumpToPage);
    on<ToggleControlsEvent>(_onToggleControls);
    on<UpdateTypographyEvent>(_onUpdateTypography);
    on<PromoteBookToLocalEvent>(_onPromoteToLocal);
  }

  Future<void> _onOpenBook(
    OpenBookEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    emit(const BookReaderLoading('Abrindo livro...'));

    try {
      ReadingSession? session;
      WorkEdition effectiveEdition = event.edition;

      if (prepareSession != null) {
        emit(const BookReaderLoading('Preparando sessão de leitura...'));
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

      final totalPages = content.totalEstimatedPages > 0
          ? content.totalEstimatedPages
          : 1;

      // Recupera o último marco de leitura persistido no SQLite
      final savedProgress = await getProgress(event.work.id);

      int initialPage = 1;
      int initialChapterIndex = 0;
      double percentage = 0.0;

      if (savedProgress != null && savedProgress.currentPage > 0) {
        initialPage = savedProgress.currentPage.clamp(1, totalPages);
        percentage = initialPage / totalPages;
        initialChapterIndex = _determineChapterForPage(content, initialPage);
      }

      AppLogger.info(
        LogCategory.reader,
        'Livro "${content.title}" carregado. Início na pág. $initialPage/$totalPages (${percentage.toStringAsFixed(1)}%) - Origem: ${session?.source.label ?? 'Direto'}',
      );

      emit(
        BookReaderLoaded(
          work: event.work,
          edition: effectiveEdition,
          content: content,
          currentChapterIndex: initialChapterIndex,
          currentPage: initialPage,
          totalPages: totalPages,
          percentage: percentage,
          session: session,
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        LogCategory.reader,
        'Erro ao abrir livro para leitura: ${event.work.title}',
        e,
        st,
      );
      emit(BookReaderError('Não foi possível carregar a obra: $e'));
    }
  }

  Future<void> _onPromoteToLocal(
    PromoteBookToLocalEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    final current = state;
    if (current is! BookReaderLoaded || current.session == null) return;
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
    } catch (e, st) {
      AppLogger.error(
        LogCategory.reader,
        'Falha ao promover livro para local',
        e,
        st,
      );
      emit(current.copyWith(isPromotingToLocal: false));
    }
  }

  Future<void> _onNextPage(
    NextPageEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    final current = state;
    if (current is! BookReaderLoaded) return;

    if (current.currentPage < current.totalPages) {
      final newPage = current.currentPage + 1;
      final newPercentage = newPage / current.totalPages;
      final newChapter = _determineChapterForPage(current.content, newPage);

      await _persistProgress(current, newPage, newPercentage);

      emit(
        current.copyWith(
          currentPage: newPage,
          currentChapterIndex: newChapter,
          percentage: newPercentage,
        ),
      );
    }
  }

  Future<void> _onPreviousPage(
    PreviousPageEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    final current = state;
    if (current is! BookReaderLoaded) return;

    if (current.currentPage > 1) {
      final newPage = current.currentPage - 1;
      final newPercentage = newPage / current.totalPages;
      final newChapter = _determineChapterForPage(current.content, newPage);

      await _persistProgress(current, newPage, newPercentage);

      emit(
        current.copyWith(
          currentPage: newPage,
          currentChapterIndex: newChapter,
          percentage: newPercentage,
        ),
      );
    }
  }

  Future<void> _onJumpToChapter(
    JumpToChapterEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    final current = state;
    if (current is! BookReaderLoaded) return;

    final targetIndex = event.chapterIndex.clamp(
      0,
      current.content.chapters.length - 1,
    );
    final targetPage = _calculateStartPageForChapter(
      current.content,
      targetIndex,
    );
    final newPercentage = targetPage / current.totalPages;

    await _persistProgress(current, targetPage, newPercentage);

    emit(
      current.copyWith(
        currentChapterIndex: targetIndex,
        currentPage: targetPage,
        percentage: newPercentage,
      ),
    );
  }

  Future<void> _onJumpToPage(
    JumpToPageEvent event,
    Emitter<BookReaderState> emit,
  ) async {
    final current = state;
    if (current is! BookReaderLoaded) return;

    final newPage = event.page.clamp(1, current.totalPages);
    final newPercentage = newPage / current.totalPages;
    final newChapter = _determineChapterForPage(current.content, newPage);

    await _persistProgress(current, newPage, newPercentage);

    emit(
      current.copyWith(
        currentPage: newPage,
        currentChapterIndex: newChapter,
        percentage: newPercentage,
      ),
    );
  }

  void _onToggleControls(
    ToggleControlsEvent event,
    Emitter<BookReaderState> emit,
  ) {
    final current = state;
    if (current is! BookReaderLoaded) return;

    emit(current.copyWith(areControlsVisible: !current.areControlsVisible));
  }

  void _onUpdateTypography(
    UpdateTypographyEvent event,
    Emitter<BookReaderState> emit,
  ) {
    final current = state;
    if (current is! BookReaderLoaded) return;

    emit(
      current.copyWith(
        typography: current.typography.copyWith(
          fontSize: event.fontSize,
          lineHeight: event.lineHeight,
          fontFamily: event.fontFamily,
          themeMode: event.themeMode,
        ),
      ),
    );
  }

  Future<void> _persistProgress(
    BookReaderLoaded state,
    int page,
    double percentage,
  ) async {
    try {
      await saveProgress(
        ReadingProgress(
          workId: state.work.id,
          editionId: state.edition.id,
          currentPage: page,
          totalPages: state.totalPages,
          percentage: percentage,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      AppLogger.warn(
        LogCategory.reader,
        'Aviso ao persistir progresso de leitura: $e',
      );
    }
  }

  int _determineChapterForPage(dynamic content, int page) {
    int accumulated = 0;
    for (int i = 0; i < content.chapters.length; i++) {
      accumulated += content.chapters[i].estimatedPages as int;
      if (page <= accumulated) {
        return i;
      }
    }
    return content.chapters.isEmpty ? 0 : content.chapters.length - 1;
  }

  int _calculateStartPageForChapter(dynamic content, int chapterIndex) {
    int page = 1;
    for (int i = 0; i < chapterIndex && i < content.chapters.length; i++) {
      page += content.chapters[i].estimatedPages as int;
    }
    return page;
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/reader/comic_content_parser.dart';
import 'package:vantareader/core/reader/comic_models.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/reading_progress.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_event.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/reader_test_fixtures.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;
  late GetReadingProgressUseCase getProgress;
  late SaveReadingProgressUseCase saveProgress;
  late ComicPageCache cache;
  late ComicContentParser parser;
  late ComicReaderBloc bloc;
  late Directory tempDir;
  late WorkEdition sampleEdition;

  final sampleComic = Work(
    id: 'work-comic-bloc-test',
    workKey: 'comic:sandman-preludios',
    title: 'Sandman: Prelúdios & Noturnos',
    author: 'Neil Gaiman',
    type: WorkType.comic,
    primaryLanguage: 'pt-BR',
    description: 'A obra-prima dos quadrinhos modernos.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vanta_comic_reader_test_');
    final cbzFile = File('${tempDir.path}/comic.cbz');
    await cbzFile.writeAsBytes(buildTestCbz());
    sampleEdition = WorkEdition(
      id: 'ed-sandman-01',
      workId: sampleComic.id,
      format: WorkFormat.cbz,
      filePath: cbzFile.path,
      fileSize: await cbzFile.length(),
      pageCount: 8,
      isLocal: true,
    );
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    repository = LibraryRepository(database);
    await repository.saveWork(sampleComic);

    getProgress = GetReadingProgressUseCase(repository);
    saveProgress = SaveReadingProgressUseCase(repository);
    cache = ComicPageCache(maxCapacity: 10);
    parser = ComicContentParser(cache: cache);

    bloc = ComicReaderBloc(
      contentParser: parser,
      getProgress: getProgress,
      saveProgress: saveProgress,
    );
  });

  tearDown(() async {
    await bloc.close();
    await Future.delayed(const Duration(milliseconds: 20));
    await database.close();
    await tempDir.delete(recursive: true);
  });

  group('ComicReaderBloc (Fase G - State Management)', () {
    test('Estado inicial é ComicReaderInitial', () {
      expect(bloc.state, isA<ComicReaderInitial>());
    });

    test(
      'OpenComicEvent carrega conteúdo e posiciona na página inicial (índice 0)',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<ComicReaderLoading>(),
            predicate<ComicReaderLoaded>((state) {
              return state.work.id == sampleComic.id &&
                  state.currentPageIndex == 0 &&
                  state.pageNumber == 1 &&
                  state.totalPages == 8 &&
                  state.areControlsVisible == false &&
                  state.percentage == 0.0;
            }),
          ]),
        );
      },
    );

    test('OpenComicEvent restaura progresso prévio salvo no SQLite', () async {
      // Salva progresso na página 4 de 8 (índice 3)
      await saveProgress(
        ReadingProgress(
          workId: sampleComic.id,
          editionId: sampleEdition.id,
          currentPage: 4,
          totalPages: 8,
          percentage: 0.5,
          updatedAt: DateTime.now(),
        ),
      );

      bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ComicReaderLoading>(),
          predicate<ComicReaderLoaded>((state) {
            return state.currentPageIndex == 3 &&
                state.pageNumber == 4 &&
                state.percentage == 0.5;
          }),
        ]),
      );
    });

    test(
      'NextComicPageEvent e PreviousComicPageEvent navegam entre páginas com persistência no SQLite',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        // Avança para página 2 (índice 1)
        bloc.add(const NextComicPageEvent());

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.currentPageIndex == 1 &&
                  state.pageNumber == 2 &&
                  state.percentage == 0.25;
            }),
          ),
        );

        // Verifica se persistiu no SQLite
        final progress = await getProgress(sampleComic.id);
        expect(progress, isNotNull);
        expect(progress!.currentPage, equals(2));
        expect(progress.percentage, equals(0.25));

        // Retrocede para página 1 (índice 0)
        bloc.add(const PreviousComicPageEvent());

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.currentPageIndex == 0 &&
                  state.pageNumber == 1 &&
                  state.percentage == 0.125;
            }),
          ),
        );

        // Tenta retroceder além do início: não deve emitir nada
        bloc.add(const PreviousComicPageEvent());
        expect(bloc.state, isA<ComicReaderLoaded>());
        expect((bloc.state as ComicReaderLoaded).currentPageIndex, equals(0));
      },
    );

    test(
      'NextComicPageEvent no limite superior não ultrapassa o total de páginas',
      () async {
        // Salva na última página (página 8)
        await saveProgress(
          ReadingProgress(
            workId: sampleComic.id,
            editionId: sampleEdition.id,
            currentPage: 8,
            totalPages: 8,
            percentage: 1.0,
            updatedAt: DateTime.now(),
          ),
        );

        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        expect((bloc.state as ComicReaderLoaded).currentPageIndex, equals(7));

        // Tenta avançar além da última página
        bloc.add(const NextComicPageEvent());
        expect((bloc.state as ComicReaderLoaded).currentPageIndex, equals(7));
      },
    );

    test(
      'JumpToComicPageEvent salta diretamente para o índice de página com clamp e persistência',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        // Salta para a página 6 (índice 5)
        bloc.add(const JumpToComicPageEvent(5));

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.currentPageIndex == 5 &&
                  state.pageNumber == 6 &&
                  state.percentage == 0.75;
            }),
          ),
        );

        final progress = await getProgress(sampleComic.id);
        expect(progress?.currentPage, equals(6));

        // Salta com índice acima do limite (clamp em 7)
        bloc.add(const JumpToComicPageEvent(99));

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.currentPageIndex == 7 &&
                  state.pageNumber == 8 &&
                  state.percentage == 1.0;
            }),
          ),
        );
      },
    );

    test(
      'ToggleComicControlsEvent alterna visibilidade dos controles imersivos',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        expect((bloc.state as ComicReaderLoaded).areControlsVisible, isFalse);

        bloc.add(const ToggleComicControlsEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) => state.areControlsVisible),
          ),
        );

        bloc.add(const ToggleComicControlsEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) => !state.areControlsVisible),
          ),
        );
      },
    );

    test(
      'ChangeReadingModeEvent altera modo de leitura entre page e webtoon',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        bloc.add(const ChangeReadingModeEvent(ComicReadingMode.webtoon));

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.settings.readingMode == ComicReadingMode.webtoon;
            }),
          ),
        );

        bloc.add(const ChangeReadingModeEvent(ComicReadingMode.page));

        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.settings.readingMode == ComicReadingMode.page;
            }),
          ),
        );
      },
    );

    test('ChangeFitModeEvent altera enquadramento da imagem', () async {
      bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
      await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

      // Padrão inicial é fitWidth, alternamos para fitHeight
      bloc.add(const ChangeFitModeEvent(ComicFitMode.fitHeight));

      await expectLater(
        bloc.stream,
        emits(
          predicate<ComicReaderLoaded>((state) {
            return state.settings.fitMode == ComicFitMode.fitHeight;
          }),
        ),
      );

      // Alternamos para fitScreen
      bloc.add(const ChangeFitModeEvent(ComicFitMode.fitScreen));

      await expectLater(
        bloc.stream,
        emits(
          predicate<ComicReaderLoaded>((state) {
            return state.settings.fitMode == ComicFitMode.fitScreen;
          }),
        ),
      );
    });

    test(
      'ToggleDoublePageEvent e ToggleRtlEvent alteram configurações de exibição e orientação',
      () async {
        bloc.add(OpenComicEvent(work: sampleComic, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is ComicReaderLoaded);

        // Alterna modo página dupla
        bloc.add(const ToggleDoublePageEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.settings.isDoublePageInLandscape == true;
            }),
          ),
        );

        // Alterna modo RTL (Mangá)
        bloc.add(const ToggleRtlEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<ComicReaderLoaded>((state) {
              return state.settings.readRightToLeft == true;
            }),
          ),
        );
      },
    );
  });
}

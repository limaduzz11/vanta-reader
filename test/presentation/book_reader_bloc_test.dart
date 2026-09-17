import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/reader/book_content_parser.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/reading_progress.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_event.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/reader_test_fixtures.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;
  late GetReadingProgressUseCase getProgress;
  late SaveReadingProgressUseCase saveProgress;
  late BookContentParser parser;
  late BookReaderBloc bloc;
  late Directory tempDir;
  late WorkEdition sampleEdition;

  final sampleWork = Work(
    id: 'work-reader-1',
    workKey: 'book:o-fim-da-eternidade',
    title: 'O Fim da Eternidade',
    author: 'Isaac Asimov',
    type: WorkType.book,
    primaryLanguage: 'pt-BR',
    description: 'Um clássico da ficção científica.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vanta_book_reader_test_');
    final epubFile = File('${tempDir.path}/book.epub');
    await epubFile.writeAsBytes(buildTestEpub());
    sampleEdition = WorkEdition(
      id: 'ed-101',
      workId: sampleWork.id,
      format: WorkFormat.epub,
      filePath: epubFile.path,
      fileSize: await epubFile.length(),
      pageCount: 10,
      isLocal: true,
    );
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    repository = LibraryRepository(database);
    await repository.saveWork(sampleWork);

    getProgress = GetReadingProgressUseCase(repository);
    saveProgress = SaveReadingProgressUseCase(repository);
    parser = const BookContentParser();

    bloc = BookReaderBloc(
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

  group('BookReaderBloc (Fase F - State Management)', () {
    test('Estado inicial é BookReaderInitial', () {
      expect(bloc.state, isA<BookReaderInitial>());
    });

    test(
      'OpenBookEvent carrega conteúdo e define estado inicial na página 1',
      () async {
        bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<BookReaderLoading>(),
            predicate<BookReaderLoaded>((state) {
              return state.work.id == sampleWork.id &&
                  state.currentPage == 1 &&
                  state.currentChapterIndex == 0 &&
                  state.totalPages == 10 &&
                  state.areControlsVisible == false;
            }),
          ]),
        );
      },
    );

    test('OpenBookEvent restaura marco salvo de leitura prévio', () async {
      // Salva progresso prévio na página 5
      await saveProgress(
        ReadingProgress(
          workId: sampleWork.id,
          editionId: sampleEdition.id,
          currentPage: 5,
          totalPages: 10,
          percentage: 0.5,
          updatedAt: DateTime.now(),
        ),
      );

      bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<BookReaderLoading>(),
          predicate<BookReaderLoaded>((state) {
            return state.currentPage == 5 && state.percentage == 0.5;
          }),
        ]),
      );
    });

    test(
      'NextPageEvent e PreviousPageEvent avançam e retrocedem páginas com persistência',
      () async {
        bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));

        await bloc.stream.firstWhere((s) => s is BookReaderLoaded);

        // Avança página
        bloc.add(const NextPageEvent());

        await expectLater(
          bloc.stream,
          emits(predicate<BookReaderLoaded>((state) => state.currentPage == 2)),
        );

        // Verifica se persistiu no SQLite
        final progress = await getProgress(sampleWork.id);
        expect(progress, isNotNull);
        expect(progress!.currentPage, equals(2));

        // Retrocede página
        bloc.add(const PreviousPageEvent());

        await expectLater(
          bloc.stream,
          emits(predicate<BookReaderLoaded>((state) => state.currentPage == 1)),
        );
      },
    );

    test(
      'JumpToChapterEvent salta diretamente para o capítulo escolhido',
      () async {
        bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is BookReaderLoaded);

        // Salta para o capítulo índice 1 (Capítulo 2)
        bloc.add(const JumpToChapterEvent(1));

        await expectLater(
          bloc.stream,
          emits(
            predicate<BookReaderLoaded>((state) {
              return state.currentChapterIndex == 1 &&
                  state.currentChapter.title.contains('Capítulo II');
            }),
          ),
        );
      },
    );

    test(
      'ToggleControlsEvent alterna visibilidade das barras de controle',
      () async {
        bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is BookReaderLoaded);

        expect((bloc.state as BookReaderLoaded).areControlsVisible, isFalse);

        bloc.add(const ToggleControlsEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<BookReaderLoaded>((state) => state.areControlsVisible),
          ),
        );

        bloc.add(const ToggleControlsEvent());
        await expectLater(
          bloc.stream,
          emits(
            predicate<BookReaderLoaded>((state) => !state.areControlsVisible),
          ),
        );
      },
    );

    test(
      'UpdateTypographyEvent atualiza tamanho de fonte e modo de cor',
      () async {
        bloc.add(OpenBookEvent(work: sampleWork, edition: sampleEdition));
        await bloc.stream.firstWhere((s) => s is BookReaderLoaded);

        bloc.add(
          const UpdateTypographyEvent(
            fontSize: 22.0,
            lineHeight: 1.8,
            fontFamily: 'serif',
            themeMode: 'sepia',
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            predicate<BookReaderLoaded>((state) {
              return state.typography.fontSize == 22.0 &&
                  state.typography.lineHeight == 1.8 &&
                  state.typography.fontFamily == 'serif' &&
                  state.typography.themeMode == 'sepia';
            }),
          ),
        );
      },
    );
  });
}

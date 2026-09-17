import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/core/reader/book_content_parser.dart';
import 'package:vantareader/core/reader/comic_content_parser.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/core/reader/online_reading_manager.dart';
import 'package:vantareader/core/reader/reading_session.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/prepare_reading_session_usecase.dart';
import 'package:vantareader/domain/usecases/promote_reading_session_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_event.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_state.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_event.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/reader_test_fixtures.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late StorageManager storageManager;
  late ProviderRegistry providerRegistry;
  late NetworkClient networkClient;
  late AppDatabase appDatabase;
  late LibraryRepository libraryRepository;
  late OnlineReadingManager onlineReadingManager;
  late PrepareReadingSessionUseCase prepareSession;
  late PromoteReadingSessionUseCase promoteSession;
  late GetReadingProgressUseCase getProgress;
  late SaveReadingProgressUseCase saveProgress;
  late TestContentServer contentServer;
  late Work sampleBook;
  late Work sampleComic;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_streaming_bloc_test_',
    );
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
    providerRegistry = ProviderRegistry();
    contentServer = await TestContentServer.start({
      '/book.epub': buildTestEpub(),
      '/comic.cbz': buildTestCbz(),
    });
    providerRegistry.register(
      TestStreamingProvider({
        WorkFormat.epub: contentServer.url('/book.epub'),
        WorkFormat.cbz: contentServer.url('/comic.cbz'),
      }),
    );
    networkClient = NetworkClient();

    sampleBook = Work(
      id: 'book-stream-test',
      workKey: 'duna__frank_herbert',
      title: 'Duna',
      author: 'Frank Herbert',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      editions: const [
        WorkEdition(
          id: 'edition-book-stream',
          workId: 'book-stream-test',
          externalId: 'book-fixture',
          format: WorkFormat.epub,
          providerId: 'test-http-provider',
          isLocal: false,
        ),
      ],
    );
    sampleComic = Work(
      id: 'comic-stream-test',
      workKey: 'cyberpunk__shinji_sato',
      title: 'Cyberpunk Neo',
      author: 'Shinji Sato',
      primaryLanguage: 'pt-BR',
      type: WorkType.comic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      editions: const [
        WorkEdition(
          id: 'edition-comic-stream',
          workId: 'comic-stream-test',
          externalId: 'comic-fixture',
          format: WorkFormat.cbz,
          providerId: 'test-http-provider',
          isLocal: false,
        ),
      ],
    );

    appDatabase = AppDatabase();
    await appDatabase.initialize(isTestInMemory: true);
    libraryRepository = LibraryRepository(appDatabase);

    onlineReadingManager = OnlineReadingManager(
      storageManager: storageManager,
      providerRegistry: providerRegistry,
      networkClient: networkClient,
      libraryRepository: libraryRepository,
    );

    prepareSession = PrepareReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );
    promoteSession = PromoteReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );
    getProgress = GetReadingProgressUseCase(libraryRepository);
    saveProgress = SaveReadingProgressUseCase(libraryRepository);
  });

  tearDown(() async {
    await appDatabase.close();
    await contentServer.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BookReaderBloc com Leitura Online (Streaming)', () {
    test(
      'carrega livro via streaming online e permite promoção para permanente local',
      () async {
        final bloc = BookReaderBloc(
          contentParser: const BookContentParser(),
          getProgress: getProgress,
          saveProgress: saveProgress,
          prepareSession: prepareSession,
          promoteSession: promoteSession,
        );

        bloc.add(
          OpenBookEvent(work: sampleBook, edition: sampleBook.editions.first),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<BookReaderLoading>(),
            isA<BookReaderLoading>(),
            isA<BookReaderLoaded>().having(
              (s) => s.session?.source,
              'source',
              ReadingSource.onlineStream,
            ),
          ]),
        );

        final state = bloc.state as BookReaderLoaded;
        expect(state.session!.isStreaming, isTrue);
        expect(state.session!.isLocal, isFalse);

        // Dispara promoção para local
        bloc.add(const PromoteBookToLocalEvent());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<BookReaderLoaded>().having(
              (s) => s.isPromotingToLocal,
              'isPromoting',
              isTrue,
            ),
            isA<BookReaderLoaded>().having(
              (s) => s.session?.isLocal,
              'isLocal',
              isTrue,
            ),
          ]),
        );

        final finalState = bloc.state as BookReaderLoaded;
        expect(finalState.edition.isLocal, isTrue);
        expect(finalState.session!.isLocal, isTrue);

        await bloc.close();
      },
    );
  });

  group('ComicReaderBloc com Leitura Online (Streaming)', () {
    test(
      'carrega quadrinho via streaming online e permite promoção para permanente local',
      () async {
        final bloc = ComicReaderBloc(
          contentParser: ComicContentParser(
            cache: ComicPageCache(maxCapacity: 7),
          ),
          getProgress: getProgress,
          saveProgress: saveProgress,
          prepareSession: prepareSession,
          promoteSession: promoteSession,
        );

        bloc.add(
          OpenComicEvent(
            work: sampleComic,
            edition: sampleComic.editions.first,
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<ComicReaderLoading>(),
            isA<ComicReaderLoading>(),
            isA<ComicReaderLoaded>().having(
              (s) => s.session?.source,
              'source',
              ReadingSource.onlineStream,
            ),
          ]),
        );

        final state = bloc.state as ComicReaderLoaded;
        expect(state.session!.isStreaming, isTrue);
        expect(state.session!.isLocal, isFalse);

        // Dispara promoção para local
        bloc.add(const PromoteComicToLocalEvent());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<ComicReaderLoaded>().having(
              (s) => s.isPromotingToLocal,
              'isPromoting',
              isTrue,
            ),
            isA<ComicReaderLoaded>().having(
              (s) => s.session?.isLocal,
              'isLocal',
              isTrue,
            ),
          ]),
        );

        final finalState = bloc.state as ComicReaderLoaded;
        expect(finalState.edition.isLocal, isTrue);
        expect(finalState.session!.isLocal, isTrue);

        await bloc.close();
      },
    );
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/download/download_manager.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/core/reader/book_content_parser.dart';
import 'package:vantareader/core/reader/comic_content_parser.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/core/reader/online_reading_manager.dart';
import 'package:vantareader/core/reader/reading_session.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/data/repositories/download_repository.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/prepare_reading_session_usecase.dart';
import 'package:vantareader/domain/usecases/promote_reading_session_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/search_online_catalog_usecase.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_event.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_state.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_event.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/reader_test_fixtures.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late StorageManager storageManager;
  late AppDatabase appDatabase;
  late LibraryRepository libraryRepository;
  late DownloadRepository downloadRepository;
  late ProviderRegistry providerRegistry;
  late MockContentProvider mockProvider;
  late ProviderManager providerManager;
  late SearchOnlineCatalogUseCase searchCatalogUseCase;
  late DownloadManager downloadManager;
  late OnlineReadingManager onlineReadingManager;
  late GetReadingProgressUseCase getReadingProgressUseCase;
  late SaveReadingProgressUseCase saveReadingProgressUseCase;
  late PrepareReadingSessionUseCase prepareReadingSessionUseCase;
  late PromoteReadingSessionUseCase promoteReadingSessionUseCase;
  late ComicContentParser comicContentParser;
  late TestContentServer contentServer;
  const bookContentParser = BookContentParser();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_e2e_test_');
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );

    appDatabase = AppDatabase();
    await appDatabase.initialize(isTestInMemory: true);

    libraryRepository = LibraryRepository(appDatabase);
    downloadRepository = DownloadRepository(appDatabase);

    providerRegistry = ProviderRegistry();
    mockProvider = MockContentProvider();
    providerRegistry.register(mockProvider);
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
    providerManager = ProviderManager(registry: providerRegistry);

    searchCatalogUseCase = SearchOnlineCatalogUseCase(providerManager);

    final networkClient = NetworkClient();
    downloadManager = DownloadManager(
      downloadRepository: downloadRepository,
      libraryRepository: libraryRepository,
      storageManager: storageManager,
      networkClient: networkClient,
      maxConcurrentDownloads: 2,
    );
    await downloadManager.initialize();

    onlineReadingManager = OnlineReadingManager(
      storageManager: storageManager,
      providerRegistry: providerRegistry,
      libraryRepository: libraryRepository,
      networkClient: networkClient,
    );

    getReadingProgressUseCase = GetReadingProgressUseCase(libraryRepository);
    saveReadingProgressUseCase = SaveReadingProgressUseCase(libraryRepository);
    prepareReadingSessionUseCase = PrepareReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );
    promoteReadingSessionUseCase = PromoteReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );

    comicContentParser = ComicContentParser(
      cache: ComicPageCache(maxCapacity: 10),
    );
  });

  tearDown(() async {
    downloadManager.dispose();
    await Future.delayed(const Duration(milliseconds: 50));
    await appDatabase.close();
    await contentServer.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Fase L — Integração Ponta a Ponta: Online -> Offline', () {
    test(
      'Cenário 1: Livro (Busca Online -> Download EPUB -> Persistência Local -> Leitura Offline e Progresso)',
      () async {
        // 1. Busca Online por "Duna"
        final searchResults = await searchCatalogUseCase('duna');
        expect(searchResults.isNotEmpty, isTrue);

        final duneWork = searchResults.firstWhere(
          (w) => w.title.contains('Duna'),
        );
        expect(duneWork.type, equals(WorkType.book));

        // 2. Seleção da edição EPUB para download
        final epubEdition = duneWork.editions.firstWhere(
          (e) => e.format == WorkFormat.epub,
        );
        expect(epubEdition.isLocal, isFalse);
        expect(epubEdition.filePath, isNull);

        // 3. Enfileiramento de Download Resiliente
        final completion = downloadManager.progressStream.firstWhere(
          (snapshot) => snapshot.status == DownloadStatus.completed,
        );
        final downloadItem = await downloadManager.enqueue(
          work: duneWork,
          edition: epubEdition,
          customDownloadUrl: contentServer.url('/book.epub'),
        );
        expect(downloadItem.workId, equals(duneWork.id));
        expect(downloadItem.editionId, equals(epubEdition.id));

        // 4. Aguarda conclusão do download via stream
        expect((await completion).downloadId, downloadItem.id);

        // 5. Verificação da Persistência na Biblioteca (SQLite + Disco)
        final savedWork = await libraryRepository.getWorkById(duneWork.id);
        expect(savedWork, isNotNull);
        expect(savedWork!.isDownloaded, isTrue);

        final savedEdition = savedWork.editions.firstWhere(
          (e) => e.id == epubEdition.id,
        );
        expect(savedEdition.isLocal, isTrue);
        expect(savedEdition.filePath, isNotNull);

        // Verifica se o arquivo EPUB físico foi salvo e não está vazio
        final bookFile = File(savedEdition.filePath!);
        expect(await bookFile.exists(), isTrue);
        expect(await bookFile.length(), greaterThan(0));
        expect(p.isWithin(storageManager.booksDir.path, bookFile.path), isTrue);

        // Metadata de capa não é convertida em arquivo artificial durante download.

        // 6. Simulação de Desconexão: Leitura 100% Offline via BookReaderBloc
        final readerBloc = BookReaderBloc(
          contentParser: bookContentParser,
          getProgress: getReadingProgressUseCase,
          saveProgress: saveReadingProgressUseCase,
        );

        readerBloc.add(OpenBookEvent(work: savedWork, edition: savedEdition));

        final loadedState =
            await readerBloc.stream.firstWhere(
                  (state) => state is BookReaderLoaded,
                )
                as BookReaderLoaded;

        expect(loadedState.work.id, equals(savedWork.id));
        expect(loadedState.content.chapters.isNotEmpty, isTrue);
        expect(loadedState.currentPage, equals(1));
        expect(loadedState.totalPages, greaterThanOrEqualTo(1));
        // Garante que o texto parseado é autêntico do EPUB gerado
        expect(loadedState.content.chapters.first.content, contains('palavra'));

        // 7. Avanço de página e persistência de progresso
        readerBloc.add(const NextPageEvent());
        final nextPage =
            await readerBloc.stream.firstWhere(
                  (state) =>
                      state is BookReaderLoaded && state.currentPage == 2,
                )
                as BookReaderLoaded;
        expect(nextPage.currentPage, equals(2));

        await readerBloc.close();

        // 8. Reabertura do Livro: Garante que o progresso foi salvo e restaurado do SQLite
        final restoredProgress = await getReadingProgressUseCase(savedWork.id);
        expect(restoredProgress, isNotNull);
        expect(restoredProgress!.currentPage, equals(2));

        final secondReaderBloc = BookReaderBloc(
          contentParser: bookContentParser,
          getProgress: getReadingProgressUseCase,
          saveProgress: saveReadingProgressUseCase,
        );

        secondReaderBloc.add(
          OpenBookEvent(work: savedWork, edition: savedEdition),
        );
        final reloadedState =
            await secondReaderBloc.stream.firstWhere(
                  (state) => state is BookReaderLoaded,
                )
                as BookReaderLoaded;

        expect(reloadedState.currentPage, equals(2));
        await secondReaderBloc.close();
      },
    );

    test(
      'Cenário 2: Quadrinho (Busca Online -> Download CBZ -> Persistência Local -> Leitura Offline com Imagens)',
      () async {
        // 1. Busca Online por "Watchmen"
        final searchResults = await searchCatalogUseCase('watchmen');
        expect(searchResults.isNotEmpty, isTrue);

        final watchmenWork = searchResults.firstWhere(
          (w) => w.title.contains('Watchmen'),
        );
        expect(watchmenWork.type, equals(WorkType.comic));

        // 2. Seleção da edição CBZ
        final cbzEdition = watchmenWork.editions.firstWhere(
          (e) => e.format == WorkFormat.cbz,
        );
        expect(cbzEdition.isLocal, isFalse);

        // 3. Enfileiramento de Download
        final completion = downloadManager.progressStream.firstWhere(
          (snapshot) => snapshot.status == DownloadStatus.completed,
        );
        final downloadItem = await downloadManager.enqueue(
          work: watchmenWork,
          edition: cbzEdition,
          customDownloadUrl: contentServer.url('/comic.cbz'),
        );

        // 4. Aguarda conclusão do download
        expect((await completion).downloadId, downloadItem.id);

        // 5. Verificação na Biblioteca
        final savedWork = await libraryRepository.getWorkById(watchmenWork.id);
        expect(savedWork, isNotNull);
        expect(savedWork!.isDownloaded, isTrue);

        final savedEdition = savedWork.editions.firstWhere(
          (e) => e.id == cbzEdition.id,
        );
        expect(savedEdition.isLocal, isTrue);
        expect(savedEdition.filePath, isNotNull);

        // Verifica arquivo CBZ no disco
        final comicFile = File(savedEdition.filePath!);
        expect(await comicFile.exists(), isTrue);
        expect(await comicFile.length(), greaterThan(0));
        expect(
          p.isWithin(storageManager.comicsDir.path, comicFile.path),
          isTrue,
        );

        // 6. Leitura Offline via ComicReaderBloc
        final comicBloc = ComicReaderBloc(
          contentParser: comicContentParser,
          getProgress: getReadingProgressUseCase,
          saveProgress: saveReadingProgressUseCase,
        );

        comicBloc.add(OpenComicEvent(work: savedWork, edition: savedEdition));

        final loadedComic =
            await comicBloc.stream.firstWhere(
                  (state) => state is ComicReaderLoaded,
                )
                as ComicReaderLoaded;

        expect(loadedComic.work.id, equals(savedWork.id));
        expect(loadedComic.totalPages, greaterThanOrEqualTo(3));
        expect(loadedComic.currentPageIndex, equals(0));

        // 7. Extração de bytes reais da primeira página a partir do arquivo CBZ físico local
        final firstPage = loadedComic.content.pages.first;
        final pageBytes = await comicContentParser.loadPageBytes(
          work: savedWork,
          edition: savedEdition,
          page: firstPage,
        );
        expect(pageBytes, isNotNull);
        expect(pageBytes.length, greaterThan(0));

        // 8. Navegação de páginas do quadrinho
        comicBloc.add(const NextComicPageEvent());
        final nextPage =
            await comicBloc.stream.firstWhere(
                  (state) =>
                      state is ComicReaderLoaded && state.currentPageIndex == 1,
                )
                as ComicReaderLoaded;
        expect(nextPage.currentPageIndex, equals(1));

        await comicBloc.close();
      },
    );

    test(
      'Cenário 3: Fluxo Híbrido (Streaming Online -> Promoção Atômica para Local -> Acesso Offline Imediato)',
      () async {
        // 1. Busca obra online
        final searchResults = await searchCatalogUseCase('clean code');
        expect(searchResults.isNotEmpty, isTrue);
        final bookWork = searchResults.first;
        final onlineEdition = bookWork.editions.firstWhere(
          (e) => e.format == WorkFormat.epub,
        );

        // 2. Prepara sessão de streaming online
        final httpEdition = onlineEdition.copyWith(
          externalId: 'book-fixture',
          downloadUrl: contentServer.url('/book.epub'),
          providerId: 'test-http-provider',
        );
        final session = await prepareReadingSessionUseCase(
          work: bookWork,
          edition: httpEdition,
        );

        expect(session.source, equals(ReadingSource.onlineStream));
        expect(session.resolvedFilePath, isNotNull);

        // Arquivo inicial existe no cache de leitura
        final cacheFile = File(session.resolvedFilePath);
        expect(await cacheFile.exists(), isTrue);
        expect(
          p.isWithin(storageManager.readingCacheDir.path, cacheFile.path),
          isTrue,
        );

        // 3. Usuário decide promover leitura para permanente na biblioteca local
        final localEdition = await promoteReadingSessionUseCase(session);

        expect(localEdition.isLocal, isTrue);
        expect(localEdition.filePath, isNotNull);

        // 4. Verifica cópia para armazenamento permanente
        final permanentFile = File(localEdition.filePath!);
        expect(await permanentFile.exists(), isTrue);
        expect(
          p.isWithin(storageManager.booksDir.path, permanentFile.path),
          isTrue,
        );

        // Limpeza de cache volátil remove o cache temporário sem afetar o arquivo permanente
        await storageManager.clearReadingCache();
        expect(await cacheFile.exists(), isFalse);
        expect(await permanentFile.exists(), isTrue);

        // 5. Verificação no banco de dados da biblioteca
        final workInLibrary = await libraryRepository.getWorkById(bookWork.id);
        expect(workInLibrary, isNotNull);
        expect(workInLibrary!.isDownloaded, isTrue);

        // 6. Nova sessão com a mesma obra agora resolve diretamente como local
        final nextSession = await prepareReadingSessionUseCase(
          work: workInLibrary,
          edition: localEdition,
        );
        expect(nextSession.source, equals(ReadingSource.local));
        expect(nextSession.resolvedFilePath, equals(permanentFile.path));
      },
    );
  });
}

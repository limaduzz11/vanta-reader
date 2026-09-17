import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/core/reader/online_reading_manager.dart';
import 'package:vantareader/core/reader/reading_session.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../support/reader_test_fixtures.dart';

class NonStreamingMockProvider implements ContentProvider {
  @override
  String get id => 'no-streaming-provider';
  @override
  String get name => 'No Streaming Provider';
  @override
  String get version => '1.0.0';
  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,
    supportsStreaming: false,
  );

  @override
  Future<ProviderHealth> checkHealth() async => ProviderHealth(
    status: ProviderStatus.healthy,
    lastChecked: DateTime.now(),
  );

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async => null;

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async => 'mock://download/test.epub';

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async => [];
}

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
  late TestContentServer contentServer;
  late Work sampleWork;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_streaming_test_',
    );
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
    providerRegistry = ProviderRegistry();
    contentServer = await TestContentServer.start({
      '/book.epub': buildTestEpub(),
    });
    providerRegistry.register(
      TestStreamingProvider({WorkFormat.epub: contentServer.url('/book.epub')}),
    );
    networkClient = NetworkClient();

    sampleWork = Work(
      id: 'work-dune',
      workKey: 'duna__frank_herbert',
      title: 'Duna',
      author: 'Frank Herbert',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      editions: const [
        WorkEdition(
          id: 'edition-dune-remote',
          workId: 'work-dune',
          externalId: 'book-fixture',
          format: WorkFormat.epub,
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
  });

  tearDown(() async {
    await appDatabase.close();
    await contentServer.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OnlineReadingManager (Fase K — Streaming Reader)', () {
    test(
      'redireciona para arquivo local quando a edição já está baixada',
      () async {
        // 1. Cria arquivo local no diretório books
        final localFile = File(
          p.join(storageManager.booksDir.path, 'duna_local.epub'),
        );
        await localFile.writeAsString('CONTEUDO LOCAL PERSISTIDO');

        final localEdition = WorkEdition(
          id: 'edition-dune-local',
          workId: 'work-dune',
          format: WorkFormat.epub,
          filePath: localFile.path,
          isLocal: true,
          fileSize: await localFile.length(),
        );

        final session = await onlineReadingManager.prepareSession(
          work: sampleWork,
          edition: localEdition,
        );

        expect(session.isLocal, isTrue);
        expect(session.isStreaming, isFalse);
        expect(session.source, ReadingSource.local);
        expect(session.resolvedFilePath, localFile.path);
        expect(session.isTemporaryCache, isFalse);
      },
    );

    test(
      'reaproveita arquivo em cache de streaming se já existir no disco',
      () async {
        final remoteEdition = sampleWork.editions.first;

        // Cria arquivo prévio no cache de streaming
        final safeWorkKey = sampleWork.workKey.replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final safeEditionId = remoteEdition.id.replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final cacheFileName = 'stream_${safeWorkKey}_$safeEditionId.epub';
        final cacheFile = File(
          storageManager.getReadingCachePath(cacheFileName),
        );
        await cacheFile.writeAsString('CONTEUDO CACHE VOLATIL');

        final session = await onlineReadingManager.prepareSession(
          work: sampleWork,
          edition: remoteEdition,
        );

        expect(session.isLocal, isFalse);
        expect(session.isStreaming, isTrue);
        expect(session.source, ReadingSource.cachedStream);
        expect(session.resolvedFilePath, cacheFile.path);
        expect(session.isTemporaryCache, isTrue);
      },
    );

    test(
      'faz streaming de nova edição remota e salva no cache volátil',
      () async {
        final remoteEdition = sampleWork.editions.first;
        double lastProgress = 0.0;

        final session = await onlineReadingManager.prepareSession(
          work: sampleWork,
          edition: remoteEdition,
          onProgress: (p) => lastProgress = p,
        );

        expect(session.source, ReadingSource.onlineStream);
        expect(session.isStreaming, isTrue);
        expect(session.isTemporaryCache, isTrue);
        expect(lastProgress, equals(1.0));

        final file = File(session.resolvedFilePath);
        expect(await file.exists(), isTrue);
        expect(await file.length(), greaterThan(0));
      },
    );

    test(
      'rejeita streaming se o provedor não suportar tal funcionalidade',
      () async {
        final nonStreamingProvider = NonStreamingMockProvider();
        providerRegistry.register(nonStreamingProvider);

        const nonStreamingEdition = WorkEdition(
          id: 'edition-no-stream',
          workId: 'work-dune',
          format: WorkFormat.epub,
          providerId: 'no-streaming-provider',
          downloadUrl: 'mock://download/test.epub',
          isLocal: false,
        );

        expect(
          () => onlineReadingManager.prepareSession(
            work: sampleWork,
            edition: nonStreamingEdition,
          ),
          throwsA(isA<NovaException>()),
        );
      },
    );

    test(
      'promove edição em buffer de streaming para armazenamento local permanente',
      () async {
        final remoteEdition = sampleWork.editions.first;

        final session = await onlineReadingManager.prepareSession(
          work: sampleWork,
          edition: remoteEdition,
        );

        expect(session.isTemporaryCache, isTrue);

        final promoted = await onlineReadingManager.promoteToLocal(session);

        expect(promoted.isLocal, isTrue);
        expect(promoted.filePath, isNotNull);
        expect(File(promoted.filePath!).existsSync(), isTrue);
        expect(
          p.isWithin(storageManager.booksDir.path, promoted.filePath!),
          isTrue,
        );

        // Confere persistência na biblioteca local
        final saved = await libraryRepository.getWorkById(sampleWork.id);
        expect(saved, isNotNull);
        expect(saved!.isDownloaded, isTrue);
      },
    );

    test(
      'clearReadingCache limpa apenas arquivos de streaming volátil',
      () async {
        // 1. Cria livro local
        final bookFile = File(
          p.join(storageManager.booksDir.path, 'livro_permanente.epub'),
        );
        await bookFile.writeAsString('LIVRO PERMANENTE');

        // 2. Prepara streaming remoto que cria arquivo em cache
        await onlineReadingManager.prepareSession(
          work: sampleWork,
          edition: sampleWork.editions.first,
        );

        expect(await storageManager.readingCacheDir.list().isEmpty, isFalse);

        // 3. Executa limpeza apenas do cache de leitura
        final freed = await storageManager.clearReadingCache();
        expect(freed, greaterThan(0));
        expect(await storageManager.readingCacheDir.list().isEmpty, isTrue);

        // 4. Arquivo permanente permanece intacto
        expect(await bookFile.exists(), isTrue);
      },
    );
  });
}

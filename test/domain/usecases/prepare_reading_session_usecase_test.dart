import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/core/reader/online_reading_manager.dart';
import 'package:vantareader/core/reader/reading_session.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/prepare_reading_session_usecase.dart';
import 'package:vantareader/domain/usecases/promote_reading_session_usecase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../support/reader_test_fixtures.dart';

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
  late PrepareReadingSessionUseCase prepareReadingSession;
  late PromoteReadingSessionUseCase promoteReadingSession;
  late TestContentServer contentServer;
  late Work sampleWork;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_session_usecase_test_',
    );
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
    providerRegistry = ProviderRegistry();
    contentServer = await TestContentServer.start({
      '/comic.cbz': buildTestCbz(),
    });
    providerRegistry.register(
      TestStreamingProvider({WorkFormat.cbz: contentServer.url('/comic.cbz')}),
    );
    networkClient = NetworkClient();

    sampleWork = Work(
      id: 'work-comic-http',
      workKey: 'public_comic__fixture_author',
      title: 'Public Comic Fixture',
      author: 'Fixture Author',
      primaryLanguage: 'en',
      type: WorkType.comic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      editions: const [
        WorkEdition(
          id: 'edition-cbz-http',
          workId: 'work-comic-http',
          externalId: 'public-comic-fixture',
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

    prepareReadingSession = PrepareReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );
    promoteReadingSession = PromoteReadingSessionUseCase(
      onlineReadingManager: onlineReadingManager,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    await contentServer.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PrepareReadingSessionUseCase & PromoteReadingSessionUseCase', () {
    test(
      'prepara sessão remota com sucesso retornando ReadingSource.onlineStream',
      () async {
        final session = await prepareReadingSession(
          work: sampleWork,
          edition: sampleWork.editions.first,
        );

        expect(session.source, ReadingSource.onlineStream);
        expect(session.isStreaming, isTrue);
        expect(session.isTemporaryCache, isTrue);
        expect(File(session.resolvedFilePath).existsSync(), isTrue);
      },
    );

    test('promove sessão para arquivo permanente na biblioteca', () async {
      final session = await prepareReadingSession(
        work: sampleWork,
        edition: sampleWork.editions.first,
      );

      final promoted = await promoteReadingSession(session);

      expect(promoted.isLocal, isTrue);
      expect(promoted.filePath, isNotNull);
      expect(File(promoted.filePath!).existsSync(), isTrue);
    });
  });
}

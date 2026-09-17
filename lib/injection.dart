import 'package:get_it/get_it.dart';
import 'core/database/app_database.dart';
import 'core/import/work_extractor_factory.dart';
import 'core/network/network_client.dart';
import 'core/services/file_picker_service.dart';
import 'core/storage/storage_manager.dart';
import 'data/repositories/download_repository.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'domain/repositories/i_download_repository.dart';
import 'domain/repositories/i_library_repository.dart';
import 'domain/repositories/i_profile_repository.dart';
import 'domain/usecases/get_library_works_usecase.dart';
import 'domain/usecases/get_reading_progress_usecase.dart';
import 'domain/usecases/import_work_usecase.dart';
import 'domain/usecases/save_reading_progress_usecase.dart';
import 'domain/usecases/search_local_library_usecase.dart';
import 'domain/usecases/seed_initial_catalog_usecase.dart';
import 'domain/usecases/toggle_favorite_usecase.dart';
import 'core/reader/book_content_parser.dart';
import 'core/reader/comic_content_parser.dart';
import 'core/reader/comic_page_cache.dart';
import 'presentation/blocs/book_reader/book_reader_bloc.dart';
import 'presentation/blocs/comic_reader/comic_reader_bloc.dart';
import 'presentation/blocs/downloads/downloads_bloc.dart';
import 'presentation/blocs/library/library_bloc.dart';
import 'presentation/blocs/work_details/work_details_bloc.dart';
import 'core/download/download_manager.dart';
import 'core/providers/provider_manager.dart';
import 'core/providers/provider_registry.dart';
import 'data/datasources/providers/mock_content_provider.dart';
import 'data/datasources/providers/open_library_content_provider.dart';
import 'data/datasources/providers/gutendex_content_provider.dart';
import 'data/datasources/providers/internet_archive_content_provider.dart';
import 'data/datasources/providers/vanta_catalog_content_provider.dart';
import 'core/providers/vanta/vanta_config.dart';
import 'domain/usecases/downloads/download_usecases.dart';
import 'domain/usecases/search_online_catalog_usecase.dart';
import 'presentation/blocs/search/search_bloc.dart';
import 'core/reader/online_reading_manager.dart';
import 'domain/usecases/prepare_reading_session_usecase.dart';
import 'domain/usecases/promote_reading_session_usecase.dart';
import 'domain/usecases/profile/clear_cache_usecase.dart';
import 'domain/usecases/profile/get_reading_stats_usecase.dart';
import 'domain/usecases/profile/get_storage_usage_usecase.dart';
import 'domain/usecases/profile/get_user_profile_usecase.dart';
import 'domain/usecases/profile/update_user_profile_usecase.dart';
import 'presentation/blocs/profile/profile_bloc.dart';

final getIt = GetIt.instance;

/// Inicializa todos os serviços de infraestrutura e repositórios
Future<void> setupInjection({
  String? customStoragePath,
  String? customDatabasePath,
  bool isTest = false,
  bool registerMockProviders = false,
}) async {
  // 1. Storage Manager
  final storage = await StorageManager.initialize(
    customRootPath: customStoragePath,
  );
  if (getIt.isRegistered<StorageManager>()) {
    await getIt.unregister<StorageManager>();
  }
  getIt.registerSingleton<StorageManager>(storage);

  // 2. Database
  final database = AppDatabase();
  await database.initialize(
    customPath: customDatabasePath ?? storage.databaseDir.path,
    isTestInMemory: isTest,
  );
  if (getIt.isRegistered<AppDatabase>()) {
    await getIt.unregister<AppDatabase>();
  }
  getIt.registerSingleton<AppDatabase>(database);

  // 3. Network Client
  if (!getIt.isRegistered<NetworkClient>()) {
    getIt.registerLazySingleton<NetworkClient>(() => NetworkClient());
  }

  // 4. Repositories
  if (getIt.isRegistered<ILibraryRepository>()) {
    await getIt.unregister<ILibraryRepository>();
  }
  getIt.registerSingleton<ILibraryRepository>(LibraryRepository(database));

  if (getIt.isRegistered<IDownloadRepository>()) {
    await getIt.unregister<IDownloadRepository>();
  }
  getIt.registerSingleton<IDownloadRepository>(DownloadRepository(database));

  if (getIt.isRegistered<IProfileRepository>()) {
    await getIt.unregister<IProfileRepository>();
  }
  getIt.registerSingleton<IProfileRepository>(
    ProfileRepository(database, storageManager: storage),
  );

  // 5. UseCases
  final libraryRepo = getIt<ILibraryRepository>();

  if (getIt.isRegistered<GetLibraryWorksUseCase>()) {
    await getIt.unregister<GetLibraryWorksUseCase>();
  }
  getIt.registerSingleton<GetLibraryWorksUseCase>(
    GetLibraryWorksUseCase(libraryRepo),
  );

  if (getIt.isRegistered<ToggleFavoriteUseCase>()) {
    await getIt.unregister<ToggleFavoriteUseCase>();
  }
  getIt.registerSingleton<ToggleFavoriteUseCase>(
    ToggleFavoriteUseCase(libraryRepo),
  );

  if (getIt.isRegistered<SaveReadingProgressUseCase>()) {
    await getIt.unregister<SaveReadingProgressUseCase>();
  }
  getIt.registerSingleton<SaveReadingProgressUseCase>(
    SaveReadingProgressUseCase(libraryRepo),
  );

  if (getIt.isRegistered<GetReadingProgressUseCase>()) {
    await getIt.unregister<GetReadingProgressUseCase>();
  }
  getIt.registerSingleton<GetReadingProgressUseCase>(
    GetReadingProgressUseCase(libraryRepo),
  );

  if (getIt.isRegistered<SearchLocalLibraryUseCase>()) {
    await getIt.unregister<SearchLocalLibraryUseCase>();
  }
  getIt.registerSingleton<SearchLocalLibraryUseCase>(
    SearchLocalLibraryUseCase(libraryRepo),
  );

  if (getIt.isRegistered<SeedInitialCatalogUseCase>()) {
    await getIt.unregister<SeedInitialCatalogUseCase>();
  }
  getIt.registerSingleton<SeedInitialCatalogUseCase>(
    SeedInitialCatalogUseCase(libraryRepo),
  );

  // 6. Serviços e Extratores de Importação (Fase E)
  if (!getIt.isRegistered<IFilePickerService>()) {
    getIt.registerLazySingleton<IFilePickerService>(
      () => const FilePickerService(),
    );
  }

  if (!getIt.isRegistered<WorkExtractorFactory>()) {
    getIt.registerLazySingleton<WorkExtractorFactory>(
      () => WorkExtractorFactory(),
    );
  }

  if (getIt.isRegistered<ImportWorkUseCase>()) {
    await getIt.unregister<ImportWorkUseCase>();
  }
  getIt.registerSingleton<ImportWorkUseCase>(
    ImportWorkUseCase(
      libraryRepository: libraryRepo,
      storageManager: storage,
      extractorFactory: getIt<WorkExtractorFactory>(),
    ),
  );

  // 7. Motor de Leitura de Livros (Fase F)
  if (!getIt.isRegistered<BookContentParser>()) {
    getIt.registerLazySingleton<BookContentParser>(() => BookContentParser());
  }

  // 8. BLoCs (Factory)
  if (getIt.isRegistered<LibraryBloc>()) {
    await getIt.unregister<LibraryBloc>();
  }
  getIt.registerFactory<LibraryBloc>(
    () => LibraryBloc(
      getLibraryWorks: getIt<GetLibraryWorksUseCase>(),
      toggleFavorite: getIt<ToggleFavoriteUseCase>(),
      searchLocalLibrary: getIt<SearchLocalLibraryUseCase>(),
      importWork: getIt<ImportWorkUseCase>(),
      libraryRepository: libraryRepo,
    ),
  );

  if (getIt.isRegistered<WorkDetailsBloc>()) {
    await getIt.unregister<WorkDetailsBloc>();
  }
  getIt.registerFactory<WorkDetailsBloc>(
    () => WorkDetailsBloc(
      libraryRepository: getIt<ILibraryRepository>(),
      toggleFavorite: getIt<ToggleFavoriteUseCase>(),
      getProgress: getIt<GetReadingProgressUseCase>(),
      saveProgress: getIt<SaveReadingProgressUseCase>(),
    ),
  );

  if (getIt.isRegistered<BookReaderBloc>()) {
    await getIt.unregister<BookReaderBloc>();
  }
  getIt.registerFactory<BookReaderBloc>(
    () => BookReaderBloc(
      contentParser: getIt<BookContentParser>(),
      getProgress: getIt<GetReadingProgressUseCase>(),
      saveProgress: getIt<SaveReadingProgressUseCase>(),
      prepareSession: getIt<PrepareReadingSessionUseCase>(),
      promoteSession: getIt<PromoteReadingSessionUseCase>(),
    ),
  );

  // 9. Motor de Leitura de Quadrinhos (Fase G)
  if (!getIt.isRegistered<ComicPageCache>()) {
    getIt.registerLazySingleton<ComicPageCache>(
      () => ComicPageCache(maxCapacity: 7),
    );
  }

  if (!getIt.isRegistered<ComicContentParser>()) {
    getIt.registerLazySingleton<ComicContentParser>(
      () => ComicContentParser(cache: getIt<ComicPageCache>()),
    );
  }

  if (getIt.isRegistered<ComicReaderBloc>()) {
    await getIt.unregister<ComicReaderBloc>();
  }
  getIt.registerFactory<ComicReaderBloc>(
    () => ComicReaderBloc(
      contentParser: getIt<ComicContentParser>(),
      getProgress: getIt<GetReadingProgressUseCase>(),
      saveProgress: getIt<SaveReadingProgressUseCase>(),
      prepareSession: getIt<PrepareReadingSessionUseCase>(),
      promoteSession: getIt<PromoteReadingSessionUseCase>(),
    ),
  );

  // 10. Gerenciador de Downloads (Fase H)
  if (getIt.isRegistered<DownloadManager>()) {
    await getIt.unregister<DownloadManager>();
  }
  final downloadManager = DownloadManager(
    downloadRepository: getIt<IDownloadRepository>(),
    libraryRepository: libraryRepo,
    storageManager: storage,
    networkClient: getIt<NetworkClient>(),
  );
  getIt.registerSingleton<DownloadManager>(downloadManager);
  await downloadManager.initialize();

  // UseCases de Downloads
  if (getIt.isRegistered<EnqueueDownloadUseCase>()) {
    await getIt.unregister<EnqueueDownloadUseCase>();
  }
  getIt.registerLazySingleton<EnqueueDownloadUseCase>(
    () => EnqueueDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<PauseDownloadUseCase>()) {
    await getIt.unregister<PauseDownloadUseCase>();
  }
  getIt.registerLazySingleton<PauseDownloadUseCase>(
    () => PauseDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<ResumeDownloadUseCase>()) {
    await getIt.unregister<ResumeDownloadUseCase>();
  }
  getIt.registerLazySingleton<ResumeDownloadUseCase>(
    () => ResumeDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<CancelDownloadUseCase>()) {
    await getIt.unregister<CancelDownloadUseCase>();
  }
  getIt.registerLazySingleton<CancelDownloadUseCase>(
    () => CancelDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<RetryDownloadUseCase>()) {
    await getIt.unregister<RetryDownloadUseCase>();
  }
  getIt.registerLazySingleton<RetryDownloadUseCase>(
    () => RetryDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<DeleteDownloadUseCase>()) {
    await getIt.unregister<DeleteDownloadUseCase>();
  }
  getIt.registerLazySingleton<DeleteDownloadUseCase>(
    () => DeleteDownloadUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<ClearCompletedDownloadsUseCase>()) {
    await getIt.unregister<ClearCompletedDownloadsUseCase>();
  }
  getIt.registerLazySingleton<ClearCompletedDownloadsUseCase>(
    () => ClearCompletedDownloadsUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<GetDownloadsUseCase>()) {
    await getIt.unregister<GetDownloadsUseCase>();
  }
  getIt.registerLazySingleton<GetDownloadsUseCase>(
    () => GetDownloadsUseCase(getIt<DownloadManager>()),
  );

  if (getIt.isRegistered<DownloadsBloc>()) {
    await getIt.unregister<DownloadsBloc>();
  }
  getIt.registerFactory<DownloadsBloc>(
    () => DownloadsBloc(
      getDownloads: getIt<GetDownloadsUseCase>(),
      pauseDownload: getIt<PauseDownloadUseCase>(),
      resumeDownload: getIt<ResumeDownloadUseCase>(),
      cancelDownload: getIt<CancelDownloadUseCase>(),
      retryDownload: getIt<RetryDownloadUseCase>(),
      deleteDownload: getIt<DeleteDownloadUseCase>(),
      clearCompletedDownloads: getIt<ClearCompletedDownloadsUseCase>(),
    ),
  );

  // 11. Motor de Provedores & Mock (Fase I)
  if (getIt.isRegistered<ProviderRegistry>()) {
    await getIt.unregister<ProviderRegistry>();
  }
  final providerRegistry = ProviderRegistry();

  // REGRA R2: mock só é registrado em runtime de teste explicitamente
  // habilitado. Produção (default) NUNCA registra MockContentProvider.
  if (registerMockProviders || isTest) {
    final mockProvider = MockContentProvider();
    providerRegistry.register(mockProvider);
    if (getIt.isRegistered<MockContentProvider>()) {
      await getIt.unregister<MockContentProvider>();
    }
    getIt.registerSingleton<MockContentProvider>(mockProvider);
  }

  final openLibraryProvider = OpenLibraryContentProvider(
    networkClient: getIt<NetworkClient>(),
  );
  providerRegistry.register(openLibraryProvider);

  final gutendexProvider = GutendexContentProvider(
    networkClient: getIt<NetworkClient>(),
  );
  providerRegistry.register(gutendexProvider);

  final iaProvider = InternetArchiveContentProvider(
    networkClient: getIt<NetworkClient>(),
  );
  providerRegistry.register(iaProvider);

  final vantaProvider = VantaCatalogContentProvider(
    networkClient: getIt<NetworkClient>(),
    config: const VantaConfig(),
  );
  providerRegistry.register(vantaProvider);

  getIt.registerSingleton<ProviderRegistry>(providerRegistry);

  if (getIt.isRegistered<OpenLibraryContentProvider>()) {
    await getIt.unregister<OpenLibraryContentProvider>();
  }
  getIt.registerSingleton<OpenLibraryContentProvider>(openLibraryProvider);

  if (getIt.isRegistered<GutendexContentProvider>()) {
    await getIt.unregister<GutendexContentProvider>();
  }
  getIt.registerSingleton<GutendexContentProvider>(gutendexProvider);

  if (getIt.isRegistered<InternetArchiveContentProvider>()) {
    await getIt.unregister<InternetArchiveContentProvider>();
  }
  getIt.registerSingleton<InternetArchiveContentProvider>(iaProvider);

  if (getIt.isRegistered<VantaCatalogContentProvider>()) {
    await getIt.unregister<VantaCatalogContentProvider>();
  }
  getIt.registerSingleton<VantaCatalogContentProvider>(vantaProvider);

  if (getIt.isRegistered<ProviderManager>()) {
    await getIt.unregister<ProviderManager>();
  }
  getIt.registerSingleton<ProviderManager>(
    ProviderManager(registry: providerRegistry),
  );

  // 12. Busca Online e Catálogo Unificado (Fase J)
  if (getIt.isRegistered<SearchOnlineCatalogUseCase>()) {
    await getIt.unregister<SearchOnlineCatalogUseCase>();
  }
  getIt.registerSingleton<SearchOnlineCatalogUseCase>(
    SearchOnlineCatalogUseCase(getIt<ProviderManager>()),
  );

  if (getIt.isRegistered<SearchBloc>()) {
    await getIt.unregister<SearchBloc>();
  }
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(
      searchCatalog: getIt<SearchOnlineCatalogUseCase>(),
      getUserProfile: getIt<GetUserProfileUseCase>(),
    ),
  );

  // 13. Leitura Online & Streaming Reader (Fase K)
  if (getIt.isRegistered<OnlineReadingManager>()) {
    await getIt.unregister<OnlineReadingManager>();
  }
  final onlineReadingManager = OnlineReadingManager(
    storageManager: storage,
    providerRegistry: providerRegistry,
    networkClient: getIt<NetworkClient>(),
    libraryRepository: libraryRepo,
  );
  getIt.registerSingleton<OnlineReadingManager>(onlineReadingManager);

  if (getIt.isRegistered<PrepareReadingSessionUseCase>()) {
    await getIt.unregister<PrepareReadingSessionUseCase>();
  }
  getIt.registerSingleton<PrepareReadingSessionUseCase>(
    PrepareReadingSessionUseCase(onlineReadingManager: onlineReadingManager),
  );

  if (getIt.isRegistered<PromoteReadingSessionUseCase>()) {
    await getIt.unregister<PromoteReadingSessionUseCase>();
  }
  getIt.registerSingleton<PromoteReadingSessionUseCase>(
    PromoteReadingSessionUseCase(onlineReadingManager: onlineReadingManager),
  );

  // 14. Perfil do Usuário, Preferências & Armazenamento (Fase M)
  final profileRepo = getIt<IProfileRepository>();

  if (getIt.isRegistered<GetUserProfileUseCase>()) {
    await getIt.unregister<GetUserProfileUseCase>();
  }
  getIt.registerSingleton<GetUserProfileUseCase>(
    GetUserProfileUseCase(profileRepo),
  );

  if (getIt.isRegistered<UpdateUserProfileUseCase>()) {
    await getIt.unregister<UpdateUserProfileUseCase>();
  }
  getIt.registerSingleton<UpdateUserProfileUseCase>(
    UpdateUserProfileUseCase(profileRepo),
  );

  if (getIt.isRegistered<GetReadingStatsUseCase>()) {
    await getIt.unregister<GetReadingStatsUseCase>();
  }
  getIt.registerSingleton<GetReadingStatsUseCase>(
    GetReadingStatsUseCase(profileRepo),
  );

  if (getIt.isRegistered<GetStorageUsageUseCase>()) {
    await getIt.unregister<GetStorageUsageUseCase>();
  }
  getIt.registerSingleton<GetStorageUsageUseCase>(
    GetStorageUsageUseCase(profileRepo),
  );

  if (getIt.isRegistered<ClearCacheUseCase>()) {
    await getIt.unregister<ClearCacheUseCase>();
  }
  getIt.registerSingleton<ClearCacheUseCase>(ClearCacheUseCase(profileRepo));

  if (getIt.isRegistered<ProfileBloc>()) {
    await getIt.unregister<ProfileBloc>();
  }
  getIt.registerFactory<ProfileBloc>(
    () => ProfileBloc(
      getProfile: getIt<GetUserProfileUseCase>(),
      updateProfile: getIt<UpdateUserProfileUseCase>(),
      getStats: getIt<GetReadingStatsUseCase>(),
      getStorageUsage: getIt<GetStorageUsageUseCase>(),
      clearCache: getIt<ClearCacheUseCase>(),
    ),
  );

  // 15. Limpeza de acervo mock residual da biblioteca local de produção
  await libraryRepo.removeLegacySeedMocks();
}

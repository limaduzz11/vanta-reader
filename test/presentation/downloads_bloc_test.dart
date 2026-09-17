import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/download/download_manager.dart';
import 'package:vantareader/core/download/download_progress_snapshot.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/download_repository.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/downloads/download_usecases.dart';
import 'package:vantareader/presentation/blocs/downloads/downloads_bloc.dart';
import 'package:vantareader/presentation/blocs/downloads/downloads_event.dart';
import 'package:vantareader/presentation/blocs/downloads/downloads_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  late AppDatabase database;
  late DownloadRepository downloadRepo;
  late LibraryRepository libraryRepo;
  late StorageManager storageManager;
  late DownloadManager downloadManager;
  late DownloadsBloc bloc;
  late Directory tempDir;

  final sampleWork = Work(
    id: 'work-bloc-test',
    workKey: 'book:hiperion',
    title: 'Hyperion',
    author: 'Dan Simmons',
    type: WorkType.book,
    primaryLanguage: 'pt-BR',
    description: 'Os peregrinos viajam para os Túmulos do Tempo.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleEdition = WorkEdition(
    id: 'ed-hyperion-01',
    workId: sampleWork.id,
    format: WorkFormat.epub,
    fileSize: 1024 * 1024,
    isLocal: false,
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_dl_bloc_test_');
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );

    database = AppDatabase();
    await database.initialize(isTestInMemory: true);

    downloadRepo = DownloadRepository(database);
    libraryRepo = LibraryRepository(database);

    await libraryRepo.saveWork(sampleWork.copyWith(editions: [sampleEdition]));

    downloadManager = DownloadManager(
      downloadRepository: downloadRepo,
      libraryRepository: libraryRepo,
      storageManager: storageManager,
    );

    bloc = DownloadsBloc(
      getDownloads: GetDownloadsUseCase(downloadManager),
      pauseDownload: PauseDownloadUseCase(downloadManager),
      resumeDownload: ResumeDownloadUseCase(downloadManager),
      cancelDownload: CancelDownloadUseCase(downloadManager),
      retryDownload: RetryDownloadUseCase(downloadManager),
      deleteDownload: DeleteDownloadUseCase(downloadManager),
      clearCompletedDownloads: ClearCompletedDownloadsUseCase(downloadManager),
    );
  });

  tearDown(() async {
    await bloc.close();
    downloadManager.dispose();
    await Future.delayed(const Duration(milliseconds: 50));
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DownloadsBloc (Fase H - State Management)', () {
    test('Estado inicial é DownloadsInitial', () {
      expect(bloc.state, isA<DownloadsInitial>());
    });

    test(
      'LoadDownloadsEvent carrega lista de downloads e emite DownloadsLoaded',
      () async {
        final sampleItem = DownloadItem(
          id: 'dl-test-bloc',
          workId: sampleWork.id,
          editionId: sampleEdition.id,
          title: sampleWork.title,
          targetPath: storageManager.getBookPath('hyperion.epub'),
          downloadUrl: 'mock://download/hyperion',
          totalBytes: 1024000,
          downloadedBytes: 0,
          status: DownloadStatus.queued,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await downloadRepo.saveDownload(sampleItem);

        bloc.add(const LoadDownloadsEvent());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<DownloadsLoading>(),
            predicate<DownloadsLoaded>((state) {
              return state.downloads.length == 1 &&
                  state.downloads.first.id == 'dl-test-bloc' &&
                  state.queuedCount == 1 &&
                  state.activeCount == 0;
            }),
          ]),
        );
      },
    );

    test(
      'DownloadProgressUpdatedEvent atualiza métricas em tempo real no progressMap',
      () async {
        bloc.emit(const DownloadsLoaded(downloads: []));

        const snapshot = DownloadProgressSnapshot(
          downloadId: 'dl-progress-1',
          status: DownloadStatus.downloading,
          downloadedBytes: 512000,
          totalBytes: 1024000,
          speedBytesPerSecond: 1024 * 1024 * 1.5, // 1.5 MB/s
          etaSeconds: 5,
        );

        bloc.add(const DownloadProgressUpdatedEvent(snapshot));

        await expectLater(
          bloc.stream,
          emits(
            predicate<DownloadsLoaded>((state) {
              final snap = state.progressMap['dl-progress-1'];
              return snap != null &&
                  snap.downloadedBytes == 512000 &&
                  snap.speedFormatted == '1.5 MB/s' &&
                  snap.etaFormatted == '5s';
            }),
          ),
        );
      },
    );

    test(
      'DownloadsUpdatedEvent substitui lista de downloads mantendo progressMap',
      () async {
        const snapshot = DownloadProgressSnapshot(
          downloadId: 'dl-1',
          status: DownloadStatus.downloading,
          downloadedBytes: 100,
          totalBytes: 200,
        );
        bloc.emit(
          const DownloadsLoaded(downloads: [], progressMap: {'dl-1': snapshot}),
        );

        final newItem = DownloadItem(
          id: 'dl-1',
          workId: 'work-1',
          editionId: 'ed-1',
          title: 'Obra 1',
          targetPath: '/path',
          downloadUrl: 'url',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        bloc.add(DownloadsUpdatedEvent([newItem]));

        await expectLater(
          bloc.stream,
          emits(
            predicate<DownloadsLoaded>((state) {
              return state.downloads.length == 1 &&
                  state.progressMap.containsKey('dl-1');
            }),
          ),
        );
      },
    );
  });
}

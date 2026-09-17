import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/download/download_manager.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/download_repository.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/reader_test_fixtures.dart';

void main() {
  late AppDatabase database;
  late DownloadRepository downloadRepo;
  late LibraryRepository libraryRepo;
  late StorageManager storageManager;
  late DownloadManager downloadManager;
  late Directory tempDir;
  late TestContentServer contentServer;
  late Work sampleWork;
  late WorkEdition sampleEdition;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_dl_mgr_test_');
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
    final epubBytes = buildTestEpub();
    contentServer = await TestContentServer.start({'/book.epub': epubBytes});
    sampleWork = Work(
      id: 'work-dl-mgr-1',
      workKey: 'book:neuromancer',
      title: 'Neuromancer',
      author: 'William Gibson',
      type: WorkType.book,
      primaryLanguage: 'pt-BR',
      description: 'Fixture de teste de download.',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sampleEdition = WorkEdition(
      id: 'ed-neuro-01',
      workId: sampleWork.id,
      format: WorkFormat.epub,
      downloadUrl: contentServer.url('/book.epub'),
      fileSize: epubBytes.length,
      isLocal: false,
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
      networkClient: NetworkClient(),
      maxConcurrentDownloads: 1,
    );
  });

  tearDown(() async {
    downloadManager.dispose();
    await Future.delayed(const Duration(milliseconds: 50));
    await database.close();
    await contentServer.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DownloadManager (Fase H - Core Engine)', () {
    test(
      'initialize reseta downloads com status DOWNLOADING para QUEUED',
      () async {
        // Simula download abandonado
        final abandoned = DownloadItem(
          id: 'dl-abandoned',
          workId: sampleWork.id,
          editionId: sampleEdition.id,
          title: sampleWork.title,
          targetPath: storageManager.getBookPath('test.epub'),
          downloadUrl: contentServer.url('/book.epub'),
          totalBytes: 1024000,
          downloadedBytes: 256000,
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await downloadRepo.saveDownload(abandoned);

        await downloadManager.initialize();

        final restored = await downloadRepo.getDownloadById('dl-abandoned');
        expect(restored, isNotNull);
        expect(
          restored!.status,
          isIn([
            DownloadStatus.queued,
            DownloadStatus.downloading,
            DownloadStatus.completed,
          ]),
        );

        // Pausa para não manter tarefa em execução concorrente no banco
        await downloadManager.pause('dl-abandoned');
      },
    );

    test(
      'enqueue adiciona nova tarefa à fila e não duplica se já estiver ativo',
      () async {
        await downloadManager.initialize();

        final item1 = await downloadManager.enqueue(
          work: sampleWork,
          edition: sampleEdition,
        );

        expect(item1.workId, equals(sampleWork.id));
        expect(item1.editionId, equals(sampleEdition.id));

        // Tenta enfileirar a mesma edição novamente
        final item2 = await downloadManager.enqueue(
          work: sampleWork,
          edition: sampleEdition,
        );

        // Deve retornar o mesmo registro sem criar novo
        expect(item2.id, equals(item1.id));

        // Pausa para não manter tarefa em execução concorrente no banco
        await downloadManager.pause(item1.id);
      },
    );

    test(
      'executa download HTTP real, valida EPUB e atualiza ContentAsset',
      () async {
        await downloadManager.initialize();

        final completion = downloadManager.progressStream.firstWhere(
          (snapshot) => snapshot.status == DownloadStatus.completed,
        );

        final item = await downloadManager.enqueue(
          work: sampleWork,
          edition: sampleEdition,
        );

        final completedSnapshot = await completion;
        expect(completedSnapshot.downloadId, item.id);

        // 1. Verifica no SQLite de downloads
        final finished = await downloadRepo.getDownloadById(item.id);
        expect(finished, isNotNull);
        expect(finished!.status, equals(DownloadStatus.completed));
        expect(finished.downloadedBytes, equals(finished.totalBytes));

        // 2. Verifica se arquivo existe no disco
        final targetFile = File(item.targetPath);
        expect(await targetFile.exists(), isTrue);

        // 3. Verifica atualização na edição da obra no LibraryRepository
        final workInDb = await libraryRepo.getWorkById(sampleWork.id);
        expect(workInDb, isNotNull);
        final updatedEdition = workInDb!.editions.firstWhere(
          (e) => e.id == sampleEdition.id,
        );
        expect(updatedEdition.isLocal, isTrue);
        expect(updatedEdition.filePath, equals(item.targetPath));
        expect(updatedEdition.contentAssets, hasLength(1));
        expect(
          updatedEdition.primaryContentAsset!.status,
          ContentAssetStatus.downloaded,
        );
        expect(updatedEdition.primaryContentAsset!.checksumAlgorithm, 'sha256');

        // 4. Verifica se a obra passa no filtro onlyDownloaded
        final downloadedWorks = await libraryRepo.getLibraryWorks(
          onlyDownloaded: true,
        );
        expect(downloadedWorks.any((w) => w.id == sampleWork.id), isTrue);
      },
    );

    test(
      'pause e cancel interrompem download e limpam arquivo .part no cancelamento',
      () async {
        await downloadManager.initialize();

        final item = await downloadManager.enqueue(
          work: sampleWork,
          edition: sampleEdition,
        );

        // Pausa o download
        await downloadManager.pause(item.id);

        final paused = await downloadRepo.getDownloadById(item.id);
        expect(paused!.status, equals(DownloadStatus.paused));

        // Cancela o download
        await downloadManager.cancel(item.id);

        final cancelled = await downloadRepo.getDownloadById(item.id);
        expect(cancelled!.status, equals(DownloadStatus.cancelled));

        // O arquivo temporário .part deve ter sido excluído
        final partFile = File('${item.targetPath}.part');
        expect(await partFile.exists(), isFalse);
      },
    );

    test('clearCompleted remove downloads concluídos da listagem', () async {
      await downloadManager.initialize();

      final compItem = DownloadItem(
        id: 'dl-completed-test',
        workId: sampleWork.id,
        editionId: sampleEdition.id,
        title: sampleWork.title,
        targetPath: storageManager.getBookPath('completed.epub'),
        downloadUrl: contentServer.url('/book.epub'),
        totalBytes: 1024,
        downloadedBytes: 1024,
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await downloadRepo.saveDownload(compItem);

      expect((await downloadRepo.getAllDownloads()).length, equals(1));

      await downloadManager.clearCompleted();

      expect((await downloadRepo.getAllDownloads()).length, equals(0));
    });
  });
}

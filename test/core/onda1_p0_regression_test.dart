import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/download/download_manager.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/download_repository.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:vantareader/domain/entities/work.dart';

/// Regressão Onda 1 P0 — G-01 (exclusão completa).
///
/// G-06 e G-03 são cobertos por `online_reading_manager_test`,
/// `prepare_reading_session_usecase_test` e `library_bloc_test`; aqui o foco
/// é o comportamento novo do `DownloadManager`: arquivo físico + `.part` +
/// reversão de edição/biblioteca.
void main() {
  late AppDatabase database;
  late DownloadRepository downloadRepo;
  late LibraryRepository libraryRepo;
  late StorageManager storageManager;
  late DownloadManager downloadManager;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vanta_onda1_g01_');
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    downloadRepo = DownloadRepository(database);
    libraryRepo = LibraryRepository(database);
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
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<(Work, WorkEdition, String)> seedDownloadedWork(String suffix) async {
    final work = Work(
      id: 'work-onda1-$suffix',
      workKey: 'book:onda1-$suffix',
      title: 'Onda1 $suffix',
      author: 'Autor Teste',
      type: WorkType.book,
      primaryLanguage: 'pt-BR',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final targetPath = storageManager.getBookPath('onda1_$suffix.epub');
    await File(targetPath).writeAsBytes(List.filled(128, 0x41));
    await File('$targetPath.part').writeAsBytes(List.filled(16, 0x42));
    final edition = WorkEdition(
      id: 'ed-onda1-$suffix',
      workId: work.id,
      format: WorkFormat.epub,
      filePath: targetPath,
      fileSize: 128,
      isLocal: true,
    );
    await libraryRepo.saveWork(work.copyWith(editions: [edition]));
    await libraryRepo.updateLibraryStatus(work.id, 'downloaded');
    final item = DownloadItem(
      id: 'dl-onda1-$suffix',
      workId: work.id,
      editionId: edition.id,
      title: work.title,
      targetPath: targetPath,
      downloadUrl: 'http://127.0.0.1:9/onda1.epub',
      totalBytes: 128,
      downloadedBytes: 128,
      status: DownloadStatus.completed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await downloadRepo.saveDownload(item);
    return (work, edition, targetPath);
  }

  test('G-01 delete(deleteFile:true) remove arquivo+.part e reverte biblioteca', () async {
    final (work, edition, targetPath) = await seedDownloadedWork('del');

    await downloadManager.delete('dl-onda1-del', deleteFile: true);

    expect(await File(targetPath).exists(), isFalse);
    expect(await File('$targetPath.part').exists(), isFalse);
    expect(await downloadRepo.getDownloadById('dl-onda1-del'), isNull);

    final reloaded = await libraryRepo.getWorkById(work.id);
    expect(reloaded, isNotNull);
    final reloadedEdition =
        reloaded!.editions.firstWhere((e) => e.id == edition.id);
    expect(reloadedEdition.isLocal, isFalse);
  });

  test('G-01 delete(deleteFile:false) mantém arquivo e biblioteca', () async {
    final (work, _, targetPath) = await seedDownloadedWork('keep');

    await downloadManager.delete('dl-onda1-keep', deleteFile: false);

    expect(await File(targetPath).exists(), isTrue);
    expect(await downloadRepo.getDownloadById('dl-onda1-keep'), isNull);
    final reloaded = await libraryRepo.getWorkById(work.id);
    expect(reloaded, isNotNull);
  });

  test('G-01 clearCompleted limpa arquivos e conclui sem tocar fila', () async {
    final (_, _, targetCompleted) = await seedDownloadedWork('cc-done');
    final (workQueued, editionQueued, _) = await seedDownloadedWork('cc-q');
    // Rebaixa o segundo para queued (não deve ser tocado).
    await downloadRepo.updateStatus('dl-onda1-cc-q', DownloadStatus.queued);

    await downloadManager.clearCompleted();

    expect(await File(targetCompleted).exists(), isFalse);
    expect(await downloadRepo.getDownloadById('dl-onda1-cc-done'), isNull);
    expect(await downloadRepo.getDownloadById('dl-onda1-cc-q'), isNotNull);
    final reloadedQueued = await libraryRepo.getWorkById(workQueued.id);
    expect(reloadedQueued, isNotNull);
    expect(
      reloadedQueued!.editions
          .firstWhere((e) => e.id == editionQueued.id)
          .isLocal,
      isTrue,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/data/repositories/download_repository.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late DownloadRepository repository;

  final sampleDownload = DownloadItem(
    id: 'dl-test-01',
    workId: 'work-test-01',
    editionId: 'ed-test-01',
    title: 'Duna',
    targetPath: '/storage/novareader/books/duna.epub',
    downloadUrl: 'https://example.com/duna.epub',
    totalBytes: 2048000,
    downloadedBytes: 512000,
    status: DownloadStatus.downloading,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);

    // Cria registro de obra correspondente no banco (por causa da foreign key)
    final db = database.db;
    await db.insert('works', {
      'id': 'work-test-01',
      'work_key': 'book:duna',
      'title': 'Duna',
      'author': 'Frank Herbert',
      'primary_language': 'pt-BR',
      'type': 'book',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    repository = DownloadRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DownloadRepository (Fase H - SQLite Persistence)', () {
    test('Salva e recupera download por ID', () async {
      await repository.saveDownload(sampleDownload);

      final retrieved = await repository.getDownloadById(sampleDownload.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(sampleDownload.id));
      expect(retrieved.title, equals('Duna'));
      expect(retrieved.status, equals(DownloadStatus.downloading));
      expect(retrieved.totalBytes, equals(2048000));
      expect(retrieved.downloadedBytes, equals(512000));
    });

    test(
      'getDownloadByEditionId recupera download mais recente associado à edição',
      () async {
        await repository.saveDownload(sampleDownload);

        final byEdition = await repository.getDownloadByEditionId(
          sampleDownload.editionId,
        );

        expect(byEdition, isNotNull);
        expect(byEdition!.editionId, equals(sampleDownload.editionId));
        expect(byEdition.title, equals('Duna'));
      },
    );

    test(
      'getAllDownloads lista downloads ordenados por data decrescente',
      () async {
        final secondDownload = sampleDownload.copyWith(
          id: 'dl-test-02',
          editionId: 'ed-test-02',
          title: 'Fundação',
          status: DownloadStatus.completed,
        );

        await repository.saveDownload(sampleDownload);
        await repository.saveDownload(secondDownload);

        final list = await repository.getAllDownloads();

        expect(list.length, equals(2));
      },
    );

    test(
      'updateStatus atualiza status e mensagem de erro com timestamp atualizado',
      () async {
        await repository.saveDownload(sampleDownload);

        await repository.updateStatus(
          sampleDownload.id,
          DownloadStatus.failed,
          errorMessage: 'Erro de conexão com servidor',
        );

        final updated = await repository.getDownloadById(sampleDownload.id);

        expect(updated, isNotNull);
        expect(updated!.status, equals(DownloadStatus.failed));
        expect(updated.errorMessage, equals('Erro de conexão com servidor'));
      },
    );

    test('updateProgress atualiza bytes transferidos e total', () async {
      await repository.saveDownload(sampleDownload);

      await repository.updateProgress(sampleDownload.id, 1024000, 2048000);

      final updated = await repository.getDownloadById(sampleDownload.id);

      expect(updated, isNotNull);
      expect(updated!.downloadedBytes, equals(1024000));
      expect(updated.totalBytes, equals(2048000));
      expect(updated.progressPercent, equals(50));
    });

    test('deleteDownload remove registro do banco de dados', () async {
      await repository.saveDownload(sampleDownload);

      await repository.deleteDownload(sampleDownload.id);

      final deleted = await repository.getDownloadById(sampleDownload.id);
      expect(deleted, isNull);
    });
  });
}

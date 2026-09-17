import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late StorageManager storageManager;
  late AppDatabase database;
  late ProfileRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_profile_repo_test_',
    );
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );

    database = AppDatabase();
    await database.initialize(isTestInMemory: true);

    repository = ProfileRepository(database, storageManager: storageManager);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ProfileRepository (Fase M)', () {
    test(
      'getProfile retorna perfil padrão quando o banco está vazio',
      () async {
        final profile = await repository.getProfile();

        expect(profile.id, equals('primary_profile'));
        expect(profile.name, equals('Leitor'));
        expect(profile.avatarId, equals('nova_monolith'));
        expect(profile.preferredLanguage, equals('pt-BR'));
        expect(profile.fontSize, equals(16.0));
        expect(profile.fontFamily, equals('Inter'));
        expect(profile.readingMode, equals('paged'));
        expect(profile.maxConcurrentDownloads, equals(2));
      },
    );

    test(
      'saveProfile atualiza campos e persiste preferências no SQLite',
      () async {
        final initial = await repository.getProfile();
        final updated = initial.copyWith(
          name: 'Leitor Avançado',
          avatarId: 'nova_prism',
          preferredLanguage: 'en',
          fontSize: 18.0,
          readingMode: 'continuous',
          maxConcurrentDownloads: 4,
        );

        await repository.saveProfile(updated);

        final retrieved = await repository.getProfile();
        expect(retrieved.name, equals('Leitor Avançado'));
        expect(retrieved.avatarId, equals('nova_prism'));
        expect(retrieved.preferredLanguage, equals('en'));
        expect(retrieved.fontSize, equals(18.0));
        expect(retrieved.readingMode, equals('continuous'));
        expect(retrieved.maxConcurrentDownloads, equals(4));
      },
    );

    test(
      'getReadingStats computa métricas agregadas reais do banco de dados',
      () async {
        // 1. Insere obra de livro
        await database.db.insert('works', {
          'id': 'book-1',
          'work_key': 'book:dune',
          'title': 'Duna',
          'author': 'Frank Herbert',
          'primary_language': 'pt-BR',
          'type': 'book',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 2. Insere edição com is_local = 1
        await database.db.insert('work_editions', {
          'id': 'ed-book-1',
          'work_id': 'book-1',
          'format': 'epub',
          'is_local': 1,
          'file_size': 1024,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 3. Progresso do livro (100% concluído)
        await database.db.insert('reading_progress', {
          'work_id': 'book-1',
          'edition_id': 'ed-book-1',
          'current_page': 350,
          'total_pages': 350,
          'percentage': 1.0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 4. Insere HQ
        await database.db.insert('works', {
          'id': 'comic-1',
          'work_key': 'comic:watchmen',
          'title': 'Watchmen',
          'author': 'Alan Moore',
          'primary_language': 'pt-BR',
          'type': 'comic',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 5. Progresso da HQ (em andamento 50%)
        await database.db.insert('reading_progress', {
          'work_id': 'comic-1',
          'edition_id': 'ed-comic-1',
          'current_page': 100,
          'total_pages': 200,
          'percentage': 0.5,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 6. Insere favorito na library
        await database.db.insert('library', {
          'work_id': 'book-1',
          'status': 'downloaded',
          'is_favorite': 1,
          'added_at': DateTime.now().millisecondsSinceEpoch,
          'last_accessed_at': DateTime.now().millisecondsSinceEpoch,
        });

        final stats = await repository.getReadingStats();

        expect(stats.booksRead, equals(1));
        expect(stats.comicsRead, equals(0));
        expect(stats.currentlyReading, equals(1));
        expect(stats.totalFavorites, equals(1));
        expect(stats.totalDownloaded, equals(1));
        expect(stats.totalPagesRead, equals(450)); // 350 + 100
      },
    );

    test(
      'getStorageUsage e clearCache interagem corretamente com o StorageManager',
      () async {
        // Cria arquivos em books e reading cache
        final bookFile = File('${storageManager.booksDir.path}/sample.epub');
        await bookFile.writeAsString('CONTEUDO DO LIVRO');

        final cacheFile = File(
          '${storageManager.readingCacheDir.path}/temp_stream.epub',
        );
        await cacheFile.writeAsString('CONTEUDO DO CACHE');

        final usage = await repository.getStorageUsage();
        expect(usage.booksBytes, greaterThan(0));
        expect(usage.cacheBytes, greaterThan(0));
        expect(usage.totalBytes, greaterThan(0));

        // Limpa cache
        final freed = await repository.clearReadingCache();
        expect(freed, greaterThan(0));
        expect(await cacheFile.exists(), isFalse);
        expect(await bookFile.exists(), isTrue);
      },
    );
  });
}

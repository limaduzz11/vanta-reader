import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';

void main() {
  late AppDatabase appDatabase;

  setUp(() async {
    appDatabase = AppDatabase();
    await appDatabase.initialize(isTestInMemory: true);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('AppDatabase', () {
    test('inicializa conexão com SQLite e valida tabelas essenciais', () async {
      expect(appDatabase.isOpen, isTrue);

      final tables = await appDatabase.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('works'));
      expect(tableNames, contains('work_editions'));
      expect(tableNames, contains('content_assets'));
      expect(tableNames, contains('library'));
      expect(tableNames, contains('reading_progress'));
      expect(tableNames, contains('reading_history'));
      expect(tableNames, contains('downloads'));
      expect(tableNames, contains('profiles'));
      expect(tableNames, contains('providers'));
      expect(tableNames, contains('settings'));
    });

    test('executa inserção e consulta relacional de obra', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await appDatabase.db.insert('works', {
        'id': 'w1',
        'work_key': 'key_dune',
        'title': 'Duna',
        'author': 'Frank Herbert',
        'primary_language': 'pt-BR',
        'type': 'book',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await appDatabase.db.query(
        'works',
        where: 'id = ?',
        whereArgs: ['w1'],
      );
      expect(rows.length, equals(1));
      expect(rows.first['title'], equals('Duna'));
      expect(rows.first['primary_language'], equals('pt-BR'));
    });

    test(
      'migra v3 para v4 com ContentAsset e progresso canônico 0–1',
      () async {
        await appDatabase.close();
        final tempDir = await Directory.systemTemp.createTemp(
          'vanta_db_v3_test_',
        );
        final dbPath = p.join(tempDir.path, AppDatabase.databaseFileName);
        final legacyDb = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) async {
              await db.execute('''
              CREATE TABLE work_editions (
                id TEXT PRIMARY KEY, work_id TEXT NOT NULL, format TEXT NOT NULL,
                file_path TEXT, file_size INTEGER DEFAULT 0, page_count INTEGER DEFAULT 0,
                checksum TEXT, download_url TEXT, provider_id TEXT,
                is_local INTEGER DEFAULT 0, created_at INTEGER NOT NULL
              )
            ''');
              await db.execute('''
              CREATE TABLE reading_progress (
                work_id TEXT PRIMARY KEY, edition_id TEXT NOT NULL,
                current_page INTEGER NOT NULL DEFAULT 0,
                total_pages INTEGER NOT NULL DEFAULT 0,
                percentage REAL NOT NULL DEFAULT 0.0,
                updated_at INTEGER NOT NULL
              )
            ''');
            },
          ),
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        await legacyDb.insert('work_editions', {
          'id': 'local-ed',
          'work_id': 'w1',
          'format': 'epub',
          'file_path': '/tmp/book.epub',
          'file_size': 100,
          'is_local': 1,
          'created_at': now,
        });
        await legacyDb.insert('work_editions', {
          'id': 'remote-ed',
          'work_id': 'w2',
          'format': 'cbz',
          'download_url': 'https://example.test/comic.cbz',
          'provider_id': 'fixture',
          'created_at': now,
        });
        await legacyDb.insert('reading_progress', {
          'work_id': 'w1',
          'edition_id': 'local-ed',
          'current_page': 50,
          'total_pages': 100,
          'percentage': 50.0,
          'updated_at': now,
        });
        await legacyDb.close();

        await appDatabase.initialize(customPath: tempDir.path);

        final columns = await appDatabase.db.rawQuery(
          'PRAGMA table_info(work_editions)',
        );
        expect(
          columns.map((row) => row['name']),
          containsAll([
            'external_id',
            'language',
            'original_title',
            'localized_title',
          ]),
        );
        final assets = await appDatabase.db.query(
          'content_assets',
          orderBy: 'edition_id',
        );
        expect(assets, hasLength(2));
        expect(assets[0]['status'], 'downloaded');
        expect(assets[1]['status'], 'remote_available');
        final progress = await appDatabase.db.query('reading_progress');
        expect(progress.single['percentage'], 0.5);

        await appDatabase.close();
        await tempDir.delete(recursive: true);
      },
    );
  });
}

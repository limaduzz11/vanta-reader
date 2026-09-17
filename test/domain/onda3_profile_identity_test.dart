import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/core/theme/nova_colors.dart';
import 'package:vantareader/data/repositories/profile_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'dart:io';

/// Onda 3 — G-07 (accent persistido) + D-06 (equality de edição).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Onda 3 G-07 — accent secundário', () {
    late AppDatabase database;
    late ProfileRepository repo;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vanta_onda3_g07_');
      final storage = await StorageManager.initialize(
        customRootPath: tempDir.path,
      );
      database = AppDatabase();
      await database.initialize(customPath: storage.databaseDir.path);
      repo = ProfileRepository(database, storageManager: storage);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('perfil padrão usa accent grafite e persiste troca', () async {
      final fresh = await repo.getProfile();
      expect(fresh.accentColor, equals('grafite'));

      await repo.saveProfile(fresh.copyWith(accentColor: 'musgo'));
      final reloaded = await repo.getProfile();
      expect(reloaded.accentColor, equals('musgo'));
      expect(
        VantaAccent.getById(reloaded.accentColor).color,
        equals(VantaAccent.getById('musgo').color),
      );
    });

    test('accent desconhecido cai no grafite sem quebrar', () {
      expect(VantaAccent.getById('inexistente').id, equals('grafite'));
      expect(VantaAccent.presets.length, greaterThanOrEqualTo(5));
    });
  });

  group('Onda 3 D-06 — equality de WorkEdition', () {
    test('edições que diferem só em downloadUrl/providerId não são iguais', () {
      const a = WorkEdition(id: 'ed-1', workId: 'w', format: WorkFormat.epub);
      const b = WorkEdition(
        id: 'ed-1',
        workId: 'w',
        format: WorkFormat.epub,
        downloadUrl: 'https://ex.example/a.epub',
        providerId: 'vanta-catalog',
      );
      expect(a == b, isFalse);
    });
  });
}

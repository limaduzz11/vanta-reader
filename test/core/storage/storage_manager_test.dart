import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late StorageManager storageManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_test_storage_');
    storageManager = await StorageManager.initialize(
      customRootPath: tempDir.path,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageManager', () {
    test('cria árvore completa de diretórios físicos', () async {
      expect(await storageManager.booksDir.exists(), isTrue);
      expect(await storageManager.comicsDir.exists(), isTrue);
      expect(await storageManager.coversDir.exists(), isTrue);
      expect(await storageManager.thumbnailsDir.exists(), isTrue);
      expect(await storageManager.databaseDir.exists(), isTrue);
      expect(await storageManager.cacheDir.exists(), isTrue);
      expect(await storageManager.readingCacheDir.exists(), isTrue);
    });

    test('bloqueia tentativas de Path Traversal', () {
      expect(
        () => storageManager.validateSafeFileName('../../etc/passwd'),
        throwsA(isA<NovaException>()),
      );
      expect(
        () => storageManager.validateSafeFileName('pasta/subarquivo.epub'),
        throwsA(isA<NovaException>()),
      );
      expect(
        () => storageManager.validateSafeFileName('   '),
        throwsA(isA<NovaException>()),
      );
      expect(
        () => storageManager.getSafeFile(
          storageManager.booksDir,
          '../malicious.txt',
        ),
        throwsA(isA<NovaException>()),
      );
    });

    test(
      'limpa apenas o diretório de cache sem tocar em livros ou quadrinhos',
      () async {
        // Cria livro
        final bookFile = File(
          p.join(storageManager.booksDir.path, 'livro_teste.epub'),
        );
        await bookFile.writeAsString('conteudo do livro');

        // Cria quadrinho
        final comicFile = File(
          p.join(storageManager.comicsDir.path, 'comic_teste.cbz'),
        );
        await comicFile.writeAsString('conteudo da hq');

        // Cria arquivo temporário em cache
        final cacheFile = File(
          p.join(storageManager.cacheDir.path, 'temp_page.jpg'),
        );
        await cacheFile.writeAsString('conteudo de cache');

        expect(await bookFile.exists(), isTrue);
        expect(await comicFile.exists(), isTrue);
        expect(await cacheFile.exists(), isTrue);

        final freed = await storageManager.clearCache();
        expect(freed, greaterThan(0));

        // Cache deve sumir
        expect(await cacheFile.exists(), isFalse);

        // Conteúdos permanentes DEVEM permanecer intactos
        expect(await bookFile.exists(), isTrue);
        expect(await comicFile.exists(), isTrue);
      },
    );

    test(
      'limpa apenas o diretório de leitura temporária sem tocar em outros caches',
      () async {
        final generalCache = File(
          p.join(storageManager.cacheDir.path, 'general.tmp'),
        );
        await generalCache.writeAsString('cache geral');

        final readingCache = File(
          p.join(storageManager.readingCacheDir.path, 'stream.epub'),
        );
        await readingCache.writeAsString('cache stream');

        final freed = await storageManager.clearReadingCache();
        expect(freed, greaterThan(0));

        expect(await readingCache.exists(), isFalse);
        expect(await generalCache.exists(), isTrue);
      },
    );

    test('calcula consumo de armazenamento por partição', () async {
      final bookFile = File(p.join(storageManager.booksDir.path, 'livro.epub'));
      await bookFile.writeAsString('1234567890'); // 10 bytes

      final usage = await storageManager.calculateUsage();
      expect(usage.booksBytes, equals(10));
      expect(usage.totalBytes, greaterThanOrEqualTo(10));
      expect(usage.formatBytes(usage.booksBytes), equals('10 B'));
    });
  });
}

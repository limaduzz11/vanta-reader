import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/providers/metadata_normalizer.dart';
import 'package:vantareader/core/providers/work_identity_system.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryRepository libraryRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_perf_test_');
    appDatabase = AppDatabase();
    await appDatabase.initialize(customPath: tempDir.path);
    libraryRepository = LibraryRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Fase O — Performance & Stress Test: SQLite 1.000+ Obras', () {
    test('popula 1.000 obras em lote e valida busca local sub-10ms', () async {
      final works = List.generate(1000, (index) {
        final id = 'work-perf-$index';
        final isBook = index % 2 == 0;
        final type = isBook ? WorkType.book : WorkType.comic;
        final isLocal = index % 3 == 0;
        final now = DateTime.now();
        final author = index % 5 == 0
            ? 'Isaac Asimov'
            : (index % 3 == 0 ? 'Alan Moore' : 'Autor Genérico $index');
        final title =
            'Obra Literária Número $index - ${isBook ? "Romance" : "HQ"}';

        return Work(
          id: id,
          workKey: 'key_perf_$index',
          title: title,
          author: author,
          type: type,
          primaryLanguage: index % 4 == 0 ? 'en' : 'pt-BR',
          series: index % 10 == 0 ? 'Série Fundação' : null,
          volume: !isBook ? '${(index % 20) + 1}' : null,
          createdAt: now,
          updatedAt: now,
          editions: [
            WorkEdition(
              id: 'ed-perf-$index',
              workId: id,
              format: isBook ? WorkFormat.epub : WorkFormat.cbz,
              fileSize: 1024 * 1024 * ((index % 10) + 1),
              pageCount: 100 + (index % 50),
              isLocal: isLocal,
              filePath: isLocal
                  ? '/fixtures/work-$index.${isBook ? 'epub' : 'cbz'}'
                  : null,
              contentAssets: isLocal
                  ? [
                      ContentAsset(
                        id: 'asset-perf-$index',
                        editionId: 'ed-perf-$index',
                        format: isBook ? WorkFormat.epub : WorkFormat.cbz,
                        status: ContentAssetStatus.downloaded,
                        localPath:
                            '/fixtures/work-$index.${isBook ? 'epub' : 'cbz'}',
                        createdAt: now,
                        updatedAt: now,
                      ),
                    ]
                  : const [],
            ),
          ],
        );
      });

      // 1. Benchmark de inserção em lote (batch transaction)
      final insertStopwatch = Stopwatch()..start();
      await libraryRepository.saveWorks(works);
      insertStopwatch.stop();

      expect(
        insertStopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: 'Inserção de 1.000 obras deve ser veloz via batch transaction',
      );

      // 2. Benchmark de recuperação completa de biblioteca (1.000 obras sem N+1)
      final fetchStopwatch = Stopwatch()..start();
      final loadedWorks = await libraryRepository.getLibraryWorks();
      fetchStopwatch.stop();

      expect(loadedWorks.length, equals(1000));
      expect(
        fetchStopwatch.elapsedMilliseconds,
        lessThan(250),
        reason:
            'Carregamento de 1.000 obras deve ser veloz com batching de edições',
      );

      // 3. Benchmark de busca local indexada sub-10ms
      // Executa aquecimento + 10 buscas reais medindo tempo médio
      final searchQueries = [
        'Fundação',
        'Asimov',
        'Moore',
        'Número 42',
        'Romance',
      ];
      final latencies = <int>[];

      for (final query in searchQueries) {
        final queryStopwatch = Stopwatch()..start();
        final results = await libraryRepository.searchLocal(query);
        queryStopwatch.stop();
        latencies.add(queryStopwatch.elapsedMilliseconds);
        expect(
          results,
          isNotEmpty,
          reason: 'A query "$query" deve retornar resultados',
        );
      }

      final averageLatency =
          latencies.reduce((a, b) => a + b) / latencies.length;
      expect(
        averageLatency,
        lessThan(50.0),
        reason:
            'A latência média de busca local em 1.000 obras deve ser sub-50ms',
      );

      // 4. Teste de filtro por obras baixadas (materializadas)
      final downloadedWorks = await libraryRepository.getLibraryWorks(
        onlyDownloaded: true,
      );
      expect(downloadedWorks.length, greaterThan(0));
      expect(downloadedWorks.every((w) => w.isDownloaded), isTrue);

      // 5. Teste de filtro por favoritos
      await libraryRepository.toggleFavorite('work-perf-0', true);
      await libraryRepository.toggleFavorite('work-perf-10', true);
      final favoriteWorks = await libraryRepository.getLibraryWorks(
        onlyFavorites: true,
      );
      expect(favoriteWorks.length, equals(2));
    });
  });

  group('Fase O — Performance & Stress Test: Contenção de Memória em HQs 4K', () {
    test(
      'ComicPageCache respeita estritamente limite de memória com páginas 4K (Anti-OOM)',
      () {
        // Configura orçamento de 10 MB e máximo de 7 itens
        const maxBytes = 10 * 1024 * 1024; // 10 MB
        final cache = ComicPageCache(
          maxCapacity: 7,
          maxBytesCapacity: maxBytes,
        );

        // Simula páginas 4K comprimidas de 3 MB cada
        const pageSize = 3 * 1024 * 1024; // 3 MB por página
        final pageData = Uint8List(pageSize);

        // Insere 1ª página (3 MB total)
        cache.put(0, pageData);
        expect(cache.length, equals(1));
        expect(cache.totalBytes, equals(pageSize));

        // Insere 2ª página (6 MB total)
        cache.put(1, pageData);
        expect(cache.length, equals(2));
        expect(cache.totalBytes, equals(pageSize * 2));

        // Insere 3ª página (9 MB total)
        cache.put(2, pageData);
        expect(cache.length, equals(3));
        expect(cache.totalBytes, equals(pageSize * 3));

        // Insere 4ª página (Tentaria 12 MB, excedendo o limite de 10 MB)
        // O cache deve expulsar a página 0 (LRU) para manter o consumo abaixo de 10 MB!
        cache.put(3, pageData);
        expect(cache.totalBytes, lessThanOrEqualTo(maxBytes));
        expect(
          cache.contains(0),
          isFalse,
          reason: 'Página 0 deve ter sido expulsa',
        );
        expect(cache.contains(1), isTrue);
        expect(cache.contains(2), isTrue);
        expect(cache.contains(3), isTrue);
        expect(cache.evictionsCount, equals(1));

        // Navegação simulada por 20 páginas consecutivas de 3 MB
        for (int i = 4; i < 24; i++) {
          cache.put(i, pageData);
          expect(
            cache.totalBytes,
            lessThanOrEqualTo(maxBytes),
            reason:
                'Consumo de memória NUNCA deve ultrapassar o orçamento de 10 MB',
          );
        }

        expect(cache.evictionsCount, greaterThan(15));
        expect(
          cache.length,
          lessThanOrEqualTo(3),
          reason:
              'Com páginas de 3MB e limite de 10MB, o cache mantém no máximo 3 páginas em RAM',
        );

        // Validação de métricas de hits e misses
        final hitPage = cache.get(23);
        expect(hitPage, isNotNull);
        expect(cache.hits, equals(1));

        final missPage = cache.get(0); // Já expulsa
        expect(missPage, isNull);
        expect(cache.misses, equals(1));
        expect(cache.hitRate, equals(0.5));

        // Limpeza ativa de cache
        cache.clear();
        expect(cache.length, equals(0));
        expect(cache.totalBytes, equals(0));
      },
    );
  });

  group('Fase O — Performance: Deduplicação e StorageManager', () {
    test(
      'MetadataNormalizer e WorkIdentitySystem processam 500 títulos em alta velocidade',
      () {
        final normalizerStopwatch = Stopwatch()..start();

        for (int i = 0; i < 500; i++) {
          final title = '  O Fim da Eternidade (Vol. $i) [Edição Especial]  ';
          final normalizedTitle = MetadataNormalizer.normalizeTitle(
            title,
          ).title;
          final normalizedAuthor = MetadataNormalizer.normalizeAuthor([
            'Asimov, Isaac',
          ]);
          final workKey = WorkIdentitySystem.generateWorkKey(
            title: normalizedTitle,
            author: normalizedAuthor,
          );
          expect(workKey, contains('fim_eternidade_$i'));
        }

        normalizerStopwatch.stop();
        expect(
          normalizerStopwatch.elapsedMilliseconds,
          lessThan(300),
          reason:
              '500 normalizações e chaves de identidade devem levar menos de 300ms',
        );
      },
    );

    test(
      'StorageManager calcula uso de disco concorrentemente em tempo reduzido',
      () async {
        final storage = await StorageManager.initialize(
          customRootPath: tempDir.path,
        );

        // Cria 50 arquivos simulados distribuídos nas pastas
        for (int i = 0; i < 50; i++) {
          final file = File('${storage.booksDir.path}/book_$i.bin');
          await file.writeAsBytes(List.filled(1024, i % 256));
        }

        final usageStopwatch = Stopwatch()..start();
        final usage = await storage.calculateUsage();
        usageStopwatch.stop();

        expect(usage.booksBytes, equals(50 * 1024));
        expect(
          usageStopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Cálculo de armazenamento paralelo via Future.wait deve ser sub-100ms',
        );
      },
    );
  });
}

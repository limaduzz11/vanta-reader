import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/reading_progress.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;

  setUp(() async {
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    repository = LibraryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('LibraryRepository', () {
    final sampleWork = Work(
      id: 'work-101',
      workKey: 'key_clean_code',
      title: 'Clean Code',
      author: 'Robert C. Martin',
      primaryLanguage: 'en',
      type: WorkType.book,
      editions: [
        WorkEdition(
          id: 'ed-1',
          workId: 'work-101',
          format: WorkFormat.epub,
          filePath: '/books/clean_code.epub',
          fileSize: 2048576,
          isLocal: true,
          contentAssets: [
            ContentAsset(
              id: 'asset-ed-1-epub',
              editionId: 'ed-1',
              format: WorkFormat.epub,
              status: ContentAssetStatus.downloaded,
              localPath: '/books/clean_code.epub',
              fileSize: 2048576,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('salva e recupera obra na biblioteca local', () async {
      await repository.saveWork(sampleWork);

      final retrieved = await repository.getWorkById('work-101');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Clean Code'));
      expect(retrieved.author, equals('Robert C. Martin'));
      expect(retrieved.editions.length, equals(1));
      expect(retrieved.editions.first.format, equals(WorkFormat.epub));
      expect(retrieved.isDownloaded, isTrue);
    });

    test('filtra obras por tipo e idioma', () async {
      await repository.saveWork(sampleWork);

      // Salva uma HQ em português
      final comic = Work(
        id: 'work-comic-1',
        workKey: 'key_batman_ano_um',
        title: 'Batman: Ano Um',
        author: 'Frank Miller',
        primaryLanguage: 'pt-BR',
        type: WorkType.comic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveWork(comic);

      // Filtra livros
      final booksOnly = await repository.getLibraryWorks(
        filterType: WorkType.book,
      );
      expect(booksOnly.length, equals(1));
      expect(booksOnly.first.title, equals('Clean Code'));

      // Filtra HQs
      final comicsOnly = await repository.getLibraryWorks(
        filterType: WorkType.comic,
      );
      expect(comicsOnly.length, equals(1));
      expect(comicsOnly.first.title, equals('Batman: Ano Um'));

      // Filtra por idioma
      final ptWorks = await repository.getLibraryWorks(language: 'pt-BR');
      expect(ptWorks.length, equals(1));
      expect(ptWorks.first.title, equals('Batman: Ano Um'));
    });

    test('alterna favoritos com persistência', () async {
      await repository.saveWork(sampleWork);

      expect(await repository.isFavorite('work-101'), isFalse);

      await repository.toggleFavorite('work-101', true);
      expect(await repository.isFavorite('work-101'), isTrue);

      final favorites = await repository.getLibraryWorks(onlyFavorites: true);
      expect(favorites.length, equals(1));
      expect(favorites.first.id, equals('work-101'));
    });

    test('salva e restaura progresso de leitura milimetricamente', () async {
      await repository.saveWork(sampleWork);

      final progress = ReadingProgress(
        workId: 'work-101',
        editionId: 'ed-1',
        chapterId: 'chap_04',
        currentPage: 67,
        totalPages: 100,
        charOffset: 120,
        percentage: 0.67,
        updatedAt: DateTime.now(),
      );

      await repository.saveProgress(progress);

      final restored = await repository.getProgress('work-101');
      expect(restored, isNotNull);
      expect(restored!.chapterId, equals('chap_04'));
      expect(restored.currentPage, equals(67));
      expect(restored.percentage, closeTo(0.67, 0.001));
      expect(restored.percentageInt, equals(67));
    });

    test('busca local por título ou autor', () async {
      await repository.saveWork(sampleWork);

      final resultsByTitle = await repository.searchLocal('clean');
      expect(resultsByTitle.length, equals(1));

      final resultsByAuthor = await repository.searchLocal('martin');
      expect(resultsByAuthor.length, equals(1));

      final resultsEmpty = await repository.searchLocal('inexistente');
      expect(resultsEmpty.isEmpty, isTrue);
    });
  });
}

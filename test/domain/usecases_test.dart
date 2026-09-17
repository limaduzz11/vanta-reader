import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/reading_progress.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_library_works_usecase.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/search_local_library_usecase.dart';
import 'package:vantareader/domain/usecases/seed_initial_catalog_usecase.dart';
import 'package:vantareader/domain/usecases/toggle_favorite_usecase.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;
  late GetLibraryWorksUseCase getLibraryWorks;
  late ToggleFavoriteUseCase toggleFavorite;
  late SaveReadingProgressUseCase saveProgress;
  late GetReadingProgressUseCase getProgress;
  late SearchLocalLibraryUseCase searchLocal;
  late SeedInitialCatalogUseCase seedCatalog;

  setUp(() async {
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    repository = LibraryRepository(database);

    getLibraryWorks = GetLibraryWorksUseCase(repository);
    toggleFavorite = ToggleFavoriteUseCase(repository);
    saveProgress = SaveReadingProgressUseCase(repository);
    getProgress = GetReadingProgressUseCase(repository);
    searchLocal = SearchLocalLibraryUseCase(repository);
    seedCatalog = SeedInitialCatalogUseCase(repository);
  });

  tearDown(() async {
    await database.close();
  });

  group('Fase D — Domain UseCases (Local-First Library)', () {
    test(
      'SeedInitialCatalogUseCase semeia catálogo inicial de 6 obras e é idempotente',
      () async {
        // 1. Banco inicialmente vazio
        var works = await getLibraryWorks();
        expect(works, isEmpty);

        // 2. Executa semeamento
        await seedCatalog();
        works = await getLibraryWorks();
        expect(works.length, equals(6));

        // Verifica que favoritos iniciais foram marcados
        final duneFav = await toggleFavorite.isFavorite('work-dune');
        expect(duneFav, isTrue);

        // 3. Execução subsequente não duplica registros (idempotência)
        await seedCatalog();
        works = await getLibraryWorks();
        expect(works.length, equals(6));
      },
    );

    test(
      'GetLibraryWorksUseCase filtra por tipo, idioma, favoritos e baixados',
      () async {
        await seedCatalog();

        // Filtro por tipo Livro
        final books = await getLibraryWorks(filterType: WorkType.book);
        expect(books.length, equals(3));
        expect(books.every((w) => w.type == WorkType.book), isTrue);

        // Filtro por tipo Quadrinho
        final comics = await getLibraryWorks(filterType: WorkType.comic);
        expect(comics.length, equals(3));
        expect(comics.every((w) => w.type == WorkType.comic), isTrue);

        // Filtro por idioma pt-BR
        final ptWorks = await getLibraryWorks(language: 'pt-BR');
        expect(ptWorks.length, equals(5));

        // Filtro por idioma en
        final enWorks = await getLibraryWorks(language: 'en');
        expect(enWorks.length, equals(1));
        expect(enWorks.first.title, equals('Clean Code'));

        // Filtro apenas favoritos
        final favorites = await getLibraryWorks(onlyFavorites: true);
        expect(favorites.length, equals(2));

        // Filtro apenas baixados
        final downloaded = await getLibraryWorks(onlyDownloaded: true);
        expect(downloaded.length, equals(5));
      },
    );

    test(
      'ToggleFavoriteUseCase alterna status de favorito no banco SQLite',
      () async {
        await seedCatalog();

        // Clean Code inicialmente não é favorito
        final initialFav = await toggleFavorite.isFavorite('work-cleancode');
        expect(initialFav, isFalse);

        // Alterna para favorito
        final nowFav = await toggleFavorite.execute('work-cleancode');
        expect(nowFav, isTrue);
        expect(await toggleFavorite.isFavorite('work-cleancode'), isTrue);

        // Alterna de volta para não favorito
        final unfav = await toggleFavorite.execute('work-cleancode');
        expect(unfav, isFalse);
        expect(await toggleFavorite.isFavorite('work-cleancode'), isFalse);
      },
    );

    test(
      'SaveReadingProgressUseCase e GetReadingProgressUseCase gravam e recuperam progresso com precisão',
      () async {
        await seedCatalog();

        final progress = ReadingProgress(
          workId: 'work-dune',
          editionId: 'ed-dune-epub',
          chapterId: 'Capítulo 10 — O Deserto Profundo',
          currentPage: 250,
          totalPages: 680,
          charOffset: 15420,
          percentage: 0.367,
          updatedAt: DateTime.now(),
        );

        await saveProgress(progress);

        final loaded = await getProgress('work-dune');
        expect(loaded, isNotNull);
        expect(loaded!.workId, equals('work-dune'));
        expect(loaded.currentPage, equals(250));
        expect(loaded.totalPages, equals(680));
        expect(loaded.charOffset, equals(15420));
        expect(loaded.percentage, closeTo(0.367, 0.001));
        expect(loaded.chapterId, equals('Capítulo 10 — O Deserto Profundo'));
      },
    );

    test(
      'SearchLocalLibraryUseCase busca obras offline por título, autor e série',
      () async {
        await seedCatalog();

        // Busca por título
        final byTitle = await searchLocal('neuromancer');
        expect(byTitle.length, equals(1));
        expect(byTitle.first.title, equals('Neuromancer'));

        // Busca por autor
        final byAuthor = await searchLocal('Martin');
        expect(byAuthor.length, equals(1));
        expect(byAuthor.first.author, contains('Martin'));

        // Busca por série
        final bySeries = await searchLocal('Sandman');
        expect(bySeries.length, equals(1));
        expect(bySeries.first.series, contains('Sandman'));

        // Busca com termo inexistente
        final emptyResult = await searchLocal('qualquercoisaqueinexiste');
        expect(emptyResult, isEmpty);

        // Busca com string vazia retorna todo o acervo
        final allResult = await searchLocal('  ');
        expect(allResult.length, equals(6));
      },
    );
  });
}

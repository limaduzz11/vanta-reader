import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/get_library_works_usecase.dart';
import 'package:vantareader/domain/usecases/search_local_library_usecase.dart';
import 'package:vantareader/domain/usecases/seed_initial_catalog_usecase.dart';
import 'package:vantareader/domain/usecases/toggle_favorite_usecase.dart';
import 'package:vantareader/presentation/blocs/library/library_bloc.dart';
import 'package:vantareader/presentation/blocs/library/library_event.dart';
import 'package:vantareader/presentation/blocs/library/library_state.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;
  late LibraryBloc bloc;

  setUp(() async {
    database = AppDatabase();
    await database.initialize(isTestInMemory: true);
    repository = LibraryRepository(database);

    final seedCatalog = SeedInitialCatalogUseCase(repository);
    await seedCatalog();

    bloc = LibraryBloc(
      getLibraryWorks: GetLibraryWorksUseCase(repository),
      toggleFavorite: ToggleFavoriteUseCase(repository),
      searchLocalLibrary: SearchLocalLibraryUseCase(repository),
    );
  });

  tearDown(() async {
    await bloc.close();
    await database.close();
  });

  group('LibraryBloc (State Management)', () {
    test('estado inicial é LibraryInitial', () {
      expect(bloc.state, isA<LibraryInitial>());
    });

    test('carrega acervo e favoritos ao despachar LoadLibraryEvent', () async {
      bloc.add(const LoadLibraryEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<LibraryLoading>(),
          predicate<LibraryLoaded>((state) {
            return state.works.length == 6 &&
                state.isFavorite('work-dune') &&
                state.isFavorite('work-watchmen') &&
                !state.isFavorite('work-cleancode');
          }),
        ]),
      );
    });

    test(
      'filtra apenas livros com LoadLibraryEvent(filterType: WorkType.book)',
      () async {
        bloc.add(const LoadLibraryEvent(filterType: WorkType.book));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<LibraryLoading>(),
            predicate<LibraryLoaded>((state) {
              return state.works.length == 3 &&
                  state.works.every((w) => w.type == WorkType.book);
            }),
          ]),
        );
      },
    );

    test('alterna favorito reativamente com ToggleFavoriteEvent', () async {
      bloc.add(const LoadLibraryEvent());

      await bloc.stream.firstWhere((s) => s is LibraryLoaded);

      // Clean Code inicialmente não é favorito
      final loadedState = bloc.state as LibraryLoaded;
      expect(loadedState.isFavorite('work-cleancode'), isFalse);

      // Despacha ToggleFavoriteEvent
      bloc.add(const ToggleFavoriteEvent('work-cleancode'));

      final nextState =
          await bloc.stream.firstWhere((s) => s is LibraryLoaded)
              as LibraryLoaded;
      expect(nextState.isFavorite('work-cleancode'), isTrue);

      // Verifica persistência no SQLite
      final isFavInDb = await repository.isFavorite('work-cleancode');
      expect(isFavInDb, isTrue);
    });

    test('executa busca local com SearchLibraryLocalEvent', () async {
      bloc.add(const SearchLibraryLocalEvent('Batman'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<LibraryLoading>(),
          predicate<LibraryLoaded>((state) {
            return state.works.length == 1 &&
                state.works.first.title.contains('Batman');
          }),
        ]),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/search_online_catalog_usecase.dart';
import 'package:vantareader/presentation/blocs/search/search_bloc.dart';
import 'package:vantareader/presentation/blocs/search/search_event.dart';
import 'package:vantareader/presentation/blocs/search/search_state.dart';

void main() {
  group('SearchBloc (Fase J - State Management)', () {
    late ProviderRegistry registry;
    late MockContentProvider mockProvider;
    late ProviderManager manager;
    late SearchOnlineCatalogUseCase useCase;
    late SearchBloc bloc;

    setUp(() {
      registry = ProviderRegistry();
      mockProvider = MockContentProvider();
      registry.register(mockProvider);
      manager = ProviderManager(registry: registry);
      useCase = SearchOnlineCatalogUseCase(manager);
      bloc = SearchBloc(
        searchCatalog: useCase,
        debounceDuration: Duration.zero, // Sem debounce nos testes unitários
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('estado inicial é SearchInitial com sugestões pré-definidas', () {
      expect(bloc.state, isA<SearchInitial>());
      final initial = bloc.state as SearchInitial;
      expect(initial.recentSearches.isNotEmpty, isTrue);
      expect(initial.recentSearches, contains('Duna'));
    });

    test(
      'SearchSubmittedEvent carrega resultados e emite SearchSuccess',
      () async {
        final states = <SearchState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const SearchSubmittedEvent('duna'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states.any((s) => s is SearchLoading), isTrue);
        expect(states.any((s) => s is SearchSuccess), isTrue);

        final success =
            states.firstWhere((s) => s is SearchSuccess) as SearchSuccess;
        expect(success.query, equals('duna'));
        expect(success.works.isNotEmpty, isTrue);
        expect(success.works.first.title, equals('Duna'));
        expect(success.works.first.editions.length, equals(2));

        await sub.cancel();
      },
    );

    test(
      'SearchSubmittedEvent com termo inexistente emite SearchEmpty',
      () async {
        final states = <SearchState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const SearchSubmittedEvent('termo_completamente_inexistente_xyz'),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states.any((s) => s is SearchLoading), isTrue);
        expect(states.any((s) => s is SearchEmpty), isTrue);

        final empty = states.firstWhere((s) => s is SearchEmpty) as SearchEmpty;
        expect(empty.query, equals('termo_completamente_inexistente_xyz'));

        await sub.cancel();
      },
    );

    test(
      'SearchFilterChangedEvent altera tipo para quadrinhos e atualiza resultados',
      () async {
        final states = <SearchState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const SearchSubmittedEvent('watchmen'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Aplica filtro de quadrinhos
        bloc.add(const SearchFilterChangedEvent(typeFilter: WorkType.comic));
        await Future.delayed(const Duration(milliseconds: 50));

        final lastState = states.last;
        expect(lastState, isA<SearchSuccess>());
        final success = lastState as SearchSuccess;
        expect(success.typeFilter, equals(WorkType.comic));
        expect(success.works.every((w) => w.type == WorkType.comic), isTrue);

        await sub.cancel();
      },
    );

    test('ClearSearchEvent reseta para SearchInitial', () async {
      bloc.add(const SearchSubmittedEvent('duna'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<SearchSuccess>());

      bloc.add(const ClearSearchEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<SearchInitial>());
    });
  });
}

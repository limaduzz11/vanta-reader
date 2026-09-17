import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/usecases/search_online_catalog_usecase.dart';
import 'package:vantareader/presentation/blocs/search/search_bloc.dart';
import 'package:vantareader/presentation/blocs/search/search_event.dart';
import 'package:vantareader/presentation/screens/search_screen.dart';

void main() {
  group('SearchScreen (Fase J - UI Widget Tests)', () {
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
        debounceDuration: Duration.zero,
      );
    });

    tearDown(() {
      bloc.close();
    });

    Widget createWidget() {
      return MaterialApp(home: SearchScreen(bloc: bloc));
    }

    testWidgets(
      'exibe campo de busca, chips de filtros e sugestões no estado inicial',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Livros'), findsOneWidget);
        expect(find.text('Quadrinhos'), findsOneWidget);
        expect(find.text('pt-BR'), findsOneWidget);
        expect(find.text('Inglês'), findsOneWidget);

        expect(find.text('SUGESTÕES DE BUSCA'), findsOneWidget);
        expect(find.text('Duna'), findsOneWidget);
        expect(find.text('Watchmen'), findsOneWidget);
      },
    );

    testWidgets(
      'ao pesquisar exibe cards de obras unificadas com formatos e autores',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pump();

        // Dispara busca diretamente no bloc
        bloc.add(const SearchSubmittedEvent('duna'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();

        // G-05: NovaCoverImage com fallback exibe o título na capa + no
        // corpo do card (2 ocorrências); antes era ícone sem texto.
        expect(find.text('Duna'), findsWidgets);
        expect(find.text('Frank Herbert'), findsOneWidget);
        // Edições disponíveis: EPUB e PDF (G-08: chips de formato na
        // barra repetem os rótulos dos badges do card).
        expect(find.text('EPUB'), findsWidgets);
        expect(find.text('PDF'), findsWidgets);
      },
    );

    testWidgets('ao buscar termo sem resultados exibe NovaEmptyState', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      bloc.add(const SearchSubmittedEvent('termo_sem_nenhum_resultado_123'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text('Nenhuma Obra Encontrada'), findsOneWidget);
    });
  });
}

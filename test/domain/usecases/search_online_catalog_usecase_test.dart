import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/search_online_catalog_usecase.dart';

void main() {
  group('SearchOnlineCatalogUseCase (Fase J - Domain UseCase)', () {
    late ProviderRegistry registry;
    late MockContentProvider mockProvider;
    late ProviderManager manager;
    late SearchOnlineCatalogUseCase useCase;

    setUp(() {
      registry = ProviderRegistry();
      mockProvider = MockContentProvider();
      registry.register(mockProvider);
      manager = ProviderManager(registry: registry);
      useCase = SearchOnlineCatalogUseCase(manager);
    });

    test('retorna obras deduplicadas para busca textual', () async {
      final results = await useCase('duna');
      expect(results.isNotEmpty, isTrue);
      final dune = results.firstWhere((w) => w.title == 'Duna');
      expect(dune.author, equals('Frank Herbert'));
      expect(dune.editions.length, equals(2));
    });

    test(
      'filtra por tipo de obra e idioma repassando parâmetros ao ProviderManager',
      () async {
        final comics = await useCase('watchmen', type: WorkType.comic);
        expect(comics.isNotEmpty, isTrue);
        expect(comics.every((w) => w.type == WorkType.comic), isTrue);

        final englishWorks = await useCase('watchmen', language: 'en');
        expect(englishWorks.isNotEmpty, isTrue);
        expect(englishWorks.every((w) => w.primaryLanguage == 'en'), isTrue);
      },
    );
  });
}

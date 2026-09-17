import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/search_online_catalog_usecase.dart';

void main() {
  group('Search Diagnostic Matrix (VANTA Reader Hardening)', () {
    late ProviderRegistry registry;
    late MockContentProvider mockProvider;
    late ProviderManager manager;
    late SearchOnlineCatalogUseCase searchUseCase;

    setUp(() {
      registry = ProviderRegistry();
      mockProvider = MockContentProvider();
      registry.register(mockProvider);
      manager = ProviderManager(registry: registry);
      searchUseCase = SearchOnlineCatalogUseCase(manager);
    });

    test(
      '1. Matriz de 9 termos obrigatorios do usuario encontra resultados relevantes',
      () async {
        final requiredQueries = [
          'vingadores',
          'avengers',
          'batman',
          'homem aranha',
          'spider-man',
          'pai rico pai pobre',
          'rich dad poor dad',
          'harry potter',
          'clean code',
        ];

        for (final query in requiredQueries) {
          final results = await searchUseCase(query);
          expect(
            results.isNotEmpty,
            isTrue,
            reason:
                'A busca por "$query" deve retornar pelo menos uma obra correspondente.',
          );
        }
      },
    );

    test(
      '2. Tratamento de Hifens e Pontuacao (Homem-Aranha e Pai Rico, Pai Pobre)',
      () async {
        // "homem aranha" sem hifen deve encontrar "Homem-Aranha"
        final spiderNoHyphen = await searchUseCase('homem aranha');
        expect(spiderNoHyphen.isNotEmpty, isTrue);
        expect(
          spiderNoHyphen.any(
            (w) => w.title.toLowerCase().contains('homem-aranha'),
          ),
          isTrue,
        );

        // "spider man" sem hifen deve encontrar "Spider-Man"
        final spiderManEn = await searchUseCase('spider man');
        expect(spiderManEn.isNotEmpty, isTrue);

        // "pai rico pai pobre" sem virgula deve encontrar "Pai Rico, Pai Pobre"
        final richDadPt = await searchUseCase('pai rico pai pobre');
        expect(richDadPt.isNotEmpty, isTrue);
        expect(
          richDadPt.any((w) => w.title.toLowerCase().contains('pai rico')),
          isTrue,
        );
      },
    );

    test('3. Insensibilidade a Diacriticos e Acentuacao', () async {
      // "codigo limpo" sem acento deve encontrar "Codigo Limpo"
      final noDiacritics = await searchUseCase('codigo limpo');
      expect(noDiacritics.isNotEmpty, isTrue);
      expect(noDiacritics.any((w) => w.title.contains('Código Limpo')), isTrue);

      // "senhor dos aneis" sem acento deve encontrar "O Senhor dos Aneis"
      final lotr = await searchUseCase('senhor dos aneis');
      expect(lotr.isNotEmpty, isTrue);
      expect(lotr.any((w) => w.title.contains('O Senhor dos Anéis')), isTrue);

      // "fundacao" sem til e cedilha deve encontrar "Fundacao"
      final fundacao = await searchUseCase('fundacao');
      expect(fundacao.isNotEmpty, isTrue);
      expect(fundacao.any((w) => w.title.contains('Fundação')), isTrue);
    });

    test(
      '4. Insensibilidade a Maiusculas e Minusculas (Case Insensitivity)',
      () async {
        final upper = await searchUseCase('BATMAN');
        final lower = await searchUseCase('batman');
        final mixed = await searchUseCase('BaTmAn');

        expect(upper.isNotEmpty, isTrue);
        expect(lower.isNotEmpty, isTrue);
        expect(mixed.isNotEmpty, isTrue);
        expect(upper.first.title, equals(lower.first.title));
        expect(mixed.first.title, equals(lower.first.title));
      },
    );

    test('5. Busca por Multiplas Palavras (Multi-word search)', () async {
      final multiWord = await searchUseCase('clean code robert martin');
      expect(multiWord.isNotEmpty, isTrue);
      expect(multiWord.first.title.toLowerCase(), contains('clean code'));
    });

    test('6. Sistema de Idioma e Ranking Ponderado (pt-BR vs en)', () async {
      // Quando preferredLanguage e pt-BR, obra em portugues fica no topo
      final resultsPt = await searchUseCase(
        'batman',
        preferredLanguage: 'pt-BR',
      );
      expect(resultsPt.isNotEmpty, isTrue);
      expect(resultsPt.first.primaryLanguage, equals('pt-BR'));

      // Quando preferredLanguage e en, obra em ingles fica no topo
      final resultsEn = await searchUseCase('batman', preferredLanguage: 'en');
      expect(resultsEn.isNotEmpty, isTrue);
      expect(resultsEn.first.primaryLanguage, equals('en'));
    });

    test('7. Filtro Estrito de Categoria (Livros vs Quadrinhos)', () async {
      final onlyComics = await searchUseCase('batman', type: WorkType.comic);
      expect(onlyComics.isNotEmpty, isTrue);
      expect(onlyComics.every((w) => w.type == WorkType.comic), isTrue);

      final onlyBooks = await searchUseCase('duna', type: WorkType.book);
      expect(onlyBooks.isNotEmpty, isTrue);
      expect(onlyBooks.every((w) => w.type == WorkType.book), isTrue);
    });
  });
}

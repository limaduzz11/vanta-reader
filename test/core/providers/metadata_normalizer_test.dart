import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/metadata_normalizer.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  group('MetadataNormalizer (Fase I - Normalização de Metadados)', () {
    test(
      'sanitizeText limpa tags HTML, caracteres de controle e espaços duplicados',
      () {
        const raw =
            '<p>Texto <b>em negrito</b> com &nbsp; espaços \x00 e quebras.\n\n</p>';
        final cleaned = MetadataNormalizer.sanitizeText(raw);
        expect(cleaned, equals('Texto em negrito com espaços e quebras.'));
      },
    );

    test(
      'normalizeTitle separa título principal e subtítulo por delimitadores',
      () {
        final res1 = MetadataNormalizer.normalizeTitle(
          'Duna: Crônicas de Duna — Livro 1',
        );
        expect(res1.title, equals('Duna'));
        expect(res1.subtitle, equals('Crônicas de Duna — Livro 1'));

        final res2 = MetadataNormalizer.normalizeTitle(
          'Clean Code',
          'A Handbook of Agile Software Craftsmanship',
        );
        expect(res2.title, equals('Clean Code'));
        expect(
          res2.subtitle,
          equals('A Handbook of Agile Software Craftsmanship'),
        );

        final res3 = MetadataNormalizer.normalizeTitle(
          'Neuromancer - Trilogia do Sprawl',
        );
        expect(res3.title, equals('Neuromancer'));
        expect(res3.subtitle, equals('Trilogia do Sprawl'));

        final res4 = MetadataNormalizer.normalizeTitle('Apenas Título');
        expect(res4.title, equals('Apenas Título'));
        expect(res4.subtitle, isNull);
      },
    );

    test(
      'normalizeAuthor inverte formato de catálogo e remove prefixos espúrios',
      () {
        expect(
          MetadataNormalizer.normalizeAuthor(['Herbert, Frank']),
          equals('Frank Herbert'),
        );

        expect(
          MetadataNormalizer.normalizeAuthor(['By Robert C. Martin']),
          equals('Robert C. Martin'),
        );

        expect(
          MetadataNormalizer.normalizeAuthor(['Por Machado de Assis']),
          equals('Machado de Assis'),
        );

        expect(
          MetadataNormalizer.normalizeAuthor(['Alan Moore', 'Dave Gibbons']),
          equals('Alan Moore, Dave Gibbons'),
        );

        expect(
          MetadataNormalizer.normalizeAuthor([]),
          equals('Autor Desconhecido'),
        );
      },
    );

    test('normalizeLanguage converte variações para pt-BR ou en', () {
      expect(MetadataNormalizer.normalizeLanguage('pt-br'), equals('pt-BR'));
      expect(MetadataNormalizer.normalizeLanguage('pt_BR'), equals('pt-BR'));
      expect(
        MetadataNormalizer.normalizeLanguage('Portuguese'),
        equals('pt-BR'),
      );
      expect(MetadataNormalizer.normalizeLanguage('por'), equals('pt-BR'));

      expect(MetadataNormalizer.normalizeLanguage('en-US'), equals('en'));
      expect(MetadataNormalizer.normalizeLanguage('english'), equals('en'));
      expect(MetadataNormalizer.normalizeLanguage('eng'), equals('en'));

      expect(MetadataNormalizer.normalizeLanguage(null), equals('und'));
    });

    test('normalizeIsbn sanitiza e valida ISBN 10 e 13', () {
      expect(
        MetadataNormalizer.normalizeIsbn('978-85-7657-313-5'),
        equals('9788576573135'),
      );

      expect(
        MetadataNormalizer.normalizeIsbn('0-13-235088-2'),
        equals('0132350882'),
      );

      // Inválido
      expect(MetadataNormalizer.normalizeIsbn('12345'), isNull);
      expect(MetadataNormalizer.normalizeIsbn(null), isNull);
    });

    test(
      'normalize converte ExternalWorkMetadata bruto em NormalizedWorkMetadata completo',
      () {
        const raw = ExternalWorkMetadata(
          providerId: 'provider-test',
          externalId: 'ext-123',
          title: 'Duna: Livro 1',
          authors: ['Herbert, Frank'],
          description: '<b>Um clássico</b> do deserto.',
          language: 'pt_BR',
          type: WorkType.book,
          format: WorkFormat.epub,
          fileSizeBytes: 3000000,
          pageCount: 680,
          isbn: '978-85-7657-313-5',
          downloadUrl: 'mock://download/dune.epub',
        );

        final normalized = MetadataNormalizer.normalize(raw);

        expect(normalized.title, equals('Duna'));
        expect(normalized.subtitle, equals('Livro 1'));
        expect(normalized.author, equals('Frank Herbert'));
        expect(normalized.primaryLanguage, equals('pt-BR'));
        expect(normalized.isbn, equals('9788576573135'));
        expect(normalized.description, equals('Um clássico do deserto.'));
        expect(normalized.editions.length, equals(1));
        expect(normalized.editions.first.format, equals(WorkFormat.epub));
        expect(normalized.editions.first.fileSize, equals(3000000));
      },
    );
  });
}

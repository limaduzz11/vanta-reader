import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/work_identity_system.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  group('WorkIdentitySystem (Fase I - Identidade Canônica e Deduplicação)', () {
    test('slugify remove diacríticos e filtra stop-words', () {
      expect(
        WorkIdentitySystem.slugify('O Fim da Eternidade'),
        equals('fim_eternidade'),
      );

      expect(
        WorkIdentitySystem.slugify(
          'A Handbook of Agile Software Craftsmanship',
        ),
        equals('handbook_agile_software_craftsmanship'),
      );
    });

    test('generateWorkKey prioriza ISBN quando válido', () {
      final key = WorkIdentitySystem.generateWorkKey(
        title: 'Duna',
        author: 'Frank Herbert',
        isbn: '978-85-7657-313-5',
      );
      expect(key, equals('isbn_9788576573135'));
    });

    test(
      'generateWorkKey cria chave canônica idêntica para variações de autor e sinônimos de título',
      () {
        final key1 = WorkIdentitySystem.generateWorkKey(
          title: 'Duna',
          author: 'Frank Herbert',
        );

        final key2 = WorkIdentitySystem.generateWorkKey(
          title: 'Dune',
          author: 'Herbert, Frank',
        );

        expect(key1, equals(key2));
        expect(key1, equals('duna__frank_herbert'));
      },
    );

    test(
      'calculateSimilarity calcula distância normalizada de Levenshtein',
      () {
        expect(
          WorkIdentitySystem.calculateSimilarity('Duna', 'Duna'),
          equals(1.0),
        );
        expect(
          WorkIdentitySystem.calculateSimilarity('Duna', 'Dune'),
          greaterThanOrEqualTo(0.75),
        );
        expect(
          WorkIdentitySystem.calculateSimilarity('Clean Code', 'Código Limpo'),
          lessThan(0.5),
        );
      },
    );

    test(
      'deduplicateAndMerge unifica itens com mesma identidade canônica em uma única obra com múltiplas edições',
      () {
        const itemPt = ExternalWorkMetadata(
          providerId: 'provider-a',
          externalId: 'dune-pt',
          title: 'Duna: Crônicas de Duna — Livro 1',
          subtitle: 'Crônicas de Duna — Livro 1',
          authors: ['Frank Herbert'],
          description:
              'Uma obra-prima da ficção científica no planeta desértico Arrakis.',
          language: 'pt-BR',
          type: WorkType.book,
          format: WorkFormat.epub,
          fileSizeBytes: 3000000,
          pageCount: 680,
          coverUrl: 'mock://covers/dune-hd.jpg',
          downloadUrl: 'mock://download/dune-pt.epub',
          isbn: '9788576573135',
        );

        const itemEn = ExternalWorkMetadata(
          providerId: 'provider-b',
          externalId: 'dune-en',
          title: 'Dune',
          authors: ['Herbert, Frank'],
          description: 'Sci-fi epic on Arrakis.',
          language: 'en',
          type: WorkType.book,
          format: WorkFormat.pdf,
          fileSizeBytes: 12000000,
          pageCount: 680,
          coverUrl: 'mock://covers/dune-low.jpg',
          downloadUrl: 'mock://download/dune-en.pdf',
          isbn: '9788576573135',
        );

        const itemWatchmen = ExternalWorkMetadata(
          providerId: 'provider-a',
          externalId: 'watchmen-1',
          title: 'Watchmen',
          authors: ['Alan Moore', 'Dave Gibbons'],
          description: 'Graphic novel seminal sobre super-heróis.',
          language: 'pt-BR',
          type: WorkType.comic,
          format: WorkFormat.cbz,
          fileSizeBytes: 50000000,
          downloadUrl: 'mock://download/watchmen.cbz',
        );

        final merged = WorkIdentitySystem.deduplicateAndMerge([
          itemPt,
          itemEn,
          itemWatchmen,
        ]);

        // Devem restar 2 obras únicas (Duna unificado e Watchmen)
        expect(merged.length, equals(2));

        final duneWork = merged.firstWhere((w) => w.isbn == '9788576573135');
        expect(duneWork.title, equals('Duna'));
        expect(duneWork.subtitle, equals('Crônicas de Duna — Livro 1'));
        expect(duneWork.author, equals('Frank Herbert'));
        expect(duneWork.primaryLanguage, equals('pt-BR'));
        expect(duneWork.coverPath, equals('mock://covers/dune-hd.jpg'));
        // Deve conter 2 edições (EPUB e PDF)
        expect(duneWork.editions.length, equals(2));
        expect(
          duneWork.editions.any((e) => e.format == WorkFormat.epub),
          isTrue,
        );
        expect(
          duneWork.editions.any((e) => e.format == WorkFormat.pdf),
          isTrue,
        );

        final watchmenWork = merged.firstWhere((w) => w.title == 'Watchmen');
        expect(watchmenWork.type, equals(WorkType.comic));
        expect(watchmenWork.editions.length, equals(1));
      },
    );

    test('deduplicateAndMerge ignora edições idênticas duplicadas', () {
      const item1 = ExternalWorkMetadata(
        providerId: 'provider-a',
        externalId: 'item-1',
        title: 'Neuromancer',
        authors: ['William Gibson'],
        type: WorkType.book,
        format: WorkFormat.epub,
        downloadUrl: 'mock://download/neuromancer.epub',
      );

      const item2 = ExternalWorkMetadata(
        providerId: 'provider-a',
        externalId: 'item-1-dup',
        title: 'Neuromancer',
        authors: ['William Gibson'],
        type: WorkType.book,
        format: WorkFormat.epub,
        downloadUrl: 'mock://download/neuromancer.epub', // mesma url e formato
      );

      final merged = WorkIdentitySystem.deduplicateAndMerge([item1, item2]);
      expect(merged.length, equals(1));
      expect(merged.first.editions.length, equals(1));
    });
  });
}

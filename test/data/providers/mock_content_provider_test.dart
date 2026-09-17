import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  group('MockContentProvider (Fase I - Provedor de Conteúdo Simulado)', () {
    late MockContentProvider provider;

    setUp(() {
      provider = MockContentProvider();
    });

    test('metadados e capacidades estão configurados corretamente', () {
      expect(provider.id, equals('mock-content-provider'));
      expect(provider.name, equals('VANTA Reader Mock Provider'));
      expect(provider.capabilities.supportsSearch, isTrue);
      expect(provider.capabilities.supportsDownload, isTrue);
      expect(provider.capabilities.supportsStreaming, isTrue);
      expect(provider.capabilities.supportedFormats, contains(WorkFormat.epub));
      expect(provider.capabilities.supportedFormats, contains(WorkFormat.cbz));
      expect(provider.capabilities.supportedLanguages, contains('pt-BR'));
      expect(provider.capabilities.supportedLanguages, contains('en'));
    });

    test(
      'checkHealth reporta status saudável por padrão e responde a simulações de falha',
      () async {
        final health = await provider.checkHealth();
        expect(health.status, equals(ProviderStatus.healthy));
        expect(health.isOperational, isTrue);

        // Simulação de erro
        provider.simulateError = true;
        final errorHealth = await provider.checkHealth();
        expect(errorHealth.status, equals(ProviderStatus.offline));
        expect(errorHealth.isOperational, isFalse);

        // Status forçado
        provider.simulateError = false;
        provider.forcedStatus = ProviderStatus.degraded;
        final degradedHealth = await provider.checkHealth();
        expect(degradedHealth.status, equals(ProviderStatus.degraded));
        expect(degradedHealth.isOperational, isTrue);
      },
    );

    test('search busca por termos em título e autor', () async {
      final results = await provider.search('duna');
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((r) => r.title.toLowerCase().contains('duna')),
        isTrue,
      );

      final authorResults = await provider.search('william gibson');
      expect(authorResults.isNotEmpty, isTrue);
      expect(authorResults.first.title.toLowerCase(), contains('neuromancer'));
    });

    test('search filtra por tipo de obra e idioma', () async {
      // Apenas quadrinhos
      final comics = await provider.search('*', type: WorkType.comic);
      expect(comics.isNotEmpty, isTrue);
      expect(comics.every((c) => c.type == WorkType.comic), isTrue);

      // Apenas inglês
      final englishWorks = await provider.search('*', language: 'en');
      expect(englishWorks.isNotEmpty, isTrue);
      expect(englishWorks.every((w) => w.language == 'en'), isTrue);
    });

    test('search suporta paginação com page e pageSize', () async {
      final page1 = await provider.search('*', page: 1, pageSize: 2);
      final page2 = await provider.search('*', page: 2, pageSize: 2);

      expect(page1.length, equals(2));
      expect(page2.length, equals(2));
      expect(page1.first.externalId, isNot(equals(page2.first.externalId)));
    });

    test(
      'getDetails retorna item correto e resolveDownloadUrl extrai URL',
      () async {
        final details = await provider.getDetails('mock-dune-pt');
        expect(details, isNotNull);
        expect(details!.title, contains('Duna'));

        final url = await provider.resolveDownloadUrl(
          'mock-dune-pt',
          WorkFormat.epub,
        );
        expect(url, equals('mock://download/dune-pt.epub'));

        final invalidFormatUrl = await provider.resolveDownloadUrl(
          'mock-dune-pt',
          WorkFormat.cbz,
        );
        expect(invalidFormatUrl, isNull);
      },
    );

    test(
      'search lança TimeoutException ou NovaException quando configurado para simulação de falha',
      () async {
        provider.timeout = const Duration(milliseconds: 50);
        provider.simulateTimeout = true;
        expect(() => provider.search('duna'), throwsA(isA<TimeoutException>()));

        provider.simulateTimeout = false;
        provider.simulateError = true;
        expect(() => provider.search('duna'), throwsA(isA<NovaException>()));
      },
    );
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/data/datasources/providers/mock_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';

class _FaultyProvider implements ContentProvider {
  @override
  String get id => 'faulty-provider';
  @override
  String get name => 'Faulty Provider';
  @override
  String get version => '1.0.0';
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();
  @override
  Duration get timeout => const Duration(milliseconds: 50);

  bool shouldThrow = true;
  bool shouldTimeout = false;

  @override
  Future<ProviderHealth> checkHealth() async =>
      ProviderHealth.offline(message: 'Falha permanente de conexão');

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (shouldTimeout) {
      await Future.delayed(const Duration(milliseconds: 200));
      throw TimeoutException('Timeout proposital');
    }
    if (shouldThrow) {
      throw Exception('Erro catastrófico de rede no provedor');
    }
    return [];
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async => null;

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async => null;
}

void main() {
  group(
    'ProviderManager (Fase I - Orquestrador de Busca e Isolamento de Falhas)',
    () {
      late ProviderRegistry registry;
      late MockContentProvider mockProvider;
      late _FaultyProvider faultyProvider;
      late ProviderManager manager;

      setUp(() {
        registry = ProviderRegistry();
        mockProvider = MockContentProvider();
        faultyProvider = _FaultyProvider();

        registry.register(mockProvider);
        registry.register(faultyProvider);

        manager = ProviderManager(registry: registry);
      });

      test(
        'search executa busca e retorna obras unificadas e deduplicadas',
        () async {
          // Busca por "duna"
          final results = await manager.search('duna');

          expect(results.isNotEmpty, isTrue);
          // Duna pt e Duna en devem ter sido mesclados em 1 obra com 2 edições
          final dune = results.firstWhere((w) => w.title == 'Duna');
          expect(dune.author, equals('Frank Herbert'));
          expect(dune.editions.length, equals(2));
          expect(dune.editions.any((e) => e.format == WorkFormat.epub), isTrue);
          expect(dune.editions.any((e) => e.format == WorkFormat.pdf), isTrue);
        },
      );

      test(
        'search isola falhas: se um provedor lança exceção ou estoura timeout, os outros funcionam sem quebrar a busca',
        () async {
          faultyProvider.shouldThrow = true;

          // Mesmo com o faultyProvider lançando erro, os resultados do mockProvider devem chegar normalmente
          final results = await manager.search('clean code');
          expect(results.isNotEmpty, isTrue);
          expect(results.first.title.toLowerCase(), contains('clean code'));

          // Teste de timeout do faultyProvider
          faultyProvider.shouldThrow = false;
          faultyProvider.shouldTimeout = true;

          final timeoutResults = await manager.search('watchmen');
          expect(timeoutResults.isNotEmpty, isTrue);
          expect(timeoutResults.first.title, contains('Watchmen'));
        },
      );

      test(
        'search respeita filtros de tipo (WorkType.comic) e ignora livros',
        () async {
          final comics = await manager.search('watchmen', type: WorkType.comic);
          expect(comics.isNotEmpty, isTrue);
          expect(comics.every((w) => w.type == WorkType.comic), isTrue);
          expect(
            comics.any(
              (w) => w.title.contains('Watchmen') || w.title.contains('Akira'),
            ),
            isTrue,
          );
        },
      );

      test(
        'resolveDownloadUrl resolve URL através do registro de provedores',
        () async {
          final url = await manager.resolveDownloadUrl(
            providerId: 'mock-content-provider',
            externalId: 'mock-dune-pt',
            format: WorkFormat.epub,
          );
          expect(url, equals('mock://download/dune-pt.epub'));

          final invalidUrl = await manager.resolveDownloadUrl(
            providerId: 'provedor-inexistente',
            externalId: '123',
            format: WorkFormat.epub,
          );
          expect(invalidUrl, isNull);
        },
      );

      test(
        'checkAllHealth realiza diagnóstico paralelo e identifica provedores ativos e com falha',
        () async {
          final healthMap = await manager.checkAllHealth();

          expect(healthMap.containsKey('mock-content-provider'), isTrue);
          expect(
            healthMap['mock-content-provider']!.status,
            equals(ProviderStatus.healthy),
          );

          expect(healthMap.containsKey('faulty-provider'), isTrue);
          expect(
            healthMap['faulty-provider']!.status,
            equals(ProviderStatus.offline),
          );

          // Provedor desativado
          registry.setProviderEnabled('faulty-provider', false);
          final updatedHealthMap = await manager.checkAllHealth();
          expect(
            updatedHealthMap['faulty-provider']!.status,
            equals(ProviderStatus.disabled),
          );
        },
      );
    },
  );
}

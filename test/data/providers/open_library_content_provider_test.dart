import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/data/datasources/providers/open_library_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  group('OpenLibraryContentProvider', () {
    late Dio mockDio;
    late NetworkClient networkClient;
    late OpenLibraryContentProvider provider;

    setUp(() {
      mockDio = Dio(BaseOptions(baseUrl: 'https://openlibrary.org'));
      networkClient = NetworkClient(dio: mockDio);
      provider = OpenLibraryContentProvider(networkClient: networkClient);
    });

    test('metadados e capacidades da OpenLibrary estão corretos', () {
      expect(provider.id, equals('open-library'));
      expect(provider.name, equals('Open Library'));
      expect(provider.capabilities.supportsSearch, isTrue);
      expect(provider.capabilities.metadataOnly, isTrue);
      expect(provider.capabilities.supportsDownload, isFalse);
      expect(provider.capabilities.supportsStreaming, isFalse);
      expect(provider.capabilities.supportedFormats, isEmpty);
      expect(provider.capabilities.supportedLanguages, contains('pt-BR'));
      expect(provider.capabilities.supportedLanguages, contains('en'));
    });

    test(
      'search com query vazia retorna lista vazia imediatamente sem chamada de rede',
      () async {
        final results = await provider.search('   ');
        expect(results, isEmpty);
      },
    );

    test(
      'resolveDownloadUrl não inventa conteúdo para provider metadata-only',
      () async {
        final url = await provider.resolveDownloadUrl(
          'OL893414W',
          WorkFormat.epub,
        );
        expect(url, isNull);
      },
    );

    test(
      'trata exceções de rede graciosamente retornando lista vazia',
      () async {
        // Simula erro interceptando chamadas
        mockDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Network connection failed',
                  type: DioExceptionType.connectionError,
                ),
              );
            },
          ),
        );

        final results = await provider.search('termo_qualquer');
        expect(results, isEmpty);

        final health = await provider.checkHealth();
        expect(health.status, equals(ProviderStatus.offline));
      },
    );
  });
}

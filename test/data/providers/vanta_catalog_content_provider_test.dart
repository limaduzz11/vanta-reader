import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/vanta/vanta_config.dart';
import 'package:vantareader/data/datasources/providers/vanta_catalog_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  group('VantaCatalogContentProvider (VANTA Catalog API v0.2)', () {
    late Dio mockDio;
    late NetworkClient networkClient;
    late VantaCatalogContentProvider provider;
    const baseUrl = 'http://127.0.0.1:9';
    Map<String, dynamic>? lastQuery;

    Map<String, dynamic> searchJson() => {
      'query': '1984',
      'total': 2,
      'limit': 20,
      'offset': 0,
      'items': [
        {
          'id': '12345',
          'title': '1984',
          'authors': ['George Orwell'],
          'publisher': 'Example Publisher',
          'year': 1949,
          'language': 'English',
          'cover_url': null,
          'formats': ['epub', 'pdf'],
        },
        {
          'id': 'c-1',
          'title': 'HQ Teste',
          'authors': 'Autor A; Autor B',
          'publisher': null,
          'year': '2020.0',
          'language': 'Portuguese',
          'cover_url': 'https://ex.example/c.jpg',
          'formats': ['CBZ'],
        },
      ],
    };

    Map<String, dynamic> detailsJson() => {
      'id': '12345',
      'title': '1984',
      'authors': ['George Orwell'],
      'publisher': 'Example Publisher',
      'year': 1949,
      'language': 'English',
      'isbn': '9780451524935',
      'doi': null,
      'pages': 328,
      'series': null,
      'edition': null,
      'cover_url': 'https://ex.example/cover.jpg',
      'topic': 'l',
      'files': [
        {
          'id': 'f9876',
          'extension': 'EPUB',
          'size_bytes': 612000,
          'pages': 328,
          'md5': 'abc123',
          'sha1': null,
          'sha256': null,
          'topic': 'l',
          'locator': '182386/abc123/1984.epub',
          'available': true,
        },
        {
          'id': 'f-off',
          'extension': 'pdf',
          'size_bytes': 10,
          'pages': 1,
          'md5': null,
          'sha1': null,
          'sha256': null,
          'topic': 'l',
          'locator': null,
          'available': false,
        },
      ],
    };

    setUp(() {
      lastQuery = null;
      mockDio = Dio(BaseOptions(baseUrl: baseUrl));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final path = options.uri.path;
            if (path == '/health') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'ok',
                    'version': '0.2.0',
                    'database': 'ok',
                    'provider_configured': false,
                    'uptime_seconds': 4,
                  },
                ),
              );
            }
            if (path == '/v1/search') {
              lastQuery = Map<String, dynamic>.from(options.queryParameters);
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: searchJson(),
                ),
              );
            }
            if (path == '/v1/books/12345') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: detailsJson(),
                ),
              );
            }
            if (path == '/v1/books/12345/files') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: (detailsJson()['files'] as List),
                ),
              );
            }
            if (path == '/v1/books/empty/files') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'f-off',
                      'extension': 'pdf',
                      'size_bytes': 10,
                      'pages': 1,
                      'available': false,
                    },
                  ],
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 404,
                data: {'detail': 'NF'},
              ),
            );
          },
        ),
      );
      networkClient = NetworkClient(dio: mockDio);
      provider = VantaCatalogContentProvider(
        networkClient: networkClient,
        config: const VantaConfig(baseUrl: baseUrl),
      );
    });

    test('1. metadados e capacidades declarados corretamente', () {
      expect(provider.id, equals('vanta-catalog'));
      expect(provider.name, equals('VANTA Catalog'));
      expect(provider.capabilities.supportsSearch, isTrue);
      expect(provider.capabilities.supportsDownload, isTrue);
      expect(provider.capabilities.supportsStreaming, isFalse);
      expect(provider.capabilities.metadataOnly, isFalse);
      expect(
        provider.capabilities.contentSourceType,
        equals('officialCatalog'),
      );
      expect(provider.capabilities.supportedFormats, contains(WorkFormat.epub));
      expect(provider.capabilities.supportedFormats, contains(WorkFormat.cbz));
      expect(provider.capabilities.supportedTypes, contains(WorkType.book));
      expect(provider.capabilities.supportedTypes, contains(WorkType.comic));
    });

    test('2. search com query vazia retorna [] sem rede', () async {
      final results = await provider.search('   ');
      expect(results, isEmpty);
      expect(lastQuery, isNull);
    });

    test('3. search happy path mapeia id prefixado, autores e tipo', () async {
      final results = await provider.search('1984');
      expect(results.length, equals(2));
      final first = results.firstWhere((e) => e.externalId == 'vanta_12345');
      expect(first.title, equals('1984'));
      expect(first.authors, equals(['George Orwell']));
      expect(first.type, equals(WorkType.book));
      expect(first.format, equals(WorkFormat.epub));
      expect(first.publisher, equals('Example Publisher'));
      expect(first.publishedDate, equals('1949'));
      // Segundo item: authors via split + extensão upper + type book (topic ausente no summary).
      final second = results.firstWhere((e) => e.externalId == 'vanta_c-1');
      expect(second.authors, equals(['Autor A', 'Autor B']));
      expect(second.format, equals(WorkFormat.cbz));
      expect(second.type, equals(WorkType.comic));
    });

    test('4. paginação page/pageSize vira limit/offset corretos', () async {
      await provider.search('1984', page: 3, pageSize: 15);
      expect(lastQuery, isNotNull);
      expect(lastQuery!['limit'], equals(15));
      expect(lastQuery!['offset'], equals(30));
      expect(lastQuery!['q'], equals('1984'));
    });

    test('5. getDetails happy path com hashes e páginas', () async {
      final details = await provider.getDetails('vanta_12345');
      expect(details, isNotNull);
      expect(details!.externalId, equals('vanta_12345'));
      expect(details.externalEditionId, equals('f9876'));
      expect(details.fileSizeBytes, equals(612000));
      expect(details.pageCount, equals(328));
      expect(details.isbn, equals('9780451524935'));
      expect(details.extraMetadata['md5'], equals('abc123'));
      expect(
        details.extraMetadata['locator'],
        equals('182386/abc123/1984.epub'),
      );
      expect(details.extraMetadata['topic'], equals('l'));
    });

    test(
      '6. resolveDownloadUrl retorna /download quando available; null quando indisponível',
      () async {
        final url = await provider.resolveDownloadUrl(
          'vanta_12345',
          WorkFormat.epub,
        );
        expect(url, equals('$baseUrl/v1/files/f9876/download'));

        final unavailable = await provider.resolveDownloadUrl(
          'vanta_empty',
          WorkFormat.pdf,
        );
        // /v1/books/empty/files só tem available=false -> null.
        expect(unavailable, isNull);
      },
    );

    test('7. checkHealth healthy no 200', () async {
      final health = await provider.checkHealth();
      expect(health.status, equals(ProviderStatus.healthy));
    });

    test('8. search retorna [] em erro de rede', () async {
      mockDio.interceptors.clear();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'down',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
      final results = await provider.search('1984');
      expect(results, isEmpty);
      final health = await provider.checkHealth();
      expect(health.status, equals(ProviderStatus.offline));
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/data/datasources/providers/gutendex_content_provider.dart';

/// Onda 2 — G-02: Gutendex expõe `summaries` como sinopse (antes null fixo).
void main() {
  group('Onda 2 G-02 — Gutendex summaries', () {
    test('search mapeia summaries[0] para description', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'results': [
                    {
                      'id': 1342,
                      'title': 'Pride and Prejudice',
                      'authors': [
                        {'name': 'Austen, Jane'}
                      ],
                      'summaries': ['A classic romance novel.'],
                      'languages': ['en'],
                      'formats': {
                        'application/epub+zip':
                            'https://example.com/1342.epub',
                        'image/jpeg': 'https://example.com/1342.jpg',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final provider = GutendexContentProvider(
        networkClient: NetworkClient(dio: mockDio),
      );

      final results = await provider.search('pride');
      expect(results, hasLength(1));
      expect(results.first.description, equals('A classic romance novel.'));
      expect(results.first.title, equals('Pride and Prejudice'));
    });

    test('search sem summaries mantém description null', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'results': [
                    {
                      'id': 11,
                      'title': 'Sem resumo',
                      'authors': [],
                      'languages': ['pt'],
                      'formats': {
                        'text/plain; charset=utf-8':
                            'https://example.com/11.txt',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final provider = GutendexContentProvider(
        networkClient: NetworkClient(dio: mockDio),
      );

      final results = await provider.search('x');
      expect(results, hasLength(1));
      expect(results.first.description, isNull);
    });
  });
}

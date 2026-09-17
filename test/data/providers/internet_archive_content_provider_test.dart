import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/data/datasources/providers/internet_archive_content_provider.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late Dio dio;
  late InternetArchiveContentProvider provider;

  Map<String, dynamic> envelope({
    required String title,
    required String license,
    bool restricted = false,
    bool includeCbz = true,
  }) {
    return {
      'metadata': {
        'title': title,
        'creator': 'Fixture Author',
        'language': 'eng',
        'licenseurl': license,
        'access-restricted-item': restricted,
      },
      'files': [
        if (includeCbz)
          {'name': 'comic issue 01.cbz', 'size': '321', 'sha1': 'abc123'},
      ],
    };
  }

  setUp(() {
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          dynamic data;
          if (options.path.endsWith('/advancedsearch.php')) {
            data = {
              'response': {
                'docs': [
                  {'identifier': 'public-comic'},
                  {'identifier': 'restricted-comic'},
                  {'identifier': 'missing-cbz'},
                ],
              },
            };
          } else if (options.path.endsWith('/metadata/public-comic')) {
            data = envelope(
              title: 'Public Comic',
              license: 'https://creativecommons.org/publicdomain/zero/1.0/',
            );
          } else if (options.path.endsWith('/metadata/restricted-comic')) {
            data = envelope(
              title: 'Restricted Comic',
              license: 'https://creativecommons.org/publicdomain/zero/1.0/',
              restricted: true,
            );
          } else if (options.path.endsWith('/metadata/missing-cbz')) {
            data = envelope(
              title: 'No CBZ',
              license: 'https://creativecommons.org/publicdomain/mark/1.0/',
              includeCbz: false,
            );
          } else {
            return handler.reject(DioException(requestOptions: options));
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );
    provider = InternetArchiveContentProvider(
      networkClient: NetworkClient(dio: dio),
    );
  });

  test('publica apenas HQ irrestrita com licença PD explícita e CBZ', () async {
    final results = await provider.search('comic', type: WorkType.comic);

    expect(results, hasLength(1));
    final item = results.single;
    expect(item.externalId, 'public-comic');
    expect(item.type, WorkType.comic);
    expect(item.format, WorkFormat.cbz);
    expect(
      item.downloadUrl,
      'https://archive.org/download/public-comic/comic%20issue%2001.cbz',
    );
    expect(item.extraMetadata['checksum'], 'abc123');
    expect(item.extraMetadata['checksumAlgorithm'], 'sha1');
  });

  test(
    'resolve URL somente para CBZ público e limpa edition id normalizado',
    () async {
      final url = await provider.resolveDownloadUrl(
        'ed-internet-archive-public-comic-cbz',
        WorkFormat.cbz,
      );

      expect(
        url,
        'https://archive.org/download/public-comic/comic%20issue%2001.cbz',
      );
      expect(
        await provider.resolveDownloadUrl('public-comic', WorkFormat.epub),
        isNull,
      );
    },
  );
}

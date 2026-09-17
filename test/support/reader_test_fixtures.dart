import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/domain/entities/work.dart';

List<int> buildTestEpub() {
  final archive = Archive();
  void addText(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addText(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>',
  );
  addText(
    'OEBPS/content.opf',
    '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf"><manifest><item id="c1" href="cap1.xhtml"/><item id="c2" href="cap2.xhtml"/></manifest><spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>',
  );
  final chapterBody = List.filled(1000, 'palavra').join(' ');
  addText(
    'OEBPS/cap1.xhtml',
    '<html><body><h1>Capítulo I</h1><p>$chapterBody</p></body></html>',
  );
  addText(
    'OEBPS/cap2.xhtml',
    '<html><body><h1>Capítulo II</h1><p>$chapterBody</p></body></html>',
  );
  return ZipEncoder().encode(archive);
}

List<int> buildTestCbz({int pageCount = 8}) {
  final archive = Archive();
  for (var page = 1; page <= pageCount; page++) {
    final bytes = utf8.encode('fixture-page-$page');
    archive.addFile(
      ArchiveFile(
        'page_${page.toString().padLeft(2, '0')}.png',
        bytes.length,
        bytes,
      ),
    );
  }
  return ZipEncoder().encode(archive);
}

class TestContentServer {
  TestContentServer._(this._server);

  final HttpServer _server;

  String url(String path) =>
      'http://${_server.address.host}:${_server.port}$path';

  static Future<TestContentServer> start(
    Map<String, List<int>> payloads,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = TestContentServer._(server);
    server.listen((request) async {
      final payload = payloads[request.uri.path];
      if (payload == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.contentLength = payload.length;
        request.response.add(payload);
      }
      await request.response.close();
    });
    return fixture;
  }

  Future<void> close() => _server.close(force: true);
}

class TestStreamingProvider implements ContentProvider {
  TestStreamingProvider(this.downloadUrls);

  final Map<WorkFormat, String> downloadUrls;

  @override
  String get id => 'test-http-provider';
  @override
  String get name => 'Test HTTP Provider';
  @override
  String get version => '1.0.0';
  @override
  Duration get timeout => const Duration(seconds: 5);
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: false,
    supportsDownload: true,
    supportsStreaming: true,
  );

  @override
  Future<ProviderHealth> checkHealth() async => ProviderHealth(
    status: ProviderStatus.healthy,
    lastChecked: DateTime.now(),
  );

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async => null;

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async => downloadUrls[format];

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async => const [];
}

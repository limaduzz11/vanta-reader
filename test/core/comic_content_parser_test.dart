import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/reader/comic_content_parser.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late ComicPageCache cache;
  late ComicContentParser parser;
  late Directory tempDir;

  final sampleComic = Work(
    id: 'work-test-comic',
    workKey: 'comic:watchmen',
    title: 'Watchmen',
    author: 'Alan Moore & Dave Gibbons',
    type: WorkType.comic,
    primaryLanguage: 'pt-BR',
    description: 'Quem vigia os vigilantes?',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    cache = ComicPageCache(maxCapacity: 5);
    parser = ComicContentParser(cache: cache);
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_comic_parser_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ComicContentParser (Fase G)', () {
    test(
      'Ordenador natural (naturalCompare) ordena páginas alfanumericamente com precisão',
      () {
        final list = ['page_10.jpg', 'page_1.jpg', 'page_2.jpg', 'page_20.jpg'];
        list.sort(ComicContentParser.naturalCompare);

        expect(
          list,
          equals(['page_1.jpg', 'page_2.jpg', 'page_10.jpg', 'page_20.jpg']),
        );
      },
    );

    test(
      'rejeita obra de catálogo sem arquivo em vez de gerar páginas',
      () async {
        final edition = WorkEdition(
          id: 'ed-sample-comic',
          workId: sampleComic.id,
          format: WorkFormat.cbz,
          filePath: null,
        );

        expect(
          () => parser.parse(work: sampleComic, edition: edition),
          throwsA(isA<NovaException>()),
        );
      },
    );

    test(
      'Parseia arquivo CBZ real filtrando apenas imagens e ordenando naturalmente',
      () async {
        final cbzFile = File('${tempDir.path}/hq_teste.cbz');
        final archive = Archive();

        // Adiciona arquivos com extensões válidas e desordenadas
        archive.addFile(ArchiveFile('page_10.jpg', 4, utf8.encode('p10')));
        archive.addFile(ArchiveFile('page_01.jpg', 3, utf8.encode('p1')));
        archive.addFile(ArchiveFile('page_02.png', 3, utf8.encode('p2')));
        // Arquivos que devem ser ignorados pelo filtro
        archive.addFile(ArchiveFile('ComicInfo.xml', 8, utf8.encode('<xml/>')));
        archive.addFile(
          ArchiveFile('__MACOSX/._page_01.jpg', 5, utf8.encode('junk')),
        );

        final zipBytes = ZipEncoder().encode(archive);
        await cbzFile.writeAsBytes(zipBytes);

        final edition = WorkEdition(
          id: 'ed-cbz-real',
          workId: sampleComic.id,
          format: WorkFormat.cbz,
          filePath: cbzFile.path,
          isLocal: true,
        );

        final content = await parser.parse(work: sampleComic, edition: edition);

        expect(content.totalPages, equals(3));
        expect(content.pages[0].fileName, equals('page_01.jpg'));
        expect(content.pages[1].fileName, equals('page_02.png'));
        expect(content.pages[2].fileName, equals('page_10.jpg'));
      },
    );

    test(
      'loadPageBytes extrai bytes reais da página e armazena no ComicPageCache',
      () async {
        final cbzFile = File('${tempDir.path}/hq_load.cbz');
        final archive = Archive();
        final pageData = utf8.encode('imagem_bytes_fake_123');
        archive.addFile(ArchiveFile('page_01.jpg', pageData.length, pageData));
        await cbzFile.writeAsBytes(ZipEncoder().encode(archive));

        final edition = WorkEdition(
          id: 'ed-load',
          workId: sampleComic.id,
          format: WorkFormat.cbz,
          filePath: cbzFile.path,
          isLocal: true,
        );

        final content = await parser.parse(work: sampleComic, edition: edition);
        final page = content.pages.first;

        expect(cache.contains(0), isFalse);

        final bytes = await parser.loadPageBytes(
          work: sampleComic,
          edition: edition,
          page: page,
        );

        expect(bytes, equals(pageData));
        expect(cache.contains(0), isTrue);
      },
    );
  });
}

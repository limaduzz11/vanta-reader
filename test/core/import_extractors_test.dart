import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/import/cbz_extractor.dart';
import 'package:vantareader/core/import/epub_extractor.dart';
import 'package:vantareader/core/import/pdf_extractor.dart';
import 'package:vantareader/core/import/txt_extractor.dart';
import 'package:vantareader/core/import/work_extractor_factory.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_extractors_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Fase E — Extratores de Metadados e Capas', () {
    test(
      'EpubExtractor extrai metadados completos e imagem de capa de EPUB válido',
      () async {
        const extractor = EpubExtractor();
        final epubFile = File('${tempDir.path}/dom_casmurro.epub');

        // Constrói EPUB sintético em memória
        final archive = Archive();

        // 1. META-INF/container.xml
        const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
        archive.addFile(
          ArchiveFile(
            'META-INF/container.xml',
            containerXml.length,
            utf8.encode(containerXml),
          ),
        );

        // 2. OEBPS/content.opf
        const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Dom Casmurro</dc:title>
    <dc:creator>Machado de Assis</dc:creator>
    <dc:language>pt-BR</dc:language>
    <dc:description>Clássico romance narrado por Bento Santiago.</dc:description>
    <dc:publisher>Editora Nova</dc:publisher>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="images/capa.jpg" media-type="image/jpeg"/>
    <item id="chapter1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
  </spine>
</package>''';
        archive.addFile(
          ArchiveFile('OEBPS/content.opf', opfXml.length, utf8.encode(opfXml)),
        );

        // 3. Imagem de capa
        final fakeCover = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x01,
          0x02,
          0x03,
        ]);
        archive.addFile(
          ArchiveFile('OEBPS/images/capa.jpg', fakeCover.length, fakeCover),
        );

        final encoded = ZipEncoder().encode(archive);
        await epubFile.writeAsBytes(encoded);

        final metadata = await extractor.extract(epubFile);

        expect(metadata.title, equals('Dom Casmurro'));
        expect(metadata.author, equals('Machado de Assis'));
        expect(metadata.description, contains('Bento Santiago'));
        expect(metadata.primaryLanguage, equals('pt-BR'));
        expect(metadata.type, equals(WorkType.book));
        expect(metadata.format, equals(WorkFormat.epub));
        expect(metadata.pageCount, equals(2));
        expect(metadata.coverBytes, isNotNull);
        expect(metadata.coverBytes!.length, equals(fakeCover.length));
      },
    );

    test(
      'EpubExtractor faz fallback gracioso para nome do arquivo em caso de arquivo mínimo/sem container',
      () async {
        const extractor = EpubExtractor();
        final rawZip = File('${tempDir.path}/livro_sem_container.epub');

        final archive = Archive();
        archive.addFile(ArchiveFile('hello.txt', 5, utf8.encode('hello')));
        final encoded = ZipEncoder().encode(archive);
        await rawZip.writeAsBytes(encoded);

        final metadata = await extractor.extract(rawZip);
        expect(metadata.title, equals('livro_sem_container'));
        expect(metadata.author, equals('Desconhecido'));
        expect(metadata.type, equals(WorkType.book));
      },
    );

    test(
      'CbzExtractor extrai metadados do ComicInfo.xml e primeira imagem como capa',
      () async {
        const extractor = CbzExtractor();
        final cbzFile = File('${tempDir.path}/hq_demolidor.cbz');

        final archive = Archive();

        // ComicInfo.xml
        const comicInfoXml = '''<?xml version="1.0"?>
<ComicInfo>
  <Title>Demolidor: A Queda de Murdock</Title>
  <Series>Demolidor</Series>
  <Number>1</Number>
  <Writer>Frank Miller</Writer>
  <Summary>A clássica saga onde o Rei do Crime descobre a identidade de Matt Murdock.</Summary>
  <PageCount>36</PageCount>
  <LanguageISO>pt-BR</LanguageISO>
</ComicInfo>''';
        archive.addFile(
          ArchiveFile(
            'ComicInfo.xml',
            comicInfoXml.length,
            utf8.encode(comicInfoXml),
          ),
        );

        // Imagens das páginas
        final p1 = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01]);
        final p2 = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x02]);
        archive.addFile(ArchiveFile('page_01.png', p1.length, p1));
        archive.addFile(ArchiveFile('page_02.png', p2.length, p2));

        final encoded = ZipEncoder().encode(archive);
        await cbzFile.writeAsBytes(encoded);

        final metadata = await extractor.extract(cbzFile);

        expect(metadata.title, equals('Demolidor: A Queda de Murdock'));
        expect(metadata.series, equals('Demolidor'));
        expect(metadata.volume, equals('1'));
        expect(metadata.author, equals('Frank Miller'));
        expect(metadata.type, equals(WorkType.comic));
        expect(metadata.format, equals(WorkFormat.cbz));
        expect(metadata.pageCount, equals(36));
        expect(metadata.coverBytes, isNotNull);
        expect(metadata.coverBytes!.length, equals(p1.length));
      },
    );

    test(
      'CbzExtractor extrai contagem de imagens como páginas quando não há ComicInfo.xml',
      () async {
        const extractor = CbzExtractor();
        final cbzFile = File('${tempDir.path}/manga_onepiece_ch01.cbz');

        final archive = Archive();
        archive.addFile(ArchiveFile('001.jpg', 3, [1, 2, 3]));
        archive.addFile(ArchiveFile('002.jpg', 3, [4, 5, 6]));
        archive.addFile(ArchiveFile('003.jpg', 3, [7, 8, 9]));
        // Adiciona arquivo que não deve ser contado como imagem
        archive.addFile(ArchiveFile('notes.txt', 4, utf8.encode('read')));

        final encoded = ZipEncoder().encode(archive);
        await cbzFile.writeAsBytes(encoded);

        final metadata = await extractor.extract(cbzFile);

        expect(metadata.title, equals('manga_onepiece_ch01'));
        expect(metadata.type, equals(WorkType.comic));
        expect(metadata.pageCount, equals(3));
        expect(metadata.coverBytes, isNotNull);
      },
    );

    test('TxtExtractor extrai título e estimativa de páginas', () async {
      const extractor = TxtExtractor();
      final txtFile = File('${tempDir.path}/memorias_postumas.txt');

      final lines = List.generate(
        105,
        (i) => 'Linha número $i do livro clássico.',
      ).join('\n');
      await txtFile.writeAsString(lines);

      final metadata = await extractor.extract(txtFile);

      expect(metadata.title, equals('memorias_postumas'));
      expect(metadata.type, equals(WorkType.book));
      expect(metadata.format, equals(WorkFormat.txt));
      expect(metadata.pageCount, equals(3)); // 105 / 35 = 3
    });

    test('PdfExtractor extrai nome e tipo de documento', () async {
      const extractor = PdfExtractor();
      final pdfFile = File('${tempDir.path}/relatorio_tecnico.pdf');
      await pdfFile.writeAsString('%PDF-1.4\n/Type /Page\n/Type /Page\n%%EOF');

      final metadata = await extractor.extract(pdfFile);

      expect(metadata.title, equals('relatorio_tecnico'));
      expect(metadata.type, equals(WorkType.book));
      expect(metadata.format, equals(WorkFormat.pdf));
      expect(metadata.pageCount, equals(2));
    });

    test(
      'WorkExtractorFactory rejeita formatos não suportados com NovaException',
      () async {
        final factory = WorkExtractorFactory();
        final invalidFile = File('${tempDir.path}/executavel.exe');
        await invalidFile.writeAsString('MZ...');

        expect(
          () => factory.extract(invalidFile),
          throwsA(
            isA<NovaException>().having(
              (e) => e.kind,
              'kind',
              NovaErrorKind.unsupportedFormat,
            ),
          ),
        );
      },
    );
  });
}

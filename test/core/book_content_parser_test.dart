import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/reader/book_content_parser.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/domain/entities/work.dart';

void main() {
  late BookContentParser parser;
  late Directory tempDir;

  setUp(() async {
    parser = const BookContentParser();
    tempDir = await Directory.systemTemp.createTemp('novareader_parser_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final sampleWork = Work(
    id: 'work-test-book',
    workKey: 'book:o-fim-da-eternidade',
    title: 'O Fim da Eternidade',
    author: 'Isaac Asimov',
    type: WorkType.book,
    primaryLanguage: 'pt-BR',
    description: 'Um clássico da ficção científica.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('BookContentParser (Fase F)', () {
    test('rejeita obra sem arquivo físico sem inventar conteúdo', () async {
      final edition = WorkEdition(
        id: 'ed-1',
        workId: sampleWork.id,
        format: WorkFormat.epub,
        filePath: null,
      );

      expect(
        () => parser.parse(work: sampleWork, edition: edition),
        throwsA(isA<NovaException>()),
      );
    });

    test(
      'Extrai capítulos e parágrafos de arquivo TXT real com paginação calculada',
      () async {
        final txtFile = File('${tempDir.path}/livro_teste.txt');
        final textBuffer = StringBuffer();
        textBuffer.writeln('Linha 1 do livro.');
        textBuffer.writeln();
        textBuffer.writeln('Linha 2 com parágrafo.');
        await txtFile.writeAsString(textBuffer.toString(), encoding: utf8);

        final edition = WorkEdition(
          id: 'ed-txt',
          workId: sampleWork.id,
          format: WorkFormat.txt,
          filePath: txtFile.path,
          isLocal: true,
        );

        final content = await parser.parse(work: sampleWork, edition: edition);

        expect(content.workId, equals(sampleWork.id));
        expect(content.chapters.isNotEmpty, isTrue);
        expect(content.chapters.first.content, contains('Linha 1 do livro.'));
        expect(content.totalEstimatedPages, greaterThanOrEqualTo(1));
      },
    );

    test(
      'Extrai capítulos a partir de arquivo EPUB estruturado (container + opf + xhtml)',
      () async {
        final epubFile = File('${tempDir.path}/teste.epub');
        final archive = Archive();

        // 1. META-INF/container.xml
        const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
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
<package version="2.0" xmlns="http://www.idpf.org/2007/opf">
  <manifest>
    <item id="ch1" href="cap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="cap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
        archive.addFile(
          ArchiveFile('OEBPS/content.opf', opfXml.length, utf8.encode(opfXml)),
        );

        // 3. OEBPS/cap1.xhtml e OEBPS/cap2.xhtml
        const cap1Html = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html>
  <head><title>Primeiro Capítulo</title></head>
  <body>
    <h1>Início da Aventura</h1>
    <p>Era uma noite escura e tempestuosa no espaço sideral.</p>
  </body>
</html>''';
        archive.addFile(
          ArchiveFile(
            'OEBPS/cap1.xhtml',
            cap1Html.length,
            utf8.encode(cap1Html),
          ),
        );

        const cap2Html = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html>
  <head><title>Segundo Capítulo</title></head>
  <body>
    <h1>O Confronto Cósmico</h1>
    <p>A nave adentrou o campo de asteroides com velocidade máxima.</p>
  </body>
</html>''';
        archive.addFile(
          ArchiveFile(
            'OEBPS/cap2.xhtml',
            cap2Html.length,
            utf8.encode(cap2Html),
          ),
        );

        final zipData = ZipEncoder().encode(archive);
        await epubFile.writeAsBytes(zipData);

        final edition = WorkEdition(
          id: 'ed-epub',
          workId: sampleWork.id,
          format: WorkFormat.epub,
          filePath: epubFile.path,
          isLocal: true,
        );

        final content = await parser.parse(work: sampleWork, edition: edition);

        expect(content.chapters.length, equals(2));
        expect(content.chapters[0].title, equals('Início da Aventura'));
        expect(content.chapters[0].content, contains('Era uma noite escura'));
        expect(content.chapters[1].title, equals('O Confronto Cósmico'));
        expect(
          content.chapters[1].content,
          contains('A nave adentrou o campo'),
        );
      },
    );

    test('rejeita EPUB corrompido sem gerar fallback', () async {
      final corruptedFile = File('${tempDir.path}/corrupto.epub');
      final archive = Archive();
      archive.addFile(ArchiveFile('dummy.txt', 5, utf8.encode('teste')));
      await corruptedFile.writeAsBytes(ZipEncoder().encode(archive));

      final edition = WorkEdition(
        id: 'ed-corrupt',
        workId: sampleWork.id,
        format: WorkFormat.epub,
        filePath: corruptedFile.path,
        isLocal: true,
      );

      expect(
        () => parser.parse(work: sampleWork, edition: edition),
        throwsA(isA<NovaException>()),
      );
    });
  });
}

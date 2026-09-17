import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/import/work_extractor_factory.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/data/repositories/library_repository.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/usecases/import_work_usecase.dart';

void main() {
  late Directory tempStorageDir;
  late StorageManager storageManager;
  late AppDatabase appDatabase;
  late LibraryRepository libraryRepository;
  late ImportWorkUseCase importWorkUseCase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempStorageDir = await Directory.systemTemp.createTemp(
      'novareader_usecase_import_test_',
    );
    storageManager = await StorageManager.initialize(
      customRootPath: tempStorageDir.path,
    );

    appDatabase = AppDatabase();
    await appDatabase.initialize(isTestInMemory: true);

    libraryRepository = LibraryRepository(appDatabase);
    importWorkUseCase = ImportWorkUseCase(
      libraryRepository: libraryRepository,
      storageManager: storageManager,
      extractorFactory: WorkExtractorFactory(),
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempStorageDir.exists()) {
      await tempStorageDir.delete(recursive: true);
    }
  });

  group('Fase E — ImportWorkUseCase (Pipeline Completo de Importação)', () {
    test(
      'Importa arquivo EPUB, copia para /books, extrai capa para /covers e persiste no SQLite',
      () async {
        // 1. Cria EPUB de teste em arquivo externo
        final sourceFile = File('${tempStorageDir.path}/o_alienista.epub');
        final archive = Archive();

        const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
        archive.addFile(
          ArchiveFile(
            'META-INF/container.xml',
            containerXml.length,
            utf8.encode(containerXml),
          ),
        );

        const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>O Alienista</dc:title>
    <dc:creator>Machado de Assis</dc:creator>
    <dc:language>pt-BR</dc:language>
    <dc:description>Dr. Simão Bacamarte funda a Casa Verde em Itaguaí.</dc:description>
    <meta name="cover" content="capa"/>
  </metadata>
  <manifest>
    <item id="capa" href="capa.jpg" media-type="image/jpeg"/>
    <item id="cap1" href="cap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="cap1"/>
  </spine>
</package>''';
        archive.addFile(
          ArchiveFile('content.opf', opfXml.length, utf8.encode(opfXml)),
        );

        final fakeCover = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xAA,
          0xBB,
          0xCC,
        ]);
        archive.addFile(ArchiveFile('capa.jpg', fakeCover.length, fakeCover));

        final encoded = ZipEncoder().encode(archive);
        await sourceFile.writeAsBytes(encoded);

        // 2. Executa UseCase
        final importedWork = await importWorkUseCase(sourceFile.path);

        // 3. Validações da entidade
        expect(importedWork.title, equals('O Alienista'));
        expect(importedWork.author, equals('Machado de Assis'));
        expect(importedWork.type, equals(WorkType.book));
        expect(importedWork.coverPath, isNotNull);
        expect(File(importedWork.coverPath!).existsSync(), isTrue);
        expect(importedWork.editions.length, equals(1));

        final edition = importedWork.editions.first;
        expect(edition.format, equals(WorkFormat.epub));
        expect(edition.isLocal, isTrue);
        expect(edition.filePath, isNotNull);
        expect(File(edition.filePath!).existsSync(), isTrue);
        // Confere se o arquivo foi salvo dentro de /books/
        expect(edition.filePath, contains('/books/'));

        // 4. Valida persistência no SQLite
        final retrieved = await libraryRepository.getWorkById(importedWork.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.title, equals('O Alienista'));
        expect(retrieved.editions.first.checksum, isNotNull);
      },
    );

    test(
      'Importa arquivo CBZ, copia para /comics, extrai capa e persiste no SQLite',
      () async {
        final sourceFile = File('${tempStorageDir.path}/sandman_preludio.cbz');
        final archive = Archive();

        const comicInfoXml = '''<?xml version="1.0"?>
<ComicInfo>
  <Title>Sandman: Prelúdio</Title>
  <Series>Sandman</Series>
  <Number>0</Number>
  <Writer>Neil Gaiman</Writer>
  <Summary>As origens secretas de Morfeu antes de sua captura.</Summary>
  <PageCount>40</PageCount>
</ComicInfo>''';
        archive.addFile(
          ArchiveFile(
            'ComicInfo.xml',
            comicInfoXml.length,
            utf8.encode(comicInfoXml),
          ),
        );

        final coverImg = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x11,
          0x22,
        ]);
        archive.addFile(
          ArchiveFile('000_cover.png', coverImg.length, coverImg),
        );

        final encoded = ZipEncoder().encode(archive);
        await sourceFile.writeAsBytes(encoded);

        final importedWork = await importWorkUseCase(sourceFile.path);

        expect(importedWork.title, equals('Sandman: Prelúdio'));
        expect(importedWork.author, equals('Neil Gaiman'));
        expect(importedWork.type, equals(WorkType.comic));
        expect(importedWork.coverPath, isNotNull);
        expect(File(importedWork.coverPath!).existsSync(), isTrue);

        final edition = importedWork.editions.first;
        expect(edition.format, equals(WorkFormat.cbz));
        expect(edition.filePath, contains('/comics/'));
        expect(File(edition.filePath!).existsSync(), isTrue);
      },
    );

    test(
      'Lança NovaException ao tentar importar arquivo inexistente',
      () async {
        expect(
          () => importWorkUseCase(
            '/caminho/completamente/inexistente/livro.epub',
          ),
          throwsA(
            isA<NovaException>().having(
              (e) => e.kind,
              'kind',
              NovaErrorKind.invalidFile,
            ),
          ),
        );
      },
    );
  });
}

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/nova_errors.dart';
import '../../core/import/work_extractor_factory.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/storage_manager.dart';
import '../../core/providers/work_identity_system.dart';
import '../entities/work.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Importar Livro ou Quadrinho do Armazenamento Local
class ImportWorkUseCase {
  final ILibraryRepository libraryRepository;
  final StorageManager storageManager;
  final WorkExtractorFactory extractorFactory;
  final Uuid uuid;

  ImportWorkUseCase({
    required this.libraryRepository,
    required this.storageManager,
    WorkExtractorFactory? extractorFactory,
    Uuid? uuid,
  }) : extractorFactory = extractorFactory ?? WorkExtractorFactory(),
       uuid = uuid ?? const Uuid();

  Future<Work> call(String sourceFilePath) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      AppLogger.error(
        LogCategory.app,
        'Arquivo de origem para importação não existe: $sourceFilePath',
      );
      throw NovaException(
        kind: NovaErrorKind.invalidFile,
        message: 'Arquivo selecionado não existe: $sourceFilePath',
      );
    }

    AppLogger.info(
      LogCategory.app,
      'Iniciando pipeline de importação para: ${sourceFile.path}',
    );

    // 1. Extração de metadados baseada no formato
    final metadata = await extractorFactory.extract(sourceFile);

    // 2. Identificação e chaves canônicas
    final workId = 'work-local-${uuid.v4()}';
    final editionId = 'ed-local-${uuid.v4()}';
    final workKey = WorkIdentitySystem.generateWorkKey(
      title: metadata.title,
      author: metadata.author,
    );

    // 3. Leitura e cálculo de checksum SHA-256
    final sourceBytes = await sourceFile.readAsBytes();
    final checksum = sha256.convert(sourceBytes).toString();

    // 4. Cópia segura para partição física de destino (/books ou /comics)
    final targetDir = metadata.type == WorkType.book
        ? storageManager.booksDir
        : storageManager.comicsDir;
    final safeFileName = '$editionId.${metadata.format.extension}';
    final destFile = storageManager.getSafeFile(targetDir, safeFileName);
    await destFile.writeAsBytes(sourceBytes, flush: true);

    // 5. Extração e armazenamento de capa em /covers
    String? coverPath;
    if (metadata.coverBytes != null && metadata.coverBytes!.isNotEmpty) {
      final coverExt = metadata.coverImageExtension ?? 'jpg';
      final coverFileName = 'cover_$editionId.$coverExt';
      final coverFile = storageManager.getSafeFile(
        storageManager.coversDir,
        coverFileName,
      );
      await coverFile.writeAsBytes(metadata.coverBytes!, flush: true);
      coverPath = coverFile.path;
    }

    // 6. Construção da edição e do ContentAsset local validado
    final now = DateTime.now();
    final contentAsset = ContentAsset(
      id: 'asset-$editionId-${metadata.format.extension}',
      editionId: editionId,
      format: metadata.format,
      status: ContentAssetStatus.downloaded,
      localPath: destFile.path,
      mediaType: metadata.format == WorkFormat.epub
          ? 'application/epub+zip'
          : metadata.format == WorkFormat.cbz
          ? 'application/vnd.comicbook+zip'
          : metadata.format == WorkFormat.pdf
          ? 'application/pdf'
          : 'text/plain',
      fileSize: metadata.fileSize > 0 ? metadata.fileSize : sourceBytes.length,
      checksum: checksum,
      checksumAlgorithm: 'sha256',
      source: 'local-import',
      verifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final edition = WorkEdition(
      id: editionId,
      workId: workId,
      format: metadata.format,
      filePath: destFile.path,
      fileSize: metadata.fileSize > 0 ? metadata.fileSize : sourceBytes.length,
      pageCount: metadata.pageCount,
      checksum: checksum,
      isLocal: true,
      externalId: editionId,
      language: metadata.primaryLanguage,
      originalTitle: metadata.title,
      contentAssets: [contentAsset],
    );

    // 7. Construção da entidade Work
    final work = Work(
      id: workId,
      workKey: workKey,
      title: metadata.title,
      author: metadata.author,
      description: metadata.description,
      primaryLanguage: metadata.primaryLanguage,
      type: metadata.type,
      series: metadata.series,
      volume: metadata.volume,
      publisher: metadata.publisher,
      publishedDate: metadata.publishedDate,
      isbn: metadata.isbn,
      coverPath: coverPath,
      editions: [edition],
      createdAt: now,
      updatedAt: now,
    );

    // 8. Persistência na biblioteca local via SQLite
    await libraryRepository.saveWork(work);

    AppLogger.info(
      LogCategory.app,
      'Obra importada e indexada com sucesso: "${work.title}" (${work.type.label})',
    );

    return work;
  }
}

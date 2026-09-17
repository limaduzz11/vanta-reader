import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../logging/app_logger.dart';
import '../errors/nova_errors.dart';

/// Gerenciador Central de Armazenamento Local e Particionamento Físico
class StorageManager {
  final Directory _rootDirectory;

  StorageManager._(this._rootDirectory);

  /// Inicializa o gerenciador com base no caminho de documentos do sistema ou override
  static Future<StorageManager> initialize({String? customRootPath}) async {
    Directory root;
    if (customRootPath != null) {
      root = Directory(customRootPath);
    } else {
      final appDocs = await getApplicationDocumentsDirectory();
      final vantaRoot = Directory(p.join(appDocs.path, 'VANTAReader'));
      final legacyRoot = Directory(p.join(appDocs.path, 'NovaReader'));
      if (!await vantaRoot.exists() && await legacyRoot.exists()) {
        try {
          await legacyRoot.rename(vantaRoot.path);
        } catch (_) {
          // Fallback silencioso
        }
      }
      root = await vantaRoot.exists()
          ? vantaRoot
          : (await legacyRoot.exists() ? legacyRoot : vantaRoot);
    }

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final manager = StorageManager._(root);
    await manager._ensureDirectoryTree();
    AppLogger.info(
      LogCategory.app,
      'StorageManager inicializado em: ${root.path}',
    );
    return manager;
  }

  // Subdiretórios Estruturados Canônicos
  Directory get rootDir => _rootDirectory;
  Directory get booksDir => Directory(p.join(_rootDirectory.path, 'books'));
  Directory get comicsDir => Directory(p.join(_rootDirectory.path, 'comics'));
  Directory get coversDir => Directory(p.join(_rootDirectory.path, 'covers'));
  Directory get thumbnailsDir =>
      Directory(p.join(_rootDirectory.path, 'thumbnails'));
  Directory get databaseDir =>
      Directory(p.join(_rootDirectory.path, 'database'));
  Directory get cacheDir => Directory(p.join(_rootDirectory.path, 'cache'));
  Directory get readingCacheDir => Directory(p.join(cacheDir.path, 'reading'));

  /// Retorna caminho seguro para arquivo de livro
  String getBookPath(String fileName) => getSafeFile(booksDir, fileName).path;

  /// Retorna caminho seguro para arquivo de quadrinho
  String getComicPath(String fileName) => getSafeFile(comicsDir, fileName).path;

  /// Retorna caminho seguro para capa de obra
  String getCoverPath(String fileName) => getSafeFile(coversDir, fileName).path;

  /// Retorna caminho seguro para arquivo temporário de streaming de leitura
  String getReadingCachePath(String fileName) =>
      getSafeFile(readingCacheDir, fileName).path;

  Future<void> _ensureDirectoryTree() async {
    final dirs = [
      booksDir,
      comicsDir,
      coversDir,
      thumbnailsDir,
      databaseDir,
      cacheDir,
      readingCacheDir,
    ];
    for (final d in dirs) {
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
    }
  }

  /// Validação de segurança estrita contra Path Traversal
  void validateSafeFileName(String fileName) {
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.trim().isEmpty) {
      AppLogger.warn(
        LogCategory.app,
        'Tentativa de Path Traversal bloqueada: $fileName',
      );
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Nome de arquivo inválido ou inseguro: $fileName',
      );
    }
  }

  /// Resolve caminho seguro de arquivo dentro de um diretório alvo
  File getSafeFile(Directory targetDir, String fileName) {
    validateSafeFileName(fileName);
    final fullPath = p.normalize(p.join(targetDir.path, fileName));
    // Confere se o caminho resolvido realmente fica dentro do diretório pretendido
    if (!p.isWithin(targetDir.path, fullPath)) {
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Caminho viola as fronteiras de segurança: $fileName',
      );
    }
    return File(fullPath);
  }

  /// Validação e resolução segura de entradas de arquivos ZIP/CBZ/EPUB contra Zip Slip e Path Traversal
  static File resolveSafeZipEntry(Directory targetDir, String entryPath) {
    if (entryPath.trim().isEmpty) {
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Caminho de entrada zip não pode ser vazio.',
      );
    }
    // Rejeita explicitamente sequências perigosas de travessia e bytes nulos
    if (entryPath.contains('\x00') ||
        entryPath.contains('..') ||
        entryPath.startsWith('/') ||
        entryPath.startsWith('\\')) {
      AppLogger.warn(
        LogCategory.app,
        'Tentativa de Zip Slip detectada: $entryPath',
      );
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message:
            'Entrada de arquivo compactado insegura (Zip Slip): $entryPath',
      );
    }

    final targetPath = p.normalize(targetDir.path);
    final resolvedPath = p.normalize(p.join(targetPath, entryPath));

    if (!p.isWithin(targetPath, resolvedPath) &&
        !p.equals(targetPath, resolvedPath)) {
      AppLogger.warn(
        LogCategory.app,
        'Tentativa de Path Traversal bloqueada: $entryPath escapa de $targetPath',
      );
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Entrada zip escapa do diretório de destino: $entryPath',
      );
    }

    return File(resolvedPath);
  }

  /// Verifica se o nome da entrada em arquivo compactado é seguro
  static bool isSafeZipEntry(String entryPath) {
    if (entryPath.trim().isEmpty) return false;
    if (entryPath.contains('\x00') ||
        entryPath.contains('..') ||
        entryPath.startsWith('/') ||
        entryPath.startsWith('\\')) {
      return false;
    }
    return true;
  }

  /// Limpa apenas arquivos em /cache/, preservando 100% de books e comics
  Future<int> clearCache() async {
    int bytesFreed = 0;
    AppLogger.info(LogCategory.cache, 'Iniciando limpeza segura de cache...');
    if (await cacheDir.exists()) {
      final entities = cacheDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          try {
            bytesFreed += await entity.length();
            await entity.delete();
          } catch (e) {
            AppLogger.warn(
              LogCategory.cache,
              'Falha ao deletar arquivo de cache: ${entity.path}',
              e,
            );
          }
        }
      }
    }
    AppLogger.info(
      LogCategory.cache,
      'Limpeza concluída. Bytes liberados: $bytesFreed',
    );
    return bytesFreed;
  }

  /// Limpa apenas arquivos temporários de streaming de leitura (/cache/reading/)
  Future<int> clearReadingCache() async {
    int bytesFreed = 0;
    AppLogger.info(
      LogCategory.cache,
      'Iniciando limpeza de cache de leitura/streaming...',
    );
    if (await readingCacheDir.exists()) {
      final entities = readingCacheDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          try {
            bytesFreed += await entity.length();
            await entity.delete();
          } catch (e) {
            AppLogger.warn(
              LogCategory.cache,
              'Falha ao deletar arquivo de streaming: ${entity.path}',
              e,
            );
          }
        }
      }
    }
    AppLogger.info(
      LogCategory.cache,
      'Limpeza de leitura concluída. Bytes liberados: $bytesFreed',
    );
    return bytesFreed;
  }

  /// Calcula estatísticas completas de armazenamento
  Future<StorageUsage> calculateUsage() async {
    final results = await Future.wait([
      _getDirSize(booksDir),
      _getDirSize(comicsDir),
      _getDirSize(coversDir),
      _getDirSize(thumbnailsDir),
      _getDirSize(cacheDir),
      _getDirSize(databaseDir),
    ]);

    return StorageUsage(
      booksBytes: results[0],
      comicsBytes: results[1],
      coversBytes: results[2],
      thumbnailsBytes: results[3],
      cacheBytes: results[4],
      databaseBytes: results[5],
    );
  }

  Future<int> _getDirSize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.app,
        'Erro ao computar tamanho do diretório: ${dir.path}',
        e,
      );
    }
    return total;
  }
}

/// Sumário estruturado de consumo de armazenamento
class StorageUsage {
  final int booksBytes;
  final int comicsBytes;
  final int coversBytes;
  final int thumbnailsBytes;
  final int cacheBytes;
  final int databaseBytes;

  const StorageUsage({
    required this.booksBytes,
    required this.comicsBytes,
    required this.coversBytes,
    required this.thumbnailsBytes,
    required this.cacheBytes,
    required this.databaseBytes,
  });

  int get totalBytes =>
      booksBytes +
      comicsBytes +
      coversBytes +
      thumbnailsBytes +
      cacheBytes +
      databaseBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

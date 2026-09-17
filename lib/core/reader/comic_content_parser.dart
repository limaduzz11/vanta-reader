import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/work.dart';
import '../errors/nova_errors.dart';
import '../logging/app_logger.dart';
import '../storage/storage_manager.dart';
import 'comic_models.dart';
import 'comic_page_cache.dart';

/// Motor de parsing, streaming e carregamento de páginas de quadrinhos (CBZ/CBR/Imagens)
class ComicContentParser {
  final ComicPageCache cache;

  /// D-07: índice do ZIP aberto 1× por sessão. Antes cada página relia o
  /// arquivo inteiro e decodificava o container (lento/OOM em HQ grande).
  /// Guarda no máximo 1 archive (o arquivo corrente); troca de arquivo
  /// descarta o anterior. Não confundir com o LRU de páginas ([cache]).
  String? _cachedArchivePath;
  Archive? _cachedArchive;

  ComicContentParser({required this.cache});

  /// Descarta o índice em cache (troca de obra/sessão, teste, baixa memória).
  void evictArchiveCache() {
    _cachedArchivePath = null;
    _cachedArchive = null;
  }

  Future<Archive> _openArchive(String filePath) async {
    if (_cachedArchivePath == filePath && _cachedArchive != null) {
      return _cachedArchive!;
    }
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    _cachedArchivePath = filePath;
    _cachedArchive = archive;
    return archive;
  }

  static const _supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  };

  /// Parseia o arquivo do quadrinho e indexa as páginas na ordem canônica natural
  Future<ComicContent> parse({
    required Work work,
    required WorkEdition edition,
  }) async {
    final filePath = edition.filePath;

    if (filePath != null && await File(filePath).exists()) {
      final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();

      try {
        if (ext == 'cbz' || ext == 'zip') {
          return await _parseCbz(work, File(filePath));
        }
        if (ext == 'cbr') {
          throw NovaException(
            kind: NovaErrorKind.unsupportedFormat,
            message:
                'Leitura de CBR (RAR) ainda não é suportada. Converta para CBZ.',
          );
        }
        throw NovaException(
          kind: NovaErrorKind.unsupportedFormat,
          message: 'Formato "$ext" não é suportado pelo leitor de quadrinhos.',
        );
      } on NovaException {
        rethrow;
      } catch (e, st) {
        AppLogger.error(
          LogCategory.reader,
          'Falha ao parsear quadrinho real: $filePath',
          e,
          st,
        );
        throw NovaException(
          kind: NovaErrorKind.corruptedFile,
          message:
              'O arquivo do quadrinho está corrompido ou incompleto: $filePath',
          cause: e,
        );
      }
    }

    // Sem arquivo local: conteúdo NÃO está disponível.
    throw NovaException(
      kind: NovaErrorKind.invalidFile,
      message:
          'Este quadrinho ainda não possui conteúdo local. Baixe para ler offline.',
    );
  }

  /// Recupera os bytes de imagem de uma página específica com cache LRU
  ///
  /// REGRA: nunca substituir por imagem sintética ou de outa obra. Se a
  /// página não puder ser extraída do container, emite NovaException.
  Future<Uint8List> loadPageBytes({
    required Work work,
    required WorkEdition edition,
    required ComicPage page,
  }) async {
    // 1. Verifica cache em memória LRU
    final cached = cache.get(page.pageIndex);
    if (cached != null) {
      return cached;
    }

    final filePath = edition.filePath;
    if (filePath != null && await File(filePath).exists()) {
      if (!StorageManager.isSafeZipEntry(page.fileName)) {
        throw NovaException(
          kind: NovaErrorKind.securityError,
          message: 'Página com nome inseguro rejeitada: ${page.fileName}',
        );
      }
      try {
        final archive = await _openArchive(filePath);
        final fileEntry = archive.findFile(page.fileName);

        if (fileEntry != null && fileEntry.content.isNotEmpty) {
          final pageBytes = Uint8List.fromList(fileEntry.content as List<int>);
          cache.put(page.pageIndex, pageBytes);
          return pageBytes;
        }
      } catch (e) {
        AppLogger.warn(
          LogCategory.reader,
          'Erro ao extrair página ${page.pageIndex}: $e',
        );
        throw NovaException(
          kind: NovaErrorKind.corruptedFile,
          message:
              'Não foi possível extrair a página ${page.pageIndex + 1} do quadrinho.',
          cause: e,
        );
      }
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message:
            'A página ${page.pageIndex + 1} não foi encontrada no container da HQ.',
      );
    }

    throw NovaException(
      kind: NovaErrorKind.invalidFile,
      message: 'O arquivo do quadrinho não está disponível no dispositivo.',
    );
  }

  Future<ComicContent> _parseCbz(Work work, File file) async {
    final archive = await _openArchive(file.path);

    final validFiles = archive.where((f) {
      if (!f.isFile ||
          f.name.startsWith('__MACOSX') ||
          f.name.startsWith('.')) {
        return false;
      }
      if (!StorageManager.isSafeZipEntry(f.name)) {
        return false;
      }
      final ext = p.extension(f.name).replaceAll('.', '').toLowerCase();
      return _supportedImageExtensions.contains(ext);
    }).toList();

    // Ordenação alfanumérica natural (page1, page2, page10...)
    validFiles.sort((a, b) => naturalCompare(a.name, b.name));

    if (validFiles.isEmpty) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'O CBZ não contém imagens suportadas (jpg/png/webp/gif/bmp).',
      );
    }

    final pages = <ComicPage>[];
    for (int i = 0; i < validFiles.length; i++) {
      final f = validFiles[i];
      pages.add(ComicPage(pageIndex: i, fileName: f.name, fileSize: f.size));
    }

    return ComicContent(workId: work.id, title: work.title, pages: pages);
  }

  /// Comparador alfanumérico natural (Natural Sort Order)
  static int naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+|\D+)');
    final aMatches = regex.allMatches(a).map((m) => m.group(0)!).toList();
    final bMatches = regex.allMatches(b).map((m) => m.group(0)!).toList();

    for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
      final aPart = aMatches[i];
      final bPart = bMatches[i];

      final aNum = int.tryParse(aPart);
      final bNum = int.tryParse(bPart);

      if (aNum != null && bNum != null) {
        final numCompare = aNum.compareTo(bNum);
        if (numCompare != 0) return numCompare;
      } else {
        final strCompare = aPart.compareTo(bPart);
        if (strCompare != 0) return strCompare;
      }
    }
    return aMatches.length.compareTo(bMatches.length);
  }

  /// Gera um Bitmap 24bpp válido com grid de quadrinhos minimalista
  static Uint8List createSampleComicPageBmp(
    int pageNumber, {
    String? title,
    int width = 360,
    int height = 540,
  }) {
    final rowSize = ((width * 3 + 3) ~/ 4) * 4;
    final pixelArraySize = rowSize * height;
    final fileSize = 54 + pixelArraySize;

    final bytes = Uint8List(fileSize);
    final data = ByteData.view(bytes.buffer);

    // Bitmap File Header (14 bytes)
    data.setUint8(0, 0x42); // 'B'
    data.setUint8(1, 0x4D); // 'M'
    data.setUint32(2, fileSize, Endian.little);
    data.setUint32(10, 54, Endian.little); // offset

    // DIB Header (40 bytes)
    data.setUint32(14, 40, Endian.little);
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, height, Endian.little);
    data.setUint16(26, 1, Endian.little);
    data.setUint16(28, 24, Endian.little);
    data.setUint32(30, 0, Endian.little);
    data.setUint32(34, pixelArraySize, Endian.little);
    data.setInt32(38, 2835, Endian.little);
    data.setInt32(42, 2835, Endian.little);

    // Painéis de quadrinho estilizados Monochromatic Minimalism
    for (int y = 0; y < height; y++) {
      final rowOffset = 54 + y * rowSize;
      for (int x = 0; x < width; x++) {
        final pixelOffset = rowOffset + x * 3;

        final isBorder =
            (x < 10 || x > width - 10 || y < 10 || y > height - 10);
        final isMiddleHoriz = (y > height ~/ 2 - 4 && y < height ~/ 2 + 4);
        final isMiddleVert = (x > width ~/ 2 - 4 && x < width ~/ 2 + 4);

        if (isBorder || isMiddleHoriz || isMiddleVert) {
          bytes[pixelOffset] = 0x38;
          bytes[pixelOffset + 1] = 0x38;
          bytes[pixelOffset + 2] = 0x38;
        } else {
          // Variação suave de tom por página
          final tone = (0x12 + (pageNumber * 2) % 15).clamp(0x10, 0x22);
          bytes[pixelOffset] = tone;
          bytes[pixelOffset + 1] = tone;
          bytes[pixelOffset + 2] = tone;
        }
      }
    }

    return bytes;
  }
}

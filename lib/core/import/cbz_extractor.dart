import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../logging/app_logger.dart';
import '../storage/storage_manager.dart';
import '../../domain/entities/work.dart';
import 'file_metadata.dart';

/// Extrator especializado de metadados e capas de Quadrinhos / Mangás (CBZ)
class CbzExtractor {
  const CbzExtractor();

  static const _supportedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };

  Future<ExtractedMetadata> extract(File file) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final fallbackTitle = p.basenameWithoutExtension(file.path);

    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Identifica imagens válidas (filtrando arquivos ocultos, metadados de SO e Zip Slip)
      final imageEntries = archive.files.where((f) {
        if (!f.isFile) return false;
        final name = f.name;
        if (!StorageManager.isSafeZipEntry(name)) return false;
        if (name.startsWith('__MACOSX') || p.basename(name).startsWith('.')) {
          return false;
        }
        final ext = p.extension(name).toLowerCase();
        return _supportedImageExtensions.contains(ext);
      }).toList();

      // Ordena alfabeticamente para garantir a capa correta (página 000 ou 001)
      imageEntries.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      // 2. Extrai primeira imagem como capa
      Uint8List? coverBytes;
      String coverExt = 'jpg';
      if (imageEntries.isNotEmpty) {
        final firstImage = imageEntries.first;
        if (firstImage.content.isNotEmpty) {
          coverBytes = Uint8List.fromList(firstImage.content as List<int>);
          final ext = p
              .extension(firstImage.name)
              .replaceAll('.', '')
              .toLowerCase();
          if (ext.isNotEmpty) {
            coverExt = ext == 'jpeg' ? 'jpg' : ext;
          }
        }
      }

      // 3. Procura por ComicInfo.xml
      final comicInfoFile = archive.firstWhere(
        (f) => p.basename(f.name).toLowerCase() == 'comicinfo.xml',
        orElse: () => ArchiveFile('', 0, []),
      );

      String title = fallbackTitle;
      String author = 'Desconhecido';
      String? series;
      String? volume;
      String? description;
      String language = 'pt-BR';
      int pageCount = imageEntries.length;

      if (comicInfoFile.content.isNotEmpty) {
        try {
          final xmlContent = utf8.decode(
            comicInfoFile.content as List<int>,
            allowMalformed: true,
          );
          final doc = XmlDocument.parse(xmlContent);

          final xmlTitle = _getElementText(doc, 'Title');
          if (xmlTitle != null && xmlTitle.isNotEmpty) title = xmlTitle;

          final xmlSeries = _getElementText(doc, 'Series');
          if (xmlSeries != null && xmlSeries.isNotEmpty) series = xmlSeries;

          final xmlNumber = _getElementText(doc, 'Number');
          if (xmlNumber != null && xmlNumber.isNotEmpty) volume = xmlNumber;

          final xmlWriter = _getElementText(doc, 'Writer');
          final xmlPenciller = _getElementText(doc, 'Penciller');
          if (xmlWriter != null && xmlWriter.isNotEmpty) {
            author = xmlWriter;
          } else if (xmlPenciller != null && xmlPenciller.isNotEmpty) {
            author = xmlPenciller;
          }

          final xmlSummary = _getElementText(doc, 'Summary');
          if (xmlSummary != null && xmlSummary.isNotEmpty) {
            description = xmlSummary;
          }

          final xmlLang = _getElementText(doc, 'LanguageISO');
          if (xmlLang != null && xmlLang.isNotEmpty) {
            language = xmlLang.toLowerCase().startsWith('en') ? 'en' : 'pt-BR';
          }

          final xmlPages = _getElementText(doc, 'PageCount');
          if (xmlPages != null) {
            final parsed = int.tryParse(xmlPages);
            if (parsed != null && parsed > 0) pageCount = parsed;
          }
        } catch (e) {
          AppLogger.warn(LogCategory.app, 'Aviso ao parsear ComicInfo.xml: $e');
        }
      }

      return ExtractedMetadata(
        title: title.trim(),
        author: author.trim(),
        description: description?.trim(),
        primaryLanguage: language,
        type: WorkType.comic,
        format: WorkFormat.cbz,
        series: series?.trim(),
        volume: volume?.trim(),
        pageCount: pageCount > 0 ? pageCount : 1,
        fileSize: fileSize,
        coverBytes: coverBytes,
        coverImageExtension: coverExt,
      );
    } catch (e, st) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao extrair metadados do CBZ: ${file.path}',
        e,
        st,
      );
      return ExtractedMetadata(
        title: fallbackTitle,
        author: 'Desconhecido',
        type: WorkType.comic,
        format: WorkFormat.cbz,
        fileSize: fileSize,
        pageCount: 1,
      );
    }
  }

  String? _getElementText(XmlDocument doc, String name) {
    final elements = doc.findAllElements(name);
    if (elements.isNotEmpty && elements.first.innerText.trim().isNotEmpty) {
      return elements.first.innerText.trim();
    }
    return null;
  }
}

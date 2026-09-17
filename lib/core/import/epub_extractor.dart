import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../logging/app_logger.dart';
import '../../domain/entities/work.dart';
import 'file_metadata.dart';

/// Extrator especializado de metadados e capas de arquivos EPUB
class EpubExtractor {
  const EpubExtractor();

  Future<ExtractedMetadata> extract(File file) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final fallbackTitle = p.basenameWithoutExtension(file.path);

    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Localiza META-INF/container.xml
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) {
        AppLogger.warn(
          LogCategory.app,
          'EPUB sem META-INF/container.xml: ${file.path}',
        );
        return ExtractedMetadata(
          title: fallbackTitle,
          author: 'Desconhecido',
          type: WorkType.book,
          format: WorkFormat.epub,
          fileSize: fileSize,
        );
      }

      final containerXml = utf8.decode(
        containerFile.content as List<int>,
        allowMalformed: true,
      );
      final containerDoc = XmlDocument.parse(containerXml);
      final rootfileElement = containerDoc
          .findAllElements('rootfile')
          .firstOrNull;
      final opfPath = rootfileElement?.getAttribute('full-path');

      if (opfPath == null) {
        return ExtractedMetadata(
          title: fallbackTitle,
          author: 'Desconhecido',
          type: WorkType.book,
          format: WorkFormat.epub,
          fileSize: fileSize,
        );
      }

      // 2. Lê o arquivo OPF
      final opfFile = archive.findFile(opfPath);
      if (opfFile == null) {
        return ExtractedMetadata(
          title: fallbackTitle,
          author: 'Desconhecido',
          type: WorkType.book,
          format: WorkFormat.epub,
          fileSize: fileSize,
        );
      }

      final opfXml = utf8.decode(
        opfFile.content as List<int>,
        allowMalformed: true,
      );
      final opfDoc = XmlDocument.parse(opfXml);

      // Metadados básicos
      final title =
          _findFirstText(opfDoc, ['title', 'dc:title']) ?? fallbackTitle;
      final author =
          _findFirstText(opfDoc, ['creator', 'dc:creator']) ?? 'Desconhecido';
      final description = _findFirstText(opfDoc, [
        'description',
        'dc:description',
      ]);
      final language =
          _findFirstText(opfDoc, ['language', 'dc:language']) ?? 'pt-BR';
      final publisher = _findFirstText(opfDoc, ['publisher', 'dc:publisher']);
      final publishedDate = _findFirstText(opfDoc, ['date', 'dc:date']);
      final isbn = _findFirstText(opfDoc, ['identifier', 'dc:identifier']);

      // Contagem de capítulos/páginas pelo spine
      final spineItems = opfDoc.findAllElements('itemref').length;
      final pageCount = spineItems > 0 ? spineItems : 1;

      // 3. Extração da capa
      Uint8List? coverBytes;
      String coverExt = 'jpg';

      final opfDir = p.dirname(opfPath);
      final coverHref = _locateCoverHref(opfDoc);

      if (coverHref != null) {
        final normalizedCoverPath = opfDir == '.'
            ? coverHref
            : p.normalize(p.join(opfDir, coverHref));
        final coverArchiveFile =
            archive.findFile(normalizedCoverPath) ??
            archive.firstWhere(
              (f) =>
                  p.basename(f.name).toLowerCase() ==
                  p.basename(coverHref).toLowerCase(),
              orElse: () => ArchiveFile('', 0, []),
            );

        if (coverArchiveFile.content.isNotEmpty) {
          coverBytes = Uint8List.fromList(
            coverArchiveFile.content as List<int>,
          );
          final ext = p
              .extension(coverArchiveFile.name)
              .replaceAll('.', '')
              .toLowerCase();
          if (ext.isNotEmpty) {
            coverExt = ext == 'jpeg' ? 'jpg' : ext;
          }
        }
      }

      return ExtractedMetadata(
        title: title.trim(),
        author: author.trim(),
        description: description?.trim(),
        primaryLanguage: language.trim().startsWith('en') ? 'en' : 'pt-BR',
        type: WorkType.book,
        format: WorkFormat.epub,
        publisher: publisher?.trim(),
        publishedDate: publishedDate?.trim(),
        isbn: isbn?.trim(),
        pageCount: pageCount,
        fileSize: fileSize,
        coverBytes: coverBytes,
        coverImageExtension: coverExt,
      );
    } catch (e, st) {
      AppLogger.error(
        LogCategory.app,
        'Falha ao extrair metadados do EPUB: ${file.path}',
        e,
        st,
      );
      return ExtractedMetadata(
        title: fallbackTitle,
        author: 'Desconhecido',
        type: WorkType.book,
        format: WorkFormat.epub,
        fileSize: fileSize,
      );
    }
  }

  String? _findFirstText(XmlDocument doc, List<String> tagNames) {
    for (final tag in tagNames) {
      final elements = doc.findAllElements(tag);
      if (elements.isNotEmpty && elements.first.innerText.trim().isNotEmpty) {
        return elements.first.innerText.trim();
      }
    }
    return null;
  }

  String? _locateCoverHref(XmlDocument doc) {
    // 1. Procura item com property="cover-image" (EPUB 3)
    for (final item in doc.findAllElements('item')) {
      final properties = item.getAttribute('properties') ?? '';
      if (properties.contains('cover-image')) {
        return item.getAttribute('href');
      }
    }

    // 2. Procura meta cover (EPUB 2)
    for (final meta in doc.findAllElements('meta')) {
      if (meta.getAttribute('name') == 'cover') {
        final coverId = meta.getAttribute('content');
        if (coverId != null) {
          final item = doc
              .findAllElements('item')
              .firstWhereOrNull((el) => el.getAttribute('id') == coverId);
          if (item != null) {
            return item.getAttribute('href');
          }
        }
      }
    }

    // 3. Heurística: item cujo id contenha "cover" e seja imagem
    for (final item in doc.findAllElements('item')) {
      final id = (item.getAttribute('id') ?? '').toLowerCase();
      final mediaType = (item.getAttribute('media-type') ?? '').toLowerCase();
      if (id.contains('cover') && mediaType.startsWith('image/')) {
        return item.getAttribute('href');
      }
    }

    return null;
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

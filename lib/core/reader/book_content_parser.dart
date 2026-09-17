import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../domain/entities/work.dart';
import '../errors/nova_errors.dart';
import '../logging/app_logger.dart';
import 'book_models.dart';

/// Motor central de parsing e carregamento de conteúdo textual para leitura
class BookContentParser {
  const BookContentParser();

  Future<BookContent> parse({
    required Work work,
    required WorkEdition edition,
  }) async {
    final filePath = edition.filePath;

    // Se houver arquivo físico existente no disco, faz parse real
    if (filePath != null && await File(filePath).exists()) {
      final file = File(filePath);
      final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();

      try {
        switch (ext) {
          case 'epub':
            return await _parseEpub(work, file, edition);
          case 'txt':
            return await _parseTxt(work, file);
          case 'pdf':
            return await _parsePdf(work, file);
          default:
            throw NovaException(
              kind: NovaErrorKind.unsupportedFormat,
              message: 'Formato "$ext" não é suportado pelo leitor de livros.',
            );
        }
      } on NovaException {
        rethrow;
      } catch (e, st) {
        AppLogger.error(
          LogCategory.reader,
          'Falha ao parsear livro real: $filePath',
          e,
          st,
        );
        throw NovaException(
          kind: NovaErrorKind.corruptedFile,
          message:
              'O arquivo do livro está corrompido ou incompleto: $filePath',
          cause: e,
        );
      }
    }

    // Sem arquivo local: conteúdo NÃO está disponível.
    throw NovaException(
      kind: NovaErrorKind.invalidFile,
      message:
          'Este livro ainda não possui conteúdo local. Baixe para ler offline.',
    );
  }

  /// Parser de arquivo EPUB baseado nos capítulos declarados no manifesto OPF
  Future<BookContent> _parseEpub(
    Work work,
    File file, [
    WorkEdition? edition,
  ]) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Localiza container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'EPUB inválido: arquivo container.xml ausente.',
      );
    }

    final containerXml = utf8.decode(
      containerFile.content as List<int>,
      allowMalformed: true,
    );
    final containerDoc = XmlDocument.parse(containerXml);
    final rootfile = containerDoc.findAllElements('rootfile').firstOrNull;
    final opfPath = rootfile?.getAttribute('full-path') ?? 'content.opf';

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'EPUB inválido: arquivo OPF $opfPath ausente.',
      );
    }

    final opfXml = utf8.decode(
      opfFile.content as List<int>,
      allowMalformed: true,
    );
    final opfDoc = XmlDocument.parse(opfXml);
    final opfDir = p.dirname(opfPath);

    // 2. Mapeia itens do manifesto: id -> href
    final manifestMap = <String, String>{};
    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifestMap[id] = href;
      }
    }

    // 3. Itera capítulos ordenados pelo <spine>
    final chapters = <BookChapter>[];
    int order = 0;
    int totalEstimatedPages = 0;

    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref == null) continue;

      final href = manifestMap[idref];
      if (href == null) continue;

      final chapterPath = opfDir == '.'
          ? href
          : p.normalize(p.join(opfDir, href));
      final chapterFile =
          archive.findFile(chapterPath) ??
          archive.firstWhere(
            (f) =>
                p.basename(f.name).toLowerCase() ==
                p.basename(href).toLowerCase(),
            orElse: () => ArchiveFile('', 0, []),
          );

      if (chapterFile.content.isNotEmpty) {
        final rawHtml = utf8.decode(
          chapterFile.content as List<int>,
          allowMalformed: true,
        );
        final cleanText = _cleanHtmlText(rawHtml);

        if (cleanText.trim().isNotEmpty) {
          final chapterTitle =
              _extractChapterTitle(rawHtml) ?? 'Capítulo ${order + 1}';
          final pages = (cleanText.length / 1800).ceil();
          final estPages = pages > 0 ? pages : 1;
          totalEstimatedPages += estPages;

          chapters.add(
            BookChapter(
              id: 'ch-$order-$idref',
              title: chapterTitle,
              content: cleanText,
              orderIndex: order,
              estimatedPages: estPages,
            ),
          );
          order++;
        }
      }
    }

    if (chapters.isEmpty) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'EPUB sem capítulos de texto válidos em <spine>.',
      );
    }

    int totalEstimated = totalEstimatedPages;
    List<BookChapter> effectiveChapters = chapters;

    return BookContent(
      workId: work.id,
      title: work.title,
      chapters: effectiveChapters,
      totalEstimatedPages: totalEstimated > 0 ? totalEstimated : 1,
    );
  }

  /// Parser para arquivos de texto simples (TXT)
  Future<BookContent> _parseTxt(Work work, File file) async {
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);

    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final chapters = <BookChapter>[];

    // Se o texto for longo, divide em blocos de leitura proporcionais
    const chunkSize = 5000;
    int order = 0;
    int totalEstimatedPages = 0;

    if (text.length <= chunkSize) {
      final pages = (text.length / 1800).ceil();
      chapters.add(
        BookChapter(
          id: 'ch-0',
          title: 'Texto Completo',
          content: text.trim(),
          orderIndex: 0,
          estimatedPages: pages > 0 ? pages : 1,
        ),
      );
      totalEstimatedPages = pages > 0 ? pages : 1;
    } else {
      var currentContent = StringBuffer();
      int currentLength = 0;

      for (final p in paragraphs) {
        currentContent.writeln(p);
        currentContent.writeln();
        currentLength += p.length;

        if (currentLength >= chunkSize) {
          final chunkText = currentContent.toString().trim();
          final pages = (chunkText.length / 1800).ceil();
          final estPages = pages > 0 ? pages : 1;
          totalEstimatedPages += estPages;

          chapters.add(
            BookChapter(
              id: 'ch-$order',
              title: 'Seção ${order + 1}',
              content: chunkText,
              orderIndex: order,
              estimatedPages: estPages,
            ),
          );
          order++;
          currentContent = StringBuffer();
          currentLength = 0;
        }
      }

      if (currentContent.isNotEmpty) {
        final chunkText = currentContent.toString().trim();
        final pages = (chunkText.length / 1800).ceil();
        final estPages = pages > 0 ? pages : 1;
        totalEstimatedPages += estPages;

        chapters.add(
          BookChapter(
            id: 'ch-$order',
            title: 'Seção ${order + 1}',
            content: chunkText,
            orderIndex: order,
            estimatedPages: estPages,
          ),
        );
      }
    }

    return BookContent(
      workId: work.id,
      title: work.title,
      chapters: chapters,
      totalEstimatedPages: totalEstimatedPages > 0 ? totalEstimatedPages : 1,
    );
  }

  /// Parser simplificado para documentos PDF locais
  ///
  /// REGRA: nunca inventar conteúdo. Sem leitor PDF real implementado,
  /// o parser NÃO produz texto substituto — emite erro tipado.
  Future<BookContent> _parsePdf(Work work, File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 8 || !bytes.sublist(0, 5).toString().contains('%PDF')) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'Arquivo PDF inválido (assinatura %PDF ausente).',
      );
    }
    throw NovaException(
      kind: NovaErrorKind.unsupportedFormat,
      message:
          'Leitura de PDF ainda não é suportada pelo VANTA Reader. Importe EPUB ou TXT.',
    );
  }

  /// Conteúdo de alta fidelidade para obras de catálogo ou simulação offline
  ///
  /// REMOVIDO por violar a regra absoluta (nunca inventar páginas/palavras).
  /// Mantido como documentação do que NÃO deve voltar ao runtime.
  // Never re-add: _generateFallbackContent generated chapters/pages/mock prose.
  /// Limpa tags HTML mantendo estrutura de parágrafos legível
  String _cleanHtmlText(String html) {
    var text = html;

    // Remove scripts e estilos
    text = text.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      '',
    );

    // Converte tags de quebra e parágrafos em saltos de linha
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(
      RegExp(r'</h1>|</h2>|</h3>', caseSensitive: false),
      '\n\n',
    );
    text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

    // Remove todas as demais tags HTML
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decodifica entidades HTML comuns
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');

    // Remove espaços e linhas vazias excessivas
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  String? _extractChapterTitle(String html) {
    // Procura por <h1> ou <h2> ou <title>
    final h1Match = RegExp(
      r'<h1[^>]*>(.*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1Match != null && h1Match.group(1) != null) {
      final clean = _cleanHtmlText(h1Match.group(1)!);
      if (clean.isNotEmpty) return clean;
    }

    final h2Match = RegExp(
      r'<h2[^>]*>(.*?)</h2>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h2Match != null && h2Match.group(1) != null) {
      final clean = _cleanHtmlText(h2Match.group(1)!);
      if (clean.isNotEmpty) return clean;
    }

    final titleMatch = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null && titleMatch.group(1) != null) {
      final clean = _cleanHtmlText(titleMatch.group(1)!);
      if (clean.isNotEmpty) return clean;
    }

    return null;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/entities/work.dart';
import 'file_metadata.dart';

/// Extrator de metadados para arquivos de texto simples (TXT)
class TxtExtractor {
  const TxtExtractor();

  Future<ExtractedMetadata> extract(File file) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final title = p.basenameWithoutExtension(file.path);

    int pageCount = 1;
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      // Estimativa canônica: 1 página a cada 2.000 caracteres ou 35 linhas
      final lines = LineSplitter.split(text).length;
      pageCount = (lines / 35).ceil();
      if (pageCount < 1) pageCount = 1;
    } catch (_) {
      pageCount = 1;
    }

    return ExtractedMetadata(
      title: title.trim(),
      author: 'Desconhecido',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.txt,
      pageCount: pageCount,
      fileSize: fileSize,
    );
  }
}

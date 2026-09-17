import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/entities/work.dart';
import 'file_metadata.dart';

/// Extrator de metadados para documentos PDF
class PdfExtractor {
  const PdfExtractor();

  Future<ExtractedMetadata> extract(File file) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final title = p.basenameWithoutExtension(file.path);

    // Contagem simplificada de páginas em PDF buscando por '/Type /Page' ou '/Count'
    int pageCount = 1;
    try {
      final content = String.fromCharCodes(bytes);
      final matches = RegExp(r'/Type\s*/Page\b').allMatches(content);
      if (matches.isNotEmpty) {
        pageCount = matches.length;
      }
    } catch (_) {
      pageCount = 1;
    }

    return ExtractedMetadata(
      title: title.trim(),
      author: 'Desconhecido',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.pdf,
      pageCount: pageCount > 0 ? pageCount : 1,
      fileSize: fileSize,
    );
  }
}

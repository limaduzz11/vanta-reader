import 'dart:io';
import 'package:path/path.dart' as p;
import '../errors/nova_errors.dart';
import 'cbz_extractor.dart';
import 'epub_extractor.dart';
import 'file_metadata.dart';
import 'pdf_extractor.dart';
import 'txt_extractor.dart';

/// Fábrica e despacho de extratores baseados no tipo/extensão do arquivo
class WorkExtractorFactory {
  final EpubExtractor _epubExtractor;
  final CbzExtractor _cbzExtractor;
  final PdfExtractor _pdfExtractor;
  final TxtExtractor _txtExtractor;

  WorkExtractorFactory({
    EpubExtractor? epubExtractor,
    CbzExtractor? cbzExtractor,
    PdfExtractor? pdfExtractor,
    TxtExtractor? txtExtractor,
  }) : _epubExtractor = epubExtractor ?? const EpubExtractor(),
       _cbzExtractor = cbzExtractor ?? const CbzExtractor(),
       _pdfExtractor = pdfExtractor ?? const PdfExtractor(),
       _txtExtractor = txtExtractor ?? const TxtExtractor();

  Future<ExtractedMetadata> extract(File file) async {
    final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();

    switch (ext) {
      case 'epub':
        return _epubExtractor.extract(file);
      case 'cbz':
      case 'cbr':
      case 'zip':
        return _cbzExtractor.extract(file);
      case 'pdf':
        return _pdfExtractor.extract(file);
      case 'txt':
        return _txtExtractor.extract(file);
      default:
        throw NovaException(
          kind: NovaErrorKind.unsupportedFormat,
          message: 'Extensão de arquivo não suportada para importação: .$ext',
        );
    }
  }
}

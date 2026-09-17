import 'package:file_picker/file_picker.dart';
import '../logging/app_logger.dart';

/// Interface para desacoplar a seleção de arquivos locais
abstract class IFilePickerService {
  Future<String?> pickDocumentFile();
}

/// Implementação padrão utilizando file_picker
class FilePickerService implements IFilePickerService {
  const FilePickerService();

  static const List<String> supportedExtensions = [
    'epub',
    'pdf',
    'txt',
    'cbz',
    'cbr',
    'zip',
  ];

  @override
  Future<String?> pickDocumentFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
      );

      if (result != null && result.path != null) {
        final path = result.path!;
        AppLogger.info(
          LogCategory.app,
          'Arquivo selecionado pelo usuário: $path',
        );
        return path;
      }
      return null;
    } catch (e, st) {
      AppLogger.error(
        LogCategory.app,
        'Erro ao abrir seletor de arquivos',
        e,
        st,
      );
      return null;
    }
  }
}

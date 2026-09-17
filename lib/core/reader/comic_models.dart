import 'package:equatable/equatable.dart';

/// Modo de navegação do leitor de quadrinhos
enum ComicReadingMode {
  page('page', 'Página por Página'),
  webtoon('webtoon', 'Webtoon (Rolagem Contínua)');

  final String code;
  final String label;
  const ComicReadingMode(this.code, this.label);

  static ComicReadingMode fromString(String val) {
    return ComicReadingMode.values.firstWhere(
      (e) => e.code == val.toLowerCase(),
      orElse: () => ComicReadingMode.page,
    );
  }
}

/// Modo de enquadramento da imagem
enum ComicFitMode {
  fitScreen('fit_screen', 'Ajustar à Tela'),
  fitWidth('fit_width', 'Ajustar à Largura'),
  fitHeight('fit_height', 'Ajustar à Altura');

  final String code;
  final String label;
  const ComicFitMode(this.code, this.label);

  static ComicFitMode fromString(String val) {
    return ComicFitMode.values.firstWhere(
      (e) => e.code == val.toLowerCase(),
      orElse: () => ComicFitMode.fitWidth,
    );
  }
}

/// Configurações do Leitor de Quadrinhos
class ComicReaderSettings extends Equatable {
  final ComicReadingMode readingMode;
  final ComicFitMode fitMode;
  final bool isDoublePageInLandscape;
  final bool readRightToLeft; // Modo Mangá (oriental)

  const ComicReaderSettings({
    this.readingMode = ComicReadingMode.page,
    this.fitMode = ComicFitMode.fitWidth,
    this.isDoublePageInLandscape = false,
    this.readRightToLeft = false,
  });

  ComicReaderSettings copyWith({
    ComicReadingMode? readingMode,
    ComicFitMode? fitMode,
    bool? isDoublePageInLandscape,
    bool? readRightToLeft,
  }) {
    return ComicReaderSettings(
      readingMode: readingMode ?? this.readingMode,
      fitMode: fitMode ?? this.fitMode,
      isDoublePageInLandscape:
          isDoublePageInLandscape ?? this.isDoublePageInLandscape,
      readRightToLeft: readRightToLeft ?? this.readRightToLeft,
    );
  }

  @override
  List<Object?> get props => [
    readingMode,
    fitMode,
    isDoublePageInLandscape,
    readRightToLeft,
  ];
}

/// Metadados de uma página de quadrinho
class ComicPage extends Equatable {
  final int pageIndex; // 0-indexed
  final String fileName;
  final int fileSize;

  const ComicPage({
    required this.pageIndex,
    required this.fileName,
    this.fileSize = 0,
  });

  int get pageNumber => pageIndex + 1;

  @override
  List<Object?> get props => [pageIndex, fileName, fileSize];
}

/// Conteúdo completo de um quadrinho carregado
class ComicContent extends Equatable {
  final String workId;
  final String title;
  final List<ComicPage> pages;

  const ComicContent({
    required this.workId,
    required this.title,
    required this.pages,
  });

  int get totalPages => pages.length;

  ComicPage? getPage(int index) {
    if (index >= 0 && index < pages.length) {
      return pages[index];
    }
    return null;
  }

  @override
  List<Object?> get props => [workId, title, pages];
}

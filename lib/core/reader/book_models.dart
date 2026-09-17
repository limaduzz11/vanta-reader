import 'package:equatable/equatable.dart';

/// Configurações tipográficas e de renderização do leitor de livros
class TypographySettings extends Equatable {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final String themeMode; // 'kindle', 'oled_dark', 'sepia', 'night'

  const TypographySettings({
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.fontFamily = 'sans-serif',
    this.themeMode = 'oled_dark',
  });

  TypographySettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    String? themeMode,
  }) {
    return TypographySettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [fontSize, lineHeight, fontFamily, themeMode];
}

/// Um capítulo ou seção navegável de um livro digital
class BookChapter extends Equatable {
  final String id;
  final String title;
  final String content;
  final int orderIndex;
  final int estimatedPages;

  const BookChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.orderIndex,
    required this.estimatedPages,
  });

  @override
  List<Object?> get props => [id, title, orderIndex, estimatedPages];
}

/// Conteúdo completo de um livro digital carregado na memória do leitor
class BookContent extends Equatable {
  final String workId;
  final String title;
  final List<BookChapter> chapters;
  final int totalEstimatedPages;

  const BookContent({
    required this.workId,
    required this.title,
    required this.chapters,
    required this.totalEstimatedPages,
  });

  BookChapter? getChapter(int index) {
    if (index >= 0 && index < chapters.length) {
      return chapters[index];
    }
    return null;
  }

  @override
  List<Object?> get props => [workId, title, chapters, totalEstimatedPages];
}

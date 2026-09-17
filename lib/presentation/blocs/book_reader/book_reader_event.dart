import 'package:equatable/equatable.dart';
import '../../../domain/entities/work.dart';

/// Eventos do Motor de Leitura de Livros (Book Reader Engine)
abstract class BookReaderEvent extends Equatable {
  const BookReaderEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a obra e inicializa a sessão de leitura recuperando o progresso persistido
class OpenBookEvent extends BookReaderEvent {
  final Work work;
  final WorkEdition edition;

  const OpenBookEvent({required this.work, required this.edition});

  @override
  List<Object?> get props => [work, edition];
}

/// Avança para a próxima página
class NextPageEvent extends BookReaderEvent {
  const NextPageEvent();
}

/// Retorna para a página anterior
class PreviousPageEvent extends BookReaderEvent {
  const PreviousPageEvent();
}

/// Pula diretamente para um capítulo do sumário
class JumpToChapterEvent extends BookReaderEvent {
  final int chapterIndex;

  const JumpToChapterEvent(this.chapterIndex);

  @override
  List<Object?> get props => [chapterIndex];
}

/// Pula para uma página específica via slider de navegação
class JumpToPageEvent extends BookReaderEvent {
  final int page;

  const JumpToPageEvent(this.page);

  @override
  List<Object?> get props => [page];
}

/// Alterna a visibilidade dos controles de interface (Modo Fullscreen Imersivo)
class ToggleControlsEvent extends BookReaderEvent {
  const ToggleControlsEvent();
}

/// Atualiza as preferências visuais de tipografia e tema
class UpdateTypographyEvent extends BookReaderEvent {
  final double? fontSize;
  final double? lineHeight;
  final String? fontFamily;
  final String? themeMode;

  const UpdateTypographyEvent({
    this.fontSize,
    this.lineHeight,
    this.fontFamily,
    this.themeMode,
  });

  @override
  List<Object?> get props => [fontSize, lineHeight, fontFamily, themeMode];
}

/// Promove a sessão de streaming atual para arquivo local permanente na biblioteca
class PromoteBookToLocalEvent extends BookReaderEvent {
  const PromoteBookToLocalEvent();
}

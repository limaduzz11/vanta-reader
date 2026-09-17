import 'package:equatable/equatable.dart';
import '../../../core/reader/book_models.dart';
import '../../../core/reader/reading_session.dart';
import '../../../domain/entities/work.dart';

/// Estados do Leitor de Livros
abstract class BookReaderState extends Equatable {
  const BookReaderState();

  @override
  List<Object?> get props => [];
}

class BookReaderInitial extends BookReaderState {
  const BookReaderInitial();
}

class BookReaderLoading extends BookReaderState {
  final String message;

  const BookReaderLoading([this.message = 'Carregando obra...']);

  @override
  List<Object?> get props => [message];
}

class BookReaderLoaded extends BookReaderState {
  final Work work;
  final WorkEdition edition;
  final BookContent content;
  final int currentChapterIndex;
  final int currentPage;
  final int totalPages;
  final double percentage;
  final bool areControlsVisible;
  final TypographySettings typography;
  final ReadingSession? session;
  final bool isPromotingToLocal;

  const BookReaderLoaded({
    required this.work,
    required this.edition,
    required this.content,
    required this.currentChapterIndex,
    required this.currentPage,
    required this.totalPages,
    required this.percentage,
    this.areControlsVisible = false,
    this.typography = const TypographySettings(),
    this.session,
    this.isPromotingToLocal = false,
  });

  BookChapter get currentChapter =>
      content.getChapter(currentChapterIndex) ?? content.chapters.first;

  BookReaderLoaded copyWith({
    Work? work,
    WorkEdition? edition,
    BookContent? content,
    int? currentChapterIndex,
    int? currentPage,
    int? totalPages,
    double? percentage,
    bool? areControlsVisible,
    TypographySettings? typography,
    ReadingSession? session,
    bool? isPromotingToLocal,
  }) {
    return BookReaderLoaded(
      work: work ?? this.work,
      edition: edition ?? this.edition,
      content: content ?? this.content,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      percentage: percentage ?? this.percentage,
      areControlsVisible: areControlsVisible ?? this.areControlsVisible,
      typography: typography ?? this.typography,
      session: session ?? this.session,
      isPromotingToLocal: isPromotingToLocal ?? this.isPromotingToLocal,
    );
  }

  @override
  List<Object?> get props => [
    work,
    edition,
    content,
    currentChapterIndex,
    currentPage,
    totalPages,
    percentage,
    areControlsVisible,
    typography,
    session,
    isPromotingToLocal,
  ];
}

class BookReaderError extends BookReaderState {
  final String message;

  const BookReaderError(this.message);

  @override
  List<Object?> get props => [message];
}

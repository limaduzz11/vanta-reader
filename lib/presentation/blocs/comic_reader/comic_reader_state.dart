import 'package:equatable/equatable.dart';
import '../../../core/reader/comic_models.dart';
import '../../../core/reader/reading_session.dart';
import '../../../domain/entities/work.dart';

abstract class ComicReaderState extends Equatable {
  const ComicReaderState();

  @override
  List<Object?> get props => [];
}

class ComicReaderInitial extends ComicReaderState {
  const ComicReaderInitial();
}

class ComicReaderLoading extends ComicReaderState {
  final String message;

  const ComicReaderLoading([this.message = 'Carregando quadrinho...']);

  @override
  List<Object?> get props => [message];
}

class ComicReaderLoaded extends ComicReaderState {
  final Work work;
  final WorkEdition edition;
  final ComicContent content;
  final int currentPageIndex;
  final int totalPages;
  final double percentage;
  final bool areControlsVisible;
  final ComicReaderSettings settings;
  final ReadingSession? session;
  final bool isPromotingToLocal;

  const ComicReaderLoaded({
    required this.work,
    required this.edition,
    required this.content,
    required this.currentPageIndex,
    required this.totalPages,
    required this.percentage,
    this.areControlsVisible = false,
    this.settings = const ComicReaderSettings(),
    this.session,
    this.isPromotingToLocal = false,
  });

  ComicPage? get currentPage => content.getPage(currentPageIndex);

  int get pageNumber => currentPageIndex + 1;

  ComicReaderLoaded copyWith({
    Work? work,
    WorkEdition? edition,
    ComicContent? content,
    int? currentPageIndex,
    int? totalPages,
    double? percentage,
    bool? areControlsVisible,
    ComicReaderSettings? settings,
    ReadingSession? session,
    bool? isPromotingToLocal,
  }) {
    return ComicReaderLoaded(
      work: work ?? this.work,
      edition: edition ?? this.edition,
      content: content ?? this.content,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      totalPages: totalPages ?? this.totalPages,
      percentage: percentage ?? this.percentage,
      areControlsVisible: areControlsVisible ?? this.areControlsVisible,
      settings: settings ?? this.settings,
      session: session ?? this.session,
      isPromotingToLocal: isPromotingToLocal ?? this.isPromotingToLocal,
    );
  }

  @override
  List<Object?> get props => [
    work,
    edition,
    content,
    currentPageIndex,
    totalPages,
    percentage,
    areControlsVisible,
    settings,
    session,
    isPromotingToLocal,
  ];
}

class ComicReaderError extends ComicReaderState {
  final String message;

  const ComicReaderError(this.message);

  @override
  List<Object?> get props => [message];
}

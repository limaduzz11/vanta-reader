import 'package:equatable/equatable.dart';
import '../../../core/reader/comic_models.dart';
import '../../../domain/entities/work.dart';

abstract class ComicReaderEvent extends Equatable {
  const ComicReaderEvent();

  @override
  List<Object?> get props => [];
}

class OpenComicEvent extends ComicReaderEvent {
  final Work work;
  final WorkEdition edition;

  const OpenComicEvent({required this.work, required this.edition});

  @override
  List<Object?> get props => [work, edition];
}

class NextComicPageEvent extends ComicReaderEvent {
  const NextComicPageEvent();
}

class PreviousComicPageEvent extends ComicReaderEvent {
  const PreviousComicPageEvent();
}

class JumpToComicPageEvent extends ComicReaderEvent {
  final int pageIndex;

  const JumpToComicPageEvent(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}

class ToggleComicControlsEvent extends ComicReaderEvent {
  const ToggleComicControlsEvent();
}

class ChangeReadingModeEvent extends ComicReaderEvent {
  final ComicReadingMode readingMode;

  const ChangeReadingModeEvent(this.readingMode);

  @override
  List<Object?> get props => [readingMode];
}

class ChangeFitModeEvent extends ComicReaderEvent {
  final ComicFitMode fitMode;

  const ChangeFitModeEvent(this.fitMode);

  @override
  List<Object?> get props => [fitMode];
}

class ToggleDoublePageEvent extends ComicReaderEvent {
  const ToggleDoublePageEvent();
}

class ToggleRtlEvent extends ComicReaderEvent {
  const ToggleRtlEvent();
}

/// Promove a sessão de streaming atual para arquivo local permanente na biblioteca
class PromoteComicToLocalEvent extends ComicReaderEvent {
  const PromoteComicToLocalEvent();
}

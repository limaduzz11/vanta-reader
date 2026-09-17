import 'package:equatable/equatable.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/work.dart';

abstract class WorkDetailsState extends Equatable {
  const WorkDetailsState();

  @override
  List<Object?> get props => [];
}

class WorkDetailsInitial extends WorkDetailsState {
  const WorkDetailsInitial();
}

class WorkDetailsLoading extends WorkDetailsState {
  const WorkDetailsLoading();
}

class WorkDetailsLoaded extends WorkDetailsState {
  final Work work;
  final bool isFavorite;
  final ReadingProgress? progress;

  const WorkDetailsLoaded({
    required this.work,
    required this.isFavorite,
    this.progress,
  });

  WorkDetailsLoaded copyWith({
    Work? work,
    bool? isFavorite,
    ReadingProgress? progress,
  }) {
    return WorkDetailsLoaded(
      work: work ?? this.work,
      isFavorite: isFavorite ?? this.isFavorite,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [work, isFavorite, progress];
}

class WorkDetailsError extends WorkDetailsState {
  final String message;

  const WorkDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}

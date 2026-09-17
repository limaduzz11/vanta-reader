import 'package:equatable/equatable.dart';
import '../../../domain/entities/reading_progress.dart';

abstract class WorkDetailsEvent extends Equatable {
  const WorkDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadWorkDetailsEvent extends WorkDetailsEvent {
  final String workId;

  const LoadWorkDetailsEvent(this.workId);

  @override
  List<Object?> get props => [workId];
}

class ToggleDetailsFavoriteEvent extends WorkDetailsEvent {
  final String workId;

  const ToggleDetailsFavoriteEvent(this.workId);

  @override
  List<Object?> get props => [workId];
}

class UpdateDetailsProgressEvent extends WorkDetailsEvent {
  final ReadingProgress progress;

  const UpdateDetailsProgressEvent(this.progress);

  @override
  List<Object?> get props => [progress];
}

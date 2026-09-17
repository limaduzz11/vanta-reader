import 'package:equatable/equatable.dart';
import '../../../core/download/download_progress_snapshot.dart';
import '../../../domain/entities/download_item.dart';

abstract class DownloadsEvent extends Equatable {
  const DownloadsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDownloadsEvent extends DownloadsEvent {
  const LoadDownloadsEvent();
}

class DownloadsUpdatedEvent extends DownloadsEvent {
  final List<DownloadItem> downloads;

  const DownloadsUpdatedEvent(this.downloads);

  @override
  List<Object?> get props => [downloads];
}

class DownloadProgressUpdatedEvent extends DownloadsEvent {
  final DownloadProgressSnapshot snapshot;

  const DownloadProgressUpdatedEvent(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}

class PauseDownloadEvent extends DownloadsEvent {
  final String downloadId;

  const PauseDownloadEvent(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}

class ResumeDownloadEvent extends DownloadsEvent {
  final String downloadId;

  const ResumeDownloadEvent(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}

class CancelDownloadEvent extends DownloadsEvent {
  final String downloadId;

  const CancelDownloadEvent(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}

class RetryDownloadEvent extends DownloadsEvent {
  final String downloadId;

  const RetryDownloadEvent(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}

class DeleteDownloadEvent extends DownloadsEvent {
  final String downloadId;
  final bool deleteFile;

  const DeleteDownloadEvent(this.downloadId, {this.deleteFile = false});

  @override
  List<Object?> get props => [downloadId, deleteFile];
}

class ClearCompletedDownloadsEvent extends DownloadsEvent {
  const ClearCompletedDownloadsEvent();
}

import 'package:equatable/equatable.dart';
import '../../../core/download/download_progress_snapshot.dart';
import '../../../domain/entities/download_item.dart';

abstract class DownloadsState extends Equatable {
  const DownloadsState();

  @override
  List<Object?> get props => [];
}

class DownloadsInitial extends DownloadsState {
  const DownloadsInitial();
}

class DownloadsLoading extends DownloadsState {
  const DownloadsLoading();
}

class DownloadsLoaded extends DownloadsState {
  final List<DownloadItem> downloads;
  final Map<String, DownloadProgressSnapshot> progressMap;

  const DownloadsLoaded({required this.downloads, this.progressMap = const {}});

  int get totalCount => downloads.length;

  int get activeCount =>
      downloads.where((d) => d.status == DownloadStatus.downloading).length;

  int get queuedCount =>
      downloads.where((d) => d.status == DownloadStatus.queued).length;

  int get completedCount =>
      downloads.where((d) => d.status == DownloadStatus.completed).length;

  DownloadsLoaded copyWith({
    List<DownloadItem>? downloads,
    Map<String, DownloadProgressSnapshot>? progressMap,
  }) {
    return DownloadsLoaded(
      downloads: downloads ?? this.downloads,
      progressMap: progressMap ?? this.progressMap,
    );
  }

  @override
  List<Object?> get props => [downloads, progressMap];
}

class DownloadsError extends DownloadsState {
  final String message;

  const DownloadsError(this.message);

  @override
  List<Object?> get props => [message];
}

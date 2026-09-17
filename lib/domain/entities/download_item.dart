import 'package:equatable/equatable.dart';

/// Estados da Máquina de Estados de Downloads
enum DownloadStatus {
  queued('QUEUED', 'Na Fila'),
  downloading('DOWNLOADING', 'Baixando'),
  paused('PAUSED', 'Pausado'),
  completed('COMPLETED', 'Concluído'),
  failed('FAILED', 'Falhou'),
  cancelled('CANCELLED', 'Cancelado');

  final String code;
  final String label;
  const DownloadStatus(this.code, this.label);

  static DownloadStatus fromCode(String code) {
    return DownloadStatus.values.firstWhere(
      (e) => e.code == code.toUpperCase(),
      orElse: () => DownloadStatus.queued,
    );
  }
}

/// Item de Download Persistido
class DownloadItem extends Equatable {
  final String id;
  final String workId;
  final String editionId;
  final String title;
  final String targetPath;
  final String downloadUrl;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DownloadItem({
    required this.id,
    required this.workId,
    required this.editionId,
    required this.title,
    required this.targetPath,
    required this.downloadUrl,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    required this.status,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  int get progressPercent => (progress * 100).toInt();

  bool get isActive =>
      status == DownloadStatus.downloading || status == DownloadStatus.queued;

  bool get isTerminal =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  DownloadItem copyWith({
    String? id,
    String? workId,
    String? editionId,
    String? title,
    String? targetPath,
    String? downloadUrl,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      editionId: editionId ?? this.editionId,
      title: title ?? this.title,
      targetPath: targetPath ?? this.targetPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    workId,
    editionId,
    title,
    targetPath,
    downloadUrl,
    status,
    downloadedBytes,
    totalBytes,
    errorMessage,
  ];
}

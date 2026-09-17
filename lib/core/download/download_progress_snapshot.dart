import 'package:equatable/equatable.dart';
import '../../domain/entities/download_item.dart';

/// Instantâneo em tempo real do progresso de uma tarefa de download
class DownloadProgressSnapshot extends Equatable {
  final String downloadId;
  final DownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final int? etaSeconds;
  final String? errorMessage;

  const DownloadProgressSnapshot({
    required this.downloadId,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.speedBytesPerSecond = 0.0,
    this.etaSeconds,
    this.errorMessage,
  });

  double get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  int get progressPercent => (progress * 100).toInt();

  /// Velocidade formatada para exibição visual
  String get speedFormatted {
    if (speedBytesPerSecond <= 0) return '0 KB/s';
    if (speedBytesPerSecond >= 1024 * 1024) {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speedBytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }

  /// Tempo restante estimado (ETA) formatado
  String get etaFormatted {
    if (status == DownloadStatus.completed) return 'Concluído';
    if (status == DownloadStatus.paused) return 'Pausado';
    if (status == DownloadStatus.failed) return 'Falha';
    if (etaSeconds == null || etaSeconds! <= 0) return '--';

    final minutes = etaSeconds! ~/ 60;
    final seconds = etaSeconds! % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  /// Tamanho transferido formatado (ex: "4.5 MB de 12.0 MB")
  String get sizeFormatted {
    final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$downloadedMb MB de $totalMb MB';
  }

  @override
  List<Object?> get props => [
    downloadId,
    status,
    downloadedBytes,
    totalBytes,
    speedBytesPerSecond,
    etaSeconds,
    errorMessage,
  ];
}

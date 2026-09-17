import 'package:equatable/equatable.dart';

/// Progresso de Leitura Persistido
class ReadingProgress extends Equatable {
  final String workId;
  final String editionId;
  final String? chapterId;
  final int currentPage;
  final int totalPages;
  final int charOffset;
  final double percentage; // 0.0 a 1.0
  final DateTime updatedAt;

  const ReadingProgress({
    required this.workId,
    required this.editionId,
    this.chapterId,
    required this.currentPage,
    required this.totalPages,
    this.charOffset = 0,
    required this.percentage,
    required this.updatedAt,
  });

  int get percentageInt => (percentage * 100).clamp(0, 100).toInt();

  @override
  List<Object?> get props => [
    workId,
    editionId,
    chapterId,
    currentPage,
    totalPages,
    charOffset,
    percentage,
    updatedAt,
  ];
}

/// Sessão do Histórico de Leitura
class ReadingHistoryEntry extends Equatable {
  final String id;
  final String workId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int pagesRead;

  const ReadingHistoryEntry({
    required this.id,
    required this.workId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.pagesRead,
  });

  @override
  List<Object?> get props => [
    id,
    workId,
    startedAt,
    durationSeconds,
    pagesRead,
  ];
}

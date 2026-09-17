import 'package:equatable/equatable.dart';
import '../../domain/entities/work.dart';

/// Origem de Resolução da Sessão de Leitura
enum ReadingSource {
  /// Arquivo residente permanentemente no armazenamento do dispositivo (Offline)
  local('local', 'Offline Local'),

  /// Arquivo já armazenado no cache volátil de streaming (/cache/reading/)
  cachedStream('cachedStream', 'Cache Streaming'),

  /// Leitura iniciada sob demanda via streaming da rede
  onlineStream('onlineStream', 'Streaming Online');

  final String code;
  final String label;
  const ReadingSource(this.code, this.label);
}

/// Representação Imutável de uma Sessão Ativa de Leitura (Híbrida: Local / Online)
class ReadingSession extends Equatable {
  final Work work;
  final WorkEdition edition;
  final ReadingSource source;
  final String resolvedFilePath;
  final bool isTemporaryCache;
  final int fileSize;
  final String? providerName;

  const ReadingSession({
    required this.work,
    required this.edition,
    required this.source,
    required this.resolvedFilePath,
    this.isTemporaryCache = false,
    this.fileSize = 0,
    this.providerName,
  });

  /// Indica se a leitura ocorre a partir de armazenamento permanente local
  bool get isLocal => source == ReadingSource.local;

  /// Indica se a leitura ocorre através de streaming (volátil ou em trânsito)
  bool get isStreaming =>
      source == ReadingSource.onlineStream ||
      source == ReadingSource.cachedStream;

  @override
  List<Object?> get props => [
    work.id,
    edition.id,
    source,
    resolvedFilePath,
    isTemporaryCache,
    fileSize,
    providerName,
  ];
}

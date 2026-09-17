import 'package:equatable/equatable.dart';
import '../../domain/entities/work.dart';

/// Estado de Saúde Operacional de um Provedor
enum ProviderStatus {
  healthy('healthy', 'Operacional'),
  degraded('degraded', 'Degradado / Lento'),
  offline('offline', 'Offline / Inacessível'),
  disabled('disabled', 'Desativado');

  final String code;
  final String label;
  const ProviderStatus(this.code, this.label);
}

/// Capacidades Suportadas por um Provedor de Conteúdo
class ProviderCapabilities extends Equatable {
  final bool supportsSearch;
  final bool supportsDownload;
  final bool supportsStreaming;
  final Set<WorkFormat> supportedFormats;
  final Set<String> supportedLanguages; // Ex: {'pt-BR', 'en'}
  final int? rateLimitPerMinute;

  /// Provider que fornece apenas metadata/capas, sem conteúdo real.
  /// Ex: Open Library (sem arquivo de leitura via API).
  final bool metadataOnly;

  /// Tipos de obra suportados/cobertos (para filtro por tipo sem heurística).
  final Set<WorkType> supportedTypes;

  /// Natureza da fonte: openApi | publicDomain | datasetLicensed | officialCatalog.
  final String contentSourceType;

  const ProviderCapabilities({
    this.supportsSearch = true,
    this.supportsDownload = true,
    this.supportsStreaming = false,
    this.supportedFormats = const {
      WorkFormat.epub,
      WorkFormat.pdf,
      WorkFormat.cbz,
    },
    this.supportedLanguages = const {'pt-BR', 'en'},
    this.rateLimitPerMinute,
    this.metadataOnly = false,
    this.supportedTypes = const {WorkType.book, WorkType.comic},
    this.contentSourceType = 'unknown',
  });

  /// Provedor entrega conteúdo real (download ou streaming) sem ser metadata-only.
  bool get providesContent => !metadataOnly;

  bool supportsType(WorkType type) => supportedTypes.contains(type);

  bool supportsFormat(WorkFormat format) => supportedFormats.contains(format);
  bool supportsLanguage(String lang) => supportedLanguages.contains(lang);

  @override
  List<Object?> get props => [
    supportsSearch,
    supportsDownload,
    supportsStreaming,
    supportedFormats,
    supportedLanguages,
    rateLimitPerMinute,
    metadataOnly,
    supportedTypes,
    contentSourceType,
  ];
}

/// Diagnóstico de Saúde de um Provedor
class ProviderHealth extends Equatable {
  final ProviderStatus status;
  final DateTime lastChecked;
  final int? latencyMs;
  final String? errorMessage;

  const ProviderHealth({
    required this.status,
    required this.lastChecked,
    this.latencyMs,
    this.errorMessage,
  });

  bool get isOperational =>
      status == ProviderStatus.healthy || status == ProviderStatus.degraded;

  factory ProviderHealth.healthy({int? latencyMs}) => ProviderHealth(
    status: ProviderStatus.healthy,
    lastChecked: DateTime.now(),
    latencyMs: latencyMs,
  );

  factory ProviderHealth.degraded({int? latencyMs, String? message}) =>
      ProviderHealth(
        status: ProviderStatus.degraded,
        lastChecked: DateTime.now(),
        latencyMs: latencyMs,
        errorMessage: message,
      );

  factory ProviderHealth.offline({String? message}) => ProviderHealth(
    status: ProviderStatus.offline,
    lastChecked: DateTime.now(),
    errorMessage: message,
  );

  factory ProviderHealth.disabled() => ProviderHealth(
    status: ProviderStatus.disabled,
    lastChecked: DateTime.now(),
  );

  @override
  List<Object?> get props => [status, lastChecked, latencyMs, errorMessage];
}

/// Metadados Externos Brutos de uma Obra Retornados por um Provedor
class ExternalWorkMetadata extends Equatable {
  final String providerId;
  final String externalId;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? description;
  final String? language; // 'pt-BR', 'en', 'por', 'eng', etc.
  final WorkType type;
  final WorkFormat format;
  final String? coverUrl;
  final String? downloadUrl;
  final int fileSizeBytes;
  final int pageCount;
  final String? publisher;
  final String? publishedDate;
  final String? isbn;
  final String? series;
  final String? volume;
  final Map<String, dynamic> extraMetadata;

  /// Identificador externo da EDIÇÃO quando a fonte distingue obra e edição
  /// (ex: nome do arquivo CBZ no Internet Archive).
  final String? externalEditionId;

  const ExternalWorkMetadata({
    required this.providerId,
    required this.externalId,
    required this.title,
    this.subtitle,
    required this.authors,
    this.description,
    this.language,
    required this.type,
    required this.format,
    this.coverUrl,
    this.downloadUrl,
    this.fileSizeBytes = 0,
    this.pageCount = 0,
    this.publisher,
    this.publishedDate,
    this.isbn,
    this.series,
    this.volume,
    this.extraMetadata = const {},
    this.externalEditionId,
  });

  String get primaryAuthor =>
      authors.isNotEmpty ? authors.first : 'Autor Desconhecido';

  ExternalWorkMetadata copyWith({
    String? providerId,
    String? externalId,
    String? title,
    String? subtitle,
    List<String>? authors,
    String? description,
    String? language,
    WorkType? type,
    WorkFormat? format,
    String? coverUrl,
    String? downloadUrl,
    int? fileSizeBytes,
    int? pageCount,
    String? publisher,
    String? publishedDate,
    String? isbn,
    String? series,
    String? volume,
    String? externalEditionId,
    Map<String, dynamic>? extraMetadata,
  }) {
    return ExternalWorkMetadata(
      providerId: providerId ?? this.providerId,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      language: language ?? this.language,
      type: type ?? this.type,
      format: format ?? this.format,
      coverUrl: coverUrl ?? this.coverUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      isbn: isbn ?? this.isbn,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      externalEditionId: externalEditionId ?? this.externalEditionId,
      extraMetadata: extraMetadata ?? this.extraMetadata,
    );
  }

  @override
  List<Object?> get props => [
    providerId,
    externalId,
    title,
    subtitle,
    authors,
    language,
    type,
    format,
    coverUrl,
    downloadUrl,
    fileSizeBytes,
    pageCount,
    isbn,
  ];
}

/// Metadados de Obra Normalizados e Higienizados
class NormalizedWorkMetadata extends Equatable {
  final String workKey;
  final String title;
  final String? subtitle;
  final String author;
  final String? description;
  final String primaryLanguage; // Sempre 'pt-BR' ou 'en'
  final WorkType type;
  final String? series;
  final String? volume;
  final String? publisher;
  final String? publishedDate;
  final String? isbn;
  final String? coverUrl;
  final List<WorkEdition> editions;
  final double confidenceScore;

  const NormalizedWorkMetadata({
    required this.workKey,
    required this.title,
    this.subtitle,
    required this.author,
    this.description,
    required this.primaryLanguage,
    required this.type,
    this.series,
    this.volume,
    this.publisher,
    this.publishedDate,
    this.isbn,
    this.coverUrl,
    this.editions = const [],
    this.confidenceScore = 1.0,
  });

  @override
  List<Object?> get props => [
    workKey,
    title,
    subtitle,
    author,
    primaryLanguage,
    type,
    series,
    volume,
    publisher,
    publishedDate,
    isbn,
    coverUrl,
    editions,
    confidenceScore,
  ];
}

import 'package:equatable/equatable.dart';

/// Tipo da Obra
enum WorkType {
  book('book', 'Livro'),
  comic('comic', 'Quadrinho / HQ');

  final String code;
  final String label;
  const WorkType(this.code, this.label);

  static WorkType fromString(String value) {
    return WorkType.values.firstWhere(
      (e) => e.code == value.toLowerCase(),
      orElse: () => WorkType.book,
    );
  }
}

/// Formatos Suportados
enum WorkFormat {
  epub('epub', 'EPUB', WorkType.book),
  pdf('pdf', 'PDF', WorkType.book),
  txt('txt', 'TXT', WorkType.book),
  cbz('cbz', 'CBZ', WorkType.comic),
  cbr('cbr', 'CBR', WorkType.comic),
  images('images', 'Imagens', WorkType.comic),
  unknown('unknown', 'Desconhecido', WorkType.book);

  final String extension;
  final String label;
  final WorkType type;
  const WorkFormat(this.extension, this.label, this.type);

  static WorkFormat fromExtension(String ext) {
    final clean = ext.replaceAll('.', '').toLowerCase();
    return WorkFormat.values.firstWhere(
      (e) => e.extension == clean,
      orElse: () => WorkFormat.unknown,
    );
  }
}

/// Status de um asset de conteúdo em relação à sua disponibilidade real
enum ContentAssetStatus {
  /// Não existe asset conhecido para a edição.
  none('none', 'Indisponível'),

  /// Asset remoto identificado, porém não validado.
  remoteAvailable('remote_available', 'Disponível remoto'),

  /// Asset remoto validado (assinatura/tamanho/container conforme fonte).
  validated('validated', 'Validado'),

  /// Asset baixado e persistido localmente.
  downloaded('downloaded', 'Baixado'),

  /// Falha ao resolver, validar ou baixar.
  failed('failed', 'Falhou');

  final String code;
  final String label;

  const ContentAssetStatus(this.code, this.label);

  static ContentAssetStatus fromCode(String code) {
    return ContentAssetStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ContentAssetStatus.none,
    );
  }
}

/// Asset de Conteúdo Real associado a uma Edição (arquivo remoto/local).
///
/// Regra de produto: uma obra NÃO é considerada disponível para leitura
/// enquanto não existir um ContentAsset com status validado/downloaded
/// comprovadamente correlacionado à mesma Edição. Metadata NO SQLite
/// não é conteúdo.
class ContentAsset extends Equatable {
  final String id;
  final String editionId;
  final WorkFormat format;
  final ContentAssetStatus status;
  final String? remoteUrl;
  final String? localPath;
  final String? mediaType;
  final int fileSize;
  final String? checksum;
  final String? checksumAlgorithm;
  final String? source;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContentAsset({
    required this.id,
    required this.editionId,
    required this.format,
    this.status = ContentAssetStatus.none,
    this.remoteUrl,
    this.localPath,
    this.mediaType,
    this.fileSize = 0,
    this.checksum,
    this.checksumAlgorithm,
    this.source,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLocalDownloaded =>
      status == ContentAssetStatus.downloaded &&
      localPath != null &&
      localPath!.isNotEmpty;

  ContentAsset copyWith({
    String? id,
    String? editionId,
    WorkFormat? format,
    ContentAssetStatus? status,
    String? remoteUrl,
    String? localPath,
    String? mediaType,
    int? fileSize,
    String? checksum,
    String? checksumAlgorithm,
    String? source,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContentAsset(
      id: id ?? this.id,
      editionId: editionId ?? this.editionId,
      format: format ?? this.format,
      status: status ?? this.status,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localPath: localPath ?? this.localPath,
      mediaType: mediaType ?? this.mediaType,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      source: source ?? this.source,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    editionId,
    format,
    status,
    remoteUrl,
    localPath,
    mediaType,
    fileSize,
    checksum,
    source,
  ];
}

/// Edição editorial de uma Obra.
///
/// WorkEdition representa a edição em si (formato, idioma, identificador
/// externo, proveniência) e agrega os ContentAssets que provam a
/// disponibilidade real de conteúdo. Não mistura edição com asset.
class WorkEdition extends Equatable {
  final String id;
  final String workId;
  final WorkFormat format;
  final String? filePath;
  final int fileSize;
  final int pageCount;
  final String? checksum;
  final String? downloadUrl;
  final String? providerId;
  final bool isLocal;

  /// Identificador externo da obra na fonte (ex: OL key, ID Gutendex, IA identifier).
  final String? externalId;

  /// Idioma da EDIÇÃO (não da obra em geral). Ex: 'pt-BR', 'en'.
  final String? language;
  final String? originalTitle;
  final String? localizedTitle;

  /// Assets de conteúdo real associados a esta edição.
  final List<ContentAsset> contentAssets;

  const WorkEdition({
    required this.id,
    required this.workId,
    required this.format,
    this.filePath,
    this.fileSize = 0,
    this.pageCount = 0,
    this.checksum,
    this.downloadUrl,
    this.providerId,
    this.isLocal = false,
    this.externalId,
    this.language,
    this.originalTitle,
    this.localizedTitle,
    this.contentAssets = const [],
  });

  ContentAsset? get primaryContentAsset {
    if (contentAssets.isNotEmpty) return contentAssets.first;
    return null;
  }

  bool get hasValidLocalAsset =>
      isLocal &&
      filePath != null &&
      filePath!.isNotEmpty &&
      contentAssets.any((asset) => asset.isLocalDownloaded);

  WorkEdition copyWith({
    String? id,
    String? workId,
    WorkFormat? format,
    String? filePath,
    int? fileSize,
    int? pageCount,
    String? checksum,
    String? downloadUrl,
    String? providerId,
    bool? isLocal,
    String? externalId,
    String? language,
    String? originalTitle,
    String? localizedTitle,
    List<ContentAsset>? contentAssets,
  }) {
    return WorkEdition(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      checksum: checksum ?? this.checksum,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      providerId: providerId ?? this.providerId,
      isLocal: isLocal ?? this.isLocal,
      externalId: externalId ?? this.externalId,
      language: language ?? this.language,
      originalTitle: originalTitle ?? this.originalTitle,
      localizedTitle: localizedTitle ?? this.localizedTitle,
      contentAssets: contentAssets ?? this.contentAssets,
    );
  }

  @override
  List<Object?> get props => [
    id,
    workId,
    format,
    filePath,
    fileSize,
    pageCount,
    checksum,
    downloadUrl,
    providerId,
    isLocal,
    externalId,
    language,
    originalTitle,
    localizedTitle,
    contentAssets,
  ];
}

/// Entidade Mestre Deduplicada (Work)
class Work extends Equatable {
  final String id;
  final String workKey;
  final String title;
  final String? subtitle;
  final String author;
  final String? description;
  final String primaryLanguage; // 'pt-BR' ou 'en'
  final WorkType type;
  final String? series;
  final String? volume;
  final String? publisher;
  final String? publishedDate;
  final String? isbn;
  final String? coverPath;
  final List<WorkEdition> editions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Work({
    required this.id,
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
    this.coverPath,
    this.editions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDownloaded => editions.any((e) => e.hasValidLocalAsset);

  /// Selecione a edição efetivamente local disponível, senão a primeira.
  WorkEdition? get primaryEdition {
    if (editions.isEmpty) return null;
    return editions.firstWhere(
      (e) => e.hasValidLocalAsset,
      orElse: () => editions.first,
    );
  }

  Work copyWith({
    String? id,
    String? workKey,
    String? title,
    String? subtitle,
    String? author,
    String? description,
    String? primaryLanguage,
    WorkType? type,
    String? series,
    String? volume,
    String? publisher,
    String? publishedDate,
    String? isbn,
    String? coverPath,
    List<WorkEdition>? editions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Work(
      id: id ?? this.id,
      workKey: workKey ?? this.workKey,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      description: description ?? this.description,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      type: type ?? this.type,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      isbn: isbn ?? this.isbn,
      coverPath: coverPath ?? this.coverPath,
      editions: editions ?? this.editions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    workKey,
    title,
    author,
    primaryLanguage,
    type,
    series,
    volume,
  ];
}

import 'package:equatable/equatable.dart';

/// DTOs espelho do contrato neutro da VANTA Catalog API (v0.2).
///
/// Regras de parsing replicam os helpers Python (`clean_text`, `to_int`,
/// `parse_authors`, `normalize_extension`): sem geradores, `fromJson` explícito.

int? _toInt(dynamic value) {
  if (value == null || value == '' || value == false) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final asInt = int.tryParse(text);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(text);
  return asDouble?.toInt();
}

String? _cleanText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _parseAuthors(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    final out = <String>[];
    for (final item in value) {
      if (item is Map) {
        final name =
            _cleanText(item['canonical_name']) ??
            _cleanText(item['author']) ??
            _cleanText(item['name']) ??
            _cleanText(item['title']);
        if (name != null) out.add(name);
      } else {
        final text = _cleanText(item);
        if (text != null) out.add(text);
      }
    }
    return _dedupe(out);
  }
  final text = _cleanText(value);
  if (text == null) return [];
  return _dedupe(
    text
        .split(RegExp(r'\s*(?:;|\||\n)\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(),
  );
}

List<String> _dedupe(List<String> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final v in values) {
    final key = v.toLowerCase();
    if (seen.add(key)) out.add(v);
  }
  return out;
}

String? _normalizeExtension(dynamic value) {
  final text = _cleanText(value);
  if (text == null) return null;
  return text.toLowerCase().replaceAll(RegExp(r'^\.+'), '');
}

class VantaBookFile extends Equatable {
  final String id;
  final String? extension;
  final int? sizeBytes;
  final int? pages;
  final String? md5;
  final String? sha1;
  final String? sha256;
  final String? topic;
  final String? locator;
  final bool available;

  const VantaBookFile({
    required this.id,
    this.extension,
    this.sizeBytes,
    this.pages,
    this.md5,
    this.sha1,
    this.sha256,
    this.topic,
    this.locator,
    this.available = true,
  });

  factory VantaBookFile.fromJson(Map<String, dynamic> json) {
    return VantaBookFile(
      id: json['id'].toString(),
      extension: _normalizeExtension(json['extension']),
      sizeBytes: _toInt(json['size_bytes']),
      pages: _toInt(json['pages']),
      md5: _cleanText(json['md5']),
      sha1: _cleanText(json['sha1']),
      sha256: _cleanText(json['sha256']),
      topic: _cleanText(json['topic'])?.toLowerCase(),
      locator: _cleanText(json['locator']),
      available: json['available'] is bool
          ? json['available'] as bool
          : (json['available']?.toString() != '0' &&
                json['available']?.toString().toLowerCase() != 'false'),
    );
  }

  @override
  List<Object?> get props => [id, extension, sizeBytes, pages, md5, sha1, sha256, topic, locator, available];
}

class VantaBookSummary extends Equatable {
  final String id;
  final String title;
  final List<String> authors;
  final String? publisher;
  final int? year;
  final String? language;
  final String? coverUrl;
  final List<String> formats;

  const VantaBookSummary({
    required this.id,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.year,
    this.language,
    this.coverUrl,
    this.formats = const [],
  });

  factory VantaBookSummary.fromJson(Map<String, dynamic> json) {
    final rawFormats = json['formats'];
    final formats = rawFormats is List
        ? rawFormats
              .map((e) => _normalizeExtension(e) ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    return VantaBookSummary(
      id: json['id'].toString(),
      title: _cleanText(json['title']) ?? 'Sem título',
      authors: _parseAuthors(json['authors'] ?? json['author']),
      publisher: _cleanText(json['publisher']),
      year: _toInt(json['year']),
      language: _cleanText(json['language'] ?? json['lang']),
      coverUrl: _cleanText(json['cover_url'] ?? json['cover']),
      formats: formats,
    );
  }

  @override
  List<Object?> get props => [id, title, authors, publisher, year, language, coverUrl, formats];
}

class VantaBookEdition extends Equatable {
  final String id;
  final String title;
  final List<String> authors;
  final String? publisher;
  final int? year;
  final String? language;
  final String? isbn;
  final String? doi;
  final int? pages;
  final String? series;
  final String? edition;
  final String? coverUrl;
  final String? topic;
  final List<VantaBookFile> files;

  const VantaBookEdition({
    required this.id,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.year,
    this.language,
    this.isbn,
    this.doi,
    this.pages,
    this.series,
    this.edition,
    this.coverUrl,
    this.topic,
    this.files = const [],
  });

  factory VantaBookEdition.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = rawFiles is List
        ? rawFiles.whereType<Map<String, dynamic>>().map(VantaBookFile.fromJson).toList()
        : <VantaBookFile>[];
    return VantaBookEdition(
      id: json['id'].toString(),
      title: _cleanText(json['title']) ?? 'Sem título',
      authors: _parseAuthors(json['authors'] ?? json['author']),
      publisher: _cleanText(json['publisher']),
      year: _toInt(json['year']),
      language: _cleanText(json['language'] ?? json['lang']),
      isbn: _cleanText(json['isbn']),
      doi: _cleanText(json['doi']),
      pages: _toInt(json['pages']),
      series: _cleanText(json['series'] ?? json['series_name']),
      edition: _cleanText(json['edition']),
      coverUrl: _cleanText(json['cover_url'] ?? json['cover']),
      topic: _cleanText(json['topic'] ?? json['libgen_topic'])?.toLowerCase(),
      files: files,
    );
  }

  @override
  List<Object?> get props => [id, title, authors, publisher, year, language, isbn, doi, pages, series, edition, coverUrl, topic, files];
}

class VantaSearchResponse extends Equatable {
  final String query;
  final int total;
  final int limit;
  final int offset;
  final List<VantaBookSummary> items;

  const VantaSearchResponse({
    required this.query,
    required this.total,
    required this.limit,
    required this.offset,
    this.items = const [],
  });

  factory VantaSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(VantaBookSummary.fromJson).toList()
        : <VantaBookSummary>[];
    return VantaSearchResponse(
      query: json['query']?.toString() ?? '',
      total: _toInt(json['total']) ?? items.length,
      limit: _toInt(json['limit']) ?? items.length,
      offset: _toInt(json['offset']) ?? 0,
      items: items,
    );
  }

  @override
  List<Object?> get props => [query, total, limit, offset, items];
}

class VantaHealthResponse extends Equatable {
  final String status;
  final String version;
  final String database;
  final bool providerConfigured;
  final int uptimeSeconds;

  const VantaHealthResponse({
    required this.status,
    required this.version,
    required this.database,
    required this.providerConfigured,
    required this.uptimeSeconds,
  });

  factory VantaHealthResponse.fromJson(Map<String, dynamic> json) {
    return VantaHealthResponse(
      status: json['status']?.toString() ?? 'unknown',
      version: json['version']?.toString() ?? '',
      database: json['database']?.toString() ?? 'unknown',
      providerConfigured: json['provider_configured'] == true,
      uptimeSeconds: _toInt(json['uptime_seconds']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [status, version, database, providerConfigured, uptimeSeconds];
}

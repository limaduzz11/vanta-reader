import 'dart:async';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/logging/app_logger.dart';
import '../../../core/network/network_client.dart';
import '../../../core/providers/content_provider.dart';
import '../../../core/providers/provider_models.dart';
import '../../../domain/entities/work.dart';

/// Quadrinhos em domínio público via APIs oficiais do Internet Archive.
///
/// Só publica um resultado quando o item possui licença pública explícita,
/// não é restrito/lendable e contém um arquivo CBZ público.
class InternetArchiveContentProvider implements ContentProvider {
  final NetworkClient networkClient;

  InternetArchiveContentProvider({required this.networkClient});

  @override
  String get id => 'internet-archive';

  @override
  String get name => 'Internet Archive (quadrinhos PD)';

  @override
  String get version => '1.1.0';

  @override
  Duration get timeout => const Duration(seconds: 15);

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,
    // Leitura online usa cache-before-read do CBZ real.
    supportsStreaming: true,
    supportedFormats: {WorkFormat.cbz},
    supportedLanguages: {'pt-BR', 'en', 'es', 'und'},
    supportedTypes: {WorkType.comic},
    contentSourceType: 'publicDomain',
    rateLimitPerMinute: 20,
  );

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await networkClient.dio.get(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': 'mediatype:texts AND format:"Comic Book ZIP"',
          'rows': 1,
          'output': 'json',
        },
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );
      sw.stop();
      if (response.statusCode == 200) {
        return ProviderHealth.healthy(latencyMs: sw.elapsedMilliseconds);
      }
      return ProviderHealth.degraded(
        latencyMs: sw.elapsedMilliseconds,
        message: 'Status HTTP ${response.statusCode}',
      );
    } catch (error) {
      sw.stop();
      return ProviderHealth.offline(
        message: 'Internet Archive indisponível: $error',
      );
    }
  }

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (type == WorkType.book) return [];
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final escaped = cleanQuery.replaceAll('"', r'\"');
    final titleClause = cleanQuery == 'comic'
        ? ''
        : '(title:"$escaped" OR description:"$escaped" OR subject:"$escaped") AND ';
    final queryText =
        '${titleClause}mediatype:texts AND subject:"Comic books" '
        'AND format:"Comic Book ZIP" '
        'AND licenseurl:(*publicdomain* OR *zero*)';

    try {
      final response = await networkClient.dio.get(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': queryText,
          'rows': pageSize,
          'page': page,
          'output': 'json',
          'fl[]': [
            'identifier',
            'title',
            'creator',
            'date',
            'year',
            'language',
            'licenseurl',
          ],
        },
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return [];
      }

      final responseBody = response.data as Map<String, dynamic>;
      final responseNode = responseBody['response'];
      if (responseNode is! Map<String, dynamic>) return [];
      final docs = responseNode['docs'] as List<dynamic>? ?? const [];

      // Verificação individual por item. Um documento de busca não basta
      // para provar licença, restrição e existência física do CBZ.
      final verified = await Future.wait(
        docs.whereType<Map<String, dynamic>>().map((doc) async {
          final identifier = doc['identifier']?.toString();
          if (identifier == null || identifier.isEmpty) return null;
          final envelope = await _fetchEnvelope(identifier);
          if (envelope == null) return null;
          return _mapVerifiedItem(identifier, envelope, searchDoc: doc);
        }),
      );

      final results = verified.whereType<ExternalWorkMetadata>().where((item) {
        if (language == null) return true;
        return _languageMatches(item.language, language);
      }).toList();

      AppLogger.info(
        LogCategory.provider,
        'Internet Archive verificou ${results.length}/${docs.length} HQs PD para "$cleanQuery".',
      );
      return results;
    } catch (error, stack) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha isolada na busca Internet Archive: $error',
        error,
        stack,
      );
      return [];
    }
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async {
    final envelope = await _fetchEnvelope(_cleanExternalId(externalId));
    if (envelope == null) return null;
    return _mapVerifiedItem(_cleanExternalId(externalId), envelope);
  }

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async {
    if (format != WorkFormat.cbz) return null;
    final identifier = _cleanExternalId(externalId);
    final envelope = await _fetchEnvelope(identifier);
    if (envelope == null || !_isPublicAndUnrestricted(envelope)) return null;
    final file = _selectPublicCbz(envelope);
    if (file == null) return null;
    return _downloadUrl(identifier, file['name'].toString());
  }

  Future<List<ExternalWorkMetadata>> getFeaturedComics({int limit = 12}) {
    return search('comic', type: WorkType.comic, pageSize: limit);
  }

  Future<Map<String, dynamic>?> _fetchEnvelope(String identifier) async {
    try {
      final response = await networkClient.dio.get(
        'https://archive.org/metadata/$identifier',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (error) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha ao verificar item IA $identifier: $error',
      );
    }
    return null;
  }

  ExternalWorkMetadata? _mapVerifiedItem(
    String identifier,
    Map<String, dynamic> envelope, {
    Map<String, dynamic>? searchDoc,
  }) {
    if (!_isPublicAndUnrestricted(envelope)) return null;
    final file = _selectPublicCbz(envelope);
    if (file == null) return null;

    final metadata = envelope['metadata'];
    if (metadata is! Map<String, dynamic>) return null;

    final title =
        metadata['title']?.toString() ??
        searchDoc?['title']?.toString() ??
        'Sem título';
    final authors = _stringList(metadata['creator'] ?? searchDoc?['creator']);
    final language = _firstString(
      metadata['language'] ?? searchDoc?['language'],
    );
    final size = int.tryParse(file['size']?.toString() ?? '') ?? 0;
    final checksum = file['sha1']?.toString() ?? file['md5']?.toString();
    final checksumAlgorithm = file['sha1'] != null ? 'sha1' : 'md5';

    return ExternalWorkMetadata(
      providerId: id,
      externalId: identifier,
      externalEditionId: file['name']?.toString(),
      title: title,
      authors: authors.isEmpty ? const ['Autor Desconhecido'] : authors,
      description: _firstString(metadata['description']),
      language: language,
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://archive.org/services/img/$identifier',
      downloadUrl: _downloadUrl(identifier, file['name'].toString()),
      fileSizeBytes: size,
      pageCount: 0,
      publisher: _firstString(metadata['publisher']),
      publishedDate: _firstString(metadata['year'] ?? metadata['date']),
      extraMetadata: {
        'licenseUrl': _firstString(metadata['licenseurl']),
        'mediaType': 'application/vnd.comicbook+zip',
        'checksum': checksum,
        'checksumAlgorithm': checksum == null ? null : checksumAlgorithm,
      },
    );
  }

  bool _isPublicAndUnrestricted(Map<String, dynamic> envelope) {
    final metadata = envelope['metadata'];
    if (metadata is! Map<String, dynamic>) return false;
    if (_isTrue(metadata['is_lendable']) ||
        _isTrue(metadata['access-restricted-item'])) {
      return false;
    }
    final license = _firstString(metadata['licenseurl'])?.toLowerCase() ?? '';
    return license.contains('publicdomain') || license.contains('/zero/');
  }

  Map<String, dynamic>? _selectPublicCbz(Map<String, dynamic> envelope) {
    final files = envelope['files'] as List<dynamic>? ?? const [];
    for (final raw in files) {
      if (raw is! Map<String, dynamic>) continue;
      final name = raw['name']?.toString() ?? '';
      if (p.extension(name).toLowerCase() != '.cbz') continue;
      if (_isTrue(raw['private'])) continue;
      return raw;
    }
    return null;
  }

  String _cleanExternalId(String externalId) {
    if (externalId.startsWith('ed-$id-')) {
      final suffix = externalId.substring('ed-$id-'.length);
      return suffix.endsWith('-cbz')
          ? suffix.substring(0, suffix.length - 4)
          : suffix;
    }
    return externalId;
  }

  String _downloadUrl(String identifier, String fileName) {
    return 'https://archive.org/download/$identifier/${Uri.encodeComponent(fileName)}';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    final single = value?.toString();
    return single == null || single.isEmpty ? const [] : [single];
  }

  String? _firstString(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first?.toString();
    final single = value?.toString();
    return single == null || single.isEmpty ? null : single;
  }

  bool _isTrue(dynamic value) {
    return value == true || value?.toString().toLowerCase() == 'true';
  }

  bool _languageMatches(String? raw, String filter) {
    final expected = filter.toLowerCase().split('-').first;
    final actual = (raw ?? '').toLowerCase().split('-').first;
    if (expected == 'pt') {
      return actual == 'pt' || actual == 'por' || actual.startsWith('portugu');
    }
    if (expected == 'en') {
      return actual == 'en' || actual == 'eng' || actual.startsWith('engli');
    }
    return actual == expected;
  }
}

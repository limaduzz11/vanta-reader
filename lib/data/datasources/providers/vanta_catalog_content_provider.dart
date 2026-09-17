import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/network_client.dart';
import '../../../core/providers/content_provider.dart';
import '../../../core/providers/provider_models.dart';
import '../../../core/providers/vanta/vanta_config.dart';
import '../../../core/providers/vanta/vanta_models.dart';
import '../../../domain/entities/work.dart';

/// Fonte oficial VANTA Catalog (gateway neutro FastAPI + SQLite+FTS5).
///
/// O app consome APENAS o contrato neutro (`BookSummary`, `BookEdition`,
/// `BookFile`, `SearchResponse`, `Health`). O protocolo do provider externo
/// (`object`, `ids`, `limit1/limit2`, `addkeys`, `topic`...) nunca vaza para cá.
class VantaCatalogContentProvider implements ContentProvider {
  final NetworkClient networkClient;
  final VantaConfig config;

  VantaCatalogContentProvider({
    required this.networkClient,
    this.config = const VantaConfig(),
  });

  String get _base => config.effectiveBaseUrl;

  @override
  String get id => 'vanta-catalog';

  @override
  String get name => 'VANTA Catalog';

  @override
  String get version => '1.0.0';

  @override
  Duration get timeout => config.timeout;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,
    supportsStreaming: false,
    supportedFormats: {
      WorkFormat.epub,
      WorkFormat.pdf,
      WorkFormat.cbz,
      WorkFormat.cbr,
      WorkFormat.txt,
      WorkFormat.images,
    },
    supportedLanguages: {'pt-BR', 'en', 'und'},
    supportedTypes: {WorkType.book, WorkType.comic},
    contentSourceType: 'officialCatalog',
  );

  String _stripPrefix(String externalId) {
    if (externalId.startsWith(VantaConfig.externalIdPrefix)) {
      return externalId.substring(VantaConfig.externalIdPrefix.length);
    }
    return externalId;
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await networkClient.dio.get(
        '$_base/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      sw.stop();
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final health = VantaHealthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        if (health.status == 'ok' && health.database == 'ok') {
          return ProviderHealth.healthy(latencyMs: sw.elapsedMilliseconds);
        }
        return ProviderHealth.degraded(
          latencyMs: sw.elapsedMilliseconds,
          message: 'Catalog ${health.status}/db ${health.database}',
        );
      }
      return ProviderHealth.degraded(
        latencyMs: sw.elapsedMilliseconds,
        message: 'Status HTTP ${response.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return ProviderHealth.offline(message: 'VANTA Catalog inalcançável: $e');
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
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    final safePage = page < 1 ? 1 : page;
    final safeSize = pageSize.clamp(1, 100);
    final offset = (safePage - 1) * safeSize;

    try {
      final queryParams = <String, dynamic>{
        'q': cleanQuery,
        'limit': safeSize,
        'offset': offset,
      };
      if (language != null && language.trim().isNotEmpty) {
        queryParams['language'] = language.trim();
      }

      final response = await networkClient.dio.get(
        '$_base/v1/search',
        queryParameters: queryParams,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return [];
      }
      final parsed = VantaSearchResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      final results = parsed.items
          .map(_mapSummary)
          .whereType<ExternalWorkMetadata>()
          .toList();

      // A API v0.2 não filtra por topic; o filtro de tipo é aplicado aqui
      // para não vazar heurística para o gateway.
      if (type != null) {
        return results.where((e) => e.type == type).toList();
      }
      return results;
    } catch (e, st) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha isolada na busca VANTA Catalog: $e',
        e,
        st,
      );
      return [];
    }
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async {
    final rawId = _stripPrefix(externalId.trim());
    if (rawId.isEmpty) return null;
    try {
      final response = await networkClient.dio.get(
        '$_base/v1/books/$rawId',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return null;
      }
      final edition = VantaBookEdition.fromJson(
        response.data as Map<String, dynamic>,
      );
      return _mapEdition(edition);
    } catch (e, st) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha isolada em getDetails VANTA Catalog ($externalId): $e',
        e,
        st,
      );
      return null;
    }
  }

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async {
    final rawId = _stripPrefix(externalId.trim());
    if (rawId.isEmpty) return null;
    try {
      final response = await networkClient.dio.get(
        '$_base/v1/books/$rawId/files',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode != 200 || response.data is! List) return null;
      final files = (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(VantaBookFile.fromJson)
          .where((f) => f.available)
          .toList();
      if (files.isEmpty) return null;

      VantaBookFile? picked;
      if (format != WorkFormat.unknown) {
        for (final f in files) {
          if ((f.extension ?? '').toLowerCase() == format.extension) {
            picked = f;
            break;
          }
        }
      }
      picked ??= files.first;
      return '$_base/v1/files/${picked.id}/download';
    } catch (e, st) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha isolada em resolveDownloadUrl VANTA Catalog ($externalId): $e',
        e,
        st,
      );
      return null;
    }
  }

  ExternalWorkMetadata? _mapSummary(VantaBookSummary s) {
    if (s.id.isEmpty) return null;
    final type = _inferType(topic: null, formats: s.formats);
    final format = s.formats.isNotEmpty
        ? WorkFormat.fromExtension(s.formats.first)
        : WorkFormat.unknown;
    return ExternalWorkMetadata(
      providerId: id,
      externalId: '${VantaConfig.externalIdPrefix}${s.id}',
      title: s.title,
      authors: s.authors.isEmpty ? const ['Autor Desconhecido'] : s.authors,
      language: s.language,
      type: type,
      format: format,
      coverUrl: s.coverUrl,
      downloadUrl: null,
      fileSizeBytes: 0,
      pageCount: 0,
      publisher: s.publisher,
      publishedDate: s.year?.toString(),
      extraMetadata: {if (s.year != null) 'year': s.year, 'formats': s.formats},
    );
  }

  ExternalWorkMetadata? _mapEdition(VantaBookEdition e) {
    if (e.id.isEmpty) return null;
    final primary = e.files.where((f) => f.available).toList();
    final first = primary.isNotEmpty
        ? primary.first
        : (e.files.isNotEmpty ? e.files.first : null);
    final formats = e.files
        .map((f) => (f.extension ?? '').toLowerCase())
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    final type = _inferType(topic: e.topic, formats: formats);
    final format = first?.extension != null
        ? WorkFormat.fromExtension(first!.extension!)
        : (formats.isNotEmpty
              ? WorkFormat.fromExtension(formats.first)
              : WorkFormat.unknown);

    return ExternalWorkMetadata(
      providerId: id,
      externalId: '${VantaConfig.externalIdPrefix}${e.id}',
      externalEditionId: first?.id,
      title: e.title,
      authors: e.authors.isEmpty ? const ['Autor Desconhecido'] : e.authors,
      language: e.language,
      type: type,
      format: format,
      coverUrl: e.coverUrl,
      downloadUrl: null,
      fileSizeBytes: first?.sizeBytes ?? 0,
      pageCount: e.pages ?? first?.pages ?? 0,
      publisher: e.publisher,
      publishedDate: e.year?.toString(),
      isbn: e.isbn,
      series: e.series,
      extraMetadata: {
        if (e.topic != null) 'topic': e.topic,
        if (e.doi != null) 'doi': e.doi,
        if (e.edition != null) 'edition': e.edition,
        if (first?.md5 != null) 'md5': first!.md5,
        if (first?.sha1 != null) 'sha1': first!.sha1,
        if (first?.sha256 != null) 'sha256': first!.sha256,
        if (first?.locator != null) 'locator': first!.locator,
        'formats': formats,
      },
    );
  }

  WorkType _inferType({String? topic, required List<String> formats}) {
    if ((topic ?? '').toLowerCase() == 'c') return WorkType.comic;
    final lower = formats.map((e) => e.toLowerCase()).toSet();
    if (lower.contains('cbz') || lower.contains('cbr')) return WorkType.comic;
    return WorkType.book;
  }
}

import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/network_client.dart';
import '../../../core/providers/content_provider.dart';
import '../../../core/providers/provider_models.dart';
import '../../../domain/entities/work.dart';

/// Livros completos em domínio público via API Gutendex.
class GutendexContentProvider implements ContentProvider {
  final NetworkClient networkClient;

  GutendexContentProvider({required this.networkClient});

  @override
  String get id => 'gutendex';

  @override
  String get name => 'Project Gutenberg (Gutendex)';

  @override
  String get version => '1.1.0';

  @override
  Duration get timeout => const Duration(seconds: 12);

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,
    supportsStreaming: true,
    supportedFormats: {WorkFormat.epub, WorkFormat.txt},
    supportedLanguages: {'pt-BR', 'pt', 'en', 'es', 'fr', 'de', 'und'},
    supportedTypes: {WorkType.book},
    contentSourceType: 'publicDomain',
    rateLimitPerMinute: 60,
  );

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await networkClient.dio.get(
        'https://gutendex.com/books/',
        queryParameters: {'page': 1},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      sw.stop();
      return response.statusCode == 200
          ? ProviderHealth.healthy(latencyMs: sw.elapsedMilliseconds)
          : ProviderHealth.degraded(
              latencyMs: sw.elapsedMilliseconds,
              message: 'Status HTTP ${response.statusCode}',
            );
    } catch (error) {
      sw.stop();
      return ProviderHealth.offline(message: 'Gutendex indisponível: $error');
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
    if (type == WorkType.comic) return [];
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    final parameters = <String, dynamic>{'search': cleanQuery, 'page': page};
    final languageCode = _apiLanguage(language);
    if (languageCode != null) parameters['languages'] = languageCode;

    try {
      final response = await networkClient.dio.get(
        'https://gutendex.com/books/',
        queryParameters: parameters,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return [];
      }
      final results =
          (response.data as Map<String, dynamic>)['results']
              as List<dynamic>? ??
          const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(_mapItem)
          .whereType<ExternalWorkMetadata>()
          .take(pageSize)
          .toList();
    } catch (error, stack) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha isolada na busca Gutendex: $error',
        error,
        stack,
      );
      return [];
    }
  }

  Future<List<ExternalWorkMetadata>> getPopularBooks({int limit = 15}) async {
    try {
      final response = await networkClient.dio.get(
        'https://gutendex.com/books/',
        queryParameters: {'languages': 'pt,en'},
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        return [];
      }
      final results =
          (response.data as Map<String, dynamic>)['results']
              as List<dynamic>? ??
          const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(_mapItem)
          .whereType<ExternalWorkMetadata>()
          .take(limit)
          .toList();
    } catch (error) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha em populares Gutendex: $error',
      );
      return [];
    }
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async {
    final item = await _fetchItem(externalId);
    return item == null ? null : _mapItem(item);
  }

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async {
    final item = await _fetchItem(externalId);
    if (item == null) return null;
    final formats = item['formats'] as Map<String, dynamic>? ?? const {};
    if (format == WorkFormat.epub) {
      return formats['application/epub+zip']?.toString();
    }
    if (format == WorkFormat.txt) {
      return formats['text/plain; charset=utf-8']?.toString() ??
          formats['text/plain']?.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchItem(String externalId) async {
    final cleanId = externalId
        .replaceAll('gut_', '')
        .replaceAll('gutendex_', '')
        .replaceAll(RegExp(r'-(epub|txt)$'), '');
    if (int.tryParse(cleanId) == null) return null;
    try {
      final response = await networkClient.dio.get(
        'https://gutendex.com/books/$cleanId',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      return response.statusCode == 200 && response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;
    } catch (error) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha ao resolver Gutendex $cleanId: $error',
      );
      return null;
    }
  }

  ExternalWorkMetadata? _mapItem(Map<String, dynamic> item) {
    final idNumber = item['id'];
    if (idNumber == null) return null;
    final formats = item['formats'] as Map<String, dynamic>? ?? const {};
    final epubUrl = formats['application/epub+zip']?.toString();
    final txtUrl =
        formats['text/plain; charset=utf-8']?.toString() ??
        formats['text/plain']?.toString();
    if (epubUrl == null && txtUrl == null) return null;

    final rawAuthors = item['authors'] as List<dynamic>? ?? const [];
    final authors = rawAuthors.map((raw) {
      if (raw is! Map<String, dynamic>) return 'Autor Desconhecido';
      final rawName = raw['name']?.toString() ?? 'Autor Desconhecido';
      final parts = rawName.split(', ');
      return parts.length == 2 ? '${parts[1]} ${parts[0]}' : rawName;
    }).toList();
    final languages = (item['languages'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList();
    final language = languages.contains('pt')
        ? 'pt-BR'
        : languages.contains('en')
        ? 'en'
        : languages.firstOrNull;
    final format = epubUrl != null ? WorkFormat.epub : WorkFormat.txt;
    final url = epubUrl ?? txtUrl!;

    // G-02: a API expõe `summaries`; antes descartávamos (description null).
    String? description;
    final summaries = item['summaries'];
    if (summaries is List && summaries.isNotEmpty) {
      final first = summaries.first?.toString().trim();
      if (first != null && first.isNotEmpty) description = first;
    }

    return ExternalWorkMetadata(
      providerId: id,
      externalId: 'gut_$idNumber',
      title: item['title']?.toString() ?? 'Sem título',
      authors: authors.isEmpty ? const ['Autor Desconhecido'] : authors,
      description: description,
      language: language,
      type: WorkType.book,
      format: format,
      coverUrl: formats['image/jpeg']?.toString(),
      downloadUrl: url,
      fileSizeBytes: 0,
      pageCount: 0,
      extraMetadata: {
        'mediaType': format == WorkFormat.epub
            ? 'application/epub+zip'
            : 'text/plain',
      },
    );
  }

  String? _apiLanguage(String? language) {
    if (language == null) return null;
    final normalized = language.toLowerCase();
    if (normalized.startsWith('pt')) return 'pt';
    if (normalized.startsWith('en')) return 'en';
    return language.split('-').first;
  }
}

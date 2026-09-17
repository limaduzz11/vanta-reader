import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/network_client.dart';
import '../../../core/providers/content_provider.dart';
import '../../../core/providers/provider_models.dart';
import '../../../domain/entities/work.dart';

/// Provedor de METADATA e CAPAS via Open Library / Internet Archive.
///
/// IMPORTANTE (regra de negócio): a Open Library NÃO disponibiliza arquivos
/// de leitura completos pela API pública (apenas empréstimo digital controlado
/// pelo Internet Archive BookReader). Portanto este provider é
/// metadataOnly=true: nunca declara download/streaming nem resolve URLs
/// mock. Capas são reais (Covers API) e podem ser persistidas localmente.
class OpenLibraryContentProvider implements ContentProvider {
  final NetworkClient networkClient;

  OpenLibraryContentProvider({required this.networkClient});

  @override
  String get id => 'open-library';

  @override
  String get name => 'Open Library';

  @override
  String get version => '1.1.0';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: false,
    supportsStreaming: false,
    metadataOnly: true,
    supportedFormats: {},
    supportedLanguages: {'pt-BR', 'en', 'es', 'fr', 'pt'},
    supportedTypes: {WorkType.book, WorkType.comic},
    contentSourceType: 'officialCatalog',
    rateLimitPerMinute: 60,
  );

  @override
  Duration get timeout => const Duration(seconds: 12);

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await networkClient.dio.get(
        'https://openlibrary.org/trending/daily.json',
        queryParameters: {'limit': 1},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      sw.stop();
      if (response.statusCode == 200) {
        return ProviderHealth.healthy(latencyMs: sw.elapsedMilliseconds);
      }
      return ProviderHealth.degraded(
        latencyMs: sw.elapsedMilliseconds,
        message: 'Status HTTP ${response.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return ProviderHealth.offline(message: 'OpenLibrary inalcançável: $e');
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

    try {
      AppLogger.info(
        LogCategory.provider,
        'Consultando API OpenLibrary por "$cleanQuery" (pág: $page, tipo: $type)...',
      );

      final queryParams = <String, dynamic>{
        'title': cleanQuery,
        'page': page,
        'limit': pageSize,
        'fields':
            'key,title,subtitle,author_name,first_publish_year,cover_i,isbn,language,number_of_pages_median,subject,edition_count,first_sentence,publisher',
      };

      if (language != null) {
        queryParams['language'] = language.toLowerCase().startsWith('pt')
            ? 'por'
            : language.toLowerCase().startsWith('en')
            ? 'eng'
            : language;
      }
      if (type == WorkType.comic) {
        queryParams['subject'] = 'comics';
      }

      final response = await networkClient.dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: queryParams,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final docs = (data['docs'] as List<dynamic>? ?? []).toList();

      final results = <ExternalWorkMetadata>[];

      for (final doc in docs) {
        if (doc is! Map<String, dynamic>) continue;

        final key = doc['key']?.toString() ?? '';
        final title = doc['title']?.toString() ?? 'Sem título';
        final authors =
            (doc['author_name'] as List?)?.map((e) => e.toString()).toList() ??
            ['Autor Desconhecido'];
        final firstPublishYear = doc['first_publish_year']?.toString();
        final coverI = doc['cover_i'];
        final isbnList = doc['isbn'] as List?;
        final isbn = isbnList?.firstOrNull?.toString();
        final pageCount = doc['number_of_pages_median'] as int? ?? 0;
        final subjects =
            (doc['subject'] as List?)
                ?.map((s) => s.toString().toLowerCase())
                .toList() ??
            [];

        // Classificação SEMÂNTICA de comic: apenas subject explícito. Nunca
        // "type == comic" por causa do filtro (isso corrompeu a busca antes).
        final isComic = subjects.any(
          (s) =>
              s == 'comic' ||
              s == 'comics' ||
              s == 'comic books' ||
              s == 'graphic novels' ||
              s == 'manga' ||
              s == 'quadrinhos' ||
              s.startsWith('comic book') ||
              s.startsWith('graphic novel'),
        );

        String? coverUrl;
        if (coverI != null) {
          coverUrl = 'https://covers.openlibrary.org/b/id/$coverI-M.jpg';
        } else if (isbn != null && isbn.isNotEmpty) {
          coverUrl = 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg';
        }

        String? description;
        if (doc['first_sentence'] != null) {
          final firstSentence = doc['first_sentence'];
          if (firstSentence is Map && firstSentence['value'] != null) {
            description = firstSentence['value'].toString();
          } else if (firstSentence is String) {
            description = firstSentence;
          }
        }

        // Idioma: usa o código informado pela fonte. NUNCA heurística de
        // título (ex.: preposições) para não inventar localização.
        final rawLangs =
            (doc['language'] as List?)
                ?.map((l) => l.toString().toLowerCase())
                .toList() ??
            [];
        String? lang;
        if (rawLangs.contains('por') ||
            rawLangs.contains('pt') ||
            rawLangs.contains('pt-br')) {
          lang = 'pt-BR';
        } else if (rawLangs.contains('eng') || rawLangs.contains('en')) {
          lang = 'en';
        } else if (rawLangs.isNotEmpty) {
          lang = rawLangs.first;
        }

        final cleanExternalId = key.replaceAll('/works/', '');

        results.add(
          ExternalWorkMetadata(
            providerId: id,
            externalId: cleanExternalId.isNotEmpty
                ? cleanExternalId
                : 'ol_${title.hashCode.abs()}',
            title: title,
            subtitle: doc['subtitle']?.toString(),
            authors: authors,
            description: description,
            language: lang,
            type: isComic ? WorkType.comic : WorkType.book,
            format: WorkFormat.unknown,
            coverUrl: coverUrl,
            // Nenhum downloadUrl: a fonte não fornece conteúdo pela API.
            downloadUrl: null,
            fileSizeBytes: 0,
            pageCount: pageCount,
            publisher: (doc['publisher'] as List?)?.firstOrNull?.toString(),
            publishedDate: firstPublishYear,
            isbn: isbn,
          ),
        );
      }

      AppLogger.info(
        LogCategory.provider,
        'OpenLibrary retornou ${results.length} obras (metadata) para a busca "$cleanQuery".',
      );

      return results;
    } catch (e, st) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha na busca online via OpenLibrary: $e',
        e,
        st,
      );
      return [];
    }
  }

  /// Recupera lista de livros populares da API da OpenLibrary (metadata).
  Future<List<ExternalWorkMetadata>> getTrendingBooks({int limit = 15}) async {
    try {
      final response = await networkClient.dio.get(
        'https://openlibrary.org/trending/daily.json',
        queryParameters: {'limit': limit},
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final works = data['works'] as List<dynamic>? ?? [];
      final results = <ExternalWorkMetadata>[];

      for (final item in works) {
        if (item is! Map<String, dynamic>) continue;

        final key = item['key']?.toString() ?? '';
        final title = item['title']?.toString() ?? 'Sem título';
        final authors =
            (item['author_name'] as List?)?.map((e) => e.toString()).toList() ??
            ['Autor Desconhecido'];
        final coverI = item['cover_i'];
        final year = item['first_publish_year']?.toString();

        String? coverUrl;
        if (coverI != null) {
          coverUrl = 'https://covers.openlibrary.org/b/id/$coverI-M.jpg';
        }

        final cleanExternalId = key.replaceAll('/works/', '');

        results.add(
          ExternalWorkMetadata(
            providerId: id,
            externalId: cleanExternalId.isNotEmpty
                ? cleanExternalId
                : 'ol_${title.hashCode.abs()}',
            title: title,
            authors: authors,
            description: null,
            language: null,
            type: WorkType.book,
            format: WorkFormat.unknown,
            coverUrl: coverUrl,
            downloadUrl: null,
            fileSizeBytes: 0,
            pageCount: 0,
            publishedDate: year,
          ),
        );
      }

      return results;
    } catch (e) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha ao buscar livros populares da OpenLibrary: $e',
      );
      return [];
    }
  }

  /// Recupera lista de quadrinhos em destaque (metadata/capas) do catálogo.
  Future<List<ExternalWorkMetadata>> getFeaturedComics({int limit = 12}) async {
    try {
      final response = await networkClient.dio.get(
        'https://openlibrary.org/subjects/graphic_novels.json',
        queryParameters: {'limit': limit},
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final works = data['works'] as List<dynamic>? ?? [];
      final results = <ExternalWorkMetadata>[];

      for (final item in works) {
        if (item is! Map<String, dynamic>) continue;

        final key = item['key']?.toString() ?? '';
        final title = item['title']?.toString() ?? 'Sem título';
        final rawAuthors = item['authors'] as List?;
        final authors =
            rawAuthors?.map((a) {
              if (a is Map && a['name'] != null) return a['name'].toString();
              return a.toString();
            }).toList() ??
            ['Autor Desconhecido'];
        final coverId = item['cover_id'];
        final year = item['first_publish_year']?.toString();

        String? coverUrl;
        if (coverId != null) {
          coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
        }

        final cleanExternalId = key.replaceAll('/works/', '');

        results.add(
          ExternalWorkMetadata(
            providerId: id,
            externalId: cleanExternalId.isNotEmpty
                ? cleanExternalId
                : 'ol_${title.hashCode.abs()}',
            title: title,
            authors: authors,
            description: null,
            language: null,
            type: WorkType.comic,
            format: WorkFormat.unknown,
            coverUrl: coverUrl,
            downloadUrl: null,
            fileSizeBytes: 0,
            pageCount: 0,
            publishedDate: year,
          ),
        );
      }

      return results;
    } catch (e) {
      AppLogger.warn(
        LogCategory.provider,
        'Falha ao buscar HQs da OpenLibrary: $e',
      );
      return [];
    }
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async {
    try {
      final response = await networkClient.dio.get(
        'https://openlibrary.org/works/$externalId.json',
        options: Options(receiveTimeout: timeout),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final title = data['title']?.toString() ?? 'Sem título';
        final covers = data['covers'] as List?;
        String? coverUrl;
        if (covers != null && covers.isNotEmpty) {
          coverUrl =
              'https://covers.openlibrary.org/b/id/${covers.first}-M.jpg';
        }
        // G-02: works.json traz só a chave do autor; resolve o nome
        // via /authors/{id}.json (best-effort, sem inventar).
        final authors = await _resolveWorkAuthorNames(data['authors']);
        String? description;
        final rawDesc = data['description'];
        if (rawDesc is Map && rawDesc['value'] != null) {
          description = rawDesc['value'].toString();
        } else if (rawDesc is String) {
          description = rawDesc;
        }

        return ExternalWorkMetadata(
          providerId: id,
          externalId: externalId,
          title: title,
          authors: authors,
          description: description,
          language: null,
          type: WorkType.book,
          format: WorkFormat.unknown,
          coverUrl: coverUrl,
          downloadUrl: null,
          fileSizeBytes: 0,
          pageCount: 0,
          publishedDate: data['first_publish_year']?.toString(),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async {
    // MetadataOnly: nunca há URL de conteúdo.
    return null;
  }

  /// Resolve nomes de autores de um work OL (`authors: [{author: {key}}]`).
  /// Retorna `['Autor Desconhecido']` quando nada resolvível (sem invenção).
  Future<List<String>> _resolveWorkAuthorNames(dynamic rawAuthors) async {
    if (rawAuthors is! List || rawAuthors.isEmpty) {
      return ['Autor Desconhecido'];
    }
    final names = <String>[];
    for (final entry in rawAuthors.take(3)) {
      String? key;
      String? directName;
      if (entry is Map) {
        final author = entry['author'];
        if (author is Map && author['key'] != null) {
          key = author['key'].toString();
        } else if (entry['key'] != null) {
          key = entry['key'].toString();
        }
        if (entry['name'] != null) directName = entry['name'].toString();
      } else if (entry is String) {
        directName = entry;
      }
      if (directName != null && directName.trim().isNotEmpty) {
        names.add(directName.trim());
        continue;
      }
      if (key != null && key.startsWith('/authors/')) {
        try {
          final response = await networkClient.dio.get(
            'https://openlibrary.org$key.json',
            options: Options(
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
            ),
          );
          if (response.statusCode == 200 && response.data is Map) {
            final name = (response.data as Map)['name']?.toString().trim();
            if (name != null && name.isNotEmpty) names.add(name);
          }
        } catch (_) {}
      }
    }
    return names.isEmpty ? ['Autor Desconhecido'] : names;
  }
}

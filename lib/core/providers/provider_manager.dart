import 'dart:async';

import 'package:vantareader/core/logging/app_logger.dart';
import 'package:vantareader/domain/entities/work.dart';

import 'provider_models.dart';
import 'provider_registry.dart';
import 'work_identity_system.dart';

/// Orquestra providers em paralelo e isola falhas por fonte.
class ProviderManager {
  final ProviderRegistry registry;

  /// Carimbo de saúde observado (não é health-check ativo): após uma falha
  /// de rede/timeout, o provider é pulado por [_offlineSkipTtl] para não
  /// penalizar toda busca (ex.: gateway local fora do ar custava 15 s por
  /// pesquisa). Sucesso limpa o carimbo.
  final Map<String, _ProviderHealthStamp> _healthStamps = {};
  static const _offlineSkipTtl = Duration(minutes: 2);

  ProviderManager({required this.registry});

  Future<List<Work>> search(
    String query, {
    WorkType? type,
    String? language,
    String? preferredLanguage,
    int page = 1,
    int pageSize = 20,
    Duration? timeout,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final activeProviders = registry.getActiveProviders().where((provider) {
      if (!provider.capabilities.supportsSearch) return false;
      if (type != null && !provider.capabilities.supportsType(type)) {
        return false;
      }
      if (language != null &&
          !provider.capabilities.supportsLanguage(language) &&
          !provider.capabilities.supportsLanguage(language.split('-').first)) {
        return false;
      }
      return true;
    }).toList();

    final reachableProviders = activeProviders.where((provider) {
      if (_isKnownOffline(provider.id)) {
        AppLogger.debug(
          LogCategory.provider,
          'SEARCH_PROVIDER_SKIP provider=${provider.id} reason=cached-offline',
        );
        return false;
      }
      return true;
    }).toList();

    if (reachableProviders.isEmpty) return [];
    AppLogger.info(
      LogCategory.provider,
      'SEARCH_STARTED query="$cleanQuery" providers=${reachableProviders.length}',
    );

    final futures = reachableProviders.map((provider) async {
      final effectiveTimeout = timeout ?? provider.timeout;
      try {
        final results = await provider
            .search(
              cleanQuery,
              type: type,
              language: language,
              page: page,
              pageSize: pageSize,
            )
            .timeout(effectiveTimeout);
        _healthStamps.remove(provider.id);
        AppLogger.debug(
          LogCategory.provider,
          'SEARCH_PROVIDER_RESULT provider=${provider.id} count=${results.length}',
        );
        return results;
      } on TimeoutException {
        _markOffline(provider.id, 'timeout');
        AppLogger.warn(
          LogCategory.provider,
          'SEARCH_PROVIDER_ERROR provider=${provider.id} reason=timeout seconds=${effectiveTimeout.inSeconds}',
        );
        return <ExternalWorkMetadata>[];
      } catch (error, stack) {
        _markOffline(provider.id, 'error');
        AppLogger.error(
          LogCategory.provider,
          'SEARCH_PROVIDER_ERROR provider=${provider.id} reason=$error',
          error,
          stack,
        );
        return <ExternalWorkMetadata>[];
      }
    });

    final nestedResults = await Future.wait(futures);
    var rawItems = nestedResults.expand((items) => items).toList();

    // Providers podem aproximar filtros; o domínio os reaplica antes do merge.
    if (type != null) {
      rawItems = rawItems.where((item) => item.type == type).toList();
    }
    if (language != null) {
      final expected = _normalizeLanguageCode(language);
      rawItems = rawItems.where((item) {
        return _normalizeLanguageCode(item.language) == expected;
      }).toList();
    }
    if (rawItems.isEmpty) return [];

    final works = WorkIdentitySystem.deduplicateAndMerge(rawItems);
    final sorted = _sortResults(
      works,
      cleanQuery,
      preferredLanguage: preferredLanguage ?? language ?? 'pt-BR',
    );
    AppLogger.info(
      LogCategory.provider,
      'SEARCH_COMPLETED raw=${rawItems.length} works=${sorted.length}',
    );
    return sorted;
  }

  List<Work> _sortResults(
    List<Work> works,
    String query, {
    required String preferredLanguage,
  }) {
    final queryNorm = _normalizeSearchTerm(query);
    final queryWords = queryNorm
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    double score(Work work) {
      var value = 0.0;
      final title = _normalizeSearchTerm(work.title);
      final author = _normalizeSearchTerm(work.author);
      final subtitle = _normalizeSearchTerm(work.subtitle ?? '');
      final series = _normalizeSearchTerm(work.series ?? '');

      if (_normalizeLanguageCode(work.primaryLanguage) ==
          _normalizeLanguageCode(preferredLanguage)) {
        value += 1000;
      }
      if (title == queryNorm) {
        value += 500;
      } else if (title.startsWith(queryNorm)) {
        value += 300;
      } else if (title.contains(queryNorm)) {
        value += 200;
      } else if (queryWords.isNotEmpty &&
          queryWords.every((word) => title.contains(word))) {
        value += 150;
      } else if (queryWords.any((word) => title.contains(word))) {
        value += 50;
      }
      if (author == queryNorm) {
        value += 250;
      } else if (author.contains(queryNorm)) {
        value += 100;
      } else if (queryWords.any((word) => author.contains(word))) {
        value += 40;
      }
      if (subtitle.contains(queryNorm) || series.contains(queryNorm)) {
        value += 30;
      }
      if (work.coverPath?.isNotEmpty == true) value += 15;
      value += work.editions.length.clamp(0, 10);
      return value;
    }

    return List<Work>.from(works)..sort((left, right) {
      final compared = score(right).compareTo(score(left));
      return compared == 0 ? left.title.compareTo(right.title) : compared;
    });
  }

  Future<String?> resolveDownloadUrl({
    required String providerId,
    required String externalId,
    required WorkFormat format,
  }) async {
    final provider = registry.getProvider(providerId);
    if (provider == null || !registry.isProviderEnabled(providerId)) {
      return null;
    }
    try {
      return await provider.resolveDownloadUrl(externalId, format);
    } catch (error, stack) {
      AppLogger.error(
        LogCategory.provider,
        'Falha ao resolver asset em $providerId: $error',
        error,
        stack,
      );
      return null;
    }
  }

  Future<Map<String, ProviderHealth>> checkAllHealth() async {
    final entries = await Future.wait(
      registry.getAllProviders().map((provider) async {
        if (!registry.isProviderEnabled(provider.id)) {
          return MapEntry(provider.id, ProviderHealth.disabled());
        }
        try {
          final health = await provider.checkHealth().timeout(
            const Duration(seconds: 5),
          );
          return MapEntry(provider.id, health);
        } catch (error) {
          return MapEntry(
            provider.id,
            ProviderHealth.offline(message: 'Falha no health check: $error'),
          );
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  bool _isKnownOffline(String providerId) {
    final stamp = _healthStamps[providerId];
    if (stamp == null || stamp.status != ProviderStatus.offline) return false;
    if (DateTime.now().difference(stamp.at) >= _offlineSkipTtl) {
      _healthStamps.remove(providerId);
      return false;
    }
    return true;
  }

  void _markOffline(String providerId, String reason) {
    _healthStamps[providerId] = _ProviderHealthStamp(
      status: ProviderStatus.offline,
      at: DateTime.now(),
      reason: reason,
    );
  }

  static String _normalizeSearchTerm(String text) {
    var clean = WorkIdentitySystem.removeDiacritics(text).toLowerCase();
    clean = clean.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeLanguageCode(String? language) {
    final clean = language?.trim().toLowerCase().replaceAll('_', '-') ?? 'und';
    if (clean.startsWith('pt') || clean == 'por') return 'pt-BR';
    if (clean.startsWith('en') || clean == 'eng') return 'en';
    return 'und';
  }
}

class _ProviderHealthStamp {
  final ProviderStatus status;
  final DateTime at;
  final String reason;

  const _ProviderHealthStamp({
    required this.status,
    required this.at,
    required this.reason,
  });
}

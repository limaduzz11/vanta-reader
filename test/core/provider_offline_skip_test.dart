import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/database/app_database.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/provider_manager.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/core/providers/vanta/vanta_config.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/domain/entities/work.dart';

class _FailingProvider implements ContentProvider {
  int calls = 0;

  @override
  String get id => 'always-down';

  @override
  String get name => 'Always Down';

  @override
  String get version => '1.0.0';

  @override
  Duration get timeout => const Duration(milliseconds: 50);

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        supportsSearch: true,
        supportsDownload: false,
        supportsStreaming: false,
        supportedFormats: {WorkFormat.epub},
        supportedLanguages: {'pt-BR', 'en', 'und'},
        supportedTypes: {WorkType.book, WorkType.comic},
      );

  @override
  Future<ProviderHealth> checkHealth() async =>
      ProviderHealth.offline(message: 'down');

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls++;
    throw Exception('unreachable');
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async => null;

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async =>
      null;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ProviderManager — skip de provider offline', () {
    test('segunda busca não chama provider que falhou (TTL 2 min)', () async {
      final registry = ProviderRegistry();
      final failing = _FailingProvider();
      registry.register(failing);
      final manager = ProviderManager(registry: registry);

      final first = await manager.search('duna');
      expect(first, isEmpty);
      expect(failing.calls, equals(1));

      final sw = Stopwatch()..start();
      final second = await manager.search('duna');
      sw.stop();
      expect(second, isEmpty);
      expect(failing.calls, equals(1),
          reason: 'provider em TTL offline deve ser pulado');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('VantaConfig — precedência e persistência', () {
    test('runtime override vence default', () {
      final before = VantaConfig.runtimeOverride;
      try {
        VantaConfig.runtimeOverride = 'http://127.0.0.1:8081/';
        expect(
          const VantaConfig().effectiveBaseUrl,
          equals('http://127.0.0.1:8081'),
        );
      } finally {
        VantaConfig.runtimeOverride = before;
      }
    });

    test('persist/load round-trip via settings', () async {
      final tempDir = await Directory.systemTemp.createTemp('vanta_gw_');
      final storage = await StorageManager.initialize(
        customRootPath: tempDir.path,
      );
      final database = AppDatabase();
      await database.initialize(customPath: storage.databaseDir.path);
      final before = VantaConfig.runtimeOverride;
      try {
        await VantaConfig.persist(database, 'http://127.0.0.1:8081/');
        VantaConfig.runtimeOverride = null;
        await VantaConfig.loadPersisted(database);
        expect(
          VantaConfig.runtimeOverride,
          equals('http://127.0.0.1:8081'),
        );
        await VantaConfig.persist(database, '  ');
        expect(VantaConfig.runtimeOverride, isNull);
      } finally {
        VantaConfig.runtimeOverride = before;
        await database.close();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/core/providers/provider_registry.dart';
import 'package:vantareader/domain/entities/work.dart';

class _FakeProvider implements ContentProvider {
  @override
  final String id;
  @override
  final String name;

  _FakeProvider(this.id, this.name);

  @override
  String get version => '1.0.0';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProviderHealth> checkHealth() async => ProviderHealth.healthy();

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async => [];

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async => null;

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async => null;
}

void main() {
  group('ProviderRegistry (Fase I - Registro de Provedores)', () {
    late ProviderRegistry registry;
    late _FakeProvider providerA;
    late _FakeProvider providerB;

    setUp(() {
      registry = ProviderRegistry();
      providerA = _FakeProvider('provider-a', 'Provedor A');
      providerB = _FakeProvider('provider-b', 'Provedor B');
    });

    test('registra e recupera provedores corretamente', () {
      registry.register(providerA);
      registry.register(providerB);

      expect(registry.getAllProviders().length, equals(2));
      expect(registry.getProvider('provider-a'), equals(providerA));
      expect(registry.getProvider('provider-b'), equals(providerB));
      expect(registry.getProvider('inexistente'), isNull);
    });

    test('desregistra provedor com sucesso', () {
      registry.register(providerA);
      registry.unregister('provider-a');

      expect(registry.getAllProviders().isEmpty, isTrue);
      expect(registry.getProvider('provider-a'), isNull);
    });

    test('permite ativar e desativar provedores individualmente', () {
      registry.register(providerA, enabled: true);
      registry.register(providerB, enabled: false);

      expect(registry.isProviderEnabled('provider-a'), isTrue);
      expect(registry.isProviderEnabled('provider-b'), isFalse);

      expect(registry.getActiveProviders().length, equals(1));
      expect(registry.getActiveProviders().first.id, equals('provider-a'));

      // Ativa provider B
      registry.setProviderEnabled('provider-b', true);
      expect(registry.getActiveProviders().length, equals(2));

      // Desativa provider A
      registry.setProviderEnabled('provider-a', false);
      expect(registry.getActiveProviders().length, equals(1));
      expect(registry.getActiveProviders().first.id, equals('provider-b'));
    });

    test('clear remove todos os provedores e estados', () {
      registry.register(providerA);
      registry.register(providerB);
      registry.clear();

      expect(registry.getAllProviders().isEmpty, isTrue);
      expect(registry.getActiveProviders().isEmpty, isTrue);
    });
  });
}

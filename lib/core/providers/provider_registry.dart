import 'package:vantareader/core/logging/app_logger.dart';
import 'content_provider.dart';

/// Registro Central de Provedores de Conteúdo
class ProviderRegistry {
  final Map<String, ContentProvider> _providers = {};
  final Map<String, bool> _providerStatus = {};

  /// Registra um novo provedor no sistema
  void register(ContentProvider provider, {bool enabled = true}) {
    _providers[provider.id] = provider;
    _providerStatus[provider.id] = enabled;
    AppLogger.info(
      LogCategory.provider,
      'Provedor registrado: ${provider.name} (${provider.id} v${provider.version}) [Ativo: $enabled]',
    );
  }

  /// Remove um provedor do registro
  void unregister(String providerId) {
    _providers.remove(providerId);
    _providerStatus.remove(providerId);
    AppLogger.info(LogCategory.provider, 'Provedor desregistrado: $providerId');
  }

  /// Recupera provedor por ID
  ContentProvider? getProvider(String providerId) => _providers[providerId];

  /// Lista todos os provedores registrados
  List<ContentProvider> getAllProviders() => _providers.values.toList();

  /// Lista apenas provedores atualmente ativados
  List<ContentProvider> getActiveProviders() {
    return _providers.entries
        .where((entry) => _providerStatus[entry.key] == true)
        .map((entry) => entry.value)
        .toList();
  }

  /// Ativa ou desativa um provedor específico
  void setProviderEnabled(String providerId, bool enabled) {
    if (_providers.containsKey(providerId)) {
      _providerStatus[providerId] = enabled;
      AppLogger.info(
        LogCategory.provider,
        'Provedor $providerId ${enabled ? "ativado" : "desativado"}.',
      );
    }
  }

  /// Verifica se um provedor está ativo
  bool isProviderEnabled(String providerId) {
    return _providerStatus[providerId] ?? false;
  }

  /// Limpa todos os provedores registrados
  void clear() {
    _providers.clear();
    _providerStatus.clear();
  }
}

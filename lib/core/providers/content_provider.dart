import '../../domain/entities/work.dart';
import 'provider_models.dart';

/// Contrato Base e Interface Abstrata para Provedores de Conteúdo do NovaReader
abstract class ContentProvider {
  /// Identificador único imutável do provedor (ex: 'mock-content-provider', 'open-library')
  String get id;

  /// Nome legível para exibição ao usuário
  String get name;

  /// Versão da implementação do provedor
  String get version;

  /// Capacidades declaradas pelo provedor (formatos, busca, rate limit)
  ProviderCapabilities get capabilities;

  /// Tempo limite padrão para operações de rede deste provedor
  Duration get timeout => const Duration(seconds: 10);

  /// Executa diagnóstico de conectividade e integridade do provedor
  Future<ProviderHealth> checkHealth();

  /// Executa pesquisa remota ou simulada com filtros opcionais
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  });

  /// Recupera detalhes completos e edições de uma obra a partir do ID do provedor
  Future<ExternalWorkMetadata?> getDetails(String externalId);

  /// Resolve URL de download direta e assinada para um formato específico
  Future<String?> resolveDownloadUrl(String externalId, WorkFormat format);
}

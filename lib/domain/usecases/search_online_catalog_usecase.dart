import '../../core/providers/provider_manager.dart';
import '../entities/work.dart';

/// Caso de Uso: Executa pesquisa unificada de catálogo através de todos os provedores ativos
class SearchOnlineCatalogUseCase {
  final ProviderManager _providerManager;

  SearchOnlineCatalogUseCase(this._providerManager);

  Future<List<Work>> call(
    String query, {
    WorkType? type,
    String? language,
    String? preferredLanguage,
    int page = 1,
    int pageSize = 20,
    Duration? timeout,
  }) async {
    return await _providerManager.search(
      query,
      type: type,
      language: language,
      preferredLanguage: preferredLanguage,
      page: page,
      pageSize: pageSize,
      timeout: timeout,
    );
  }
}

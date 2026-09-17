import '../entities/work.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Recupera obras da biblioteca local com filtros opcionais
class GetLibraryWorksUseCase {
  final ILibraryRepository _repository;

  GetLibraryWorksUseCase(this._repository);

  Future<List<Work>> call({
    WorkType? filterType,
    String? language,
    bool onlyFavorites = false,
    bool onlyDownloaded = false,
  }) async {
    return _repository.getLibraryWorks(
      filterType: filterType,
      language: language,
      onlyFavorites: onlyFavorites,
      onlyDownloaded: onlyDownloaded,
    );
  }
}

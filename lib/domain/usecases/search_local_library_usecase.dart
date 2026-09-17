import '../entities/work.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Busca rápida offline no SQLite por título, autor ou série
class SearchLocalLibraryUseCase {
  final ILibraryRepository _repository;

  SearchLocalLibraryUseCase(this._repository);

  Future<List<Work>> call(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return _repository.getLibraryWorks();
    }
    return _repository.searchLocal(trimmed);
  }
}

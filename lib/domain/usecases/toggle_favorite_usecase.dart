import '../repositories/i_library_repository.dart';

/// Caso de Uso: Alterna ou consulta o status de favorito de uma obra no banco local
class ToggleFavoriteUseCase {
  final ILibraryRepository _repository;

  ToggleFavoriteUseCase(this._repository);

  Future<bool> execute(String workId) async {
    final currentStatus = await _repository.isFavorite(workId);
    final newStatus = !currentStatus;
    await _repository.toggleFavorite(workId, newStatus);
    return newStatus;
  }

  Future<bool> isFavorite(String workId) async {
    return _repository.isFavorite(workId);
  }
}

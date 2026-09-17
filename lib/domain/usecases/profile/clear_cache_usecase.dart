import '../../repositories/i_profile_repository.dart';

/// Caso de Uso: Executa limpeza segura de arquivos temporários de cache
class ClearCacheUseCase {
  final IProfileRepository _repository;

  const ClearCacheUseCase(this._repository);

  Future<int> call({bool readingCacheOnly = false}) {
    if (readingCacheOnly) {
      return _repository.clearReadingCache();
    }
    return _repository.clearCache();
  }
}

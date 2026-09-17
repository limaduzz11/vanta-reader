import '../entities/reading_progress.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Recupera o progresso de leitura atual de uma obra
class GetReadingProgressUseCase {
  final ILibraryRepository _repository;

  GetReadingProgressUseCase(this._repository);

  Future<ReadingProgress?> call(String workId) async {
    return _repository.getProgress(workId);
  }
}

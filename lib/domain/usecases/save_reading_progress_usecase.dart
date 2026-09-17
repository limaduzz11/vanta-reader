import '../entities/reading_progress.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Persiste o progresso de leitura milimétrico no SQLite
class SaveReadingProgressUseCase {
  final ILibraryRepository _repository;

  SaveReadingProgressUseCase(this._repository);

  Future<void> call(ReadingProgress progress) async {
    await _repository.saveProgress(progress);
  }
}

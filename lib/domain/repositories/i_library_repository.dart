import '../entities/work.dart';
import '../entities/reading_progress.dart';

/// Contrato Abstrato do Repositório de Biblioteca Local
abstract class ILibraryRepository {
  Future<List<Work>> getLibraryWorks({
    WorkType? filterType,
    String? language,
    bool onlyFavorites = false,
    bool onlyDownloaded = false,
  });

  Future<Work?> getWorkById(String id);
  Future<void> saveWork(Work work);
  Future<void> saveWorks(List<Work> works);
  Future<void> deleteWork(String id);

  Future<void> toggleFavorite(String workId, bool isFavorite);
  Future<bool> isFavorite(String workId);

  Future<ReadingProgress?> getProgress(String workId);
  Future<void> saveProgress(ReadingProgress progress);

  Future<List<Work>> searchLocal(String query);

  Future<void> updateEditionFile({
    required String editionId,
    required String filePath,
    required int fileSize,
    required bool isLocal,
  });

  /// Persiste/atualiza um asset de conteúdo real associado a uma edição.
  Future<void> updateContentAsset(ContentAsset asset);

  Future<void> updateLibraryStatus(String workId, String status);

  Future<void> updateCoverPath(String workId, String coverPath);

  Future<void> removeLegacySeedMocks();
}

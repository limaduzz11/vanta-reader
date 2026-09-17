import '../../core/logging/app_logger.dart';
import '../../data/datasources/mock_data.dart';
import '../repositories/i_library_repository.dart';

/// Caso de Uso: Inicializa o acervo inicial no SQLite se a biblioteca estiver vazia
class SeedInitialCatalogUseCase {
  final ILibraryRepository _repository;

  SeedInitialCatalogUseCase(this._repository);

  Future<void> call() async {
    final currentWorks = await _repository.getLibraryWorks();
    if (currentWorks.isNotEmpty) {
      AppLogger.info(
        LogCategory.database,
        'Catálogo local já inicializado (${currentWorks.length} obras no SQLite). Sincronizando capas e edições...',
      );
      for (final work in MockData.allWorks) {
        await _repository.saveWork(work);
      }
      return;
    }

    AppLogger.info(
      LogCategory.database,
      'Semeando catálogo inicial no SQLite (${MockData.allWorks.length} obras)...',
    );

    for (final work in MockData.allWorks) {
      await _repository.saveWork(work);
    }

    for (final progress in MockData.sampleProgressList) {
      await _repository.saveProgress(progress);
    }

    // Marca 2 obras de exemplo como favoritas
    await _repository.toggleFavorite('work-dune', true);
    await _repository.toggleFavorite('work-watchmen', true);

    AppLogger.info(
      LogCategory.database,
      'Semeamento de catálogo concluído com sucesso.',
    );
  }
}

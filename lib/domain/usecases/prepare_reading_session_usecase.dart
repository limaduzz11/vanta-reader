import '../../core/reader/online_reading_manager.dart';
import '../../core/reader/reading_session.dart';
import '../entities/work.dart';

/// Caso de Uso: Prepara uma sessão de leitura híbrida (Local Direto ou Streaming Online)
class PrepareReadingSessionUseCase {
  final OnlineReadingManager onlineReadingManager;

  const PrepareReadingSessionUseCase({required this.onlineReadingManager});

  Future<ReadingSession> call({
    required Work work,
    required WorkEdition edition,
    void Function(double progress)? onProgress,
  }) {
    return onlineReadingManager.prepareSession(
      work: work,
      edition: edition,
      onProgress: onProgress,
    );
  }
}

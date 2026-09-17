import '../../core/reader/online_reading_manager.dart';
import '../../core/reader/reading_session.dart';
import '../entities/work.dart';

/// Caso de Uso: Promove uma edição em buffer de streaming para a biblioteca local permanente
class PromoteReadingSessionUseCase {
  final OnlineReadingManager onlineReadingManager;

  const PromoteReadingSessionUseCase({required this.onlineReadingManager});

  Future<WorkEdition> call(ReadingSession session) {
    return onlineReadingManager.promoteToLocal(session);
  }
}

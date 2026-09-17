import '../../entities/user_profile.dart';
import '../../repositories/i_profile_repository.dart';

/// Caso de Uso: Computa estatísticas agregadas de leitura
class GetReadingStatsUseCase {
  final IProfileRepository _repository;

  const GetReadingStatsUseCase(this._repository);

  Future<ReadingStats> call() => _repository.getReadingStats();
}

import '../../../core/storage/storage_manager.dart';
import '../../repositories/i_profile_repository.dart';

/// Caso de Uso: Calcula uso real de armazenamento físico do dispositivo
class GetStorageUsageUseCase {
  final IProfileRepository _repository;

  const GetStorageUsageUseCase(this._repository);

  Future<StorageUsage> call() => _repository.getStorageUsage();
}

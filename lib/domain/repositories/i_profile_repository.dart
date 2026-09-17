import '../../core/storage/storage_manager.dart';
import '../entities/user_profile.dart';

/// Contrato Abstrato do Repositório de Perfil e Armazenamento (Fase M)
abstract class IProfileRepository {
  Future<UserProfile> getProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<ReadingStats> getReadingStats();
  Future<StorageUsage> getStorageUsage();
  Future<int> clearCache();
  Future<int> clearReadingCache();
}

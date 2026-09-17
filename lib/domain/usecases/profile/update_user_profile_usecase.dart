import '../../entities/user_profile.dart';
import '../../repositories/i_profile_repository.dart';

/// Caso de Uso: Atualiza o perfil e preferências do usuário local
class UpdateUserProfileUseCase {
  final IProfileRepository _repository;

  const UpdateUserProfileUseCase(this._repository);

  Future<void> call(UserProfile profile) => _repository.saveProfile(profile);
}

import '../../entities/user_profile.dart';
import '../../repositories/i_profile_repository.dart';

/// Caso de Uso: Recupera o perfil e preferências do usuário local
class GetUserProfileUseCase {
  final IProfileRepository _repository;

  const GetUserProfileUseCase(this._repository);

  Future<UserProfile> call() => _repository.getProfile();
}

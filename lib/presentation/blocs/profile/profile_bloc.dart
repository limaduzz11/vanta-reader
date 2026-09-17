import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/usecases/profile/clear_cache_usecase.dart';
import '../../../domain/usecases/profile/get_reading_stats_usecase.dart';
import '../../../domain/usecases/profile/get_storage_usage_usecase.dart';
import '../../../domain/usecases/profile/get_user_profile_usecase.dart';
import '../../../domain/usecases/profile/update_user_profile_usecase.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC para Gerenciamento de Perfil, Estatísticas e Armazenamento (Fase M)
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserProfileUseCase getProfile;
  final UpdateUserProfileUseCase updateProfile;
  final GetReadingStatsUseCase getStats;
  final GetStorageUsageUseCase getStorageUsage;
  final ClearCacheUseCase clearCache;

  ProfileBloc({
    required this.getProfile,
    required this.updateProfile,
    required this.getStats,
    required this.getStorageUsage,
    required this.clearCache,
    ProfileState initialState = const ProfileInitial(),
  }) : super(initialState) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<UpdateProfileNameEvent>(_onUpdateProfileName);
    on<UpdateAvatarEvent>(_onUpdateAvatar);
    on<UpdatePreferencesEvent>(_onUpdatePreferences);
    on<RefreshStatsEvent>(_onRefreshStats);
    on<LoadStorageUsageEvent>(_onLoadStorageUsage);
    on<ClearCacheEvent>(_onClearCache);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profile = await getProfile();
      final stats = await getStats();
      final storageUsage = await getStorageUsage();

      emit(
        ProfileLoaded(
          profile: profile,
          stats: stats,
          storageUsage: storageUsage,
        ),
      );
    } catch (e, st) {
      AppLogger.error(LogCategory.app, 'Erro ao carregar perfil: $e', e, st);
      emit(ProfileError('Falha ao carregar perfil: $e'));
    }
  }

  Future<void> _onUpdateProfileName(
    UpdateProfileNameEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    final trimmed = event.newName.trim();
    if (trimmed.isEmpty) return;

    try {
      final updated = currentState.profile.copyWith(name: trimmed);
      await updateProfile(updated);
      emit(
        currentState.copyWith(
          profile: updated,
          feedbackMessage: 'Nome atualizado para "$trimmed"',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(feedbackMessage: 'Erro ao atualizar nome: $e'),
      );
    }
  }

  Future<void> _onUpdateAvatar(
    UpdateAvatarEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      final updated = currentState.profile.copyWith(avatarId: event.avatarId);
      await updateProfile(updated);
      emit(
        currentState.copyWith(
          profile: updated,
          feedbackMessage: 'Avatar atualizado com sucesso',
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(feedbackMessage: 'Erro ao trocar avatar: $e'));
    }
  }

  Future<void> _onUpdatePreferences(
    UpdatePreferencesEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      final updated = currentState.profile.copyWith(
        fontSize: event.fontSize,
        fontFamily: event.fontFamily,
        readingMode: event.readingMode,
        maxConcurrentDownloads: event.maxConcurrentDownloads,
        preferredLanguage: event.preferredLanguage,
        accentColor: event.accentColor,
      );
      await updateProfile(updated);
      emit(
        currentState.copyWith(
          profile: updated,
          feedbackMessage: 'Preferências salvas com sucesso',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          feedbackMessage: 'Erro ao salvar preferências: $e',
        ),
      );
    }
  }

  Future<void> _onRefreshStats(
    RefreshStatsEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      final stats = await getStats();
      final storageUsage = await getStorageUsage();
      emit(currentState.copyWith(stats: stats, storageUsage: storageUsage));
    } catch (_) {}
  }

  Future<void> _onLoadStorageUsage(
    LoadStorageUsageEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      final storageUsage = await getStorageUsage();
      emit(currentState.copyWith(storageUsage: storageUsage));
    } catch (_) {}
  }

  Future<void> _onClearCache(
    ClearCacheEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(currentState.copyWith(isClearingCache: true));

    try {
      final bytesFreed = await clearCache(
        readingCacheOnly: event.readingCacheOnly,
      );
      final refreshedStorage = await getStorageUsage();

      final formattedFreed = _formatBytes(bytesFreed);
      final msg = event.readingCacheOnly
          ? 'Cache de leitura limpo com sucesso! ($formattedFreed liberados)'
          : 'Cache completo limpo com sucesso! ($formattedFreed liberados)';

      emit(
        currentState.copyWith(
          storageUsage: refreshedStorage,
          isClearingCache: false,
          feedbackMessage: msg,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isClearingCache: false,
          feedbackMessage: 'Falha ao limpar cache: $e',
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

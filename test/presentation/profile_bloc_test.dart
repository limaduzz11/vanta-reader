import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/domain/entities/user_profile.dart';
import 'package:vantareader/domain/repositories/i_profile_repository.dart';
import 'package:vantareader/domain/usecases/profile/clear_cache_usecase.dart';
import 'package:vantareader/domain/usecases/profile/get_reading_stats_usecase.dart';
import 'package:vantareader/domain/usecases/profile/get_storage_usage_usecase.dart';
import 'package:vantareader/domain/usecases/profile/get_user_profile_usecase.dart';
import 'package:vantareader/domain/usecases/profile/update_user_profile_usecase.dart';
import 'package:vantareader/presentation/blocs/profile/profile_bloc.dart';
import 'package:vantareader/presentation/blocs/profile/profile_event.dart';
import 'package:vantareader/presentation/blocs/profile/profile_state.dart';

class FakeProfileRepository implements IProfileRepository {
  UserProfile profile = UserProfile(
    id: 'primary_profile',
    name: 'Leitor',
    avatarId: 'nova_monolith',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  ReadingStats stats = const ReadingStats(
    booksRead: 5,
    comicsRead: 2,
    currentlyReading: 1,
    totalFavorites: 3,
    totalDownloaded: 4,
    totalPagesRead: 1200,
  );

  StorageUsage storageUsage = const StorageUsage(
    booksBytes: 1048576,
    comicsBytes: 2097152,
    coversBytes: 524288,
    thumbnailsBytes: 131072,
    cacheBytes: 262144,
    databaseBytes: 65536,
  );

  @override
  Future<UserProfile> getProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile newProfile) async {
    profile = newProfile;
  }

  @override
  Future<ReadingStats> getReadingStats() async => stats;

  @override
  Future<StorageUsage> getStorageUsage() async => storageUsage;

  @override
  Future<int> clearCache() async {
    final freed = storageUsage.cacheBytes;
    storageUsage = StorageUsage(
      booksBytes: storageUsage.booksBytes,
      comicsBytes: storageUsage.comicsBytes,
      coversBytes: storageUsage.coversBytes,
      thumbnailsBytes: storageUsage.thumbnailsBytes,
      cacheBytes: 0,
      databaseBytes: storageUsage.databaseBytes,
    );
    return freed;
  }

  @override
  Future<int> clearReadingCache() async {
    final freed = storageUsage.cacheBytes;
    storageUsage = StorageUsage(
      booksBytes: storageUsage.booksBytes,
      comicsBytes: storageUsage.comicsBytes,
      coversBytes: storageUsage.coversBytes,
      thumbnailsBytes: storageUsage.thumbnailsBytes,
      cacheBytes: 0,
      databaseBytes: storageUsage.databaseBytes,
    );
    return freed;
  }
}

void main() {
  late FakeProfileRepository repository;
  late ProfileBloc bloc;

  setUp(() {
    repository = FakeProfileRepository();
    bloc = ProfileBloc(
      getProfile: GetUserProfileUseCase(repository),
      updateProfile: UpdateUserProfileUseCase(repository),
      getStats: GetReadingStatsUseCase(repository),
      getStorageUsage: GetStorageUsageUseCase(repository),
      clearCache: ClearCacheUseCase(repository),
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('ProfileBloc (Fase M)', () {
    test('estado inicial é ProfileInitial', () {
      expect(bloc.state, isA<ProfileInitial>());
    });

    test(
      'LoadProfileEvent emite ProfileLoading e depois ProfileLoaded',
      () async {
        final states = <ProfileState>[];
        bloc.stream.listen(states.add);

        bloc.add(const LoadProfileEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states.length, equals(2));
        expect(states[0], isA<ProfileLoading>());
        expect(states[1], isA<ProfileLoaded>());

        final loaded = states[1] as ProfileLoaded;
        expect(loaded.profile.name, equals('Leitor'));
        expect(loaded.stats.booksRead, equals(5));
        expect(loaded.storageUsage.booksBytes, equals(1048576));
      },
    );

    test(
      'UpdateProfileNameEvent altera o nome no perfil e emite feedback',
      () async {
        bloc.add(const LoadProfileEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        bloc.add(const UpdateProfileNameEvent('Leitor VIP'));
        await Future.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as ProfileLoaded;
        expect(state.profile.name, equals('Leitor VIP'));
        expect(state.feedbackMessage, contains('Leitor VIP'));
        expect(repository.profile.name, equals('Leitor VIP'));
      },
    );

    test('UpdateAvatarEvent atualiza o avatar e emite feedback', () async {
      bloc.add(const LoadProfileEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const UpdateAvatarEvent('nova_prism'));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as ProfileLoaded;
      expect(state.profile.avatarId, equals('nova_prism'));
      expect(repository.profile.avatarId, equals('nova_prism'));
    });

    test(
      'UpdatePreferencesEvent atualiza preferências de leitura e download',
      () async {
        bloc.add(const LoadProfileEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        bloc.add(
          const UpdatePreferencesEvent(
            fontSize: 18.0,
            readingMode: 'continuous',
            preferredLanguage: 'en',
            maxConcurrentDownloads: 4,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as ProfileLoaded;
        expect(state.profile.fontSize, equals(18.0));
        expect(state.profile.readingMode, equals('continuous'));
        expect(state.profile.preferredLanguage, equals('en'));
        expect(state.profile.maxConcurrentDownloads, equals(4));
      },
    );

    test(
      'ClearCacheEvent limpa cache, atualiza armazenamento e emite feedback de bytes liberados',
      () async {
        bloc.add(const LoadProfileEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        bloc.add(const ClearCacheEvent(readingCacheOnly: true));
        await Future.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as ProfileLoaded;
        expect(state.storageUsage.cacheBytes, equals(0));
        expect(
          state.feedbackMessage,
          contains('Cache de leitura limpo com sucesso'),
        );
        expect(state.isClearingCache, isFalse);
      },
    );
  });
}

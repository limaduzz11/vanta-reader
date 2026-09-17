import 'package:flutter/material.dart';
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
import 'package:vantareader/presentation/blocs/profile/profile_state.dart';
import 'package:vantareader/presentation/screens/profile_screen.dart';

class MockProfileRepoForWidgetTest implements IProfileRepository {
  UserProfile profile = UserProfile(
    id: 'primary_profile',
    name: 'Leitor',
    avatarId: 'nova_monolith',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  ReadingStats stats = const ReadingStats(
    booksRead: 10,
    comicsRead: 5,
    currentlyReading: 2,
    totalFavorites: 7,
    totalDownloaded: 8,
    totalPagesRead: 2500,
  );

  StorageUsage usage = const StorageUsage(
    booksBytes: 10485760, // 10 MB
    comicsBytes: 20971520, // 20 MB
    coversBytes: 1048576, // 1 MB
    thumbnailsBytes: 524288, // 512 KB
    cacheBytes: 2097152, // 2 MB
    databaseBytes: 65536, // 64 KB
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
  Future<StorageUsage> getStorageUsage() async => usage;

  @override
  Future<int> clearCache() async => 2097152;

  @override
  Future<int> clearReadingCache() async => 2097152;
}

void main() {
  late MockProfileRepoForWidgetTest repo;
  late ProfileBloc bloc;

  setUp(() {
    repo = MockProfileRepoForWidgetTest();
    bloc = ProfileBloc(
      getProfile: GetUserProfileUseCase(repo),
      updateProfile: UpdateUserProfileUseCase(repo),
      getStats: GetReadingStatsUseCase(repo),
      getStorageUsage: GetStorageUsageUseCase(repo),
      clearCache: ClearCacheUseCase(repo),
      initialState: ProfileLoaded(
        profile: repo.profile,
        stats: repo.stats,
        storageUsage: repo.usage,
      ),
    );
  });

  tearDown(() {
    bloc.close();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(home: ProfileScreen(bloc: bloc));
  }

  group('ProfileScreen (Fase M - Widget Test)', () {
    testWidgets(
      'renderiza perfil com nome, avatar, estatísticas e armazenamento',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Perfil & Preferências'), findsOneWidget);
        expect(find.text('Leitor'), findsOneWidget);
        expect(find.text('Perfil Local • Modo Offline'), findsOneWidget);

        // Estatísticas
        expect(find.text('Livros Lidos'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expect(find.text('HQs Lidas'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Em Andamento'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Favoritos'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);

        // Preferências
        expect(find.text('Tamanho de Fonte do Leitor'), findsOneWidget);
        expect(find.text('Modo de Leitura Padrão'), findsOneWidget);
        expect(find.text('Idioma de Descoberta'), findsOneWidget);

        // Armazenamento
        expect(find.text('ARMAZENAMENTO DO DISPOSITIVO'), findsOneWidget);
        expect(find.text('Limpar Cache de Streaming'), findsOneWidget);
      },
    );

    testWidgets('abre modal de seleção de avatar ao clicar em Trocar Avatar', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final trocarAvatarBtn = find.text('Trocar Avatar');
      expect(trocarAvatarBtn, findsOneWidget);
      await tester.tap(trocarAvatarBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CATÁLOGO DE AVATARES MONOCROMÁTICOS'), findsOneWidget);
    });

    testWidgets(
      'abre diálogo de alteração de nome ao clicar no botão de editar',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final editNameBtn = find.byTooltip('Editar Nome');
        expect(editNameBtn, findsOneWidget);
        await tester.tap(editNameBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Alterar Nome'), findsOneWidget);
        expect(find.text('CANCELAR'), findsOneWidget);
        expect(find.text('SALVAR'), findsOneWidget);
      },
    );
  });
}

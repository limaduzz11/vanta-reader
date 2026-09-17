import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/storage_manager.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_profile_repository.dart';

/// Repositório Concreto de Perfil, Preferências e Armazenamento baseado em SQLite (Fase M)
class ProfileRepository implements IProfileRepository {
  final AppDatabase _appDatabase;
  final StorageManager? storageManager;

  ProfileRepository(this._appDatabase, {this.storageManager});

  Database get _db => _appDatabase.db;

  static const String _defaultProfileId = 'primary_profile';

  @override
  Future<UserProfile> getProfile() async {
    final rows = await _db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [_defaultProfileId],
    );
    if (rows.isNotEmpty) {
      final r = rows.first;
      return UserProfile(
        id: r['id'] as String,
        name: r['name'] as String,
        avatarId: r['avatar_id'] as String,
        preferredLanguage: r['preferred_language'] as String? ?? 'pt-BR',
        fontSize: (r['font_size'] as num?)?.toDouble() ?? 16.0,
        fontFamily: r['font_family'] as String? ?? 'Inter',
        readingMode: r['reading_mode'] as String? ?? 'paged',
        maxConcurrentDownloads: (r['max_concurrent_downloads'] as int?) ?? 2,
        accentColor: r['accent_color'] as String? ?? 'grafite',
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
      );
    }

    // Perfil inicial padrão local (Leitor)
    final defaultProfile = UserProfile(
      id: _defaultProfileId,
      name: 'Leitor',
      avatarId: 'nova_monolith',
      preferredLanguage: 'pt-BR',
      fontSize: 16.0,
      fontFamily: 'Inter',
      readingMode: 'paged',
      maxConcurrentDownloads: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveProfile(defaultProfile);
    return defaultProfile;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _db.insert('profiles', {
      'id': profile.id,
      'name': profile.name,
      'avatar_id': profile.avatarId,
      'preferred_language': profile.preferredLanguage,
      'font_size': profile.fontSize,
      'font_family': profile.fontFamily,
      'reading_mode': profile.readingMode,
      'max_concurrent_downloads': profile.maxConcurrentDownloads,
      'accent_color': profile.accentColor,
      'created_at': profile.createdAt.millisecondsSinceEpoch,
      'updated_at': profile.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<ReadingStats> getReadingStats() async {
    // Escala CANÔNICA: percentage em 0.0–1.0 (concluído >= 0.999)
    // 1. Livros lidos (type = 'book' e percentage >= 0.999)
    final booksReadResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT w.id) as count
      FROM works w
      JOIN reading_progress rp ON w.id = rp.work_id
      WHERE w.type = 'book' AND rp.percentage >= 0.999
    ''');
    final booksRead = Sqflite.firstIntValue(booksReadResult) ?? 0;

    // 2. HQs lidas (type = 'comic' e percentage >= 0.999)
    final comicsReadResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT w.id) as count
      FROM works w
      JOIN reading_progress rp ON w.id = rp.work_id
      WHERE w.type = 'comic' AND rp.percentage >= 0.999
    ''');
    final comicsRead = Sqflite.firstIntValue(comicsReadResult) ?? 0;

    // 3. Em andamento (0 < percentage < 0.999)
    final inProgressResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT work_id) as count
      FROM reading_progress
      WHERE percentage > 0.0 AND percentage < 0.999
    ''');
    final currentlyReading = Sqflite.firstIntValue(inProgressResult) ?? 0;

    // 4. Favoritos
    final favResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM library WHERE is_favorite = 1
    ''');
    final totalFavorites = Sqflite.firstIntValue(favResult) ?? 0;

    // 5. Total de obras com download local concluído
    final downloadedResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT work_id) as count
      FROM work_editions
      WHERE is_local = 1
    ''');
    final totalDownloaded = Sqflite.firstIntValue(downloadedResult) ?? 0;

    // 6. Total acumulado de páginas lidas
    final pagesResult = await _db.rawQuery('''
      SELECT SUM(current_page) as total
      FROM reading_progress
    ''');
    final totalPagesRead = Sqflite.firstIntValue(pagesResult) ?? 0;

    return ReadingStats(
      booksRead: booksRead,
      comicsRead: comicsRead,
      currentlyReading: currentlyReading,
      totalFavorites: totalFavorites,
      totalDownloaded: totalDownloaded,
      totalPagesRead: totalPagesRead,
    );
  }

  @override
  Future<StorageUsage> getStorageUsage() async {
    if (storageManager != null) {
      return await storageManager!.calculateUsage();
    }
    return const StorageUsage(
      booksBytes: 0,
      comicsBytes: 0,
      coversBytes: 0,
      thumbnailsBytes: 0,
      cacheBytes: 0,
      databaseBytes: 0,
    );
  }

  @override
  Future<int> clearCache() async {
    if (storageManager != null) {
      return await storageManager!.clearCache();
    }
    return 0;
  }

  @override
  Future<int> clearReadingCache() async {
    if (storageManager != null) {
      return await storageManager!.clearReadingCache();
    }
    return 0;
  }
}

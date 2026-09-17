import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/work.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/i_library_repository.dart';

/// Implementação Concreta do Repositório de Biblioteca baseado em SQLite
class LibraryRepository implements ILibraryRepository {
  final AppDatabase _appDatabase;

  LibraryRepository(this._appDatabase);

  Database get _db => _appDatabase.db;

  @override
  Future<List<Work>> getLibraryWorks({
    WorkType? filterType,
    String? language,
    bool onlyFavorites = false,
    bool onlyDownloaded = false,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    String query = '''
      SELECT w.*, l.status as lib_status, l.is_favorite
      FROM works w
      JOIN library l ON w.id = l.work_id
    ''';

    if (filterType != null) {
      whereClauses.add('w.type = ?');
      whereArgs.add(filterType.code);
    }
    if (language != null) {
      whereClauses.add('w.primary_language = ?');
      whereArgs.add(language);
    }
    if (onlyFavorites) {
      whereClauses.add('l.is_favorite = 1');
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }
    query += ' ORDER BY l.last_accessed_at DESC, l.added_at DESC';

    final rows = await _db.rawQuery(query, whereArgs);
    final workIds = rows.map((r) => r['id'] as String).toList();
    final editionsMap = await _getEditionsForWorks(workIds);

    final works = <Work>[];
    for (final row in rows) {
      final workId = row['id'] as String;
      final editions = editionsMap[workId] ?? const [];
      if (onlyDownloaded && !editions.any((e) => e.isLocal)) {
        continue;
      }
      works.add(_mapRowToWork(row, editions));
    }

    return works;
  }

  @override
  Future<Work?> getWorkById(String id) async {
    final rows = await _db.query(
      'works',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final editions = await _getEditionsForWork(id);
    return _mapRowToWork(rows.first, editions);
  }

  @override
  Future<void> saveWork(Work work) async {
    await _db.transaction((txn) async {
      await txn.insert('works', {
        'id': work.id,
        'work_key': work.workKey,
        'title': work.title,
        'subtitle': work.subtitle,
        'author': work.author,
        'description': work.description,
        'primary_language': work.primaryLanguage,
        'type': work.type.code,
        'series': work.series,
        'volume': work.volume,
        'publisher': work.publisher,
        'published_date': work.publishedDate,
        'isbn': work.isbn,
        'cover_path': work.coverPath,
        'created_at': work.createdAt.millisecondsSinceEpoch,
        'updated_at': work.updatedAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Salva / atualiza edições
      for (final edition in work.editions) {
        await txn.insert('work_editions', {
          'id': edition.id,
          'work_id': work.id,
          'format': edition.format.extension,
          'file_path': edition.filePath,
          'file_size': edition.fileSize,
          'page_count': edition.pageCount,
          'checksum': edition.checksum,
          'download_url': edition.downloadUrl,
          'provider_id': edition.providerId,
          'is_local': edition.isLocal ? 1 : 0,
          'external_id': edition.externalId,
          'language': edition.language,
          'original_title': edition.originalTitle,
          'localized_title': edition.localizedTitle,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _insertContentAssets(txn, work.id, edition);
      }

      // Garante entrada na biblioteca
      await txn.insert('library', {
        'work_id': work.id,
        'status': 'added',
        'is_favorite': 0,
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'last_accessed_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  @override
  Future<void> saveWorks(List<Work> works) async {
    if (works.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final work in works) {
        batch.insert('works', {
          'id': work.id,
          'work_key': work.workKey,
          'title': work.title,
          'subtitle': work.subtitle,
          'author': work.author,
          'description': work.description,
          'primary_language': work.primaryLanguage,
          'type': work.type.code,
          'series': work.series,
          'volume': work.volume,
          'publisher': work.publisher,
          'published_date': work.publishedDate,
          'isbn': work.isbn,
          'cover_path': work.coverPath,
          'created_at': work.createdAt.millisecondsSinceEpoch,
          'updated_at': work.updatedAt.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        for (final edition in work.editions) {
          batch.insert('work_editions', {
            'id': edition.id,
            'work_id': work.id,
            'format': edition.format.extension,
            'file_path': edition.filePath,
            'file_size': edition.fileSize,
            'page_count': edition.pageCount,
            'checksum': edition.checksum,
            'download_url': edition.downloadUrl,
            'provider_id': edition.providerId,
            'is_local': edition.isLocal ? 1 : 0,
            'external_id': edition.externalId,
            'language': edition.language,
            'original_title': edition.originalTitle,
            'localized_title': edition.localizedTitle,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          for (final asset in edition.contentAssets) {
            batch.insert('content_assets', {
              'id': asset.id,
              'edition_id': edition.id,
              'format': asset.format.extension,
              'status': asset.status.code,
              'remote_url': asset.remoteUrl,
              'local_path': asset.localPath,
              'media_type': asset.mediaType,
              'file_size': asset.fileSize,
              'checksum': asset.checksum,
              'checksum_algorithm': asset.checksumAlgorithm,
              'source': asset.source,
              'verified_at': asset.verifiedAt?.millisecondsSinceEpoch,
              'created_at': asset.createdAt.millisecondsSinceEpoch,
              'updated_at': asset.updatedAt.millisecondsSinceEpoch,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        batch.insert('library', {
          'work_id': work.id,
          'status': 'added',
          'is_favorite': 0,
          'added_at': now,
          'last_accessed_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteWork(String id) async {
    await _db.delete('works', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> toggleFavorite(String workId, bool isFavorite) async {
    await _db.update(
      'library',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'work_id = ?',
      whereArgs: [workId],
    );
  }

  @override
  Future<bool> isFavorite(String workId) async {
    final rows = await _db.query(
      'library',
      columns: ['is_favorite'],
      where: 'work_id = ?',
      whereArgs: [workId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['is_favorite'] as int?) == 1;
  }

  @override
  Future<ReadingProgress?> getProgress(String workId) async {
    final rows = await _db.query(
      'reading_progress',
      where: 'work_id = ?',
      whereArgs: [workId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ReadingProgress(
      workId: row['work_id'] as String,
      editionId: row['edition_id'] as String,
      chapterId: row['chapter_id'] as String?,
      currentPage: row['current_page'] as int,
      totalPages: row['total_pages'] as int,
      charOffset: row['char_offset'] as int? ?? 0,
      percentage: (row['percentage'] as num).toDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    final existing = await _db.query(
      'works',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [progress.workId],
      limit: 1,
    );
    if (existing.isEmpty) {
      // Regra de identidade: NUNCA criar obra fantasma ("Obra Online"/
      // "Desconhecido") por causa de progresso. Sem obra persistentída não há
      // progresso a persistir; o Aviso é registrado e o retorno é silencioso
      // (callers leem como best-effort).
      AppLogger.warn(
        LogCategory.database,
        'Progresso ignorado: obra ${progress.workId} não existe na biblioteca local.',
      );
      return;
    }

    await _db.insert('reading_progress', {
      'work_id': progress.workId,
      'edition_id': progress.editionId,
      'chapter_id': progress.chapterId,
      'current_page': progress.currentPage,
      'total_pages': progress.totalPages,
      'char_offset': progress.charOffset,
      'percentage': progress.percentage,
      'updated_at': progress.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Atualiza last_accessed_at na library
    await _db.update(
      'library',
      {'last_accessed_at': DateTime.now().millisecondsSinceEpoch},
      where: 'work_id = ?',
      whereArgs: [progress.workId],
    );
  }

  @override
  Future<List<Work>> searchLocal(String query) async {
    final sanitized = '%${query.trim().toLowerCase()}%';
    final rows = await _db.rawQuery(
      '''
      SELECT w.* FROM works w
      JOIN library l ON w.id = l.work_id
      WHERE LOWER(w.title) LIKE ? OR LOWER(w.author) LIKE ? OR LOWER(w.series) LIKE ?
      ORDER BY w.title ASC
      ''',
      [sanitized, sanitized, sanitized],
    );

    final workIds = rows.map((r) => r['id'] as String).toList();
    final editionsMap = await _getEditionsForWorks(workIds);

    final works = <Work>[];
    for (final row in rows) {
      final workId = row['id'] as String;
      final editions = editionsMap[workId] ?? const [];
      works.add(_mapRowToWork(row, editions));
    }
    return works;
  }

  Future<Map<String, List<WorkEdition>>> _getEditionsForWorks(
    List<String> workIds,
  ) async {
    if (workIds.isEmpty) return {};
    final map = <String, List<WorkEdition>>{};
    for (var i = 0; i < workIds.length; i += 500) {
      final end = (i + 500 > workIds.length) ? workIds.length : i + 500;
      final chunk = workIds.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT * FROM work_editions WHERE work_id IN ($placeholders)',
        chunk,
      );
      final assetsMap = await _getContentAssetsForEditions(
        rows.map((row) => row['id'] as String).toList(),
      );
      for (final row in rows) {
        final wId = row['work_id'] as String;
        final edition = _mapRowToEdition(row);
        final assets = assetsMap[edition.id] ?? const <ContentAsset>[];
        map
            .putIfAbsent(wId, () => [])
            .add(
              assets.isNotEmpty
                  ? edition.copyWith(contentAssets: assets)
                  : edition,
            );
      }
    }
    return map;
  }

  Future<void> _insertContentAssets(
    Transaction txn,
    String workId,
    WorkEdition edition,
  ) async {
    for (final asset in edition.contentAssets) {
      await txn.insert('content_assets', {
        'id': asset.id,
        'edition_id': edition.id,
        'format': asset.format.extension,
        'status': asset.status.code,
        'remote_url': asset.remoteUrl,
        'local_path': asset.localPath,
        'media_type': asset.mediaType,
        'file_size': asset.fileSize,
        'checksum': asset.checksum,
        'checksum_algorithm': asset.checksumAlgorithm,
        'source': asset.source,
        'verified_at': asset.verifiedAt?.millisecondsSinceEpoch,
        'created_at': asset.createdAt.millisecondsSinceEpoch,
        'updated_at': asset.updatedAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> updateContentAsset(ContentAsset asset) async {
    await _db.insert('content_assets', {
      'id': asset.id,
      'edition_id': asset.editionId,
      'format': asset.format.extension,
      'status': asset.status.code,
      'remote_url': asset.remoteUrl,
      'local_path': asset.localPath,
      'media_type': asset.mediaType,
      'file_size': asset.fileSize,
      'checksum': asset.checksum,
      'checksum_algorithm': asset.checksumAlgorithm,
      'source': asset.source,
      'verified_at': asset.verifiedAt?.millisecondsSinceEpoch,
      'created_at': asset.createdAt.millisecondsSinceEpoch,
      'updated_at': asset.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, List<ContentAsset>>> _getContentAssetsForEditions(
    List<String> editionIds,
  ) async {
    if (editionIds.isEmpty) return const {};
    final map = <String, List<ContentAsset>>{};
    for (var i = 0; i < editionIds.length; i += 500) {
      final end = (i + 500 > editionIds.length) ? editionIds.length : i + 500;
      final chunk = editionIds.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT * FROM content_assets WHERE edition_id IN ($placeholders) ORDER BY created_at ASC',
        chunk,
      );
      for (final row in rows) {
        final asset = _mapRowToContentAsset(row);
        map.putIfAbsent(asset.editionId, () => []).add(asset);
      }
    }
    return map;
  }

  ContentAsset _mapRowToContentAsset(Map<String, dynamic> r) {
    return ContentAsset(
      id: r['id'] as String,
      editionId: r['edition_id'] as String,
      format: WorkFormat.fromExtension(r['format'] as String),
      status: ContentAssetStatus.fromCode(r['status'] as String? ?? 'none'),
      remoteUrl: r['remote_url'] as String?,
      localPath: r['local_path'] as String?,
      mediaType: r['media_type'] as String?,
      fileSize: r['file_size'] as int? ?? 0,
      checksum: r['checksum'] as String?,
      checksumAlgorithm: r['checksum_algorithm'] as String?,
      source: r['source'] as String?,
      verifiedAt: r['verified_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(r['verified_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
    );
  }

  WorkEdition _mapRowToEdition(Map<String, dynamic> r) {
    return WorkEdition(
      id: r['id'] as String,
      workId: r['work_id'] as String,
      format: WorkFormat.fromExtension(r['format'] as String),
      filePath: r['file_path'] as String?,
      fileSize: r['file_size'] as int? ?? 0,
      pageCount: r['page_count'] as int? ?? 0,
      checksum: r['checksum'] as String?,
      downloadUrl: r['download_url'] as String?,
      providerId: r['provider_id'] as String?,
      isLocal: (r['is_local'] as int? ?? 0) == 1,
      externalId: r['external_id'] as String?,
      language: r['language'] as String?,
      originalTitle: r['original_title'] as String?,
      localizedTitle: r['localized_title'] as String?,
    );
  }

  Future<List<WorkEdition>> _getEditionsForWork(String workId) async {
    final rows = await _db.query(
      'work_editions',
      where: 'work_id = ?',
      whereArgs: [workId],
    );
    final assetsMap = await _getContentAssetsForEditions(
      rows.map((row) => row['id'] as String).toList(),
    );
    final editions = <WorkEdition>[];
    for (final row in rows) {
      final edition = _mapRowToEdition(row);
      final assets = assetsMap[edition.id] ?? const <ContentAsset>[];
      editions.add(
        assets.isNotEmpty ? edition.copyWith(contentAssets: assets) : edition,
      );
    }
    return editions;
  }

  Work _mapRowToWork(Map<String, dynamic> row, List<WorkEdition> editions) {
    return Work(
      id: row['id'] as String,
      workKey: row['work_key'] as String,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String?,
      author: row['author'] as String,
      description: row['description'] as String?,
      primaryLanguage: row['primary_language'] as String,
      type: WorkType.fromString(row['type'] as String),
      series: row['series'] as String?,
      volume: row['volume'] as String?,
      publisher: row['publisher'] as String?,
      publishedDate: row['published_date'] as String?,
      isbn: row['isbn'] as String?,
      coverPath: row['cover_path'] as String?,
      editions: editions,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  @override
  Future<void> updateEditionFile({
    required String editionId,
    required String filePath,
    required int fileSize,
    required bool isLocal,
  }) async {
    await _db.update(
      'work_editions',
      {
        'file_path': filePath,
        'file_size': fileSize,
        'is_local': isLocal ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [editionId],
    );
  }

  @override
  Future<void> updateLibraryStatus(String workId, String status) async {
    await _db.update(
      'library',
      {
        'status': status,
        'last_accessed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'work_id = ?',
      whereArgs: [workId],
    );
  }

  @override
  Future<void> updateCoverPath(String workId, String coverPath) async {
    await _db.update(
      'works',
      {
        'cover_path': coverPath,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [workId],
    );
  }

  /// Remove da biblioteca local quaisquer obras semeadas por mocks legados que não tenham sido baixadas
  @override
  Future<void> removeLegacySeedMocks() async {
    const legacyMockIds = [
      'work-dune',
      'work-watchmen',
      'work-cleancode',
      'work-sandman',
      'work-neuromancer',
      'work-domcasmurro',
    ];
    for (final mockId in legacyMockIds) {
      final downloadedEditions = await _db.query(
        'work_editions',
        where: 'work_id = ? AND is_local = 1',
        whereArgs: [mockId],
      );
      if (downloadedEditions.isEmpty) {
        await _db.delete('library', where: 'work_id = ?', whereArgs: [mockId]);
        await _db.delete('works', where: 'id = ?', whereArgs: [mockId]);
      }
    }
  }
}

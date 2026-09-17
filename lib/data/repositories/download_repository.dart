import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/repositories/i_download_repository.dart';

/// Repositório Concreto de Downloads baseado em SQLite
class DownloadRepository implements IDownloadRepository {
  final AppDatabase _appDatabase;

  DownloadRepository(this._appDatabase);

  Database get _db => _appDatabase.db;

  @override
  Future<List<DownloadItem>> getAllDownloads() async {
    final rows = await _db.query('downloads', orderBy: 'created_at DESC');
    return rows.map(_mapRowToDownload).toList();
  }

  @override
  Future<DownloadItem?> getDownloadById(String id) async {
    final rows = await _db.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToDownload(rows.first);
  }

  @override
  Future<DownloadItem?> getDownloadByEditionId(String editionId) async {
    final rows = await _db.query(
      'downloads',
      where: 'edition_id = ?',
      whereArgs: [editionId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToDownload(rows.first);
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    await _db.insert('downloads', {
      'id': item.id,
      'work_id': item.workId,
      'edition_id': item.editionId,
      'title': item.title,
      'target_path': item.targetPath,
      'download_url': item.downloadUrl,
      'total_bytes': item.totalBytes,
      'downloaded_bytes': item.downloadedBytes,
      'status': item.status.code,
      'error_message': item.errorMessage,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'updated_at': item.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateStatus(
    String id,
    DownloadStatus status, {
    String? errorMessage,
  }) async {
    await _db.update(
      'downloads',
      {
        'status': status.code,
        'error_message': errorMessage,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateProgress(
    String id,
    int downloadedBytes,
    int totalBytes,
  ) async {
    await _db.update(
      'downloads',
      {
        'downloaded_bytes': downloadedBytes,
        'total_bytes': totalBytes,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteDownload(String id) async {
    await _db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  DownloadItem _mapRowToDownload(Map<String, dynamic> row) {
    return DownloadItem(
      id: row['id'] as String,
      workId: row['work_id'] as String,
      editionId: row['edition_id'] as String,
      title: row['title'] as String,
      targetPath: row['target_path'] as String,
      downloadUrl: row['download_url'] as String,
      totalBytes: row['total_bytes'] as int? ?? 0,
      downloadedBytes: row['downloaded_bytes'] as int? ?? 0,
      status: DownloadStatus.fromCode(row['status'] as String),
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}

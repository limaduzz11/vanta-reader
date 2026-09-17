import '../entities/download_item.dart';

/// Contrato Abstrato do Repositório de Downloads
abstract class IDownloadRepository {
  Future<List<DownloadItem>> getAllDownloads();
  Future<DownloadItem?> getDownloadById(String id);
  Future<DownloadItem?> getDownloadByEditionId(String editionId);
  Future<void> saveDownload(DownloadItem item);
  Future<void> updateStatus(
    String id,
    DownloadStatus status, {
    String? errorMessage,
  });
  Future<void> updateProgress(String id, int downloadedBytes, int totalBytes);
  Future<void> deleteDownload(String id);
}

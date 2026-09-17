import '../../entities/download_item.dart';
import '../../entities/work.dart';
import '../../../core/download/download_manager.dart';
import '../../../core/download/download_progress_snapshot.dart';

/// Caso de Uso: Enfileirar novo download
class EnqueueDownloadUseCase {
  final DownloadManager _manager;

  const EnqueueDownloadUseCase(this._manager);

  Future<DownloadItem> call({
    required Work work,
    required WorkEdition edition,
    String? customDownloadUrl,
  }) {
    return _manager.enqueue(
      work: work,
      edition: edition,
      customDownloadUrl: customDownloadUrl,
    );
  }
}

/// Caso de Uso: Pausar download ativo
class PauseDownloadUseCase {
  final DownloadManager _manager;

  const PauseDownloadUseCase(this._manager);

  Future<void> call(String downloadId) {
    return _manager.pause(downloadId);
  }
}

/// Caso de Uso: Retomar download pausado
class ResumeDownloadUseCase {
  final DownloadManager _manager;

  const ResumeDownloadUseCase(this._manager);

  Future<void> call(String downloadId) {
    return _manager.resume(downloadId);
  }
}

/// Caso de Uso: Cancelar download
class CancelDownloadUseCase {
  final DownloadManager _manager;

  const CancelDownloadUseCase(this._manager);

  Future<void> call(String downloadId) {
    return _manager.cancel(downloadId);
  }
}

/// Caso de Uso: Repetir download com falha
class RetryDownloadUseCase {
  final DownloadManager _manager;

  const RetryDownloadUseCase(this._manager);

  Future<void> call(String downloadId) {
    return _manager.retry(downloadId);
  }
}

/// Caso de Uso: Excluir registro de download
class DeleteDownloadUseCase {
  final DownloadManager _manager;

  const DeleteDownloadUseCase(this._manager);

  Future<void> call(String downloadId, {bool deleteFile = false}) {
    return _manager.delete(downloadId, deleteFile: deleteFile);
  }
}

/// Caso de Uso: Limpar todos os downloads concluídos
class ClearCompletedDownloadsUseCase {
  final DownloadManager _manager;

  const ClearCompletedDownloadsUseCase(this._manager);

  Future<void> call() {
    return _manager.clearCompleted();
  }
}

/// Caso de Uso: Obter lista e streams de downloads
class GetDownloadsUseCase {
  final DownloadManager _manager;

  const GetDownloadsUseCase(this._manager);

  Future<List<DownloadItem>> getAll() {
    return _manager.downloadRepository.getAllDownloads();
  }

  Stream<List<DownloadItem>> get listStream => _manager.downloadsStream;

  Stream<DownloadProgressSnapshot> get progressStream =>
      _manager.progressStream;
}

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/download_item.dart';
import '../../domain/entities/work.dart';
import '../../domain/repositories/i_download_repository.dart';
import '../../domain/repositories/i_library_repository.dart';
import '../errors/nova_errors.dart';
import '../logging/app_logger.dart';
import '../network/network_client.dart';
import '../storage/storage_manager.dart';
import 'content_asset_validator.dart';
import 'download_progress_snapshot.dart';

/// Controlador interno de uma tarefa de download ativa
class _ActiveDownloadTask {
  final DownloadItem item;
  final Completer<void> completer;
  CancelToken? cancelToken;
  bool isPaused = false;
  bool isCancelled = false;
  int? expectedTotalBytes;

  _ActiveDownloadTask({
    required this.item,
    required this.completer,
    this.cancelToken,
  });
}

/// Gerenciador Central e Fila Resiliente de Downloads (Fase H)
class DownloadManager {
  final IDownloadRepository downloadRepository;
  final ILibraryRepository libraryRepository;
  final StorageManager storageManager;
  final NetworkClient? networkClient;
  final int maxConcurrentDownloads;

  final Map<String, _ActiveDownloadTask> _activeTasks = {};
  final StreamController<DownloadProgressSnapshot> _progressController =
      StreamController<DownloadProgressSnapshot>.broadcast();
  final StreamController<List<DownloadItem>> _downloadsListController =
      StreamController<List<DownloadItem>>.broadcast();

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  DownloadManager({
    required this.downloadRepository,
    required this.libraryRepository,
    required this.storageManager,
    this.networkClient,
    this.maxConcurrentDownloads = 2,
  });

  Stream<DownloadProgressSnapshot> get progressStream =>
      _progressController.stream;

  Stream<List<DownloadItem>> get downloadsStream =>
      _downloadsListController.stream;

  void _safeAddProgress(DownloadProgressSnapshot snapshot) {
    if (!_isDisposed && !_progressController.isClosed) {
      _progressController.add(snapshot);
    }
  }

  /// Inicializa o gerenciador e restaura fila pendente do SQLite
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    AppLogger.info(
      LogCategory.database,
      'Inicializando DownloadManager e restaurando fila persistida...',
    );

    final all = await downloadRepository.getAllDownloads();

    // Se o aplicativo foi fechado inesperadamente durante download, reseta para fila
    for (final item in all) {
      if (item.status == DownloadStatus.downloading) {
        await downloadRepository.updateStatus(item.id, DownloadStatus.queued);
      }
    }

    await _notifyListChanged();
    _processQueue();
  }

  /// Enfileira uma nova obra para download
  Future<DownloadItem> enqueue({
    required Work work,
    required WorkEdition edition,
    String? customDownloadUrl,
  }) async {
    // 0. Garante que a obra existe no repositório da biblioteca antes de enfileirar download
    final existingWork = await libraryRepository.getWorkById(work.id);
    if (existingWork == null) {
      await libraryRepository.saveWork(work);
    }

    // 1. Verifica se já existe download em andamento ou concluído para esta edição
    final existing = await downloadRepository.getDownloadByEditionId(
      edition.id,
    );
    if (existing != null &&
        (existing.isActive || existing.status == DownloadStatus.completed)) {
      AppLogger.info(
        LogCategory.database,
        'Download já existente para edição ${edition.id}: status=${existing.status}',
      );
      return existing;
    }

    // 2. Determina o destino seguro no disco
    final extension = edition.format.extension;
    final fileName =
        '${work.workKey.replaceAll(':', '_')}_${edition.id}.$extension';
    final targetPath = work.type == WorkType.book
        ? storageManager.getBookPath(fileName)
        : storageManager.getComicPath(fileName);

    final url = customDownloadUrl ?? edition.downloadUrl;

    if (url == null || url.isEmpty) {
      // REGRA ABSOLUTA: nunca inventar URL. O download só é possível quando
      // a fonte fornece asset de conteúdo real para a EDIÇÃO selecionada.
      throw NovaException(
        kind: NovaErrorKind.providerError,
        message:
            'Esta edição não possui um conteúdo válido para download. Apenas metadata está disponível.',
      );
    }

    if (url.startsWith('mock://') || url.startsWith('test://')) {
      throw NovaException(
        kind: NovaErrorKind.invalidFile,
        message:
            'Conteúdo de demonstração não pode ser baixado. Selecione uma obra do catálogo público.',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message: 'URL de download inválida para esta edição.',
      );
    }

    final estimatedSize = edition.fileSize > 0 ? edition.fileSize : 0;

    final item = DownloadItem(
      id: 'dl_${DateTime.now().millisecondsSinceEpoch}_${edition.id}',
      workId: work.id,
      editionId: edition.id,
      title: work.title,
      targetPath: targetPath,
      downloadUrl: url,
      totalBytes: estimatedSize,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await downloadRepository.saveDownload(item);
    AppLogger.info(
      LogCategory.database,
      'Novo download enfileirado: "${item.title}" (${item.id})',
    );

    await _notifyListChanged();
    _processQueue();

    return item;
  }

  /// Pausa um download ativo ou enfileirado
  Future<void> pause(String downloadId) async {
    final active = _activeTasks[downloadId];
    if (active != null) {
      active.isPaused = true;
      active.cancelToken?.cancel('Pausado pelo usuário');
    }

    await downloadRepository.updateStatus(downloadId, DownloadStatus.paused);
    _activeTasks.remove(downloadId);

    _safeAddProgress(
      DownloadProgressSnapshot(
        downloadId: downloadId,
        status: DownloadStatus.paused,
        downloadedBytes: 0,
        totalBytes: 0,
      ),
    );

    await _notifyListChanged();
    _processQueue();
  }

  /// Retoma um download pausado
  Future<void> resume(String downloadId) async {
    final item = await downloadRepository.getDownloadById(downloadId);
    if (item == null) return;

    if (item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.failed) {
      await downloadRepository.updateStatus(downloadId, DownloadStatus.queued);
      await _notifyListChanged();
      _processQueue();
    }
  }

  /// Cancela um download e remove arquivo temporário
  Future<void> cancel(String downloadId) async {
    final active = _activeTasks[downloadId];
    if (active != null) {
      active.isCancelled = true;
      active.cancelToken?.cancel('Cancelado pelo usuário');
    }

    final item = await downloadRepository.getDownloadById(downloadId);
    if (item != null) {
      // Limpa arquivo parcial .part
      final partFile = File('${item.targetPath}.part');
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
    }

    await downloadRepository.updateStatus(downloadId, DownloadStatus.cancelled);
    _activeTasks.remove(downloadId);

    _safeAddProgress(
      DownloadProgressSnapshot(
        downloadId: downloadId,
        status: DownloadStatus.cancelled,
        downloadedBytes: 0,
        totalBytes: 0,
      ),
    );

    await _notifyListChanged();
    _processQueue();
  }

  /// Tenta novamente um download que falhou ou foi cancelado
  Future<void> retry(String downloadId) async {
    final item = await downloadRepository.getDownloadById(downloadId);
    if (item == null) return;

    await downloadRepository.updateStatus(downloadId, DownloadStatus.queued);
    await _notifyListChanged();
    _processQueue();
  }

  /// Exclui o registro de download e, quando [deleteFile], remove o arquivo
  /// físico (.part incluso) e reverte a edição/biblioteca para `added`
  /// (G-01: exclusão antes deixava arquivo órfão e status `downloaded`).
  Future<void> delete(String downloadId, {bool deleteFile = false}) async {
    final item = await downloadRepository.getDownloadById(downloadId);
    if (item != null && deleteFile) {
      await _deletePhysicalFiles(item.targetPath);
      await _revertLibraryAfterFileRemoval(
        workId: item.workId,
        editionId: item.editionId,
      );
    }

    await downloadRepository.deleteDownload(downloadId);
    _activeTasks.remove(downloadId);
    await _notifyListChanged();
  }

  /// Limpa todos os downloads concluídos: remove registros, arquivos físicos
  /// e reverte a biblioteca (G-01). Antes apagava só a linha do banco.
  Future<void> clearCompleted() async {
    final all = await downloadRepository.getAllDownloads();
    for (final item in all) {
      if (item.status == DownloadStatus.completed) {
        await _deletePhysicalFiles(item.targetPath);
        await _revertLibraryAfterFileRemoval(
          workId: item.workId,
          editionId: item.editionId,
        );
        await downloadRepository.deleteDownload(item.id);
      }
    }
    await _notifyListChanged();
  }

  Future<void> _deletePhysicalFiles(String targetPath) async {
    try {
      final file = File(targetPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      final partFile = File('$targetPath.part');
      if (await partFile.exists()) await partFile.delete();
    } catch (_) {}
  }

  Future<void> _revertLibraryAfterFileRemoval({
    required String workId,
    required String editionId,
  }) async {
    try {
      await libraryRepository.updateEditionFile(
        editionId: editionId,
        filePath: '',
        fileSize: 0,
        isLocal: false,
      );
      await libraryRepository.updateLibraryStatus(workId, 'added');
    } catch (_) {}
  }

  /// Processa a fila respeitando a concorrência máxima
  void _processQueue() {
    if (_isProcessing || _isDisposed) return;
    _isProcessing = true;

    scheduleMicrotask(() async {
      try {
        if (_isDisposed) return;
        final all = await downloadRepository.getAllDownloads();
        final activeCount = _activeTasks.length;
        final availableSlots = maxConcurrentDownloads - activeCount;

        if (availableSlots <= 0 || _isDisposed) return;

        final queuedItems = all
            .where((d) => d.status == DownloadStatus.queued)
            .toList();

        for (int i = 0; i < availableSlots && i < queuedItems.length; i++) {
          if (_isDisposed) break;
          final itemToStart = queuedItems[i];
          if (!_activeTasks.containsKey(itemToStart.id)) {
            _startDownload(itemToStart);
          }
        }
      } finally {
        _isProcessing = false;
      }
    });
  }

  /// Executa o download de um item em background
  Future<void> _startDownload(DownloadItem item) async {
    if (_isDisposed) return;
    final completer = Completer<void>();
    final cancelToken = CancelToken();
    final task = _ActiveDownloadTask(
      item: item,
      completer: completer,
      cancelToken: cancelToken,
    );

    _activeTasks[item.id] = task;

    // Atualiza status no banco para DOWNLOADING
    await downloadRepository.updateStatus(item.id, DownloadStatus.downloading);
    await _notifyListChanged();

    try {
      if (item.downloadUrl.startsWith('mock://') || networkClient == null) {
        // REGRA ABSOLUTA: nunca simular download em runtime normal.
        throw NovaException(
          kind: NovaErrorKind.invalidFile,
          message: 'Download de demonstração não permitido no runtime normal.',
        );
      }
      await _executeRealDownload(task);

      if (!task.isPaused && !task.isCancelled) {
        await _onDownloadSuccess(task);
      }
    } catch (e, st) {
      if (task.isPaused) {
        AppLogger.info(
          LogCategory.database,
          'Download "${item.title}" pausado com sucesso.',
        );
      } else if (task.isCancelled) {
        AppLogger.info(
          LogCategory.database,
          'Download "${item.title}" cancelado com sucesso.',
        );
      } else {
        if (_isDisposed) return;
        AppLogger.error(
          LogCategory.database,
          'Falha no download "${item.title}": $e',
          e,
          st,
        );
        await downloadRepository.updateStatus(
          item.id,
          DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        _safeAddProgress(
          DownloadProgressSnapshot(
            downloadId: item.id,
            status: DownloadStatus.failed,
            downloadedBytes: item.downloadedBytes,
            totalBytes: item.totalBytes,
            errorMessage: e.toString(),
          ),
        );
        await _notifyListChanged();
      }
    } finally {
      _activeTasks.remove(item.id);
      if (!_isDisposed) {
        _processQueue();
      }
    }
  }

  /// Pipeline de download real via HTTP com suporte a Range/Resume
  Future<void> _executeRealDownload(_ActiveDownloadTask task) async {
    final item = task.item;
    final partFile = File('${item.targetPath}.part');
    await partFile.parent.create(recursive: true);

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    final headers = <String, dynamic>{};
    if (existingBytes > 0) {
      headers['Range'] = 'bytes=$existingBytes-';
    }

    final dio = networkClient!.dio;
    final response = await dio.get<ResponseBody>(
      item.downloadUrl,
      options: Options(responseType: ResponseType.stream, headers: headers),
      cancelToken: task.cancelToken,
    );

    final responseBytes = (response.data?.headers['content-length'] != null)
        ? int.tryParse(response.data!.headers['content-length']!.first) ??
              item.totalBytes
        : item.totalBytes;

    late final int actualTotal;
    IOSink sink;
    if (existingBytes > 0 && response.statusCode == 206) {
      actualTotal = existingBytes + responseBytes;
      sink = partFile.openWrite(mode: FileMode.append);
    } else {
      existingBytes = 0;
      actualTotal = responseBytes;
      sink = partFile.openWrite(mode: FileMode.write);
    }
    task.expectedTotalBytes = actualTotal > 0 ? actualTotal : null;

    int currentBytes = existingBytes;
    int lastNotifiedBytes = currentBytes;
    DateTime lastSpeedTime = DateTime.now();
    int bytesSinceLastSpeed = 0;
    double currentSpeed = 0.0;

    try {
      await for (final chunk in response.data!.stream) {
        if (task.isPaused || task.isCancelled) break;

        sink.add(chunk);
        currentBytes += chunk.length;
        bytesSinceLastSpeed += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastSpeedTime).inMilliseconds;
        if (elapsedMs >= 1000) {
          currentSpeed = (bytesSinceLastSpeed / (elapsedMs / 1000.0));
          bytesSinceLastSpeed = 0;
          lastSpeedTime = now;
        }

        // Throttled UI update (a cada 200ms ou término)
        final remainingBytes = actualTotal - currentBytes;
        final eta = (currentSpeed > 0 && remainingBytes > 0)
            ? (remainingBytes / currentSpeed).round()
            : null;

        _safeAddProgress(
          DownloadProgressSnapshot(
            downloadId: item.id,
            status: DownloadStatus.downloading,
            downloadedBytes: currentBytes,
            totalBytes: actualTotal,
            speedBytesPerSecond: currentSpeed,
            etaSeconds: eta,
          ),
        );

        // Throttled DB update (a cada 500 KB)
        if (currentBytes - lastNotifiedBytes > 512 * 1024) {
          lastNotifiedBytes = currentBytes;
          await downloadRepository.updateProgress(
            item.id,
            currentBytes,
            actualTotal,
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// Trata a conclusão com sucesso do download e integra com a Biblioteca
  Future<void> _onDownloadSuccess(_ActiveDownloadTask task) async {
    final item = task.item;
    final partFile = File('${item.targetPath}.part');
    final targetFile = File(item.targetPath);

    if (await partFile.exists()) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await partFile.rename(item.targetPath);
    }

    // Recupera a prova remota para validar tamanho/checksum e preservar
    // proveniência ao promover o mesmo asset para `downloaded`.
    final workBeforeValidation = await libraryRepository.getWorkById(
      item.workId,
    );
    final editionBeforeValidation = workBeforeValidation?.editions
        .where((edition) => edition.id == item.editionId)
        .firstOrNull;
    final remoteAsset = editionBeforeValidation?.primaryContentAsset;

    // REGRA DE INTEGRIDADE: validação obrigatória antes de COMPLETED.
    final format = WorkFormat.fromExtension(p.extension(item.targetPath));
    final validation = await const ContentAssetValidator().validateFile(
      targetFile,
      format,
      expectedSize:
          task.expectedTotalBytes ??
          (item.totalBytes > 0 ? item.totalBytes : null),
      expectedChecksum: remoteAsset?.checksum,
      checksumAlgorithm: remoteAsset?.checksumAlgorithm,
    );
    if (!validation.isValid) {
      await targetFile.delete().catchError((_) => targetFile);
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message:
            'Download rejeitado na validação: ${validation.error ?? 'arquivo inválido'}',
      );
    }

    final fileSize = await targetFile.exists()
        ? await targetFile.length()
        : item.totalBytes;

    // 1. Atualiza status no banco de downloads
    await downloadRepository.updateStatus(item.id, DownloadStatus.completed);
    await downloadRepository.updateProgress(item.id, fileSize, fileSize);

    // 2. Atualiza a edição concreta da obra (marcando como local e apontando o arquivo físico)
    await libraryRepository.updateEditionFile(
      editionId: item.editionId,
      filePath: item.targetPath,
      fileSize: fileSize,
      isLocal: true,
    );

    // 2b. Registra o ContentAsset REAL (prova de conteúdo baixado)
    final now = DateTime.now();
    await libraryRepository.updateContentAsset(
      remoteAsset?.copyWith(
            status: ContentAssetStatus.downloaded,
            localPath: item.targetPath,
            mediaType: remoteAsset.mediaType ?? validation.detectedMediaType,
            fileSize: fileSize,
            verifiedAt: now,
            updatedAt: now,
          ) ??
          ContentAsset(
            id: 'asset-${item.editionId}-${format.extension}',
            editionId: item.editionId,
            format: format,
            status: ContentAssetStatus.downloaded,
            localPath: item.targetPath,
            remoteUrl: item.downloadUrl,
            mediaType: validation.detectedMediaType,
            fileSize: fileSize,
            checksum: validation.checksumSha256,
            checksumAlgorithm: 'sha256',
            source: item.id,
            verifiedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
    );

    // 3. Atualiza o status da obra na biblioteca para "downloaded"
    await libraryRepository.updateLibraryStatus(item.workId, 'downloaded');

    // 4. Se a capa for remota, baixa a capa REAL correspondente; nunca dummy.
    try {
      final work = await libraryRepository.getWorkById(item.workId);
      if (work != null) {
        final currentCover = work.coverPath;
        final isCoverAlreadyLocal =
            currentCover != null &&
            !currentCover.startsWith('http') &&
            await File(currentCover).exists();

        if (!isCoverAlreadyLocal && networkClient != null) {
          final coverUrl = currentCover;
          if (coverUrl != null && coverUrl.startsWith('http')) {
            await _persistRealCover(work, coverUrl);
          }
        }
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.download,
        'Não foi possível salvar a capa local para obra ${item.workId}: $e',
      );
    }

    AppLogger.info(
      LogCategory.download,
      'Download concluído com sucesso: "${item.title}". Arquivo salvo em: ${item.targetPath} (${validation.detectedMediaType})',
    );

    _safeAddProgress(
      DownloadProgressSnapshot(
        downloadId: item.id,
        status: DownloadStatus.completed,
        downloadedBytes: fileSize,
        totalBytes: fileSize,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
      ),
    );

    await _notifyListChanged();
  }

  /// Persiste a capa real da obra com validação de assinatura de imagem.
  Future<void> _persistRealCover(Work work, String coverUrl) async {
    final coverName = '${work.workKey}_cover.jpg';
    final tempFile = File('${storageManager.coversDir.path}/.tmp_$coverName');
    await tempFile.parent.create(recursive: true);

    await networkClient!.dio.download(coverUrl, tempFile.path);
    final bytes = await tempFile.readAsBytes();

    final isJpeg =
        bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng =
        bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final isPngOrJpeg = isJpeg || isPng;
    if (!isPngOrJpeg) {
      throw NovaException(
        kind: NovaErrorKind.corruptedFile,
        message: 'Capa remota não é uma imagem válida (JPEG/PNG).',
      );
    }

    final finalFile = File(storageManager.getCoverPath(coverName));
    await tempFile.rename(finalFile.path);
    await libraryRepository.updateCoverPath(work.id, finalFile.path);
    AppLogger.info(
      LogCategory.download,
      'Capa real persistida em ${finalFile.path}',
    );
  }

  Future<void> _notifyListChanged() async {
    if (_isDisposed) return;
    try {
      final all = await downloadRepository.getAllDownloads();
      if (!_isDisposed && !_downloadsListController.isClosed) {
        _downloadsListController.add(all);
      }
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    for (final task in _activeTasks.values) {
      task.isCancelled = true;
      task.cancelToken?.cancel();
    }
    _activeTasks.clear();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    if (!_downloadsListController.isClosed) {
      _downloadsListController.close();
    }
  }
}

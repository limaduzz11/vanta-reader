import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/entities/work.dart';
import '../../domain/repositories/i_library_repository.dart';
import '../errors/nova_errors.dart';
import '../logging/app_logger.dart';
import '../network/network_client.dart';
import '../providers/content_provider.dart';
import '../providers/provider_registry.dart';
import '../storage/storage_manager.dart';
import 'reading_session.dart';

/// Gerenciador Central de Leitura Híbrida (Offline-First + Streaming Online) — Fase K
class OnlineReadingManager {
  final StorageManager storageManager;
  final ProviderRegistry providerRegistry;
  final NetworkClient networkClient;
  final ILibraryRepository libraryRepository;

  const OnlineReadingManager({
    required this.storageManager,
    required this.providerRegistry,
    required this.networkClient,
    required this.libraryRepository,
  });

  /// Prepara uma sessão de leitura (Local imediato, Cache de Streaming ou Download em Buffer)
  ///
  /// G-06: usa o [NetworkClient] tipado (HTTPS/local allowlist + timeouts +
  /// erros `NovaException` preservados) em vez de `dio.download` cru; aceita
  /// [cancelToken] para interromper o streaming pela UI; remove buffer parcial
  /// em falha para não deixar cache corrompido.
  Future<ReadingSession> prepareSession({
    required Work work,
    required WorkEdition edition,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    AppLogger.info(
      LogCategory.reader,
      'Preparando sessão de leitura para "${work.title}" (${edition.format.label})...',
    );

    // 1. Verificação de Arquivo Local Permanente (Offline)
    if (edition.isLocal && edition.filePath != null) {
      final localFile = File(edition.filePath!);
      if (await localFile.exists() && await localFile.length() > 0) {
        AppLogger.info(
          LogCategory.reader,
          'Obra já disponível localmente: ${edition.filePath}. Redirecionamento transparente sem rede.',
        );
        return ReadingSession(
          work: work,
          edition: edition,
          source: ReadingSource.local,
          resolvedFilePath: edition.filePath!,
          isTemporaryCache: false,
          fileSize: await localFile.length(),
          providerName: edition.providerId,
        );
      }
    }

    // 2. Verificação de Cache Volátil de Streaming (/cache/reading/)
    final safeWorkKey = work.workKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeEditionId = edition.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cacheFileName =
        'stream_${safeWorkKey}_$safeEditionId.${edition.format.extension}';
    final cacheFilePath = storageManager.getReadingCachePath(cacheFileName);
    final cacheFile = File(cacheFilePath);

    if (await cacheFile.exists() && await cacheFile.length() > 0) {
      AppLogger.info(
        LogCategory.reader,
        'Obra encontrada no cache de streaming: $cacheFilePath. Carregamento instantâneo do buffer.',
      );
      return ReadingSession(
        work: work,
        edition: edition,
        source: ReadingSource.cachedStream,
        resolvedFilePath: cacheFilePath,
        isTemporaryCache: true,
        fileSize: await cacheFile.length(),
        providerName: edition.providerId,
      );
    }

    // 3. Obtenção e Verificação do Provedor de Conteúdo
    ContentProvider? provider;
    if (edition.providerId != null) {
      provider = providerRegistry.getProvider(edition.providerId!);
    }
    if (provider == null) {
      final active = providerRegistry.getActiveProviders();
      if (active.isNotEmpty) {
        provider = active.first;
      }
    }

    if (provider != null && !provider.capabilities.supportsStreaming) {
      AppLogger.warn(
        LogCategory.reader,
        'Provedor ${provider.id} não oferece suporte a streaming online para ${work.title}',
      );
      throw NovaException(
        kind: NovaErrorKind.providerError,
        message:
            'O provedor "${provider.name}" não suporta leitura direta via streaming. Faça o download para ler offline.',
      );
    }

    // 4. Resolução da URL pelo identificador EXTERNO da edição.
    String? streamUrl;
    if (provider != null) {
      try {
        final externalId = edition.externalId;
        if (externalId != null && externalId.isNotEmpty) {
          streamUrl = await provider.resolveDownloadUrl(
            externalId,
            edition.format,
          );
        }
      } catch (error) {
        AppLogger.warn(
          LogCategory.reader,
          'Falha ao resolver URL no provedor ${provider.id}: $error',
        );
      }
    }
    streamUrl ??= edition.downloadUrl;

    if (streamUrl == null || streamUrl.isEmpty) {
      throw NovaException(
        kind: NovaErrorKind.providerError,
        message:
            'Conteúdo online não disponível para esta edição. Use o catálogo para buscar obras com conteúdo validado.',
      );
    }

    if (streamUrl.startsWith('mock://') || streamUrl.startsWith('test://')) {
      // REGRA ABSOLUTA: conteúdo sintético é proibido em runtime normal.
      throw NovaException(
        kind: NovaErrorKind.invalidFile,
        message:
            'Este conteúdo de demonstração não está disponível. Selecione uma obra do catálogo público.',
      );
    }

    final uri = Uri.tryParse(streamUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message: 'URL de leitura inválida para esta edição.',
      );
    }

    // 5. Streaming do Arquivo para o Cache Volátil (via NetworkClient tipado)
    onProgress?.call(0.1);

    try {
      await networkClient.download(
        streamUrl,
        cacheFilePath,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
    } on NovaException catch (e, st) {
      // Preserva o kind tipado (timeout/cancel/provider/network) do NetworkClient.
      AppLogger.warn(
        LogCategory.reader,
        'Falha no streaming de rede para "${work.title}": $e',
        e,
        st,
      );
      await _deleteQuietly(cacheFile);
      rethrow;
    } catch (e, st) {
      AppLogger.warn(
        LogCategory.reader,
        'Falha no streaming de rede para "${work.title}": $e',
        e,
        st,
      );
      await _deleteQuietly(cacheFile);
      throw NovaException(
        kind: NovaErrorKind.networkError,
        message:
            'Falha ao baixar o conteúdo online. Verifique sua conexão e tente novamente.',
        cause: e,
      );
    }

    if (!await cacheFile.exists() || await cacheFile.length() == 0) {
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Falha ao salvar buffer temporário de streaming.',
      );
    }

    AppLogger.info(
      LogCategory.reader,
      'Sessão de streaming iniciada com sucesso. Arquivo em cache: $cacheFilePath (${await cacheFile.length()} bytes)',
    );

    return ReadingSession(
      work: work,
      edition: edition,
      source: ReadingSource.onlineStream,
      resolvedFilePath: cacheFilePath,
      isTemporaryCache: true,
      fileSize: await cacheFile.length(),
      providerName: provider?.name ?? edition.providerId,
    );
  }

  /// Promove uma edição em cache temporário de streaming para armazenamento local permanente
  Future<WorkEdition> promoteToLocal(ReadingSession session) async {
    if (!session.isTemporaryCache || session.isLocal) {
      return session.edition;
    }

    final cacheFile = File(session.resolvedFilePath);
    if (!await cacheFile.exists()) {
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Arquivo de buffer temporário não encontrado para promoção.',
      );
    }

    final safeWorkKey = session.work.workKey.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final safeEditionId = session.edition.id.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final permanentFileName =
        '${safeWorkKey}_$safeEditionId.${session.edition.format.extension}';

    final destPath = session.work.type == WorkType.book
        ? storageManager.getBookPath(permanentFileName)
        : storageManager.getComicPath(permanentFileName);

    await cacheFile.copy(destPath);
    final permanentFile = File(destPath);
    final fileSize = await permanentFile.length();

    // Salva a obra na biblioteca se ainda não estiver presente
    final existingWork = await libraryRepository.getWorkById(session.work.id);
    if (existingWork == null) {
      await libraryRepository.saveWork(session.work);
    }

    // Promove a edição
    await libraryRepository.updateEditionFile(
      editionId: session.edition.id,
      filePath: destPath,
      fileSize: fileSize,
      isLocal: true,
    );
    final now = DateTime.now();
    final existingAsset = session.edition.primaryContentAsset;
    await libraryRepository.updateContentAsset(
      existingAsset?.copyWith(
            status: ContentAssetStatus.downloaded,
            localPath: destPath,
            fileSize: fileSize,
            verifiedAt: now,
            updatedAt: now,
          ) ??
          ContentAsset(
            id: 'asset-${session.edition.id}',
            editionId: session.edition.id,
            format: session.edition.format,
            status: ContentAssetStatus.downloaded,
            remoteUrl: session.edition.downloadUrl,
            localPath: destPath,
            fileSize: fileSize,
            source: session.edition.providerId,
            verifiedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
    );
    await libraryRepository.updateLibraryStatus(session.work.id, 'downloaded');

    AppLogger.info(
      LogCategory.reader,
      'Obra "${session.work.title}" promovida com sucesso de streaming para local: $destPath',
    );

    return session.edition.copyWith(
      filePath: destPath,
      isLocal: true,
      fileSize: fileSize,
    );
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

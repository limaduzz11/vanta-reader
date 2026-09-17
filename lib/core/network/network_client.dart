import 'package:dio/dio.dart';
import '../logging/app_logger.dart';
import '../errors/nova_errors.dart';

/// Cliente HTTP Resiliente do NovaReader
class NetworkClient {
  final Dio _dio;

  NetworkClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 35),
              sendTimeout: const Duration(seconds: 25),
              headers: {
                'User-Agent':
                    'VANTAReader/1.0 (Android; Local-First Reader; VANTA Labz)',
                'Accept': 'application/json, text/html, */*',
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.debug(
            LogCategory.network,
            '-> [${options.method}] ${options.uri}',
          );
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.debug(
            LogCategory.network,
            '<- [${response.statusCode}] ${response.requestOptions.uri}',
          );
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          AppLogger.warn(
            LogCategory.network,
            'Erro HTTP: [${error.type}] ${error.message} para ${error.requestOptions.uri}',
            error,
          );
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Validação estrita de transporte seguro (HTTPS obrigatório para conexões remotas)
  static void validateUrlSecurity(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message: 'URL inválida ou sem protocolo: $url',
      );
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message: 'Protocolo de transporte não suportado: $scheme. Use HTTPS.',
      );
    }
    if (scheme == 'http') {
      final host = uri.host.toLowerCase();
      final isLocal =
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '10.0.2.2' ||
          host.isEmpty;
      if (!isLocal) {
        AppLogger.warn(
          LogCategory.network,
          'Tentativa de requisição em HTTP puro bloqueada: $url',
        );
        throw NovaException(
          kind: NovaErrorKind.networkError,
          message:
              'Conexões não criptografadas (HTTP) são proibidas para hosts remotos. Use HTTPS.',
        );
      }
    }
  }

  /// Executa GET seguro convertendo falhas em NovaFailure tipadas
  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    validateUrlSecurity(url);
    try {
      return await _dio.get<T>(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw NovaException(
        kind: NovaErrorKind.networkError,
        message: 'Erro desconhecido de rede: $e',
        cause: e,
      );
    }
  }

  /// Baixa arquivo com suporte a progresso e cancelamento
  Future<Response> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    validateUrlSecurity(url);
    try {
      return await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw NovaException(
        kind: NovaErrorKind.downloadError,
        message: 'Falha no download do arquivo: $e',
        cause: e,
      );
    }
  }

  NovaException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NovaException(
          kind: NovaErrorKind.timeout,
          message: 'Tempo limite da conexão esgotado.',
          cause: e,
        );
      case DioExceptionType.badResponse:
        return NovaException(
          kind: NovaErrorKind.providerError,
          message:
              'Resposta com código de erro do servidor: ${e.response?.statusCode}.',
          cause: e,
        );
      case DioExceptionType.cancel:
        return NovaException(
          kind: NovaErrorKind.downloadError,
          message: 'A operação de rede foi cancelada.',
          cause: e,
        );
      default:
        return NovaException(
          kind: NovaErrorKind.networkError,
          message: 'Falha de comunicação de rede: ${e.message}',
          cause: e,
        );
    }
  }
}

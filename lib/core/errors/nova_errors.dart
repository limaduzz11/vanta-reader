/// Tipos Canônicos de Falhas no Sistema NovaReader
enum NovaErrorKind {
  networkError('NETWORK_ERROR', 'Falha na conexão com a rede.'),
  timeout('TIMEOUT', 'A operação excedeu o tempo limite.'),
  providerError('PROVIDER_ERROR', 'Falha na resposta do provedor de conteúdo.'),
  parsingError('PARSING_ERROR', 'Erro ao processar dados ou metadados.'),
  downloadError('DOWNLOAD_ERROR', 'Falha durante a transferência do arquivo.'),
  storageError('STORAGE_ERROR', 'Erro ao acessar o sistema de arquivos local.'),
  databaseError('DATABASE_ERROR', 'Erro na persistência do banco de dados.'),
  readerError('READER_ERROR', 'Erro no motor de leitura.'),
  invalidFile('INVALID_FILE', 'Arquivo com formato inválido ou inexistente.'),
  unsupportedFormat('UNSUPPORTED_FORMAT', 'Formato de arquivo não suportado.'),
  corruptedFile('CORRUPTED_FILE', 'Arquivo corrompido ou incompleto.'),
  validationError(
    'VALIDATION_ERROR',
    'Entrada de dados inválida ou não conforme.',
  ),
  securityError(
    'SECURITY_ERROR',
    'Violação de integridade ou política de segurança.',
  );

  final String code;
  final String defaultMessage;
  const NovaErrorKind(this.code, this.defaultMessage);
}

/// Exceção Tipada Básica
class NovaException implements Exception {
  final NovaErrorKind kind;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  NovaException({
    required this.kind,
    String? message,
    this.cause,
    this.stackTrace,
  }) : message = message ?? kind.defaultMessage;

  @override
  String toString() =>
      '[${kind.code}] $message ${cause != null ? "(Causa: $cause)" : ""}';
}

/// Representação de Falha imutável na camada de Domínio
sealed class NovaFailure {
  final NovaErrorKind kind;
  final String message;
  final Object? cause;

  const NovaFailure({required this.kind, required this.message, this.cause});

  @override
  String toString() => '[${kind.code}] $message';
}

class NetworkFailure extends NovaFailure {
  const NetworkFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.networkError, message: message, cause: cause);
}

class TimeoutFailure extends NovaFailure {
  const TimeoutFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.timeout, message: message, cause: cause);
}

class ProviderFailure extends NovaFailure {
  const ProviderFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.providerError, message: message, cause: cause);
}

class ParsingFailure extends NovaFailure {
  const ParsingFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.parsingError, message: message, cause: cause);
}

class DownloadFailure extends NovaFailure {
  const DownloadFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.downloadError, message: message, cause: cause);
}

class StorageFailure extends NovaFailure {
  const StorageFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.storageError, message: message, cause: cause);
}

class DatabaseFailure extends NovaFailure {
  const DatabaseFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.databaseError, message: message, cause: cause);
}

class ReaderFailure extends NovaFailure {
  const ReaderFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.readerError, message: message, cause: cause);
}

class InvalidFileFailure extends NovaFailure {
  const InvalidFileFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.invalidFile, message: message, cause: cause);
}

class UnsupportedFormatFailure extends NovaFailure {
  const UnsupportedFormatFailure(String message, [Object? cause])
    : super(
        kind: NovaErrorKind.unsupportedFormat,
        message: message,
        cause: cause,
      );
}

class CorruptedFileFailure extends NovaFailure {
  const CorruptedFileFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.corruptedFile, message: message, cause: cause);
}

class ValidationFailure extends NovaFailure {
  const ValidationFailure(String message, [Object? cause])
    : super(
        kind: NovaErrorKind.validationError,
        message: message,
        cause: cause,
      );
}

class SecurityFailure extends NovaFailure {
  const SecurityFailure(String message, [Object? cause])
    : super(kind: NovaErrorKind.securityError, message: message, cause: cause);
}

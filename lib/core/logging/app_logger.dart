import 'dart:developer' as developer;

/// Categorias Estruturadas de Log do NovaReader
enum LogCategory {
  app('APP'),
  database('DATABASE'),
  network('NETWORK'),
  provider('PROVIDER'),
  download('DOWNLOAD'),
  reader('READER'),
  cache('CACHE'),
  sync('SYNC');

  final String label;
  const LogCategory(this.label);
}

/// Níveis Canônicos de Severidade
enum LogLevel {
  debug('DEBUG', 500),
  info('INFO', 800),
  warn('WARN', 900),
  error('ERROR', 1000);

  final String label;
  final int value;
  const LogLevel(this.label, this.value);
}

/// Registro estruturado de um evento de log
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19);
    final errStr = error != null ? ' | Error: $error' : '';
    return '[$timeStr] [${level.label}] [${category.label}] $message$errStr';
  }
}

/// Motor Centralizado de Logging do NovaReader
class AppLogger {
  static final List<LogEntry> _inMemoryLogs = [];
  static const int _maxInMemoryLogs = 500;
  static bool enableConsoleOutput = true;

  static List<LogEntry> get recentLogs => List.unmodifiable(_inMemoryLogs);

  static void debug(LogCategory category, String message) {
    _log(LogLevel.debug, category, message);
  }

  static void info(LogCategory category, String message) {
    _log(LogLevel.info, category, message);
  }

  static void warn(
    LogCategory category,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.warn, category, message, error, stackTrace);
  }

  static void error(
    LogCategory category,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, category, message, error, stackTrace);
  }

  static final _sensitivePatterns = [
    RegExp(
      r'(password|token|secret|key|authorization|bearer)\s*[:=]\s*([^\s,;&]+)',
      caseSensitive: false,
    ),
    RegExp(r'bearer\s+[a-zA-Z0-9_\-\.]+', caseSensitive: false),
    RegExp(r'/home/[^/\s]+', caseSensitive: false),
    RegExp(r'/media/[^/\s]+', caseSensitive: false),
    RegExp(r'C:\\Users\\[^\\]+', caseSensitive: false),
  ];

  /// Sanitiza mensagens de log, mascarando senhas, tokens e diretórios pessoais do host
  static String sanitizeMessage(String input) {
    var sanitized = input;
    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        final text = match.group(0) ?? '';
        final lower = text.toLowerCase();
        if (lower.startsWith('bearer ')) {
          return 'Bearer ***REDACTED***';
        } else if (text.startsWith('/home/') ||
            text.startsWith('/media/') ||
            text.startsWith('C:\\Users\\')) {
          return '[SANDBOX_USER_DIR]';
        } else if (match.groupCount >= 2) {
          return '${match.group(1)}: ***REDACTED***';
        }
        return '***REDACTED***';
      });
    }
    return sanitized;
  }

  static void _log(
    LogLevel level,
    LogCategory category,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final sanitizedMessage = sanitizeMessage(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: sanitizedMessage,
      error: error,
      stackTrace: stackTrace,
    );

    if (_inMemoryLogs.length >= _maxInMemoryLogs) {
      _inMemoryLogs.removeAt(0);
    }
    _inMemoryLogs.add(entry);

    if (enableConsoleOutput) {
      developer.log(
        entry.message,
        time: entry.timestamp,
        level: level.value,
        name: 'VANTAReader.${category.label}',
        error: error,
        stackTrace: stackTrace,
      );
      // ignore: avoid_print
      print(entry.toString());
    }
  }

  static void clear() {
    _inMemoryLogs.clear();
  }
}

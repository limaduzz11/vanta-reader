import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/logging/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clear();
    AppLogger.enableConsoleOutput = false;
  });

  group('AppLogger', () {
    test('grava logs estruturados com timestamp, categoria e nível', () {
      AppLogger.info(LogCategory.app, 'Inicializando teste');
      AppLogger.debug(LogCategory.database, 'Query executada');
      AppLogger.warn(LogCategory.network, 'Latência alta');
      AppLogger.error(
        LogCategory.reader,
        'Falha de renderização',
        'Exceção simulada',
      );

      final logs = AppLogger.recentLogs;
      expect(logs.length, equals(4));

      expect(logs[0].level, equals(LogLevel.info));
      expect(logs[0].category, equals(LogCategory.app));
      expect(logs[0].message, equals('Inicializando teste'));

      expect(logs[1].level, equals(LogLevel.debug));
      expect(logs[1].category, equals(LogCategory.database));

      expect(logs[2].level, equals(LogLevel.warn));
      expect(logs[2].category, equals(LogCategory.network));

      expect(logs[3].level, equals(LogLevel.error));
      expect(logs[3].category, equals(LogCategory.reader));
      expect(logs[3].error, equals('Exceção simulada'));
    });

    test('limpa histórico de logs corretamente', () {
      AppLogger.info(LogCategory.cache, 'Mensagem');
      expect(AppLogger.recentLogs.length, equals(1));

      AppLogger.clear();
      expect(AppLogger.recentLogs.isEmpty, isTrue);
    });
  });
}

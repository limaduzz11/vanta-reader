import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';

/// Configuração central da fonte oficial VANTA Catalog.
///
/// O app nunca conhece o protocolo do provider externo. Toda a conversa
/// com o gateway neutro passa por esta base URL + contrato v1.
///
/// Precedência: `--dart-define` > ajuste em runtime (Perfil > Gateway) >
/// padrão. O override de runtime é persistido na tabela `settings`
/// (`vanta_api_base_url`) e vale de imediato, sem rebuild — essencial no
/// aparelho físico, onde `10.0.2.2` (só-emulador) não roteia.
class VantaConfig {
  /// Base URL do gateway (sem barra final).
  final String baseUrl;

  /// Timeout padrão das operações deste provider.
  final Duration timeout;

  /// Override definido em runtime (tela de Perfil). Nulo = sem override.
  static String? runtimeOverride;

  const VantaConfig({
    this.baseUrl = VantaConfig.defaultBaseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  /// Padrão para desenvolvimento local (emulador Android => host da máquina).
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  /// Chave na tabela `settings`.
  static const String settingsKey = 'vanta_api_base_url';

  /// Prefixo de externalId usado pelo app para evitar colisão entre providers.
  static const String externalIdPrefix = 'vanta_';

  /// Permite trocar a base sem rebuild de código:
  /// `--dart-define=VANTA_API_BASE_URL=http://192.168.x.x:8080`
  static String? fromEnvironment() {
    const raw = String.fromEnvironment('VANTA_API_BASE_URL');
    return raw.isNotEmpty ? raw : null;
  }

  static String _strip(String url) =>
      url.trim().replaceAll(RegExp(r'/$'), '');

  /// Carrega o override persistido (`settings`) para memória. Best-effort:
  /// falha silenciosa mantém o default.
  static Future<void> loadPersisted(AppDatabase db) async {
    try {
      final rows = await db.db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [settingsKey],
      );
      if (rows.isNotEmpty) {
        final value = (rows.first['value'] as String?)?.trim() ?? '';
        runtimeOverride = value.isEmpty ? null : value;
      }
    } catch (_) {}
  }

  /// Persiste e aplica de imediato (sem rebuild).
  static Future<void> persist(AppDatabase db, String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/$'), '');
    runtimeOverride = clean.isEmpty ? null : clean;
    try {
      if (clean.isEmpty) {
        await db.db.delete(
          'settings',
          where: 'key = ?',
          whereArgs: [settingsKey],
        );
      } else {
        await db.db.insert('settings', {
          'key': settingsKey,
          'value': clean,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }

  /// Base efetiva (env > runtime > default).
  String get effectiveBaseUrl {
    final env = fromEnvironment();
    if (env != null && env.isNotEmpty) return _strip(env);
    final rt = runtimeOverride;
    if (rt != null && rt.isNotEmpty) return _strip(rt);
    return _strip(baseUrl);
  }
}

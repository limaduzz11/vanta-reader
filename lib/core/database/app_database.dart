import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../logging/app_logger.dart';

/// Gerenciador Central de Banco de Dados SQLite do VANTA Reader
class AppDatabase {
  static const String databaseFileName = 'vantareader.db';
  static const int currentDatabaseVersion = 5;

  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('O banco de dados ainda não foi inicializado.');
    }
    return _db!;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  /// Inicializa a conexão com o banco de dados e aplica migrations
  Future<void> initialize({
    String? customPath,
    bool isTestInMemory = false,
  }) async {
    if (_db != null && _db!.isOpen) return;

    // Se estiver em ambiente Desktop Linux ou teste sem plugin Android nativo, ativa FFI
    if (Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        isTestInMemory) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (isTestInMemory) {
      path = inMemoryDatabasePath;
    } else if (customPath != null) {
      path = p.join(customPath, databaseFileName);
      final legacyPath = p.join(customPath, 'novareader.db');
      if (!File(path).existsSync() && File(legacyPath).existsSync()) {
        try {
          File(legacyPath).renameSync(path);
        } catch (_) {}
      }
    } else {
      final defaultDatabasesPath = await getDatabasesPath();
      path = p.join(defaultDatabasesPath, databaseFileName);
      final legacyPath = p.join(defaultDatabasesPath, 'novareader.db');
      if (!File(path).existsSync() && File(legacyPath).existsSync()) {
        try {
          File(legacyPath).renameSync(path);
        } catch (_) {}
      }
    }

    AppLogger.info(
      LogCategory.database,
      'Abrindo SQLite em: $path (Versão: $currentDatabaseVersion)',
    );

    _db = await openDatabase(
      path,
      version: currentDatabaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    AppLogger.info(LogCategory.database, 'SQLite inicializado com sucesso.');
  }

  Future<void> _onConfigure(Database db) async {
    // Ativa Foreign Keys e WAL (Write-Ahead Logging) de forma segura e multiplataforma
    try {
      await db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      AppLogger.warn(LogCategory.database, 'Aviso ao ativar foreign_keys: $e');
    }
    if (!Platform.isWindows && !Platform.isAndroid) {
      try {
        await db.rawQuery('PRAGMA journal_mode = WAL;');
      } catch (e) {
        AppLogger.warn(
          LogCategory.database,
          'Aviso ao ativar journal_mode WAL: $e',
        );
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info(
      LogCategory.database,
      'Criando tabelas iniciais na versão $version...',
    );
    final batch = db.batch();

    // 1. Obras (Work — entidade mestre deduplicada)
    batch.execute('''
      CREATE TABLE works (
        id TEXT PRIMARY KEY,
        work_key TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        subtitle TEXT,
        author TEXT NOT NULL,
        description TEXT,
        primary_language TEXT NOT NULL,
        type TEXT NOT NULL,
        series TEXT,
        volume TEXT,
        publisher TEXT,
        published_date TEXT,
        isbn TEXT,
        cover_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_works_title ON works (title);');
    batch.execute('CREATE INDEX idx_works_author ON works (author);');
    batch.execute('CREATE INDEX idx_works_type ON works (type);');
    batch.execute(
      'CREATE INDEX idx_works_language ON works (primary_language);',
    );
    batch.execute('CREATE INDEX idx_works_series ON works (series);');

    // 2. Edições / Formatos Físicos Concretos (Books / Comics)
    batch.execute('''
      CREATE TABLE work_editions (
        id TEXT PRIMARY KEY,
        work_id TEXT NOT NULL,
        format TEXT NOT NULL,
        file_path TEXT,
        file_size INTEGER DEFAULT 0,
        page_count INTEGER DEFAULT 0,
        checksum TEXT,
        download_url TEXT,
        provider_id TEXT,
        is_local INTEGER DEFAULT 0,
        external_id TEXT,
        language TEXT,
        original_title TEXT,
        localized_title TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (work_id) REFERENCES works (id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_editions_work ON work_editions (work_id);');
    batch.execute(
      'CREATE INDEX idx_editions_format ON work_editions (format);',
    );
    batch.execute(
      'CREATE INDEX idx_editions_external ON work_editions (provider_id, external_id);',
    );

    // 2b. Assets de Conteúdo Real (prova de disponibilidade de conteúdo)
    batch.execute('''
      CREATE TABLE content_assets (
        id TEXT PRIMARY KEY,
        edition_id TEXT NOT NULL,
        format TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'none',
        remote_url TEXT,
        local_path TEXT,
        media_type TEXT,
        file_size INTEGER DEFAULT 0,
        checksum TEXT,
        checksum_algorithm TEXT,
        source TEXT,
        verified_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (edition_id) REFERENCES work_editions (id) ON DELETE CASCADE
      );
    ''');
    batch.execute(
      'CREATE INDEX idx_content_assets_edition ON content_assets (edition_id);',
    );
    batch.execute(
      'CREATE INDEX idx_content_assets_status ON content_assets (status);',
    );

    // 3. Biblioteca Local (Estante do usuário)
    batch.execute('''
      CREATE TABLE library (
        work_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        is_favorite INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        last_accessed_at INTEGER,
        FOREIGN KEY (work_id) REFERENCES works (id) ON DELETE CASCADE
      );
    ''');
    batch.execute(
      'CREATE INDEX idx_library_favorite ON library (is_favorite);',
    );
    batch.execute('CREATE INDEX idx_library_status ON library (status);');
    batch.execute(
      'CREATE INDEX idx_library_accessed ON library (last_accessed_at, added_at);',
    );

    // 4. Progresso de Leitura
    batch.execute('''
      CREATE TABLE reading_progress (
        work_id TEXT PRIMARY KEY,
        edition_id TEXT NOT NULL,
        chapter_id TEXT,
        current_page INTEGER NOT NULL DEFAULT 0,
        total_pages INTEGER NOT NULL DEFAULT 0,
        char_offset INTEGER DEFAULT 0,
        percentage REAL NOT NULL DEFAULT 0.0,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (work_id) REFERENCES works (id) ON DELETE CASCADE
      );
    ''');

    // 5. Histórico de Sessões de Leitura
    batch.execute('''
      CREATE TABLE reading_history (
        id TEXT PRIMARY KEY,
        work_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        pages_read INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (work_id) REFERENCES works (id) ON DELETE CASCADE
      );
    ''');
    batch.execute(
      'CREATE INDEX idx_history_work ON reading_history (work_id);',
    );
    batch.execute(
      'CREATE INDEX idx_history_date ON reading_history (started_at);',
    );

    // 6. Downloads Persistentes
    batch.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        work_id TEXT NOT NULL,
        edition_id TEXT NOT NULL,
        title TEXT NOT NULL,
        target_path TEXT NOT NULL,
        download_url TEXT NOT NULL,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        downloaded_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (work_id) REFERENCES works (id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_downloads_status ON downloads (status);');

    // 7. Perfil do Usuário Local e Preferências (Fase M)
    batch.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar_id TEXT NOT NULL,
        preferred_language TEXT NOT NULL DEFAULT 'pt-BR',
        font_size REAL NOT NULL DEFAULT 16.0,
        font_family TEXT NOT NULL DEFAULT 'Inter',
        reading_mode TEXT NOT NULL DEFAULT 'paged',
        max_concurrent_downloads INTEGER NOT NULL DEFAULT 2,
        accent_color TEXT NOT NULL DEFAULT 'grafite',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 8. Provedores Registrados e Saúde
    batch.execute('''
      CREATE TABLE providers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        capabilities TEXT,
        last_health_check INTEGER,
        is_healthy INTEGER DEFAULT 1
      );
    ''');

    // 9. Configurações Globais (Chave-Valor)
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await batch.commit(noResult: true);
    AppLogger.info(
      LogCategory.database,
      'Tabelas criadas com sucesso na versão $version.',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      LogCategory.database,
      'Migrando banco de dados da versão $oldVersion para $newVersion...',
    );
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE profiles ADD COLUMN font_size REAL NOT NULL DEFAULT 16.0;",
      );
      await db.execute(
        "ALTER TABLE profiles ADD COLUMN font_family TEXT NOT NULL DEFAULT 'Inter';",
      );
      await db.execute(
        "ALTER TABLE profiles ADD COLUMN reading_mode TEXT NOT NULL DEFAULT 'paged';",
      );
      await db.execute(
        "ALTER TABLE profiles ADD COLUMN max_concurrent_downloads INTEGER NOT NULL DEFAULT 2;",
      );
      AppLogger.info(
        LogCategory.database,
        'Migration v2 aplicada: colunas de preferências adicionadas a profiles.',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_works_series ON works (series);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_library_accessed ON library (last_accessed_at, added_at);',
      );
      AppLogger.info(
        LogCategory.database,
        'Migration v3 aplicada: índices de performance em works e library.',
      );
    }
    if (oldVersion < 4) {
      // v4: identity edição (external_id, idioma, títulos) + ContentAsset
      await db.execute(
        'ALTER TABLE work_editions ADD COLUMN external_id TEXT;',
      );
      await db.execute('ALTER TABLE work_editions ADD COLUMN language TEXT;');
      await db.execute(
        'ALTER TABLE work_editions ADD COLUMN original_title TEXT;',
      );
      await db.execute(
        'ALTER TABLE work_editions ADD COLUMN localized_title TEXT;',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_editions_external ON work_editions (provider_id, external_id);',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS content_assets (
          id TEXT PRIMARY KEY,
          edition_id TEXT NOT NULL,
          format TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'none',
          remote_url TEXT,
          local_path TEXT,
          media_type TEXT,
          file_size INTEGER DEFAULT 0,
          checksum TEXT,
          checksum_algorithm TEXT,
          source TEXT,
          verified_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (edition_id) REFERENCES work_editions (id) ON DELETE CASCADE
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_content_assets_edition ON content_assets (edition_id);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_content_assets_status ON content_assets (status);',
      );

      // Backfill seguro: cobre SEMPRE a verdade. Um asset local validado só
      // existe quando há arquivo físico; um asset remoto, somente quando a
      // URL é HTTP(S) (nunca mock://test://) e não é página de metadata HTML.
      await db.execute('''
        INSERT INTO content_assets (
          id, edition_id, format, status, local_path, file_size, checksum,
          remote_url, created_at, updated_at
        )
        SELECT
          'asset-' || id,
          id,
          format,
           CASE
             WHEN is_local = 1 AND file_path IS NOT NULL AND file_path != ''
               THEN 'downloaded'
             WHEN download_url IS NOT NULL
                  AND (download_url LIKE 'http://%' OR download_url LIKE 'https://%')
                  AND download_url NOT LIKE '%openlibrary.org%'
                  AND download_url NOT LIKE '%/works/%'
                  AND download_url NOT LIKE '%/subjects/%'
                  AND download_url NOT LIKE '%search.json%'
               THEN 'remote_available'
             ELSE 'failed'
           END,
          CASE WHEN is_local = 1 THEN file_path ELSE NULL END,
          file_size,
          checksum,
          CASE WHEN download_url IS NOT NULL
                AND (download_url LIKE 'http://%' OR download_url LIKE 'https://%')
                AND download_url NOT LIKE '%openlibrary.org%'
                AND download_url NOT LIKE '%/works/%'
                AND download_url NOT LIKE '%/subjects/%'
                AND download_url NOT LIKE '%search.json%'
               THEN download_url ELSE NULL END,
          created_at, created_at
        FROM work_editions
        WHERE is_local = 1
           OR (download_url IS NOT NULL AND download_url LIKE 'http%');
      ''');
      // Converte a escala legada 0–100 para a escala canônica 0–1.
      await db.execute('''
        UPDATE reading_progress
        SET percentage = percentage / 100.0
        WHERE percentage > 1.0;
      ''');
      AppLogger.info(
        LogCategory.database,
        'Migration v4 aplicada: ContentAsset, identidade de edição e progresso 0–1.',
      );
    }
    if (oldVersion < 5) {
      // v5 (G-07): acento secundário do perfil; default preserva identidade.
      // Defensiva: DBs sintéticos/antigos podem não ter `profiles`.
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='profiles';",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            avatar_id TEXT NOT NULL,
            preferred_language TEXT NOT NULL DEFAULT 'pt-BR',
            font_size REAL NOT NULL DEFAULT 16.0,
            font_family TEXT NOT NULL DEFAULT 'Inter',
            reading_mode TEXT NOT NULL DEFAULT 'paged',
            max_concurrent_downloads INTEGER NOT NULL DEFAULT 2,
            accent_color TEXT NOT NULL DEFAULT 'grafite',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
      } else {
        final columns = await db.rawQuery('PRAGMA table_info(profiles)');
        final names = columns.map((c) => c['name'] as String?).toSet();
        if (!names.contains('accent_color')) {
          await db.execute(
            "ALTER TABLE profiles ADD COLUMN accent_color TEXT NOT NULL DEFAULT 'grafite';",
          );
        }
      }
      AppLogger.info(
        LogCategory.database,
        'Migration v5 aplicada: accent_color em profiles.',
      );
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      AppLogger.info(LogCategory.database, 'Conexão com SQLite encerrada.');
    }
  }
}

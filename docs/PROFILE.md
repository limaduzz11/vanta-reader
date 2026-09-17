# NovaReader — Perfil do Usuário, Preferências & Armazenamento (Fase M)

## 1. Visão Geral

O subsistema de Perfil do NovaReader foi projetado sob os pilares de **Privacidade Absoluta (Zero Contas Obrigatórias)**, **Local-First** e **Monochromatic Minimalism**. O usuário possui total controle sobre sua identidade local, estatísticas agregadas de consumo e espaço ocupado em disco, sem requisições de rede ou dependência de servidores de terceiros.

---

## 2. Estrutura de Domínio & Entidades

### `UserProfile`
Entidade mestre de identificação e preferências de leitura:
- `id`: Identificador exclusivo da conta local (`primary_profile`).
- `name`: Nome do leitor exibido na interface (padrão: "Leitor").
- `avatarId`: Identificador do avatar monocromático selecionado (padrão: `nova_monolith`).
- `preferredLanguage`: Idioma para filtros de busca e metadados (`pt-BR`, `en`).
- `fontSize`: Tamanho de tipografia preferencial para livros (`14.0`, `16.0`, `18.0`, `20.0`).
- `fontFamily`: Família tipográfica do leitor (`Inter`, `Cinzel`, etc.).
- `readingMode`: Modo padrão de leitura (`paged` para livro paginado, `continuous` para rolagem vertical contínua).
- `maxConcurrentDownloads`: Limite de tarefas de download simultâneas no `DownloadManager` (1 a 4).

### `ReadingStats`
Métricas de leitura computadas em tempo real a partir do SQLite local:
- `booksRead`: Total de livros concluídos (progresso >= 99%).
- `comicsRead`: Total de quadrinhos concluídos (progresso >= 99%).
- `currentlyReading`: Obras com leitura em andamento (0 < progresso < 99%).
- `totalFavorites`: Obras marcadas com estrela na estante local.
- `totalDownloaded`: Total de edições presentes fisicamente no armazenamento.
- `totalPagesRead`: Soma acumulada de páginas lidas em todos os registros.

### `StorageUsage`
Visão transparente do consumo em disco do dispositivo:
- `booksBytes`: Bytes consumidos por livros em `/books/`.
- `comicsBytes`: Bytes consumidos por HQs em `/comics/`.
- `coversBytes`: Bytes consumidos por capas em `/covers/`.
- `thumbnailsBytes`: Bytes consumidos por miniaturas em `/thumbnails/`.
- `cacheBytes`: Bytes ocupados por streaming/buffer em `/cache/`.
- `databaseBytes`: Bytes do arquivo SQLite WAL em `/database/`.
- `totalBytes`: Soma consolidada do consumo do aplicativo.

---

## 3. Catálogo de Avatares Monocromáticos (`NovaAvatar`)

O NovaReader implementa 12 avatares abstratos desenhados exclusivamente com a paleta monocromática da aplicação (`#121212`, `#1E1E1E`, `#E0E0E0`, `#444444`, `#888888`):

| ID | Nome | Simbolismo / Ícone |
|---|---|---|
| `nova_monolith` | Monólito | Obelisco clássico da ficção científica e estabilidade |
| `nova_circle` | Singularidade | Ponto concêntrico e foco profundo de leitura |
| `nova_book` | Grimório | Sabedoria, literatura clássica e páginas abertas |
| `nova_comic` | Quadrinhos | Arte sequencial, nona arte e narrativa gráfica |
| `nova_eye` | Percepção | Atenção, análise crítica e visão ampla |
| `nova_star` | Cosmos | Exploração literária e novos horizontes |
| `nova_cube` | Arquitetura | Estrutura lógica, engenharia e minimalismo técnico |
| `nova_shield` | Guardião | Privacidade local e proteção de dados do leitor |
| `nova_prism` | Prisma | Refração de luz e múltiplas perspectivas de leitura |
| `nova_helix` | Evolução | Aprendizado contínuo e desenvolvimento pessoal |
| `nova_horizon` | Horizonte | Viagem literária e abstração linear |
| `nova_compass` | Bússola | Direção, descoberta e navegação no acervo |

---

## 4. Persistência Relacional (SQLite Schema v2)

Tabela `profiles`:
```sql
CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  avatar_id TEXT NOT NULL,
  preferred_language TEXT NOT NULL,
  font_size REAL NOT NULL DEFAULT 16.0,
  font_family TEXT NOT NULL DEFAULT 'Inter',
  reading_mode TEXT NOT NULL DEFAULT 'paged',
  max_concurrent_downloads INTEGER NOT NULL DEFAULT 2,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

Migração atômica no `AppDatabase._onUpgrade` garante que instalações na versão 1 recebam as novas colunas sem perder nenhum dado prévio.

---

## 5. Gerenciamento Seguro de Armazenamento

O `StorageManager` e o `ProfileBloc` disponibilizam rotinas de higienização de cache:
1. **Limpeza do Cache de Streaming (`ClearCacheEvent(readingCacheOnly: true)`):**
   - Esvazia `/cache/reading/` (arquivos temporários baixados durante sessões de leitura online).
   - Mantém as capas em cache e todo o acervo da estante intacto.
2. **Limpeza de Todo o Cache Volátil (`ClearCacheEvent(readingCacheOnly: false)`):**
   - Esvazia todo o diretório `/cache/`.
   - Exibe diálogo modal de confirmação prévia no Flutter antes de disparar a limpeza.
   - Preserva estritamente as partições permanentes `/books/`, `/comics/`, `/covers/` e `/database/`.

---

## 6. Cobertura de Testes Automatizados

- **Repositório:** `test/data/repositories/profile_repository_test.dart` (4/4 testes passando).
- **BLoC:** `test/presentation/profile_bloc_test.dart` (6/6 testes passando).
- **Widgets e UI:** `test/presentation/profile_screen_test.dart` (3/3 testes passando).
- **Navegação Integrada:** `test/presentation/navigation_test.dart` (2/2 testes passando).

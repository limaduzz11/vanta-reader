# VANTA Reader — Auditoria do Banco de Dados SQLite (Fase 24)

**Data:** 2026-09-09  
**Banco:** SQLite (Driver: `sqflite`)  
**Versão Atual do Schema:** 3  
**Modo Journal:** WAL (Write-Ahead Logging) com `PRAGMA foreign_keys = ON`

---

## 1. Auditoria Estrutural de Tabelas e Índices

### 1. `works` (Tabela Mestre de Obras)
- **Campos:** `id` (PK), `work_key` (UNIQUE), `title`, `subtitle`, `author`, `description`, `primary_language`, `type`, `series`, `volume`, `publisher`, `published_date`, `isbn`, `cover_path`, `created_at`, `updated_at`.
- **Índices:** `idx_works_title`, `idx_works_author`, `idx_works_type`, `idx_works_language`, `idx_works_series`.
- **Integridade:** Chave única `work_key` impede duplicatas de obras equivalentes.

### 2. `work_editions` (Edições e Arquivos Concretos)
- **Campos:** `id` (PK), `work_id` (FK -> `works(id)` ON DELETE CASCADE), `format`, `file_path`, `file_size`, `page_count`, `checksum`, `download_url`, `provider_id`, `is_local`, `created_at`.
- **Índices:** `idx_editions_work`, `idx_editions_format`.
- **Integridade:** Chave estrangeira atrelada à tabela `works`.

### 3. `library` (Estante Pessoal do Usuário)
- **Campos:** `work_id` (PK / FK -> `works(id)` ON DELETE CASCADE), `status`, `is_favorite`, `added_at`, `last_accessed_at`.
- **Índices:** `idx_library_favorite`, `idx_library_status`, `idx_library_accessed`.
- **Integridade:** Relação 1:1 estrita com a obra.

### 4. `reading_progress` (Progresso e Marcos de Leitura)
- **Campos:** `work_id` (PK / FK -> `works(id)` ON DELETE CASCADE), `edition_id`, `chapter_id`, `current_page`, `total_pages`, `char_offset`, `percentage`, `updated_at`.
- **Índices:** `idx_progress_updated`.
- **Garantia de Integridade:** Caso o usuário inicie leitura de uma obra remota via streaming antes de adicioná-la à biblioteca, o método `saveProgress` insere um registro mínimo referencial para evitar violações de FK.

### 5. `downloads` (Fila de Downloads Resiliente)
- **Campos:** `id` (PK), `work_id`, `edition_id`, `title`, `target_path`, `download_url`, `total_bytes`, `downloaded_bytes`, `status`, `error_message`, `retry_count`, `created_at`, `updated_at`.
- **Índices:** `idx_downloads_status`.

### 6. `profiles` (Perfil e Preferências)
- **Campos:** `id` (PK), `name`, `avatar_id`, `preferred_language`, `font_size`, `font_family`, `reading_mode`, `max_concurrent_downloads`, `created_at`, `updated_at`.

---

## 2. Diagnóstico e Limpeza de Dados Mock

### Problema:
O caso de uso legado `SeedInitialCatalogUseCase` inseria obras como `work-dune`, `work-watchmen`, `work-cleancode`, `work-sandman`, `work-neuromancer` e `work-domcasmurro` com o id fixo e as marcava na biblioteca.

### Estratégia Segura de Limpeza:
1. Desativar a execução do seed no `main.dart` e `injection.dart`.
2. O aplicativo verifica se existem registros de `library` cujos `work_id` pertencem aos IDs sintéticos de seed e que não possuam arquivos físicos baixados no disco (`is_local = 0`).
3. Registros de seed que não foram baixados nem explicitamente mantidos pelo usuário são removidos da tabela `library`, deixando a estante limpa no primeiro acesso.
4. Nenhuma obra legítima baixada ou importada pelo usuário é afetada.

---

## 3. Reauditoria — 2026-09-09 (schema real v3)

### Divergências com o documento acima

1. **WAL não é aplicado em Android:** `app_database.dart:77` desativa WAL em `Platform.isAndroid`. O doc afirma "Modo Journal: WAL" como se fosse universal; o ADR-006 ("WAL obrigatório") está **violado** no Android.
2. **Tabelas/colunas divergentes do doc:**
   - `downloads` NÃO possui `retry_count` (o doc afirma que tem).
   - `reading_progress` NÃO possui índice `idx_progress_updated` (não criado no DDL).
   - `downloads.edition_id` não possui FK para `work_editions`.
   - `reading_progress.edition_id` não possui FK para `work_editions` (pode apontar edição inexistente).
   - Schema só v3; `db` de `vantareader.db` com migração de `novareader.db` (rename). Nome compatível preservado de forma segura no código.
3. **Sem tabela de ContentAsset** — identidade de conteúdo remoto/local ausente no schema. `work_editions` acumula `download_url`, `provider_id`, `format`, `file_path` (mistura de fonte/asset).
4. **Sem `external_id`** — a identidade externa é embutida em `work_editions.id` (isso já foi observado também em `id` derivado de provider).
5. **Sem idioma/edição e títulos localizados** — `primary_language` é solo de `works`; nenhum conceito de Edition-language, originalTitle, localizedTitle.
6. **Sem proveniência de metadata** — não há coluna para origem de capa/descrição/título.
7. **`REPLACE` conflitante com FK** — `saveWork/saveWorks` usam `ConflictAlgorithm.replace` em `works`; em SQLite REPLACE com `work_key UNIQUE` pode deletar/usar linha de outra obra, especialmente com FK ON, impactando ids de library/editions.
8. **`removeLegacySeedMocks`** é uma coleção fixa de 6 IDs; não é migração geral (não cobre outros mocks possíveis).
9. **Índices de FTS** — não há busca por título/conteúdo FTS5; `searchLocal` usa `LIKE %s%` (sem performance/escala).
10. **Schema não comporta:**
    - múltiplos assets por edição (EX: mesma edição com PDF+EPUB);
    - cache/reference de capa por Edition;
    - ordem de download/histórico de `edition_id` válido (FK);
    - origem de tipo/serie (para Book/Comic type safety).

### Resultado da auditoria

| Item | Status |
|---|---|
| FK `works → library/editions` | OK |
| FK `editions → works` | OK |
| FK `reading_progress → edition` | FALTA |
| FK `downloads → edition` | FALTA |
| Foreign keys ON | OK (config) |
| WAL Android | FORA |
| FTS/metadata language | FALTA |
| ContentAsset | FALTA |
| Proveniência de metadata | FALTA |
| Migração de limpeza v3 → v4 | NECESSÁRIA (com preservação de dados, analisando órfãos, assets ausentes e compat) |

### Plano de migração v4 (proposta, não executada)

1. Criar `content_assets(id, edition_id FK, kind, remote_url, local_path, media_type, file_size, checksum, status, verified_at, created_at, updated_at)`.
2. Adicionar `external_id` e `content_source` em `work_editions`; manter `work_editions.id` como ID legado preservado.
3. Adicionar `language`, `original_title`, `localized_title` em `work_editions` (ou tabela `edition_metadata`).
4. Adicionar FKs corretas em `reading_progress` e `downloads` (ou registrar colunas como `edition_id` FK).
5. Backfill de `content_assets` a partir de `work_editions.is_local=1` com `file_path` existente; não criar asset fictício para `download_url` HTML.
6. Incluir `removeLegacySeedMocks` como migração versão 4 com whitelist de IDs reais (remover a lista fixa).
7. Índice `(work_id, updated_at)` em `reading_progress` e `idx_downloads_creation`.

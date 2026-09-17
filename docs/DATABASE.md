# NOVAREADER — Especificação Técnica do Banco de Dados SQLite
**Documento Canônico:** `docs/DATABASE.md`  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  
**Status:** IMPLEMENTADO / BASELINE HOMOLOGADA (FASE B)  

---

## 1. Visão Geral e Invariantes
O **NovaReader** utiliza **SQLite nativo** como sua fonte única da verdade para persistência de dados local-first.
- **Arquivo Canônico:** `/NovaReader/database/novareader.db`
- **Modo de Journaling:** `PRAGMA journal_mode = WAL;` (Write-Ahead Logging para permitir leituras concorrentes sem bloqueio durante gravações de downloads ou progresso).
- **Integridade Referencial:** `PRAGMA foreign_keys = ON;` ativa em todas as conexões com deleções em cascata seguras (`ON DELETE CASCADE`).
- **Compatibilidade FFI:** Roda via driver nativo Android no mobile e via `sqflite_common_ffi` no Linux Desktop e suíte de testes unitários.

---

## 2. Diagrama Entidade-Relacionamento (DER)

```mermaid
erDiagram
    WORKS ||--o{ WORK_EDITIONS : "possui edições"
    WORKS ||--o| LIBRARY : "está catalogada"
    WORKS ||--o| READING_PROGRESS : "possui progresso"
    WORKS ||--o{ READING_HISTORY : "registra sessões"
    WORKS ||--o{ DOWNLOADS : "tem downloads"

    WORKS {
        text id PK
        text work_key UK "hash(título + autor)"
        text title
        text subtitle
        text author
        text description
        text primary_language "pt-BR / en"
        text type "book / comic"
        text series
        text volume
        text publisher
        text published_date
        text isbn
        text cover_path
        integer created_at
        integer updated_at
    }

    WORK_EDITIONS {
        text id PK
        text work_id FK
        text format "epub, pdf, txt, cbz, cbr, images"
        text file_path
        integer file_size
        integer page_count
        text checksum
        text download_url
        text provider_id
        integer is_local "0 ou 1"
        integer created_at
    }

    LIBRARY {
        text work_id PK, FK
        text status "added, reading, completed"
        integer is_favorite "0 ou 1"
        integer added_at
        integer last_accessed_at
    }

    READING_PROGRESS {
        text work_id PK, FK
        text edition_id
        text chapter_id
        integer current_page
        integer total_pages
        integer char_offset
        real percentage
        integer updated_at
    }

    READING_HISTORY {
        text id PK
        text work_id FK
        integer started_at
        integer ended_at
        integer duration_seconds
        integer pages_read
    }

    DOWNLOADS {
        text id PK
        text work_id FK
        text edition_id
        text title
        text target_path
        text download_url
        integer total_bytes
        integer downloaded_bytes
        text status "QUEUED, DOWNLOADING, PAUSED, COMPLETED, FAILED, CANCELLED"
        text error_message
        integer created_at
        integer updated_at
    }

    PROFILES {
        text id PK
        text name
        text avatar_id
        text preferred_language
        integer created_at
        integer updated_at
    }

    PROVIDERS {
        text id PK
        text name
        integer is_enabled
        text capabilities
        integer last_health_check
        integer is_healthy
    }

    SETTINGS {
        text key PK
        text value
    }
```

---

## 3. Índices e Otimização de Performance

Os seguintes índices foram criados para garantir pesquisas e filtros com latência < 5ms:
1. `idx_works_title` (`works(title)`): Otimiza busca textual de obras.
2. `idx_works_author` (`works(author)`): Otimiza agrupamento e busca por autor.
3. `idx_works_type` (`works(type)`): Filtro instantâneo entre Livros e Quadrinhos.
4. `idx_works_language` (`works(primary_language)`): Filtro obrigatório de prioridade `pt-BR` e `en`.
5. `idx_editions_work` (`work_editions(work_id)`): Join de alta performance para recuperar múltiplos formatos de uma obra.
6. `idx_library_favorite` (`library(is_favorite)`): Filtro de favoritos instantâneo.
7. `idx_downloads_status` (`downloads(status)`): Consulta imediata da fila de transferências pendentes.

---

## 4. Política de Migrations e Atualizações
- Todas as evoluções estruturais passam pelo callback `onUpgrade(db, oldVersion, newVersion)`.
- Alterações são rigorosamente aditivas (`ALTER TABLE ADD COLUMN`), preservando integralmente o histórico de leitura e obras baixadas.

# VANTA Catalog Import — Guia de Importação de Catálogos Externos

## Visão

O VANTA Catalog API (v0.2) é neutro: não tem provedor built-in. O catálogo é
povoado via **importação direta** (`POST /v1/catalog/import`) ou via provedor
JSON configurável. Este documento cobre a importação direta, incluindo dados
do LIBGEN.

## Opções de Importação

### (A) Importação Direta — `POST /v1/catalog/import`

Endpoint admin que recebe lotes de `BookEdition` e faz upsert no SQLite.

Contrato:
```json
{
  "editions": [
    {
      "id": "string",
      "title": "string",
      "authors": ["string"],
      "publisher": "string | null",
      "year": 1949 | null,
      "language": "string | null",
      "isbn": "string | null",
      "doi": "string | null",
      "pages": 328 | null,
      "series": "string | null",
      "edition": "string | null",
      "cover_url": "string | null",
      "topic": "l",
      "files": [
        {
          "id": "string",
          "extension": "epub | pdf | ...",
          "size_bytes": 612000 | null,
          "pages": 328 | null,
          "md5": "string | null",
          "sha1": "string | null",
          "sha256": "string | null",
          "topic": "l | null",
          "locator": "string | null",
          "available": true
        }
      ]
    }
  ]
}
```

Limites:
- Max **500 edições** por batch (409 se exceder).
- Idempotente: mesma `id` → substitui.
- Requires `VANTA_ADMIN_KEY` (header `X-Vanta-Admin-Key`) se configurado.

Resposta:
```json
{
  "indexed_editions": 200,
  "indexed_files": 203
}
```

### Ferramenta: `scripts/import-libgen.py`

Script Python que lê catálogos LIBGEN (CSV, JSON, SQLite) e envia para a API.

Uso:
```bash
cd "/media/limaduzz/HD 1TB LDUZZ 2/VANTA READER, BIBLIOTECA"

# 1. Simular (não envia)
python3 scripts/import-libgen.py \
    --input /caminho/catalogo.csv \
    --files-dir /caminho/arquivos_locais \
    --dry-run

# 2. Importar de verdade
python3 scripts/import-libgen.py \
    --input /caminho/catalogo.csv \
    --files-dir /caminho/arquivos_locais \
    --api-base http://127.0.0.1:8081 \
    --batch-size 200

# 3. Sugerir template de download (só imprime, não envia)
python3 scripts/import-libgen.py \
    --input /caminho/catalogo.csv \
    --files-dir /caminho/arquivos_locais \
    --suggest-template
```

Formatos suportados:
| Extensão | Formato | Detecção |
|----------|---------|----------|
| `.csv` | CSV libgen | Autodetect colunas via mapeamento flexível |
| `.json` | JSON array/object | `books`, `editions`, `items`, `data`, `results`, `entries` |
| `.ndjson` | NDJSON | Linhas JSON independentes |
| `.db`/`.sqlite`/`.sqlite3` | SQLite | Tabela `Content`/`Books`/`Editions`/`Data` (primeira se não achar) |

Mapeamento de colunas libgen → VANTA:
- Autor: `author`, `authors`, `author(s)`, `writer`
- Título: `title`, `booktitle`
- Editora: `publisher`, `publishers`, `editora`
- Ano: `year`, `publish_year`, `publication_year`
- Idioma: `language`, `lang`, `idioma`
- Formato: `format`, `extension`, `ext`, `tipo`
- Tamanho: `size`, `filesize`, `size_bytes`, `tamanho`
- Páginas: `pages`, `pagecount`, `page_count`
- Hash: `md5`, `hash`, `sha1`, `sha256`
- Locator/URL: `locator`, `url`, `download_url`, `file_url`, `link`
- Tópico: `topic`, `category`, `categories`, `subcategory`, `libgen_topic`

### (B) Provedor JSON — `VANTA_PROVIDER_BASE_URL`

Se libgen expõe API JSON, configure a variável de ambiente. A API faz proxy
paralelo + deduplicação. Veja `PROVIDERS.md`.

## Download — Arquivos Físicos

A API NÃO serve arquivos diretamente. O download é resolvido assim:

1. App chama `GET /v1/files/{file_id}/download`
2. API monta URL via `VANTA_PROVIDER_DOWNLOAD_TEMPLATE` + `file.locator`
3. Retorna `307 Temporary Redirect` para a URL real
4. App segue o redirect e baixa o arquivo

Se `VANTA_PROVIDER_DOWNLOAD_TEMPLATE` não está configurado → **501**
(app trata como metadata-only).

Para servir arquivos locais (biblioteca pessoal):

```bash
# Opção 1: servidor HTTP simples (outro terminal)
python3 -m http.server 8082 --directory /caminho/para/arquivos

# Configure na API:
export VANTA_PROVIDER_DOWNLOAD_TEMPLATE="http://127.0.0.1:8082/{locator}"

# Opção 2: template opaco (requer infra própria)
export VANTA_PROVIDER_DOWNLOAD_TEMPLATE="https://sua-cdn.example/{md5}.{extension}"
```

## Fluxo Completo LIBGEN → VANTA

```
[export.csv / export.json / dump.sqlite]
        │
        ▼
scripts/import-libgen.py
   ├─ parse → VantaBookEdition[]
   ├─ resume: GET /v1/books/{id} (skip existing)
   ├─ batch POST /v1/catalog/import (200/editions)
   └─ report: imported / skipped / errors
        │
        ▼
POST /v1/catalog/import (upsert SQLite FTS5)
        │
        ▼
[app Flutter] GET /v1/search?q=harry → resultados
         /v1/books/{id}            → detalhes + files
         /v1/files/{id}/download   → 307 → arquivo
```

## Resume (Reimportação)

O script verifica automaticamente quais edições já existem via
`GET /v1/books/{id}` antes de importar. Edições existentes são puladas
(skipped). Se quiser forçar reimportação, delete do banco:

```bash
# Apagar tudo e reimportar
python3 -c "
import sqlite3
conn = sqlite3.connect('/caminho/vanta_catalog.db')
conn.execute('DELETE FROM editions')
conn.execute('DELETE FROM files')
conn.commit()
conn.close()
"
```

## Configuração Ambiental (vanta_api.py)

```bash
# Catálogo local (import via API admin)
export VANTA_ADMIN_KEY="minha-chave-secreta"

# Download de arquivos locais
export VANTA_PROVIDER_DOWNLOAD_TEMPLATE="http://127.0.0.1:8082/{locator}"

# Se tiver provedor JSON externo (não necessário para import direto)
export VANTA_PROVIDER_BASE_URL="https://libgen.example/json"

# Log
export VANTA_LOG_LEVEL="INFO"
```

## Status

| Item | Status |
|------|--------|
| Contrato `/v1/catalog/import` | IMPLEMENTADO |
| Script `import-libgen.py` | IMPLEMENTADO (CSV/JSON/NDJSON/SQLite) |
| Resume (skip existing) | IMPLEMENTADO |
| Download template local | AGUARDA CONFIG (precisa de servidor HTTP local) |
| Provedor LIBGEN direto (B) | PLANEJADO |
| Resiliência no download | PLANEJADO |

# VANTA Catalog API — Integração com o App (Flutter)

**Status:** IMPLEMENTADO (2026-09-15) — vanta_api v0.2.0 + provider Flutter `vanta-catalog` + 8 testes verdes
**Data:** 2026-09-10 (arquitetura) / 2026-09-15 (implementação)
**Autor:** NOVA / KRONOS_BUILD (para VANTA Labz)
**Fonte backend:** `vanta_api.py` (FastAPI, catalog gateway neutro)
**Fonte app:** `VANTA Reader` (Flutter, Clean Architecture, provider engine)

**Evidência 2026-09-15:**
- Backend: `APP_VERSION=0.2.0`; `GET /health` 200 `{"status":"ok","version":"0.2.0"}`; `/v1/search` 200; `/v1/files/{id}` 200/404; `/v1/files/{id}/download` 501 sem template e 307 `Location: https://dl.example/get.php?md5=abc123` com template; `POST /v1/catalog/import` indexou 1 edição + 1 arquivo. Backup v0.1: `vanta_api.py.bak-2026-09-15-v0.1` (SHA-256 `38814d8d…7bf`); atual SHA-256 `22255a51…76f4`.
- App: `flutter analyze` **0 issues**; `test/data/providers/vanta_catalog_content_provider_test.dart` **8/8 PASS**; suíte completa **208/208 PASS** (200 + 8).
- Residuais: `description` ponta a ponta (API sem coluna), rate-limit/SSRF allowlist, admin fail-closed em prod, HTTP LAN físico bloqueado pelo `NetworkClient`, Git+backup do app.

---

## 1. Objetivo e Decisão

Adicionar **+1 fonte de dados** ao VANTA Reader: a **VANTA Catalog API** (fastapi gateway
que indexa um catálogo JSON externo em SQLite+FTS5 local e expõe contrato REST estável).

**Decisão do proprietário (Eduardo, 2026-09-10):** a vanta_api é fonte **oficial** do projeto.
O protocolo de catálogo legado é tratado como **API oficial VANTA** — não há política de
negação de fontes no projeto.

**Princípio de arquitetura:** o app **nunca** conhece o protocolo do provider externo
(`object`, `ids`, `limit1/limit2`, `addkeys`, `topic`...). O app consome apenas o contrato
neutro da vanta_api (`BookSummary`, `BookEdition`, `BookFile`, `SearchResponse`, `Health`).
Isso já está estruturado na API e será preservado no Flutter via DTOs próprios.

---

## 2. Contrato da vanta_api consumido pelo app

Base URL configurável (ver §6). Endpoints relevantes:

| Endpoint | Uso no app |
|---|---|
| `GET /health` | `checkHealth()` |
| `GET /v1/search?q=&limit=&offset=&language=&format=` | `search()` com paginação + filtros |
| `GET /v1/books/{edition_id}` | `getDetails()` |
| `GET /v1/books/{edition_id}/files` | Enriquecer edição com arquivos (fallback) |
| `GET /v1/files/{file_id}` | (v0.2 — proposta) detalhe de arquivo |
| `GET /v1/files/{file_id}/download` | (v0.2 — proposta) proxy/redirect de download |
| `POST /v1/catalog/sync`, `POST /v1/catalog/import` | Admin; **não** consumidos pelo app |

Exemplos reais de payload (contrato público da API):

```json
// GET /v1/search?q=1984
{
  "query": "1984",
  "total": 2,
  "limit": 20,
  "offset": 0,
  "items": [
    {
      "id": "12345",
      "title": "1984",
      "authors": ["George Orwell"],
      "publisher": "Example Publisher",
      "year": 1949,
      "language": "English",
      "cover_url": null,
      "formats": ["epub", "pdf"]
    }
  ]
}

// GET /v1/books/12345
{
  "id": "12345",
  "title": "1984",
  "authors": ["George Orwell"],
  "publisher": "Example Publisher",
  "year": 1949,
  "language": "English",
  "isbn": null,
  "doi": null,
  "pages": 328,
  "series": null,
  "edition": null,
  "cover_url": "https://.../cover.jpg",
  "topic": "l",
  "files": [
    {
      "id": "f9876",
      "extension": "epub",
      "size_bytes": 612000,
      "pages": 328,
      "md5": "abc...",
      "sha1": null,
      "sha256": null,
      "topic": "l",
      "locator": "182386/abc.../1984.epub",
      "available": true
    }
  ]
}
```

---

## 3. Arquitetura da Integração no App (Flutter)

Segue exatamente o padrão do provider engine existente (`ContentProvider` →
`ProviderRegistry` → `ProviderManager` → `SearchOnlineCatalogUseCase` → `SearchBloc`).

### 3.1 Novos arquivos

```
lib/
├── core/
│   └── providers/
│       └── vanta/
│           ├── vanta_config.dart              # base URL, timeouts, prefixo de ID
│           └── vanta_models.dart              # DTOs do contrato (4 classes + enums)
└── data/
    └── datasources/
        └── providers/
            └── vanta_catalog_content_provider.dart  # implementa ContentProvider
```

### 3.2 `vanta_config.dart`

```dart
/// Configuração central da fonte VANTA Catalog.
class VantaConfig {
  /// Use --dart-define=VANTA_API_BASE_URL=... para trocar sem rebuild de código.
  final String baseUrl;
  final Duration timeout;

  const VantaConfig({
    this.baseUrl = VantaConfig.defaultBaseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  /// Padrão para desenvolvimento local (emulador Android => host da máquina).
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  /// Prefixo de externalId usado pelo app para evitar colisão entre providers.
  static const String externalIdPrefix = 'vanta_';

  static String? fromEnvironment() => const String.fromEnvironment(
    'VANTA_API_BASE_URL',
  ).isNotEmpty
      ? const String.fromEnvironment('VANTA_API_BASE_URL')
      : null;
}
```

### 3.3 `vanta_models.dart` — DTOs (espelho do contrato)

Classes `Equatable` com `fromJson` explícito (sem geradores):

- `VantaSearchResponse { query, total, limit, offset, items: List<VantaBookSummary> }`
- `VantaBookSummary { id, title, authors: List<String>, publisher?, year?, language?, coverUrl?, formats: List<String> }`
- `VantaBookEdition { id, title, authors, publisher?, year?, language?, isbn?, doi?, pages?, series?, edition?, coverUrl?, topic?, files: List<VantaBookFile> }`
- `VantaBookFile { id, extension?, sizeBytes?, pages?, md5?, sha1?, sha256?, topic?, locator?, available }`
- `VantaHealthResponse { status, version, database, providerConfigured, uptimeSeconds }`

Regras de parsing (replicam os helpers da API Python):
- `authors`: lista simples; se vier string, split por `;`/`|`/`\n`.
- `language`: fica como string crua; a normalização para `pt-BR`/`en` é do
  `MetadataNormalizer` (pipeline existente), não do provider.
- `formats`: já lowercases; vira `WorkFormat.fromExtension`.

### 3.4 `vanta_catalog_content_provider.dart`

```dart
class VantaCatalogContentProvider implements ContentProvider {
  final NetworkClient networkClient;
  final VantaConfig config;

  @override
  String get id => 'vanta-catalog';
  @override
  String get name => 'VANTA Catalog';
  @override
  String get version => '1.0.0';
  @override
  Duration get timeout => config.timeout;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,          // quando /v1/files/{id}/download existir
    supportsStreaming: false,        // leitura online exige download-before-read
    supportedFormats: {epub, pdf, cbz, cbr, txt, images},
    supportedLanguages: {'pt-BR', 'en', 'und'},  // any-language via API
    supportedTypes: {WorkType.book, WorkType.comic},
    contentSourceType: 'officialCatalog',
    rateLimitPerMinute: null,
  );

  Future<ProviderHealth> checkHealth() async { ... GET /health ... }

  Future<List<ExternalWorkMetadata>> search(...) async { ... GET /v1/search ... }

  Future<ExternalWorkMetadata?> getDetails(String externalId) async { ... GET /v1/books/{id} ... }

  Future<String?> resolveDownloadUrl(String externalId, WorkFormat format) async {
    // 1. GET /v1/books/{id}/files (ou reusa cache do getDetails)
    // 2. escolhe file com extension == format.extension && available == true
    // 3. retorna '${baseUrl}/v1/files/${file.id}/download'
  }
}
```

### 3.5 Mapeamento JSON → `ExternalWorkMetadata`

| Campo do app | Origem na API | Observação |
|---|---|---|
| `providerId` | `id` (`'vanta-catalog'`) | fixo |
| `externalId` | `'vanta_' + edition.id` | prefixo previne colisão com OL/IA/Gutendex |
| `externalEditionId` | `file.id` do file primário | usado para resolver download |
| `title` | `title` | |
| `authors` | `authors` | lista direta |
| `language` | `language` | normalizado depois pelo pipeline |
| `type` | derivado: `topic == 'c'` → comic; senão book | heurística documentada |
| `format` | primeiro `formats`/`file.extension` | `WorkFormat.fromExtension` |
| `coverUrl` | `cover_url` | |
| `downloadUrl` | `null` no metadado; resolvido sob demanda | não embutir URL mutável |
| `fileSizeBytes` | `files[0].size_bytes` | |
| `pageCount` | `pages` da edição (ou do file) | |
| `publisher` | `publisher` | |
| `publishedDate` | `year?.toString()` | |
| `isbn` | `isbn` | |
| `series` | `series` | |
| `extraMetadata` | `{topic, doi, md5, sha1, sha256, locator}` | provenance/hashes |

### 3.6 Integração — `lib/injection.dart` (seção 11, após Internet Archive)

```dart
final vantaProvider = VantaCatalogContentProvider(
  networkClient: getIt<NetworkClient>(),
  config: VantaConfig(),
);
providerRegistry.register(vantaProvider);
// + getIt.registerSingleton<VantaCatalogContentProvider>(vantaProvider);
```

Sem mudanças em `ProviderManager`, `SearchOnlineCatalogUseCase`, `SearchBloc`,
`HomeScreen` ou `WorkDetailsScreen`: o provider herdará busca paralela, deduplicação
por `WorkIdentitySystem` e isolamento de falhas automaticamente.

---

## 4. Download — extensão necessária na vanta_api (v0.2)

A vanta_api **v0.1 não distribui links de download** (por design). Para o app baixar e ler
de verdade, o gateway precisa expor 2 novos endpoints (a API é do proprietário, decisão
já autorizada):

```python
# PROPOSTA — vanta_api.py v0.2
@app.get(f"{API_PREFIX}/files/{{file_id}}", response_model=BookFile, tags=["Catalog"])
async def get_file(file_id: str) -> BookFile: ...

@app.get(
    f"{API_PREFIX}/files/{{file_id}}/download",
    status_code=status.HTTP_307_TEMPORARY_REDIRECT,
    tags=["Catalog"],
)
async def download_file(file_id: str) -> RedirectResponse:
    # 1. busca file no SQLite
    # 2. monta URL real a partir do `locator` + template configurável
    #    VANTA_PROVIDER_DOWNLOAD_TEMPLATE=https://host.arch/get.php?md5={md5}  (opcional)
    # 3. retorna 307 Location: <url>
    # Sem template: responde 501 (download indisponível) e o app trata como metadata-only.
```

O app então baixa com `NetworkClient.download(url, ...)` seguindo o redirect (Dio segue
307 por padrão com `followRedirects`) e o `DownloadManager` existente valida container,
tamanho e checksum MD5/SHA-1/SHA-256 quando o file expõe hashes.

**Dependência:** se os endpoints `/v1/files/*` não forem implementados no servidor,
`resolveDownloadUrl` retorna `null` e o provider deve ser declarado `metadataOnly: true`
(comporta como Open Library). Os dois cenários são suportados pela arquitetura.

---

## 5. Mapeamento de Tipo e Idioma

- **Tipo:** o `topic` retornado pela API define a semântica: `c` (comics) → `WorkType.comic`;
  `l`, `m`, `a`, `s`, `f`, `r` → `WorkType.book`. Fallback: extensão dos `formats`
  (`cbz`/`cbr` → comic).
- **Idioma:** o provider retorna o valor cru; `MetadataNormalizer.normalizeLanguage`
  converte `english`→`en`, `portuguese`→`pt-BR`, etc. O filtro `language` da busca
  (`/v1/search?language=`) recebe o código normalizado do app (`pt-BR`/`en`) e a API
  compara com `LOWER()`, aceitando ambos.
- **Deduplicação:** títulos em múltiplos idiomas da mesma obra colapsam via
  `WorkIdentitySystem.generateWorkKey` (ISBN > slug título+autor), sem mudanças.

---

## 6. Configuração e Ambiente

| Ambiente | Base URL | Como |
|---|---|---|
| Emulador Android | `http://10.0.2.2:8080` | default; `NetworkClient` permite HTTP local |
| Device físico (LAN) | `http://192.168.x.x:8080` | `--dart-define=VANTA_API_BASE_URL=...` |
| Produção | `https://api.vantalabz.com` | obrigatório HTTPS (`NetworkClient` bloqueia HTTP remoto) |

Servidor (vanta_api):
```bash
export VANTA_PROVIDER_BASE_URL="URL_DO_PROVEDOR"
export VANTA_DB_PATH=./vanta_catalog.db
uvicorn vanta_api:app --host 0.0.0.0 --port 8080
```

Nota ADB/rede: `usesCleartextTraffic=false` está no manifesto — tráfego HTTP só é aceito
para hosts locais na validação do `NetworkClient` (mesma regra já usada por
Gutendex/OL/IA em dev). Para device físico com IP LAN, avaliar debug-overrides
(flags de debug) em vez de liberar cleartext global.

---

## 7. Testes (espelho do padrão OL/IA)

`test/data/providers/vanta_catalog_content_provider_test.dart`:

1. metadados e capacidades (id, name, formats, types, source type).
2. `search` com query vazia → lista vazia sem rede.
3. `search` happy path com JSON fixo do `/v1/search` → mapeamento correto
   (id prefixado, título, autores, tipo comic para topic `c`).
4. paginação: `page`/`pageSize` → `limit`/`offset` corretos.
5. `getDetails` happy path com JSON fixo de `/v1/books/{id}` → `ExternalWorkMetadata`
   cheio (fileSize, pageCount, isbn, extraMetadata com hashes).
6. `resolveDownloadUrl` → retorna `{base}/v1/files/{id}/download` quando file available;
   `null` quando `available=false` ou formato ausente.
7. `checkHealth` → `healthy` no 200; `offline` em exceção de rede.
8. network error → `search` retorna `[]`.

Também: registro no `provider_registry_test`/`provider_manager_test` permanece verde
(sem mudança de contrato). Rodar `flutter analyze` e `flutter test` (expectativa:
200/200 + novos testes, exit 0).

---

## 8. Ordem de Implementação (executada em 2026-09-15)

> Estado em 2026-09-10: arquitetura CONCLUÍDA e documentada. Nenhum código implementado.
> Execução 2026-09-15: Fases 1–6 CONCLUÍDAS com gates verdes (ver evidência no topo).

### Fase 1 — vanta_api v0.2 (Python / `vanta_api.py`)
1. Refatorar `CatalogDatabase` para expor `get_file(file_id) -> Optional[BookFile]` sincrono
   (+ wrapper async), reutilizando `_load_files` e consultando `files` por `id`.
2. Adicionar endpoint `GET /v1/files/{file_id}` → `BookFile` (404 se inexistente).
3. Adicionar endpoint `GET /v1/files/{file_id}/download` → `307 Temporary Redirect`:
   - lê `file.locator` e opcionalmente `md5`; monta URL via nova env
     `VANTA_PROVIDER_DOWNLOAD_TEMPLATE` (formato `https://host/get.php?md5={md5}` ou
     `{locator}`); sem template → `501` com `detail` claro.
   - nunca expor credenciais/host do provider no corpo.
4. Atualizar docstring de topo (versão 0.2, novos endpoints) e `APP_VERSION = "0.2.0"`.
5. Validar: `uvicorn` + `curl` em `/health`, `/v1/files/{id}`, `/v1/files/{id}/download`
   (esperar 307 com `Location`), e 404/501 nos casos limites.

### Fase 2 — DTOs Flutter (`lib/core/providers/vanta/`)
1. `vanta_config.dart` (base URL, timeout, prefixo `vanta_`, `fromEnvironment`).
2. `vanta_models.dart` — classes `Equatable` com `fromJson`: `VantaSearchResponse`,
   `VantaBookSummary`, `VantaBookEdition`, `VantaBookFile`, `VantaHealthResponse`.
   Regras de parsing replicam os helpers Python (authors split, integers "123.0",
   extension lowercase sem ponto, available booleano).

### Fase 3 — Provider (`lib/data/datasources/providers/vanta_catalog_content_provider.dart`)
1. Implementar `ContentProvider`: `checkHealth` → `/health`; `search` → `/v1/search`
   (page/pageSize → limit/offset, language quando informado); `getDetails` → `/v1/books/{id}`.
2. `resolveDownloadUrl`: escolher file por `format.extension` e `available==true`,
   retornar `{base}/v1/files/{file_id}/download`; senão `null`.
3. Mapeamento JSON → `ExternalWorkMetadata` conforme §3.5 (topic `c` → comic).
4. Declarar capabilities: `supportsDownload` condicional a `/v1/files/*` disponível
   (default `true`; queda para `metadataOnly` automática quando download resolver `null`).

### Fase 4 — Injeção (`lib/injection.dart`)
1. Registrar `VantaCatalogContentProvider` na seção 11 após Internet Archive.
2. Registro singleton em GetIt (padrão existente).

### Fase 5 — Testes (`test/data/providers/vanta_catalog_content_provider_test.dart`)
1. Suite do §7 (8 casos) com `Dio` mock (padrão OL/IA).
2. Iterar até `flutter analyze` 0 issues + `flutter test` verde (200/200 + novos).

### Fase 6 — Sincronização de docs
1. `docs/VANTA-CATALOG-API.md` → status IMPLEMENTADO + evidências (curl, analyze, test).
2. `docs/PROVIDERS.md` → adicionar vanta-catalog na arquitetura de providers.
3. `PROJECT.md` → nova fonte na linha das fases + evidências de teste.

## 9. Ajustes e Melhorias planejadas (para desenvolvimento da API COMPLETA)

Além do Mínimo Viável (Fases 1–6), melhorias que tornam a fonte **completa** e alinhada
ao app (registradas para priorização, não bloqueiam o MVP):

1. **Paginação estável:** expor `total`/`limit`/`offset` já existentes e permitir
   `page_size` maior (batch 100–500) no provider conforme rate limit.
2. **Filtros combinados:** usar `format` + `language` + `topic` juntos no `/v1/search`
   (hoje a API aceita ambos); mapear `topic=c` para o chip "Quadrinhos" da UI.
3. **Tópico configurável no app:** expor seletor de `topic` (l/c/m/a/s/f/r) na tela de
   busca avançada, repassado ao provider via `extraMetadata`.
4. **Enriquecimento tardio:** chamar `getDetails` no detalhe da obra (G-04) para
   preencher `pages`, `description`, `series`, `edition` quando a busca só traz summary.
5. **Cache de capas:** materializar `cover_url` via `CryptoVault`/`StorageManager`
   (D-03) para as fontes vanta-catalog, respeitando offline-first.
6. **Resiliência no download:** retry/backoff no resolver (espelhar retry do servidor),
   e fallback para `refresh=true` quando `/v1/books/{id}` não tiver a edição indexada.
7. **Health com métricas:** incluir `latency_ms`, `provider_configured` e
   `indexed_editions` no `checkHealth` para visibilidade no perfil/erros.
8. **Rate limit por cliente:** header `X-Vanta-Admin-Key` opcional no servidor e
   respeito a `429` no cliente (marcar `degraded`).

## 10. Riscos / Limitações

- Sem `/v1/files/*` no servidor, o provider opera **metadata-only** (não lê/baixa).
- Latência de sincronização: catálogo é indexado via `/v1/catalog/sync` no servidor;
  itens não indexados ainda podem ser resolvidos por `refresh=true` em `/v1/books/{id}`.
- Filtro `format` usa `LOWER(extension)`; formatos com extensões compostas (`epub+zip`)
  precisam de mapeamento no parser da API.
- Sincronização de faixa (`id_start/id_end`) é administrada no servidor, não no app;
  o app depende do acervo já indexado.

---

## 11. Ponto de Retomada (2026-09-15 — pós-implementação)

**Entregue em 2026-09-10:**
- [x] Arquitetura completa documentada (este arquivo).
- [x] Limpeza de referências ao ADR-019 em todo o projeto (docs/lib/test/PROJECT.md) —
      zero ocorrências residuais; protocolo legado tratado como **API oficial VANTA**.
- [x] `PROJECT.md` atualizado apontando para esta fonte.

**Entregue em 2026-09-15:**
- [x] Fase 1 (vanta_api v0.2) → `curl` validado (health/search/files/download 200/404/501/307).
- [x] Fases 2–4 (DTOs, provider, DI) → `lib/core/providers/vanta/` + `vanta_catalog_content_provider.dart` + registro em `injection.dart`.
- [x] Fase 5 (testes) → `flutter analyze` 0 issues + suíte 208/208 (8 novos).
- [x] Fase 6 (docs/project sync com evidências).

**Próxima sessão — priorizar com o proprietário (§9 + Onda 1 P0):**
1. Onda 1 P0 do Gap Register: G-06 (streaming), G-03 (reatividade), G-01 (exclusão).
2. G-02/G-04: `description` ponta a ponta (coluna + FTS + `getDetails` na UI) e correção de metadados descartados.
3. Hardening API: admin fail-closed em prod, rate-limit, SSRF allowlist, OpenAPI versionada, Git + `requirements.txt`.
4. Release: signing + E2E Android real (gate continua WARNING).
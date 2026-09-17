# VANTA Reader — Auditoria de Download (Content Acquisition)

**Data:** 2026-09-09  
**Arquivo avaliado:** `lib/core/download/download_manager.dart`, `online_reading_manager.dart`  
**Gate:** **BLOCK** — o pipeline permite `COMPLETED` sem conteúdo real.

---

## 1. Pipeline atual

```text
enqueue(workId, editionId, url, format)
  → DownloadRepository (SQLite, status=DOWNLOADING)
  → _startDownload
      ├─ url mock:// ou networkClient==null → _executeMockDownload (gera bytes + simula latência)
      └─ url real → dio.get(stream) → sink .part
  → _onDownloadSuccess (rename .part → target, update DB, updateEditionFile, updateLibraryStatus, capa dummy)
```

## 2. Ausência de validação de integridade

| Validação | Presente? | Evidência |
|---|---|---|
| Content-Length completo | Não | `actualTotal = existingBytes + totalBytes`; sem comparação com `Content-Range`/final result |
| Assinatura de arquivo (PNG/JPEG/EPUB/CBZ/PDF) | Não | sem checagem; apenas `.part` rename |
| MIME type | Não | `responseType.stream` sem verificar `content-type` |
| Container válido (zip/epub/pdf) | Não | só o reader valida (e tem fallback sintético) |
| Hash/checksum esperado | Não | `checksum` calculado só no import local |
| Range 206 ↔ 200 coerente | Parcial | usa Range se `.part` existe; sem validação de status/coerência |
| Correlação obra ↔ arquivo | Não | qualquer URL pode gravar em qualquer `editionId` |
| Espaço livre | Não | sem preflight |
| Cancelamento/cleanup | Parcial | `cancelToken` existe; `.part` pode sobrar |

## 3. Violações da regra "Conteúdo real"

- **`enqueue` cria URL `mock://`** quando `edition.downloadUrl` é nulo → download de produção gera EPUB/CBZ/TXT **fictícios** e marca `COMPLETED`.
- **`networkClient == null`** (só em testes) desvia para mock; EM PRODUÇÃO com Dio nulo também desviaria — hoje não há nulo, mas a decisão é frágil.
- **`_onDownloadSuccess` gera capa dummy JPEG** quando a capa não é local.
- **`resolveDownloadUrl` da Open Library retorna `mock://`** para itens sem URL real → qualquer "download" de obra OpenLibrary é sintético.

## 4. Resumo/resume

- `.part` + Range: **implementado** quando servidor suporta 206.
- Sem `Retry-After` nem retry explícito; `retry_count` nem existe no schema (auditoria de banco).
- Após `process death` (`kill` do app): fila de downloads persiste no SQLite; tokens/cancel não sobrevivem, mas a lógica resume do `.part` em novo start — **não testado em Android**.

## 5. Ações necessárias

1. **Criar `ContentAsset`** como contrato único do download: `edition_id + remote_url + media_type + expected_size + expected_checksum + status`.
2. **Validar antes do `COMPLETED`:**
   - status 2xx e tamanho total correto;
   - assinatura/magic bytes por formato;
   - MIME compatível;
   - container minimalmente válido (ZIP/EPUB container.xml/PDF %PDF);
   - checksum quando o provider fornece (SHA-1/MD5 da Metadata API do IA, por exemplo).
3. **Proibir `mock://` em produção:** se `url` é `mock`/`test` e não `kDebugMode`/config de teste → `FAILED` com erro claro.
4. **Correlação obrigatória:** `assetId` gravado em `content_assets` e `work_editions`; a fan-out de download nunca aceita `editionId` de obra diferente.
5. **Capa:** baixar/validar a capa referenciada pela edition; nunca dummy. Usar temp + rename.
6. **Rollback:** `.part`/target removido em falha; atualização de DB em transação com atualização do arquivo.
7. **Retry:** exponencial por `Retry-After`/`429`, limite configurável, `failed` com motivo.
8. **Testes:**
   - URL `mock://` blow up em release;
   - Range/206 e 200 compatíveis;
   - arquivo truncado + assinatura inválida → `FAILED`;
   - hash inválido → `FAILED`;
   - obra A nunca baixa/usa arquivo da obra B;
   - `.part` limpo em falha;
   - process death → resume ou `FAILED` explícito.

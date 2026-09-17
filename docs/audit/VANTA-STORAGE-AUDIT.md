# VANTA Reader — Auditoria de Armazenamento (Storage)

**Data:** 2026-09-09  
**Arquivo avaliado:** `lib/core/storage/storage_manager.dart`  
**Estado:** parcial — estrutura boa, invariante Metadata ≠ Content violado por conveniência.

---

## 1. Estrutura física

| Diretório | Uso | Regra de exclusão |
|---|---|---|
| `VANTAReader/books/` | Livros (EPUB/TXT/PDF) do usuário | NUNCA automática |
| `VANTAReader/comics/` | HQs (CBZ/CBR) do usuário | NUNCA automática |
| `VANTAReader/covers/` | Capas persistidas | NUNCA automática (vínculo com Work) |
| `VANTAReader/thumbnails/` | Miniaturas/cache derivado | PODE ser recriado |
| `VANTAReader/cache/reading/` | Streaming temporário | **PODE ser excluído** (é cache) |
| `VANTAReader/database/` | SQLite | NUNCA automática |

> **Observação:** `storage_manager.dart` cria `databaseDir` mas `AppDatabase` usa `getDatabasesPath()` (padrão do sistema), não o `databaseDir` do manager. Divergência: banco fora da árvore VANTAReader em Android.

## 2. Migração de legado (NovaReader → VANTAReader)

`initialize()` tenta `rename(NovaReader → VANTAReader)` **apenas uma vez** e silencia erro (`catch (_)`), depois escolhe `vantaRoot` ou `legacyRoot` inconsistente com o rename.
`AppDatabase` também tenta `novareader.db → vantareader.db` com `renameSync` em try/catch.

**Risco:** se o rename falhar (ex.: diretório de destino já existe com conteúdo), o app usa quem existir e pode, em execuções seguidas, alternar entre raízes, "perdendo" obras no nível da UI. Não há sinalização de migração incompleta nem hash de origem.

## 3. Separação METADATA / COVERS / THUMBNAILS / CACHE / DOWNLOADS

- Metadados: SQLite (fora da árvore física) — OK.
- Covers: `covers/` — porém o download **gera JPEG dummy** quando ausente (não baixa a capa real), e o parser/leitor usa capa remota sem cache consistente.
- Thumbnails: diretório criado e medido, mas não é populado por nenhum pipeline identificado.
- Cache: `cache/reading/` — correto; `clearCache()` limpa **somente** `cache/`, preservando books/comics. OK.
- Downloads: `books/` e `comics/` — correto; porém há **duplicata de conceito** com `cache/reading/` (streaming que não foi promovido pode ser "promovido" com conteúdo sintético).

## 4. Segurança de path

- `validateSafeFileName` bloqueia `..`, `/`, `\`, vazio. OK.
- `getSafeFile` + `p.isWithin`. OK.
- `resolveSafeZipEntry` bloqueia `..`, NUL, `..` inicial, absoluto. OK.
- `isSafeZipEntry` usado no `ComicContentParser`; quando inválida, **gera página BMP sintética** (mascaramento de segurança).

## 5. Validações que faltam

- No `clearCache`/`clearReadingCache`: objetos/metadata que apontam para `cache/reading` não são sinalizados (sessões promovidas nunca devem apontar para cache).
- `getCoverPath` não valida extensão de imagem nem assinatura.
- Não há `storage quota`/`free space` checado antes de download; `targetFile` pode falhar mid-stream sem rollback de `.part`.
- Não há verificação de estado de arquivo importado vs. tabela (órfãos em disco sem registro; registros sem arquivo em disco).
- Não há `file signature`/MIME.

## 6. Correções necessárias

1. Fazer `AppDatabase` usar `storageManager.databaseDir` (unificar árvore) OU documentar e manter separado intencionalmente (migrar DB de sistema → árvore é mais determinístico).
2. Migração de legado: exigir resultado explícito, registrar hash/marca para não repetir, e evitar alternância de raízes; teste de migração com ambas as raízes.
3. Baixar capa real em `covers/` (nunca dummy) e validar assinatura JPEG/PNG; registrar `coverPath` atômico (temp + rename).
4. `clearReadingCache` deve remover apenas `cache/reading` e nunca tocar `books/comics` — já correto, mas falta por sessão/uso.
5. Auditoria de órfãos: arquivos sem registro (somente em dev/tools) e registros sem arquivo (marque status, não delete).
6. Validar espaço livre antes de enfileirar download; abortar com estado claro.
7. Remover geração sintética no parser ao detectar entrada zip inválida; apresentar erro.
8. Separar explicitamente: `downloads/` é sinônimo de `books/`+`comics/` com `is_local=1` (não criar terceiro diretório).

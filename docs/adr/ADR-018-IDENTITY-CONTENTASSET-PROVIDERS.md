# ADR-018 — Identidade de Obra, ContentAsset e Providers Honestos

**Data:** 2026-09-09  
**Status:** PROPOSTO (aguarda aprovacão da reauditoria)  
**Substitui/deriva de:** ADR-010, ADR-011, ADR-012, ADR-014  
**Consequência de:** VANTA-DOCUMENT-INDEX.md, VANTA-METADATA-AUDIT.md, VANTA-CONTENT-AUDIT.md, VANTA-PROVIDER-AUDIT.md

## Contexto

A causa raiz sistêmica não é a Search: é a ausência de uma identidade completa e rastreável entre obra, edição, fonte e conteúdo, combinada com mocks/fallbacks que podem aparentar sucesso. O modelo atual (`WorkEdition` acumulando edição/formato/URL/arquivo) não permite garantir: obra A → capa A → conteúdo A.

## Decisão

1. **Modelo em camadas rastreável:**
   - `Work`: identidade canônica (workId, workKey, metadata localizada principal, type BOOK|COMIC explícito).
   - `Edition`: identidade editorial (editionId, language, originalTitle, localizedTitle, publisher, isbn); pode ter múltiplos formatos.
   - `ProviderSource`: referência por edição (providerId, externalId, collection, sourceType).
   - `CoverAsset`: ligado à obra/edição com proveniência (URI remota ou path local, checksum).
   - `ContentAsset`: ligado à edição e ao formato (remoteUrl, localPath, mediaType, size, checksum, status: none|remote_available|validated|downloaded|failed).

2. **Proibição absoluta:** runtime normal nunca gera conteúdo sintético (páginas, capítulos, capas, streams, downloads). Falha → estado de erro tipado. Test/demo devem ser explicitamente rotulados e impossíveis em release.

3. **Capabilities honestas:** `supportsDownload`/`supportsStreaming` somente quando há resolução real de asset para a obra em questão; caso contrário, `metadataOnly=true`.

4. **Providers:**
   - Open Library: metadata + capas apenas (sem download/streaming declarados).
   - Gutendex (mirror/self-host preferido): livros domínio público com asset real; buscar por identical external ID.
   - Internet Archive: fonte de comics public domain com verificação por item (`is_lendable`, `licenseurl`, `collection`); somente download quando public domain; não usar conteúdo lendable.
   - Padrão ouro: APIs oficiais, datasets licenciados, domínio público.
   - VANTA Catalog API: fonte oficial do projeto (gateway neutro; ver `docs/VANTA-CATALOG-API.md`).
   - HQMania fica como benchmark de UX apenas.

5. **Navegação por identidade:** Details/Reader recebem `workId + editionId` e resolvem pelo repositório; nunca apenas `title`. Reader resolve o `ContentAsset` local/remoto da edição, não "qualquer edição da obra".

6. **Idioma por edição:** prefer/ranking por edição localizada do perfil, sem inventar localização; título original exibido quando não existe localizada.

7. **Progresso com escala única:** `percentage` sempre 0.0–1.0 (e 0–100 apenas em camada de exibição); `current_page`/`total_pages` válidos por edição; nunca criar "Obra Online" fantasma.

8. **Migrations:** v4 adiciona `content_assets`, `external_id`/`language`/`original_title`/`localized_title` em editions, FKs corretas de `reading_progress`/`downloads`, remove lista fixa de seeds (substitui por migração de IDs de seed), sem deletar dados de usuário.

9. **Isolamento de dev data:** `MockData`/`MockContentProvider` só registrados por flag explícita de teste (nunca em release/default); fixtures movidas para `test/fixtures/` e fora do bundle release; assets comerciais (`sample_comics`, `covers`) removidos do bundle ou licenciados.

## Alternativas consideradas

- **A) Adicionar mais validações no modelo atual:** rejeitada — não resolve a mistura de conceitos por campo (Edition = edição + source + asset).
- **B) Substituir tudo por Catálogo remoto:** rejeitada — sem offline/autonomia da biblioteca.
- **C) Manter WorkEdition mas criar coluna local_path:** rejeitada — duplica conceito de asset e não resolve correlacionamento de capa/metadata.
- **D) Modelo em camadas + ContentAsset explícito + providers honestos:** escolhida — resolve identidade, testabilidade e compliance com custo controlado.

## Consequências

- Migração de schema v3 → v4 com backfill seguro (nunca cria asset fictício).
- Componentes afetados: entidades, repositório, normalizador, providers, download manager, online reading, readers, UI de Details/Library/Home, testes.
- Compatibilidade legada: storage `NovaReader/` → `VANTAReader/` e `novareader.db` → `vantareader.db` mantidos com migração explícita e sem delete.
- Custo em desempenho: 1 query a mais por edição (content_assets); aceitável.

## Rollback

- Migração v4 é reversível (backup de banco antes; `DROP` de tabelas novas restaurando v3) desde que arquivos de usuário não sejam deletados.
- Nova entidade isolada: pode ser desativada por `feature flag` sem retornar ao modelo antigo.

## Testes

- Unit: identidade, dedup, localização, escala de progresso, capabilities, validação de asset.
- Integração: repositório com FK, migrations v3→v4, mock never registered, capa real, download real com URL, sem contenido sintético.
- E2E: busca → details → download → offline → reabrir (E2E #1–#10 do mandato).

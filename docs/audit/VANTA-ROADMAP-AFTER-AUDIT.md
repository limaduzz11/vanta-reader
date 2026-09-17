# VANTA Reader — Roadmap Pós-Auditoria

**Data:** 2026-09-09  
**Base:** diagnóstico inicial concluído (docs/audit/VANTA-*.md) + ADR-018  
**Estado:** implementação ainda NÃO iniciada  
**Meta:** VANTA Reader funcional, coerente, testável, sem pontas soltas, com conteúdo real e fontes legais.

## Ordem de execução (checagem PRÉ-REQUISITO)

### Fase R1 — Fundação de identidade e dados (E4)
- [ ] Modelo `ContentAsset`, `ProviderSource`, `CoverAsset` + refactor `Work/Edition` (compat preservada).
- [ ] Migração SQLite v4 (backfill seguro, FKs, `external_id`, `language`, originais localizados).
- [ ] Escala única de progresso (0–1) + correção de stats e readers.
- [ ] Navegação por `workId + editionId` (Details/Reader; WorkDetailsBloc ativado).

### Fase R2 — Proibição de conteúdo sintético em produção
- [ ] `MockContentProvider`/`MockData` fora do runtime default (flag explícita).
- [ ] Remover fallbacks sintéticos de `BookContentParser`, `ComicContentParser`, `OnlineReadingManager`, `DownloadManager`, capa dummy.
- [ ] Erros tipados (conteúdo indisponível/fora de rede), estados empty/error honestos.
- [ ] Fixtures para `test/fixtures/`; remover assets comerciais do bundle (ou licença documentada).
- [ ] `kill switch` de ambiente para conteúdo demo (config separada), nunca em release.

### Fase R3 — Providers honestos e Search
- [ ] Capabilities baseadas em evidência (`metadataOnly`, formatos reais, rate limits documentados).
- [ ] Open Library: metadata + capas somente (cache, User-Agent, throttle).
- [ ] Gutendex: busca/download apenas com `externalId` correto (resolve pelo endpoint `/books/{id}` e não recria por título).
- [ ] Internet Archive: provider Comics public domain (advancedsearch + metadata/item) com verificação `is_lendable`/`licenseurl`/coleção; falha isolada; `type=COMIC` por coleção, não heurística.
- [ ] Search: normalização por provider, idioma do perfil na cadeia inteira, dedup por página, timeout progressivo (resultados parciais), regra min-query, ranking por edição localizada.
- [ ] Home: `LIVROS POPULARES` preservado; `QUADRINHOS EM DESTAQUE` de fonte comic real; "Continuar lendo" por progresso real.

### Fase R4 — Download e leitura online
- [ ] Pipeline de download com validação (status, Content-Length, MIME, assinatura, container, checksum quando houver).
- [ ] `ContentAsset.status` lifecycle; `COMPLETED` só após validação; `FAILED` com motivo; `.part` limpo.
- [ ] Capa real persistida em `covers/` (temp + rename + assinatura).
- [ ] `Read Online` exige asset remoto validável; retry/exponencial; sem payload artificial.
- [ ] Espaço livre antes do enqueue; multi-download com limite configurado.

### Fase R5 — Readers
- [ ] Book Reader: texto real EPUB/TXT, PDF via lib real ou erro honesto (PDF real é P1; sem fake), busca/seleção/bookmark/margens por preferência, tipografia persistida do perfil.
- [ ] Comic Reader: CBZ real (páginas validadas), CBR real (RAR) ou erro honesto (sem tratar como ZIP), paginação/zoom/pan/prefetch/landscape/reabertura, orientação, progresso com escala correta.
- [ ] Reabertura por identidade preservando edição+progresso.

### Fase R6 — Library / Profile / Offline
- [ ] Library: somente estado do usuário (adicionar/importar/baixar); remoção com cleanup de arquivos (com confirmação); estados vazios honestos.
- [ ] Profile: idioma efetivo no Search/ranking/UI; avatar persistido local; preferências aplicadas nos readers.
- [ ] Offline: verificação de conectividade; obras não baixadas → aviso "requer rede"; baixado → leitura local; cache de streaming nunca=disponibilidade.
- [ ] Assinatura do APK release com keystore própria; remoção de debug signing.

### Fase R7 — Qualidade e validação
- [ ] Unit + integração para R1–R6 (mocks de rede, fixtures legais).
- [ ] E2E #1–#10 do mandato (com device Android quando disponível; Linux/desktop como fallback com mesma suíte).
- [ ] Regression (Fase 27) + Performance (Fase 25: 50/100/500/1000 obras, PDF/EPUB/HQ grandes, múltiplos downloads).
- [ ] Logs estruturados com contexto (SEARCH_*, DOWNLOAD_*, READER_*, DB_*).
- [ ] Release Gate (Fase 34) + Health Score (Fase 33) + relatório final (Fase 39).

## Não contido nesta rodada (não bloquear release se decorrente de fonte externa legal):

- Catálogo traduzido/pt-BR de HQs: depende de fonte legal verificada (Internet Archive PD pode ser majoritariamente EN); **nunca** inventar localização.
- PDF render (se lib real aprovar) — P1.
- Streaming incremental real — hoje é cache-before-read; documentar e usar somente se provider suportar.

## Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Migração v4 quebra dados existentes | Backup antes; migração testada em fixture v3 real; rollback descrito |
| Remoção de mock reduz catálogo | Estado honesto vazio > catálogo fake; Home/documentação esclarecem |
| IA/Open Library sem resultados de HQ pt-BR | Fonte primária EN/PD; busca em português cai num "sem resultados" explicado |
| Muitas dependências externas | Preferência por API oficial + mirror próprio; isolamento por provider |
| Falta de device Android | E2E em Linux com abstração; suíte de device marcada como pendente |

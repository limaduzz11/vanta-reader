# VANTA Reader — Índice Documental da Reauditoria

**Data:** 2026-09-09  
**Status:** diagnóstico inicial, pré-correção  
**Escopo:** 59 documentos textuais lidos; ZIPs duplicados não foram tratados como fonte.  
**Hierarquia aplicada:** código executável → testes → runtime observado → arquitetura → planejamento → comentários.

## Legenda

- **ATIVO:** ainda representa uma decisão vigente.
- **RECONCILIAR:** contém valor, mas diverge do código ou de evidências superiores.
- **HISTÓRICO:** preservado como contexto datado, não como estado atual.
- **OBSOLETO:** não deve orientar implementação nova.
- **BLOQUEADO:** não pode sustentar release até nova validação.

## Documentos da raiz

| Documento | Objetivo | Status | Relevância | Decisões importantes | Contradições/divergências com código | Ação |
|---|---|---|---|---|---|---|
| `PROJECT.md` | Estado canônico e fases | RECONCILIAR | Crítica | VANTA Reader; Flutter; local-first; fases A–P | Declara conclusão integral, Clean Architecture, formatos e 184 testes sem refletir mocks ativos, PDF/CBR incompletos, ausência de ContentAsset e gate real | Corrigir após validação dinâmica; manter como entrada canônica |
| `README.md` | Apresentação do projeto | OBSOLETO | Alta | Nenhuma | Boilerplate Flutter; título `novareader` | Substituir por README VANTA verificável |
| `NOVAREADER-INITIAL-AUDIT.md` | Baseline inicial de ambiente | HISTÓRICO | Média | Toolchain e riscos iniciais | Nome legado e dados sensíveis ao tempo | Preservar; marcar superseded |
| `NOVAREADER-ARCHITECTURE-PROPOSAL.md` | Arquitetura-alvo inicial | HISTÓRICO | Alta | Clean Architecture, SQLite, providers, readers | Arquitetura real é híbrida; formatos e streaming divergem | Preservar proposta; apontar para arquitetura as-built |
| `NOVAREADER-ROADMAP.md` | Roadmap A–R | OBSOLETO | Alta | Sequência e gates | Duplica `docs/ROADMAP.md`; estados não refletem realidade | Substituir por roadmap pós-auditoria |

## Documentos técnicos e de produto

| Documento | Objetivo | Status | Relevância | Decisões importantes | Contradições/divergências com código | Ação |
|---|---|---|---|---|---|---|
| `docs/ROADMAP.md` | Roadmap A–R | OBSOLETO | Alta | Mesmo conteúdo do roadmap raiz | Duplicidade canônica e gate não comprovado | Manter apenas referência histórica |
| `docs/PRODUCT-SPEC.md` | Requisitos funcionais e não funcionais | RECONCILIAR | Crítica | Livros/HQs, offline, readers especializados | Parte dos requisitos está apenas mock/parcial | Converter em matriz requisito→código→teste→runtime |
| `docs/ARCHITECTURE.md` | Arquitetura consolidada | RECONCILIAR | Crítica | Clean Architecture e limites | UI acessa data/core/getIt; Domain depende de core/data; DataSource explícito ausente | Reescrever como as-built após correções |
| `docs/DESIGN-SYSTEM.md` | Tokens, componentes e responsividade | ATIVO/LEGADO | Alta | Design monocromático e breakpoint tablet | APIs e arquivos ainda usam `Nova*` | Definir migração segura para `Vanta*` ou compatibilidade explícita |
| `docs/DATABASE.md` | Schema e política SQLite | OBSOLETO | Crítica | SQLite, WAL, FKs | Nome do DB, WAL Android, índices e campos divergem do DDL | Regenerar a partir do schema executável |
| `docs/OFFLINE-FIRST.md` | Invariantes offline | RECONCILIAR | Alta | SQLite local e cache isolado | Fallback sintético pode aparentar disponibilidade real | Reforçar Metadata ≠ Content e remover fallback de produção |
| `docs/FILE-IMPORT.md` | Pipeline de importação | RECONCILIAR | Alta | EPUB/CBZ/PDF/TXT/CBR | CBR é enviado a ZIP; pasta de imagens ausente; PDF limitado | Publicar matriz real de formatos |
| `docs/BOOK-READER.md` | Motor de livros | RECONCILIAR | Alta | EPUB/TXT/PDF e progresso | PDF não é renderizado; corrupção vira demo | Separar suportado, parcial e não suportado |
| `docs/COMIC-READER.md` | Motor de HQ | RECONCILIAR | Alta | CBZ/CBR, LRU, webtoon, RTL | CBR real não abre; orçamento cobre bytes compactados, não bitmap | Corrigir claims e validar device real |
| `docs/DOWNLOADS.md` | Download manager | RECONCILIAR | Alta | Fila, `.part`, Range, retry | Providers podem entregar `mock://`; caminho HTTP real sem teste | Exigir asset real e validação de integridade |
| `docs/PROVIDERS.md` | Contratos e providers | RECONCILIAR | Alta | Registry, health, normalização, dedup | Mock ativo; capabilities não correspondem a conteúdo real | Criar matriz as-built por provider |
| `docs/SEARCH-CATALOG.md` | Busca unificada | RECONCILIAR | Alta | Debounce, filtros, ranking | Resultados podem ser mock; idioma não governa toda cadeia | Revalidar com consultas reais e rastreamento por etapa |
| `docs/ONLINE-READING.md` | Leitura online/cache | RECONCILIAR | Alta | Local→cache→rede e promoção | Implementação baixa arquivo inteiro; falha gera conteúdo sintético | Proibir promoção/fallback artificial em produção |
| `docs/END-TO-END-INTEGRATION.md` | Evidência online→offline | HISTÓRICO/MOCK | Alta | Fluxo integrado determinístico | Usa provider mock e SQLite FFI; não é E2E Android/rede | Reclassificar como teste de integração |
| `docs/PROFILE.md` | Perfil e preferências | RECONCILIAR | Média | Perfil local, idioma, avatar, storage | Preferências não controlam integralmente readers/downloads | Validar persistência e efeito comportamental |
| `docs/ACCESSIBILITY-AND-POLISH.md` | Acessibilidade e UX | RECONCILIAR | Alta | Semantics, Hero, touch target | Claim completo não possui validação TalkBack/device; chip aceita 36dp | Criar matriz manual+automatizada |
| `docs/PERFORMANCE.md` | Benchmarks | RECONCILIAR | Alta | Batch DB e LRU | Métricas host/sintéticas não provam Android, bitmap ou 4K | Medir em phone/tablet e registrar método |
| `docs/SECURITY.md` | Hardening | BLOQUEADO | Crítica | Cripto, HTTPS, path safety | KDF não é PBKDF2; acesso direto a Dio contorna política; assets sem licença | Revisão de segurança e legal antes de release |

## ADRs

| Documento | Objetivo/decisão | Status | Relevância | Contradição/divergência | Ação |
|---|---|---|---|---|---|
| `docs/adr/ADR-001-ARCHITECTURE.md` | Flutter + BLoC + SQLite + Clean | ACEITO/DRIFT | Crítica | Dependências violam limites | Manter decisão e corrigir aderência mínima necessária |
| `docs/adr/ADR-002-LOCAL-FIRST.md` | Local-first e cache isolado | ACEITO | Alta | Mock/fallback viola transparência | Adendo contra conteúdo sintético |
| `docs/adr/ADR-003-DESIGN-SYSTEM.md` | Design `Nova*` e breakpoint 720 | ACEITO/LEGADO | Alta | Nome oficial é VANTA | Decidir alias/migração sem replace cego |
| `docs/adr/ADR-004-LOCAL-FIRST-PERSISTENCE.md` | Repositórios, WAL e seed | ACEITO/DRIFT | Alta | Seed foi desativado; WAL Android não explícito | Atualizar decisão |
| `docs/adr/ADR-005-FILE-IMPORT-PIPELINE.md` | Importação de formatos | ACEITO PARCIAL | Alta | CBR/imagens/PDF não atendem claims | Adendo de suporte real |
| `docs/adr/ADR-006-DATABASE.md` | WAL obrigatório | VIOLADO | Crítica | Android é excluído do PRAGMA observado | Corrigir código ou decisão, com teste |
| `docs/adr/ADR-007-BOOK-READER-ENGINE.md` | Reader EPUB/TXT/PDF | ACEITO PARCIAL | Alta | PDF/fallback são sintéticos | Separar pipelines e erros |
| `docs/adr/ADR-008-COMIC-READER-ENGINE.md` | Reader CBZ/CBR/imagens | ACEITO PARCIAL | Alta | CBR e imagens soltas ausentes | Reabrir decisão |
| `docs/adr/ADR-009-DOWNLOAD-MANAGER.md` | Fila, resume e persistência | ACEITO/DRIFT | Alta | Caminho real e process death não comprovados | Testar servidor Range e restart |
| `docs/adr/ADR-010-PROVIDER-ENGINE.md` | Registry, health e mock | ACEITO/DRIFT | Alta | Mock está no runtime padrão | Condicionar por ambiente |
| `docs/adr/ADR-011-UNIFIED-SEARCH-CATALOG.md` | Busca e ranking | ACEITO PARCIAL | Alta | Mock e idioma afetam integridade | Revalidar pipeline real |
| `docs/adr/ADR-012-ONLINE-STREAMING-READER.md` | Streaming/cache | ACEITO/SEMÂNTICA INCORRETA | Alta | É cache-before-read, não streaming incremental | Corrigir termo ou implementação |
| `docs/adr/ADR-013-END-TO-END-PIPELINE.md` | E2E catálogo→offline | ACEITO COM EVIDÊNCIA MOCK | Alta | Não usa Android nem rede real | Reclassificar e criar E2E real |
| `docs/adr/ADR-014-USER-PROFILE-SYSTEM.md` | Perfil local | ACEITO/SUPERADO EM PARTE | Média | Default e IDs legados divergem de ADR-017 | Registrar supersessão |
| `docs/adr/ADR-015-ACCESSIBILITY-AND-UX-POLISH.md` | WCAG/TalkBack/48dp | ACEITO PARCIAL | Alta | Evidência manual/device ausente | Revalidar |
| `docs/adr/ADR-016-PERFORMANCE-AND-RESOURCE-MANAGEMENT.md` | N+1, LRU, 4K | ACEITO COM OVERCLAIM | Alta | Não mede bitmap/VRAM | Reespecificar orçamento |
| `docs/adr/ADR-017-SECURITY-HARDENING.md` | Cripto, HTTPS e release | BLOQUEADO | Crítica | Implementação não sustenta claims | Revisão ARGOS antes de release |
| `docs/adr/ADR-018-IDENTITY-CONTENTASSET-PROVIDERS.md` | Identidade, `ContentAsset` e providers | ACEITO | Crítica | Baseline R1–R4 | Manter como decisão vigente |
| `docs/VANTA-CATALOG-API.md` | Fonte oficial VANTA Catalog (gateway neutro + provider Flutter) | PROPOSTO | Crítica | Resolve G-02/G-04 | Implementar (passos 1–5) |

## Pesquisas

| Documento | Objetivo | Status | Relevância | Divergências/limites | Ação |
|---|---|---|---|---|---|
| `docs/research/OPENLIB-RESEARCH.md` | Referência Openlib | HISTÓRICO | Média | Sem versão/commit reproduzível | Usar apenas qualitativamente |
| `docs/research/BOOKLORE-RESEARCH.md` | Referência BookLore | HISTÓRICO | Média | Métricas não demonstradas | Registrar fontes em futura revisão |
| `docs/research/IREADER-RESEARCH.md` | Referência de providers/filas | HISTÓRICO | Média | Branding legado | Preservar |
| `docs/research/READEST-RESEARCH.md` | Referência de UX | HISTÓRICO | Baixa | Claims não medidos | Tratar como inspiração |
| `docs/research/READERA-RESEARCH.md` | Referência offline/readers | HISTÓRICO | Média | Capacidades não herdadas pelo VANTA | Separar inspiração de implementação |
| `docs/research/COMPETITIVE-ANALYSIS.md` | Diferenciais desejados | RECONCILIAR | Alta | Mistura alvo e implementado | Criar colunas alvo/implementado/validado |

## Auditorias e gates existentes

| Documento | Objetivo | Status | Relevância | Contradições/divergências | Ação |
|---|---|---|---|---|---|
| `docs/audit/VANTA-INITIAL-INVENTORY.md` | Inventário prévio | HISTÓRICO ÚTIL | Alta | Alguns achados persistem | Mapear finding→correção→teste |
| `docs/audit/VANTA-ARCHITECTURE-AUDIT.md` | Auditoria de camadas | REABERTO | Alta | Violações ainda existem | Substituir por reauditoria atual |
| `docs/audit/VANTA-FUNCTIONAL-AUDIT.md` | Observação em device | HISTÓRICO | Alta | Sem anexos reproduzíveis | Reexecutar com build/hash/logs |
| `docs/audit/VANTA-FIX-PLAN.md` | Plano FIX-01–08 | OBSOLETO | Alta | Status não acompanha claims posteriores | Substituir por roadmap pós-auditoria |
| `docs/audit/VANTA-SEARCH-AUDIT.md` | Busca e ranking | REABERTO | Alta | Mistura esperado e observado; mock ativo | Reexecutar matriz real |
| `docs/audit/VANTA-PROVIDER-AUDIT.md` | Providers e licenças | INCORRETO | Crítica | Declara Archive.org não implementado | Reescrever pelo registry real |
| `docs/audit/VANTA-DATABASE-AUDIT.md` | Schema e cleanup | REABERTO | Crítica | Campos/índices divergem do DDL | Auditar banco real e migrations |
| `docs/audit/VANTA-READER-AUDIT.md` | Readers e fullscreen | REABERTO | Alta | PDF/CBR/conteúdo real não comprovados | Revalidar por formato |
| `docs/audit/VANTA-LIBRARY-AUDIT.md` | Isolamento da biblioteca | REABERTO | Alta | Home/provider continuam mock | Validar DB limpo e estado vazio |
| `docs/audit/VANTA-OFFLINE-AUDIT.md` | Modo offline | EVIDÊNCIA INSUFICIENTE | Alta | Sem modo avião real; mock mascara falha | Reexecutar em Android |
| `docs/audit/VANTA-TEST-REPORT.md` | Consolidar suíte | REVISAR | Crítica | Contagens históricas e natureza E2E divergentes | Gerar relatório do runner atual |
| `docs/audit/VANTA-FULL-AUDIT.md` | Fechamento/RC | INVALIDADO | Crítica | Claims contraditos por código | Substituir ao final da reauditoria |
| `docs/audit/VANTA-RELEASE-GATE.md` | Autorizar release | WARNING (debug validado) | Crítica | Sem release assinada; device debug validado | Manter WARNING até release assinada |
| `docs/audit/VANTA-GENERAL-AUDIT-2026-09-09.md` | Auditoria geral e diagnóstico do funcionamento | ATIVO | Crítica | Baseline de como tudo funciona + 8 gaps do usuário + derivados; APK debug validado no SM-A366E | Fonte para correções R5+ |
| `docs/audit/VANTA-GAP-REGISTER-2026-09-09.md` | Registro dos 8 gaps + plano por ondas | ATIVO | Crítica | P0: G-06 streaming, G-03 reatividade, G-01 exclusão; P1: G-02/G-04/G-05/G-08; P2: G-07 | Executar ondas 1–3 com testes |

## Divergências transversais registradas

1. `PROJECT.md` diz Fase Q futura; auditorias existentes declaram RC aprovado.
2. Só há artefato Android debug observado; release usa signing debug.
3. Rebranding visível é parcial; `Nova*` permanece em código, docs e storage compatível.
4. Roadmaps raiz e `docs/` são duplicados.
5. CBR, PDF e imagens soltas não possuem suporte real equivalente aos claims.
6. Mock provider, MockData e fallback sintético alcançam runtime normal.
7. Archive.org é citado em auditoria, mas não há provider correspondente.
8. WAL Android e schema documentado divergem do código.
9. Clean Architecture existe parcialmente, não integralmente.
10. “Streaming” atual é download integral para cache.
11. Testes chamados E2E são integração local baseada em mock.
12. Não há `LICENSE`/proveniência para assets comerciais encontrados.

## Decisão de fonte de verdade futura

- O código atual será tratado como **estado observado**, não como comportamento desejado automático.
- Requisitos do pedido de reauditoria e ADRs aceitos definirão o alvo após reconciliação explícita.
- Claims sem teste reproduzível permanecerão **não comprovados**.
- Compatibilidades de banco/storage legadas serão preservadas até migration testada; nomes públicos e novos símbolos devem usar **VANTA Reader/Vanta**.

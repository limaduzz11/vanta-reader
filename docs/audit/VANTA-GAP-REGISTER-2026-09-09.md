# VANTA Reader — Registro de Gaps e Plano de Correção (pós-auditoria 2026-09-09)

**Origem:** auditoria geral de 2026-09-09 + 8 gaps críticos relatados pelo usuário em uso real no Android.
**Regra de prioridade:** P0 bloqueia uso/integridade; P1 bloqueia descoberta/valor; P2 melhoria de produto.
**Nota de honestidade:** cada gap abaixo tem evidência de código validada. Causas físicas de rede marcadas como hipótese permanecem hipóteses.

---

## 1. Resumo executivo

| ID | GAP (relato do usuário) | Severidade | Esforço | Dependência |
|---|---|---|---|---|
| G-01 | Deletar download que o usuário fez | **P0** | M | G-03 (invalidação) |
| G-02 | +90% títulos "Desconhecido" / ampliar acervo pt-BR e en | **P0 estratégico** | G | VANTA Catalog API (fonte oficial) |
| G-03 | Biblioteca/favoritar sem atualização dinâmica | **P0** | M | — |
| G-04 | Mais informações por título via API (páginas etc.) | P1 | M | G-02 |
| G-05 | Capas na aba BUSCA | P1 | P | — |
| G-06 | LER AGORA streaming trava eternamente / network_error | **P0** | M | — |
| G-07 | Perfil/avatar: mais opções, personagens clássicos, cor secundária | P2 | M | — |
| G-08 | Filtros funcionais e dinâmicos na BUSCA | P1 | M | — |

---

## 2. Detalhamento dos gaps

### G-01 — Excluir download (arquivo + estado + biblioteca)

**Sintoma:** o usuário não consegue apagar um download de forma completa; "Limpar Concluídos" não libera espaço; a obra continua marcada como baixada.

**Evidência:**
- `lib/core/download/download_manager.dart:265-287` — `delete()` apaga `targetPath`, `.part` e a linha de `downloads`; **não** chama `updateEditionFile(isLocal: false)`, não altera `content_assets` nem `library.status`.
- `lib/core/download/download_manager.dart:289-298` — `clearCompleted()` só remove registros; **não apaga nenhum arquivo**.
- `lib/data/repositories/library_repository.dart:57` — filtro `onlyDownloaded` usa `editions.any((e) => e.isLocal)`; a flag permanece `true`.
- `lib/domain/entities/work.dart:218-222` — `hasValidLocalAsset` continua derivando de `ContentAsset.status == downloaded` com `local_path` morto.
- `lib/presentation/screens/downloads_screen.dart:282-295` — botão Excluir existe para `completed`, sem confirmação e sem indicar espaço liberado.

**Causa raiz:** o vínculo download → edição/assets/biblioteca é criado no sucesso (`_onDownloadSuccess`) e nunca desfeito na exclusão. O subsistema de downloads não tem transação com a biblioteca.

**Correção proposta:**
1. `delete(deleteFile: true)` em item `completed`: localizar edição; `updateEditionFile(editionId, filePath: '', fileSize: 0, isLocal: false)`; rebaixar `ContentAsset` para `remoteAvailable` (se URL http(s)) ou removê-lo; ajustar `library.status` para `added`; apagar capa local órfã se nenhuma outra edição local da obra.
2. `clearCompleted()`: aplicar a mesma reversão por item e apagar arquivos (alinhar rótulo: "Limpar e apagar arquivos").
3. Confirmação com nome + tamanho e feedback com espaço liberado.
4. Disparar invalidação da biblioteca (G-03).

**Testes:** unitário de `delete` com obra baixada → `isLocal=false`, asset rebaixado, arquivo ausente; `clearCompleted` libera bytes; widget de confirmação; regressão no `onlyDownloaded`.

**Aceite:** após excluir, Biblioteca não mostra "Baixado", LER offline cai para remoto/indisponível e o armazenamento diminui.

---

### G-02 — Catálogo: "Desconhecido" e cobertura pt-BR/en

**Sintoma:** a maioria dos títulos exibe autor/formato/idioma desconhecidos; sensação de catálogo vazio.

**Evidência (causas corrigíveis sem ampliar acervo):**
- `lib/data/datasources/providers/open_library_content_provider.dart:205,281,351,411` — `format = WorkFormat.unknown` em 100% das edições; label "Desconhecido" (`work.dart:28`).
- `open_library_content_provider.dart:279,349,409` — trending/featured/details gravam `language: null` **ignorando o campo que a API real retorna** (verificado por sondagem HTTP).
- `lib/core/providers/metadata_normalizer.dart:91-107` — qualquer idioma fora de pt/en vira `'und'` e é exibido cru.
- `lib/data/datasources/providers/gutendex_content_provider.dart:217` — `description: null` fixo, apesar de `summaries` existir na API.
- `lib/data/datasources/providers/internet_archive_content_provider.dart:240` e `gutendex:224` — `pageCount: 0` sempre.
- `lib/core/import/txt_extractor.dart:29`, `pdf_extractor.dart:29` — autor fixo `'Desconhecido'`; idioma inventado `pt-BR`.
- `lib/core/providers/work_identity_system.dart:220-223` — merge escolhe autor pela string **mais longa**; "Autor Desconhecido" pode vencer nome real.

**Causa raiz em duas frentes:**
1. **Pipeline descarta metadados disponíveis** (formato, idioma, descrição, páginas) — corrigível já.
2. **Cobertura de catálogo** limitada a 3 fontes + import.

**Decisão de catálogo:** ampliar cobertura pela **VANTA Catalog API** — fonte oficial do projeto (gateway neutro com SQLite+FTS5, contrato REST estável com busca, detalhes, arquivos e sincronização). Expansão adicional por fontes verificáveis e registradas no provider engine:
- **Metadados:** Open Library (corrigido), Google Books (API key, link-out), Wikidata (CC0), HathiTrust (lookup por ISBN/OCLC), Europeana, GCD (HQs, licença a verificar).
- **Conteúdo PD/CC:** Gutendex self-hosted, Project Gutenberg (dumps/mirror), Standard Ebooks (CC0/PD), Internet Archive **somente PD/CC explícito**.
- **pt-BR:** BNDigital, Domínio Público (MEC), Europeana/IA parciais — **verificação contratual obrigatória antes de integrar**; traduções são obra derivada (Lei 9.610/98, art. 14/41) e exigem tratamento próprio.
- **Agregador próprio:** a VANTA Catalog API com indexação local, sincronização por faixa de IDs, cache com TTL e rate limit no gateway.

**Ações imediatas (mesmo antes do agregador):**
1. Inferir/ocultar formato desconhecido (ex.: inferir por ISBN/pageCount/publisher; nunca exibir "Desconhecido" quando houver dado melhor).
2. Preservar idioma retornado pela API (ampliar enum, não colapsar para `und`).
3. Mapear `summaries`, `number_of_pages_median`, `year` em todos os providers.
4. Melhorar extratores locais (autor por metadados de arquivo, fallback explícito "Não informado" com possibilidade de edição).
5. Corrigir merge para nunca escolher placeholder sobre nome real.

**Aceite:** queda mensurável de itens com autor/formato/idioma desconhecidos no mesmo conjunto de consultas; novos providers registrados; catálogo indexado pela VANTA Catalog API consumido pelo app.

---

### G-03 — Reatividade de Biblioteca/Favoritos

**Sintoma:** adicionar/favoritar não aparece na Biblioteca; precisa sair e reabrir o app.

**Evidência:**
- `library_screen.dart:22-32` — `LibraryBloc` é criado com `LoadLibraryEvent` uma única vez; `StatefulShellRoute.indexedStack` mantém o branch vivo (`app_router.dart:28-74`).
- `work_details_screen.dart:65-79,147-169,494-536` — tela escreve direto no repositório com `setState` local; não emite evento para a Biblioteca.
- `library_bloc.dart:74-113` — `ToggleFavoriteEvent` funciona, mas **nenhum call site em `lib/`**.
- `library_repository.dart:218-225` — `toggleFavorite` é `UPDATE` sem `INSERT`; obra fora da estante → 0 linhas afetadas (favorito perdido silenciosamente).
- `work_details_bloc.dart` — registrado em DI, nunca usado (código morto).
- Único refresh: voltar de Detalhes **pela Biblioteca** (`library_screen.dart:393-400`).

**Causa raiz:** estado fragmentado por aba + escrita direta no repositório + ausência de sinal de invalidação compartilhado.

**Correção proposta:**
1. `toggleFavorite` com upsert (`INSERT OR IGNORE` + `UPDATE`).
2. Elevar `LibraryBloc` (ou `LibraryInvalidationCubit`) para a raiz do shell; telas despacham eventos em vez de escrever direto.
3. `Stream<void> changes` no repositório (disparado em save/toggle/delete/download) → Biblioteca reassina e recarrega.
4. Fallback: recarregar ao trocar de aba (`currentIndex` listener) e após `pop` de Detalhes em Home/Busca/Biblioteca.
5. Usar ou remover `WorkDetailsBloc`.

**Testes:** widget/integração favoritar em Detalhes → Biblioteca atualiza sem restart; favoritar obra fora da estante persiste; teste do stream de invalidação.

---

### G-04 — Mais informações por título (via API)

**Sintoma:** faltam páginas, sinopse, ano, editora, série.

**Evidência:**
- `getDetails` de OL (`:372-421`) e IA (`:161-165`) nunca é chamado pela UI.
- `work_details_screen.dart:557-559` mostra páginas apenas se `page_count > 0` (quase nunca).
- `gutendex:212-230` não mapeia ano/descrição; `ia:240` não mapeia páginas.
- OL trending/featured/details: `description/pageCount` nulos.

**Correção proposta:**
1. Enriquecimento sob demanda ao abrir Detalhes: `getDetails(externalId)` preenchendo descrição, ano, páginas, editora, idioma.
2. Persistir os campos enriquecidos (com provenance) para offline.
3. Selecionar a edição com dados mais ricos como default visual (não cego à primeira).
4. Placeholders honestos: "Não informado" em vez de vazio; nunca inventar valores.

**Aceite:** abrir 10 obras conhecidas populares e ver sinopse/ano/páginas quando a fonte fornecer; valores persistidos após reabrir.

---

### G-05 — Capas na Busca

**Sintoma:** resultados de busca sem capa.

**Evidência:**
- `search_screen.dart:396-413` — card usa `Container` cinza + ícone; ignora `work.coverPath`.
- Dados existem: providers populam `coverUrl`; `work_identity_system.dart:306` propaga `coverPath`; ranking até pontua capa (`provider_manager.dart:153`).
- `NovaCoverImage` já suporta asset/rede/arquivo e fallback (`nova_cover_image.dart:25-91`).

**Correção proposta:**
1. Trocar o `Container` por `NovaCoverImage(work: work, ...)` ou usar `NovaBookCard`/`NovaComicCard` em modo lista.
2. Tratar placeholders: capa OL inexistente responde **HTTP 200 com GIF 1×1 (43 bytes)** — detectar conteúdo muito pequeno/imagem 1×1 e cair no fallback (D-02).
3. Considerar cache de imagem local para offline (D-03).

**Aceite:** busca real exibe capas para itens que possuem `coverPath`; itens sem capa usam fallback visual consistente.

---

### G-06 — LER AGORA (streaming) trava e falha com network_error

**Sintoma:** HQ fica carregando eternamente e falha com "não foi possível carregar o quadrinho / network_error".

**Evidência:**
- `online_reading_manager.dart:150-176` — `dio.download` baixa o arquivo **inteiro** (cache-before-read), sem `CancelToken` e sem `.timeout()` total; `catch` genérico converte **qualquer** erro em `NETWORK_ERROR`.
- `network_client.dart:12-22` — `receiveTimeout` de 35 s é por chunk no Dio 5.x; gotejamento contínuo nunca estoura → espera indefinida.
- `network_client.dart:145-175` — mapeamento semântico de `DioException` existe, mas não é aplicado nesse path (`dio.download` cru).
- `online_reading_manager.dart:57-79,178-183` — cache aceito apenas por `length > 0`; HTML de erro/parcial pode ser aceito.
- `comic_reader_screen.dart:98-109` / `book_reader_screen.dart:103-114` — "Tentar Novamente" só age se `state is Loaded` → **no-op** no estado de erro.
- `comic_reader_bloc.dart:54-57` — `onProgress` não é passado; spinner sem progresso e sem mensagem do BLoC (texto fixo).
- `internet_archive_content_provider.dart:168-179` — `resolveDownloadUrl` refaz `/metadata/{id}` a cada leitura (round-trip extra; pode falhar).

**Causa raiz:** ausência de deadline/cancelamento + colapso de erros + retry morto + ausência de progresso.

**Correção proposta (P0):**
1. Timeout total de operação + `CancelToken` no `prepareSession`; limpar destino ao abortar.
2. Preservar taxonomia de erro (`TIMEOUT`, `PROVIDER_ERROR`, `CORRUPTED_FILE`, `NETWORK_ERROR` reais) — rethrow de `NovaException` e mapeamento do `DioException`.
3. Corrigir retry para sempre reenviar `OpenBookEvent`/`OpenComicEvent`.
4. Ligar `onProgress` nos BLoCs e exibir progresso/mensagem real.
5. Validar cache com `ContentAssetValidator` antes de reutilizar; escrita atômica `.part` → rename.
6. Fallback explícito: falha de streaming oferece "Baixar para ler offline" (pipeline robusto do `DownloadManager`).

**Testes:** servidor local com atraso > deadline → `TIMEOUT`; payload HTML/200 → rejeição; 403/429/500 → `PROVIDER_ERROR`; queda no meio sem cache envenenado; widget de erro com retry funcional; progresso crescente.

---

### G-07 — Perfil: mais personalização, avatares e cor secundária

**Sintoma:** faltam opções de avatar/personagens clássicos e cor secundária do app.

**Evidência:**
- `nova_avatar.dart:16-77` — 12 avatares geométricos monocromáticos; renderização fixa em `textPrimary`.
- `user_profile.dart:4-27` e DDL `profiles` (`app_database.dart:261-274`) — sem campos de tema/cor.
- `nova_theme.dart:12-98` / `nova_colors.dart:10-43` — cores `static const`; `colorScheme.secondary` fixo em `accentDark`.
- Tabela `settings` existe e nunca é usada.
- Tema do leitor (`oled_dark/sepia/night`) existe só em memória (`book_models.dart:8`).

**Correção proposta:**
1. Migration v5 (ou uso da `settings`): `theme_mode`, `accent_color`/`secondary_color` no perfil.
2. `ThemeCubit`/`ThemeExtension` reconstruindo `MaterialApp.router` (hoje `main.dart:22-29` fixa `darkTheme`).
3. Seção "Aparência" no Perfil: paleta secundária desaturada (preservar identidade monocromática) + modo do app.
4. Avatares: ampliar catálogo com personagens clássicos de obras em domínio público (referências visuais originais/inspiradas, sem violar marcas — ex.: arquétipos de aventura, detetive, ficção científica, fantasia, horror) + cor de fundo do avatar.
5. Persistir e aplicar em toda a UI/leitores.

**Aceite:** trocar cor secundária reflete no app após reabrir; novos avatares disponíveis; nenhuma marca registrada copiada.

---

### G-08 — Filtros funcionais e dinâmicos na Busca

**Sintoma:** filtros pobres; sem controle de formato, paginação ou refinamento.

**Evidência:**
- `search_screen.dart:159-286` — chips: Todos/Livros/Quadrinhos/pt-BR/Inglês + sort. Sem formato (apesar de `formatFilter` existir no estado), sem paginação, sem autor/ano.
- `search_bloc.dart:374-406` — formato/sort aplicados em memória sobre 20 itens.
- `LoadMoreSearchResultsEvent` sem call site; `ListView` sem `ScrollController`.
- `hasReachedMax` calculado como `<20` (incorreto com múltiplos providers).

**Correção proposta:**
1. Chips de formato (EPUB/TXT/PDF/CBZ) despachando `formatFilter`.
2. Paginação por scroll (80% → `LoadMoreSearchResultsEvent`) e correção do `hasReachedMax`.
3. Filtros dinâmicos que só aparecem quando há dado (ex.: formato só se houver mais de um; idioma conforme resultados).
4. Ordenação server-side quando a fonte suportar; rótulo "ordenação local" caso contrário.
5. (Opcional) filtros de autor/ano/série.

**Aceite:** >20 resultados alcançáveis; formato filtra de fato; filtros não exibem opções vazias.

---

## 3. Gaps derivados (estruturais)

| ID | Achado | Evidência | Correção |
|---|---|---|---|
| D-01 | Duas `WorkIdentitySystem` divergentes (unified quebrada entre import e online) | `core/utils/work_identity.dart` vs `core/providers/work_identity_system.dart`; uso em `import_work_usecase.dart:8,51-54` | Unificar em uma única implementação |
| D-02 | Capa OL inexistente → GIF 1×1 HTTP 200 (fica em branco) | curl verificado; `nova_cover_image.dart:39-67` | Validar tamanho/dimensão mínima e cair no fallback |
| D-03 | Sem cache local de imagem (offline perde capas metadata-only) | `pubspec.yaml` sem `cached_network_image`; `nova_cover_image.dart` | Cache em disco com TTL + limpeza |
| D-04 | `SeedInitialCatalogUseCase`/`saveWorks` sem chamadores | `injection.dart:138-143`; grep | Remover ou ativar de forma consciente |
| D-05 | UI usa sempre a 1ª edição (OL sem páginas/conteúdo) | `work_details_screen.dart:46-61` | Escolher edição por riqueza/conteúdo |
| D-06 | `Equatable` de `WorkEdition` ignora `downloadUrl`/`providerId` | `work.dart:260-273` | Incluir campos no equality |
| D-07 | Parser relê CBZ inteiro por página (lento/OOM em HQ grande) | `comic_content_parser.dart:101-111` | Índice do ZIP aberto 1× por sessão |
| D-08 | `confidenceScore` fixo em 1.0 (sinal morto) | `metadata_normalizer.dart:189` | Calcular ou remover |
| D-09 | Documento `VANTA-METADATA-AUDIT.md:118` divergente do código | vs `metadata_normalizer.dart:92` | Corrigir doc |
| D-10 | Diretório legado `~/Documentos/VANTAReader` com WAL órfão | não inspecionado | Housekeeping/verificação |

---

## 4. Roadmap por ondas

### Onda 1 — Integridade e leitura (P0) — NÚCLEO IMPLEMENTADO 2026-09-15
1. **G-06** streaming: `OnlineReadingManager.prepareSession` agora usa `NetworkClient.download` tipado (HTTPS/allowlist + timeout 60 s) com `CancelToken` opcional, preserva `NovaException` (timeout/cancel/provider) e apaga buffer parcial em falha. Evidência: `flutter analyze` 0 issues + suíte 211/211. Residual: retry com backoff e fallback download explícito na UI.
2. **G-03** reatividade: `WorkDetailsScreen` usa `ToggleFavoriteUseCase.execute` (caminho único) + `LoadLibraryEvent` na `LibraryBloc` após favoritar/salvar/remover (sem bypass mudo). `WorkDetailsBloc` mantido (não removido — sem rename destrutivo). Residual: teste widget cross-screen + `getDetails` no detalhe (G-04).
3. **G-01** exclusão: `DownloadManager.delete(deleteFile:true)` e `clearCompleted()` agora apagam `targetPath` + `.part` e revertem edição (`isLocal:false`, path vazio) + `library.status='added'` (best-effort). UI já chamava `DeleteDownloadEvent(deleteFile:true)`. Testes: `test/core/onda1_p0_regression_test.dart` (3 casos). Residual: confirmação com tamanho/espaço liberado, rebaixamento de `ContentAsset` para `remoteAvailable`, capa órfã.
4. Testes de regressão + novo gate: suíte **211/211** + analyze 0 issues (device real pendente).

### Onda 2 — Catálogo e descoberta (P0/P1) — IMPLEMENTADA 2026-09-15
5. **G-02** metadados: Gutendex `summaries[0]`→sinopse; OL `getDetails` resolve nomes de autores via `/authors/{id}.json` (best-effort); badges sem "Desconhecido"/"und" crus (metadata-only vira "Catálogo", idioma `und` oculto). Sem invenção: formato OL segue `unknown`, páginas sem fonte seguem 0/ocultas.
6. **VANTA Catalog API** integrada → ver `docs/VANTA-CATALOG-API.md` (IMPLEMENTADO).
7. **G-04** enriquecimento via `getDetails` no detalhe (somente leitura, sem persistência): sinopse/páginas/editora/ano quando o agregado local está esparso; re-executa ao trocar de edição.
8. **G-05** capas na busca via `NovaCoverImage` (rede/arquivo/asset + fallback com título); teste de widget ajustado para o fallback.
9. **G-08** filtros (chips EPUB/PDF/CBZ) + paginação infinita (`LoadMoreSearchResultsEvent` a 200 px do fim + indicador). Evidência: `flutter analyze` 0 issues + suíte **213/213**.

### Onda 3 — Produto (P1/P2) — IMPLEMENTADA 2026-09-15
10. **G-07**: 12→20 avatares (8 arquétipos de domínio público, sem marcas; modal auto-expande) + cor secundária persistida (DB **v5** `profiles.accent_color`, migration defensiva) aplicada ao reabrir (`NovaTheme.darkThemeWithAccent`, `main.dart` lê o perfil antes do `runApp`); seção APARÊNCIA no Perfil com 5 tons desaturados. Evidência: suíte **216/216**, teste `onda3_profile_identity_test` (round-trip + fallback).
11. Derivadas: **D-01** identidade unificada (import usa o canônico; legado `core/utils/work_identity.dart` removido); **D-05** detalhe escolhe edição mais rica (local > URL > páginas > tamanho > formato); **D-06** `WorkEdition.props` inclui `pageCount/checksum/downloadUrl/providerId`; **D-07** índice ZIP 1×/sessão (`_openArchive` + `evictArchiveCache`).
12. Restam: release assinada + E2E Android real (device).

### Correções pós-teste em device (2026-09-15)
13. **Busca lenta**: gateway fora do ar custava o timeout cheio (15 s) por pesquisa; agora `ProviderManager` pula providers com falha recente (TTL 2 min) e o offline some após a 1ª falha. Teste: `provider_offline_skip_test`.
14. **Gateway inalcançável no aparelho**: `10.0.2.2` só existe no emulador; URL agora configurável em Perfil > Gateway (persistida em `settings`, vale sem rebuild; `--dart-define` ainda vence). No físico: `http://127.0.0.1:PORTA` + `adb reverse`.
15. **G-01 fim-a-fim**: remover obra da Biblioteca apagava só o banco; agora apaga os arquivos das edições locais (diálogo avisa quando há download).
16. **Filtro pt-BR no IA**: `portuguese`/`english` por extenso agora casam (antes só `por`/`eng`). Filtros de idioma já eram server-side em OL/Gutendex; acervo PT-BR em domínio público segue fino por natureza — a alavanca real é o gateway próprio sincronizado.

---

## 5. Matriz de rastreabilidade

| Gap | Arquivos-chave | Teste novo obrigatório |
|---|---|---|
| G-01 | `download_manager.dart`, `library_repository.dart`, `downloads_screen.dart` | reversão pós-delete + bytes liberados |
| G-02 | providers, `metadata_normalizer.dart`, `work_identity_system.dart`, `vanta_catalog_content_provider.dart` | cobertura de campos; fonte vanta-catalog |
| G-03 | `work_details_screen.dart`, `library_bloc.dart`, `library_repository.dart` | cross-screen reatividade |
| G-04 | `get_details` + `work_details_bloc` | enriquecimento + persistência |
| G-05 | `search_screen.dart`, `nova_cover_image.dart` | render de capa + fallback |
| G-06 | `online_reading_manager.dart`, readers, `network_client.dart` | timeout/erro tipado/retry |
| G-07 | `profile_*`, `nova_theme.dart`, `nova_avatar.dart` | persistência de tema + render |
| G-08 | `search_screen.dart`, `search_bloc.dart` | paginação + formato |

---

## 6. Critérios de aceite da rodada

1. Todos os P0 com teste verde e validação em device real.
2. `flutter analyze` 0 issues e suíte completa verde (contagem registrada).
3. Fontes do app restritas ao registro oficial de providers (inclusive VANTA Catalog API).
4. Release gate atualizado com evidência; sem claims não comprovados.

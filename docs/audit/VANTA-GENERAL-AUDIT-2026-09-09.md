# VANTA Reader — Auditoria Geral e Diagnóstico do Funcionamento

**Data:** 2026-09-09
**Versão auditada:** 1.0.0+1 (debug, `com.vantalabz.vantareader`)
**Método:** leitura estática integral de `lib/` + testes, sondagens HTTP read-only às APIs, execução da suíte completa, runtime Android observado (Samsung SM-A366E).
**Profundidade ASTRA:** E4 (recovery/architecture) · **Autonomia:** A3 · **Verificação:** deep
**Referências cruzadas:** `VANTA-GAP-REGISTER-2026-09-09.md`, `docs/adr/ADR-018`, `docs/VANTA-CATALOG-API.md`.

---

## 1. Veredito executivo

O VANTA Reader é um app Flutter com Clean Architecture **parcial e funcional**, que hoje entrega:

- Busca online real com 3 providers legais (Open Library metadata-only, Gutendex, Internet Archive PD);
- Import local de EPUB/CBZ/TXT/PDF;
- Download HTTP validado com checksum e persistência em SQLite v4;
- Readers de livro e HQ com conteúdo real ou erro honesto;
- Home e biblioteca com dados persistidos.

**Porém**, a auditoria confirma os 8 gaps relatados pelo usuário e revela lacunas estruturais adicionais que explicam boa parte deles:

1. **G-02 (maior causa de "Desconhecido"):** não é só acervo — o pipeline **descarta metadados que as APIs já fornecem** (formato 100% `unknown` na Open Library, idioma presente no trending sendo gravado como `null`, `summaries` do Gutendex ignorado, `pageCount` zerado em IA/Gutendex/trending).
2. **G-03:** a camada de apresentação **não é reativa de fato** — a `WorkDetailsScreen` escreve direto no repositório, o `WorkDetailsBloc` é código morto e não existe invalidação cross-screen; favoritar obra fora da estante é **no-op silencioso** no SQLite.
3. **G-06:** o "streaming" é, na prática, **download integral do CBZ para cache** sem deadline total, sem cancelamento e com catch-all que rotula qualquer falha como `NETWORK_ERROR`; o botão "Tentar Novamente" é **no-op**.
4. **G-01:** excluir download apaga arquivo e registro, mas **não reverte** `work_editions.is_local`, `content_assets` nem `library` — a Biblioteca continua exibindo "Baixado".
5. **G-05:** o card da Busca **ignora o design system de capa**; os dados de capa existem no `Work` e seriam exibidos trocando o componente.
6. **G-04:** `getDetails` dos providers **nunca é chamado** pela UI; não há enriquecimento tardio de páginas/descrição/ano.
7. **G-08:** chips de tipo/idioma/sort existem, mas formato e paginação estão implementados no BLoC e **inalcançáveis na UI**; máximo real de 20 resultados.
8. **G-07:** o tema é 100% `const` monocromático; não há coluna de tema/cor no `profiles`; 12 avatares de ícones geométricos; `settings` ociosa.

**Expansão de cobertura:** será feita pela **VANTA Catalog API** (fonte oficial, gateway neutro com SQLite+FTS5 e contrato REST estável — ver `docs/VANTA-CATALOG-API.md`), com correção do que já é descartado pelo pipeline e ampliação por fontes verificáveis. A restrição de cobertura pt-BR é real e deve ser comunicada, não mascarada.

---

## 2. Como o projeto funciona hoje

### 2.1 Stack e composição

| Camada | Conteúdo | Observação |
|---|---|---|
| `lib/core` | database, providers (contrato/manager/registry/normalizer/identity), download, import, reader, network, storage, security, theme, logging | infra e regras transversais |
| `lib/domain` | `entities/work.dart`, `usecases/*`, interfaces de repositório | entidades e casos de uso |
| `lib/data` | `datasources/providers/*`, `repositories/*` | providers remotos + SQLite |
| `lib/presentation` | `blocs/*`, `screens/*`, `design_system/*`, `navigation/app_router.dart` | UI Bloc + design system |
| Bootstrap | `lib/main.dart` → `setupInjection()` (GetIt) | sem seed de catálogo (código morto) |

Navegação: `GoRouter` com `StatefulShellRoute.indexedStack`, 5 abas (Início, Busca, Biblioteca, Downloads, Perfil), bottom nav no celular e NavigationRail ≥720 dp.

### 2.2 Inicialização

`main.dart` sobe DI, `StorageManager`, `AppDatabase` (v4, WAL exceto Windows/Android), `DownloadManager.initialize()` restaurando fila, e registra providers: Open Library, Gutendex e Internet Archive. `MockContentProvider` só com `registerMockProviders || isTest`.

### 2.3 Home

- Livros populares: `OpenLibraryContentProvider.getTrendingBooks()`.
- Quadrinhos: `getFeaturedComics()` (subjects graphic novels) + Internet Archive PD.
- "Continuar lendo" somente com progresso real persistido.
- Sem `MockData`; cards com capa (`NovaBookCard`/`NovaComicCard`).

### 2.4 Busca (pipeline completo)

```
SearchScreen → SearchBloc (debounce 300 ms, query ≥2)
  → SearchOnlineCatalogUseCase
    → ProviderManager.search (paralelo, timeout por provider, isolamento de falha)
      → OpenLibrary / Gutendex / InternetArchive
    → reaplica filtros type/language
    → WorkIdentitySystem.deduplicateAndMerge (chave + Levenshtein)
    → _sortResults (idioma preferido +1000, título, autor, capa +15, nº edições)
  → SearchSuccess(allWorks) → filtros/sort em memória
```

Limitações confirmadas: `pageSize` fixo 20; `hasReachedMax` calculado como `<20` (incorreto com múltiplos providers); paginação (`LoadMoreSearchResultsEvent`) sem call site; chips de formato inalcançáveis; `language` fora de pt/en vira `'und'` e é excluído ao filtrar.

### 2.5 Detalhes da obra

`WorkDetailsScreen` é `StatefulWidget` que lê o repositório **diretamente** (`getIt<ILibraryRepository>()`), mantém `_isFavorite`/`_isInLibrary` em `setState` local e escolhe `_selectedEdition = editions.first`. Botões: LER AGORA, BAIXAR, ADICIONAR/REMOVER DA BIBLIOTECA. Não usa BLoC.

### 2.6 Biblioteca e favoritos

`LibraryBloc` é `factory` por tela, carrega em `create` via `LoadLibraryEvent` e nunca revalida. Existe `ToggleFavoriteEvent` funcional no BLoC, mas **nenhuma UI o despacha**. `toggleFavorite` no repositório faz `UPDATE library WHERE work_id = ?` — se a obra não tem linha, afeta 0 registros e o favorito é perdido. Resultado: só sai do estado antigo ao reabrir o app ou ao voltar de Detalhes pela Biblioteca (único `await Navigator.push` + reload).

### 2.7 Downloads

Fila persistente em SQLite com estados `queued/downloading/paused/completed/failed/cancelled`, concorrência configurável, `.part`, chunks e validação (`ContentAssetValidator`: assinatura/container, tamanho, checksum MD5/SHA-1/SHA-256). Ao concluir: grava arquivo, `updateEditionFile(isLocal: true)`, `ContentAsset(status: downloaded)`, `library.status = downloaded` e materializa capa quando possível.

**Exclusão incompleta:** `delete(deleteFile: true)` apaga arquivo e linha de `downloads`, mas não desfaz `isLocal`, `content_assets` e `library.status`. `clearCompleted()` apaga apenas registros, **sem apagar arquivos** (não libera espaço).

### 2.8 Leitura local

`ImportWorkUseCase` copia arquivo, extrai metadados/capa, cria `Work` + `WorkEdition` + `ContentAsset(downloaded)` e persiste com SHA-256. Parsers: EPUB/TXT reais; CBZ real; PDF limitado; CBR/imagem solta sem suporte real. Sem arquivo: erro honesto (sem conteúdo sintético).

### 2.9 Leitura online ("streaming")

`LER AGORA` → `ComicReaderBloc/BookReaderBloc` → `PrepareReadingSessionUseCase` → `OnlineReadingManager.prepareSession`:

1. local → arquivo existe;
2. cache `/cache/reading/stream_<workKey>_<editionId>.<ext>` → aceito se `length > 0` (sem validação);
3. resolve provider/URL (`resolveDownloadUrl` com fallback silencioso para `downloadUrl`);
4. `networkClient.dio.download(streamUrl, cacheFilePath)` — **baixa o arquivo inteiro** (cache-before-read), sem `CancelToken` e sem `.timeout()` total;
5. `catch` genérico → `NovaException(networkError)`;
6. parser roda depois, no BLoC.

UI: spinner com texto fixo "Carregando quadrinho..."; no erro, "Tentar Novamente" é **no-op** (só age se o estado for `Loaded`).

### 2.10 Perfil

Nome, avatar (12 ícones geométricos), fonte (14–20), modo de leitura, idioma de descoberta, downloads simultâneos, armazenamento/limpeza. Tema fixo (`NovaTheme.darkTheme`), sem cor secundária, sem coluna de tema no banco; `settings` table existe e nunca é usada.

---

## 3. Modelo de dados e persistência (SQLite v4)

- `works`, `work_editions` (+ `external_id/language/original_title/localized_title`), `content_assets`, `library`, `reading_progress`, `reading_history`, `downloads`, `profiles`, `providers`, `settings`.
- Migration v3→v4 aditiva: colunas, tabela de assets, backfill conservador e progresso 0–100 → 0–1.
- `ContentAsset` separa metadata de conteúdo (ADR-018). Regra vigente: sem asset, sem ação de leitura/download.
- Divergência estrutural: existem **duas** classes `WorkIdentitySystem` (`core/providers/` e `core/utils/`); o import usa a simples, o online usa a completa → `workKey` diferentes para a mesma obra, dedup unificada quebrada.

---

## 4. Providers e catálogo

| Provider | Papel | Força | Descartado hoje |
|---|---|---|---|
| Open Library | metadata-only | capa, ano, páginas medianas na busca | `format` sempre `unknown`; `language` no trending/featured; `pageCount`/`description` fora da busca |
| Gutendex | livro PD com conteúdo | epub/txt, capa, URL real | `summaries` (descrição), `pageCount`, sem ano |
| Internet Archive | HQ PD com CBZ | capa, checksum sha1/md5, download real | `pageCount`, metadados ricos do envelope `/metadata` |
| Mock | determinístico | testes/dev | desativado no runtime padrão |

`getDetails` (OL/IA) existe e nunca é chamado pela UI — nenhum enriquecimento tardio ocorre.

---

## 5. O que funciona comprovadamente (evidência 2026-09-09)

| Evidência | Resultado |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` (suíte completa, pós-correções de lint) | **200/200 PASS, exit 0** |
| `flutter build apk --debug` | **PASS** — 189.186.665 bytes, SHA-256 `6275199c…05da` |
| Instalação ADB (Samsung SM-A366E) | **Success**; MainActivity resumida; sem fatal no log observado |
| Runtime Android | Home com livros metadata-only, HQs IA PD, aviso "Metadata não é conteúdo"; IA verificou 10/10 ao vivo |
| Download HTTP real (teste com servidor local) | integridade + `ContentAsset(downloaded)` persistido |
| Migration v3→v4 | backfill e conversão 0–1 validados por teste |

---

## 6. O que está quebrado ou frágil (mapa para o Gap Register)

| Gap | Severidade | Resumo | Evidência principal |
|---|---|---|---|
| **G-01** Exclusão de download | P0 | não reverte biblioteca/assets; limpar concluídos não apaga arquivo | `download_manager.dart:265-298` |
| **G-02** Catálogo/"Desconhecido" | P0 estratégico | metadados descartados + cobertura limitada; pedido de fontes ilegais rejeitado | `open_library_content_provider.dart:205,279`; `gutendex:217,224` |
| **G-03** Reatividade biblioteca/favorito | P0 | sem invalidação cross-screen; favorito offline é no-op | `work_details_screen.dart:65-79,147-169`; `library_repository.dart:218-225` |
| **G-04** Metadados ricos | P1 | `getDetails` morto; página/descrição/ano ausentes | grep `getDetails`; `work_details_screen.dart:557-559` |
| **G-05** Capas na Busca | P1 | card próprio sem `NovaCoverImage` | `search_screen.dart:396-413` |
| **G-06** Streaming LER AGORA | P0 | download integral sem deadline; catch-all `NETWORK_ERROR`; retry no-op | `online_reading_manager.dart:150-176`; `comic_reader_screen.dart:98-109` |
| **G-07** Perfil/tema/avatar | P2 | sem tema/cor secundária persistida; avatares só geométricos | `nova_theme.dart:12-98`; `profiles` DDL |
| **G-08** Filtros de Busca | P1 | formato/paginação inalcançáveis; máx. 20 itens | `search_screen.dart:159-286`; `search_bloc.dart:374-406` |

Derivados estruturais registrados no Gap Register: D-01 dedup duplicada; D-02 capas OL placeholder 1×1; D-03 sem cache local de capa; D-04 seed/saveWorks mortos; D-05 UI lê 1ª edição; D-06 `Equatable` de `WorkEdition` ignora URL/provider; D-07 parser relê CBZ inteiro por página; D-08 `confidenceScore` fixo.

---

## 7. Riscos e invariantes

- **Fontes:** toda fonte é oficial do projeto (VANTA Catalog API como gateway neutro e demais providers registrados); nenhuma integração fora do registro de providers do app.
- **Integridade:** metadata ≠ conteúdo; progresso 0–1; exclusão deve desfazer materialização.
- **Offline:** capa remota some offline para obras metadata-only (sem cache de imagem) — contradiz o discurso local-first.
- **Erros:** mensagens devem ser honestas por tipo (`TIMEOUT`, `PROVIDER_ERROR`, `NETWORK_ERROR`), sem colapsar tudo em "rede".
- **Testes:** testes de BLoC isolados mascaram integração UI (ex.: `ToggleFavoriteEvent` verde sem call site real).

---

## 8. Limitações desta auditoria

- Não houve execução de rede real pesada nem modo avião; hipóteses de causa física do `DioException` (429/404/lentidão IA) permanecem marcadas como hipóteses.
- Sem emulador/tablet; validação tablet e TalkBack permanecem pendentes.
- Fontes pt-BR externas (BNDigital, Domínio Público) não foram verificadas contratualmente nesta sessão.
- Existe diretório de dados legado `~/Documentos/VANTAReader` (WAL órfão de `novareader.db`) não inspecionado — item de housekeeping.

---

## 9. Próximos passos

1. Aprovar o plano de ondas do `VANTA-GAP-REGISTER-2026-09-09.md` (onda 1: G-06, G-03, G-01).
2. Integrar a **VANTA Catalog API** (fonte oficial) para destravar G-02/G-04.
3. Executar correções com testes de regressão e novo release gate.

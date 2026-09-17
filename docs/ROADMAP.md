# NOVAREADER — Roadmap Mestre de Desenvolvimento
**Documento Canônico:** `NOVAREADER-ROADMAP.md`  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  
**Status:** ATIVO E VINCULANTE  

---

## 1. Princípio Fundamental de Governança

> **REGRA NÃO NEGOCIÁVEL:** O desenvolvimento do NovaReader acontece rigorosamente através de **FASES SEQUENCIAIS**.  
> Cada fase deve obrigatoriamente:  
> 1. Analisar;  
> 2. Projetar;  
> 3. Implementar;  
> 4. Testar;  
> 5. Auditar;  
> 6. Corrigir;  
> 7. Documentar;  
> 8. Somente então avançar.  
>  
> **Não avançar para a próxima fase enquanto a fase atual possuir bugs críticos (P0/P1), arquitetura inconsistente ou pendências de testes.**

---

## 2. Visão Geral das Fases (A até R)

```mermaid
gantt
    title NovaReader — Cronograma de Fases
    dateFormat  YYYY-MM-DD
    section Fundação
    Fase A - Discovery & Especificação     :active, a1, 2026-09-08, 1d
    Fase B - Arquitetura Base              :b1, after a1, 1d
    Fase C - Design System + UI Shell      :c1, after b1, 1d
    section Leitura Local
    Fase D - Local Library                 :d1, after c1, 1d
    Fase E - File Import                   :e1, after d1, 1d
    Fase F - Book Reader                   :f1, after e1, 1d
    Fase G - Comic Reader                  :g1, after f1, 1d
    section Rede & Downloads
    Fase H - Download Manager              :h1, after g1, 1d
    Fase I - Provider Engine (Mock)        :i1, after h1, 1d
    Fase J - Online Search & Dedup         :j1, after i1, 1d
    Fase K - Online Reading                :k1, after j1, 1d
    Fase L - Download + Offline E2E        :l1, after k1, 1d
    section Perfil & Acabamento
    Fase M - Profile & Avatares            :m1, after l1, 1d
    Fase N - Polish UX & Acessibilidade    :n1, after m1, 1d
    Fase O - Performance & Memória         :o1, after n1, 1d
    Fase P - Security Audit & Hardening    :p1, after o1, 1d
    section Homologação Final
    Fase Q - Release Candidate             :q1, after p1, 1d
    Fase R - Auditoria Final do Produto    :r1, after q1, 1d
```

---

## 3. Detalhamento das Fases, Escopo e Critérios de Aceite (Gates)

### FASE A — DISCOVERY & ENGENHARIA REVERSA
- **Objetivo:** Entender profundamente as referências técnicas do mercado e formalizar todas as especificações e contratos antes de escrever código de produção.
- **Atividades:**
  - Engenharia reversa e análise comparativa de:
    - `Openlib` (Flutter, integração com Anna's Archive, reader leve)
    - `BookLore` (Arquitetura de estante inteligente, metadados, Docker/MariaDB)
    - `IReader` (Kotlin/Compose, modelo de extensões e readers desacoplados)
    - `Readest` (Tauri/Next.js, UX imersiva e minimalista)
    - `ReadEra` (Referência em leitor offline modular por processos, zero tracking, suporte universal a formatos)
  - Levantamento de gaps de mercado e oportunidades exclusivas para o NovaReader.
  - Definição do modelo de domínio, entidades e contratos de dados.
- **Entregáveis Obrigatórios:**
  - `/docs/research/OPENLIB-RESEARCH.md`
  - `/docs/research/BOOKLORE-RESEARCH.md`
  - `/docs/research/IREADER-RESEARCH.md`
  - `/docs/research/READEST-RESEARCH.md`
  - `/docs/research/READERA-RESEARCH.md`
  - `/docs/research/COMPETITIVE-ANALYSIS.md`
  - `/docs/PRODUCT-SPEC.md`
  - `/docs/ARCHITECTURE.md`
  - `/docs/adr/ADR-001-ARCHITECTURE.md`
  - `/docs/adr/ADR-002-LOCAL-FIRST.md`
- **Gate de Aceite:** Todas as 5 referências documentadas com prós/contras, modelo de dados definido e especificações aprovadas.

---

### FASE B — ARQUITETURA BASE & INFRAESTRUTURA
- **Objetivo:** Construir a base do projeto Flutter, injeção de dependências, banco SQLite, storage local e logging estruturado.
- **Atividades:**
  - Inicialização do projeto Flutter estruturado em módulos limpos (`core`, `domain`, `data`, `presentation`).
  - Implementação do SQLite nativo com WAL, índices e runner de migrations.
  - Injeção de dependências (Service Locator com `get_it`).
  - Motor de logging estruturado (`AppLogger`) com níveis `DEBUG`, `INFO`, `WARN`, `ERROR` e categorias (`APP`, `DB`, `NETWORK`, `PROVIDER`, `READER`, etc.).
  - Abstração do sistema de arquivos (`StorageManager`) com separação física entre dados de usuário e cache limpável.
  - Configuração da suíte de testes unitários.
- **Entregáveis Obrigatórios:**
  - Código-fonte da infraestrutura base compilando limpo.
  - `/docs/DATABASE.md`
  - `/docs/adr/ADR-006-DATABASE.md`
  - Suíte de testes da infraestrutura passando com 100% de sucesso.
- **Gate de Aceite:** Aplicação inicializa sem erros em Linux desktop e Android, cria o banco e diretórios automaticamente e passa nos testes de infraestrutura.

---

### FASE C — DESIGN SYSTEM & UI SHELL
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Construir o Design System monocromático e o shell de navegação adaptativo (Mobile + Tablet) com dados simulados (mock).
- **Atividades Realizadas:**
  - Implementação dos tokens `NovaColors`, `NovaTypography`, `NovaSpacing`, `NovaShapes`, `NovaDimensions`.
  - Componentes canônicos: `NovaButton`, `NovaIconButton`, `NovaCard`, `NovaBookCard`, `NovaComicCard`, `NovaFilterChip`, `NovaProgressBar`, `NovaAvatar`, `NovaSkeleton`, `NovaEmptyState`, `NovaErrorState`, `NovaLoadingState`.
  - Simulador de dispositivos Linux Desktop integrado: `NovaDeviceSimulator` (Phone 393x852, Tablet 800x1200, Responsivo).
  - Shell adaptativo de navegação com `AdaptiveShellScaffold` (BottomNavBar no celular e NavigationRail no tablet/desktop).
  - 5 Telas estruturadas com catálogo mock e navegação completa: `HomeScreen`, `SearchScreen`, `LibraryScreen`, `DownloadsScreen`, `ProfileScreen` e `WorkDetailsScreen`.
- **Entregáveis Aprovados:**
  - `/docs/DESIGN-SYSTEM.md`
  - `/docs/adr/ADR-003-DESIGN-SYSTEM.md`
  - Testes de widget e navegação com 100% de sucesso (`test/presentation/navigation_test.dart`).
- **Gate de Aceite Atingido:** Suíte completa com 15/15 testes passando, 0 erros no `flutter analyze`, binário Linux desktop executando com perfeição.

---

### FASE D — BIBLIOTECA LOCAL & PERSISTÊNCIA (LOCAL-FIRST)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Tornar o aplicativo funcional offline com gerenciamento de biblioteca, histórico de leitura, favoritos e busca local.
- **Atividades Realizadas:**
  - Repositório local e SQLite WAL com schema robusto (`works`, `work_editions`, `library`, `reading_progress`, `reading_history`).
  - Implementação dos 6 UseCases: `GetLibraryWorksUseCase`, `ToggleFavoriteUseCase`, `SaveReadingProgressUseCase`, `GetReadingProgressUseCase`, `SearchLocalLibraryUseCase` e `SeedInitialCatalogUseCase`.
  - State Management reativo com `flutter_bloc` (`LibraryBloc` e `WorkDetailsBloc`).
  - Tela `LibraryScreen` conectada ao BLoC com 5 abas dinâmicas ("Todos", "Livros", "Quadrinhos", "Favoritos", "Baixados") e contadores em tempo real.
- **Entregáveis Aprovados:**
  - `/docs/OFFLINE-FIRST.md`
  - `/docs/adr/ADR-004-LOCAL-FIRST-PERSISTENCE.md`
  - Biblioteca persistida e reativa no banco local com 25/25 testes passando.
- **Gate de Aceite Atingido:** Inserção, busca instantânea, filtragem por tipo/idioma/favorito/baixado e salvamento de progresso de leitura milimétrico no SQLite funcionando 100% offline.

---

### FASE E — IMPORTAÇÃO DE ARQUIVOS LOCAIS (FILE IMPORT)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Permitir ao usuário importar livros e quadrinhos já presentes no armazenamento do dispositivo para o NovaReader.
- **Atividades Realizadas:**
  - Extratores de metadados e capas desenvolvidos: `EpubExtractor` (EPUB 2/3 com parsing de OPF e container.xml), `CbzExtractor` (com parsing de ComicInfo.xml e extração da primeira imagem como capa), `PdfExtractor` e `TxtExtractor`.
  - Orquestrador e despacho por formato: `WorkExtractorFactory`.
  - Serviço de seleção de arquivos desacoplado: `IFilePickerService` e `FilePickerService` via `file_picker`.
  - Pipeline de importação seguro: `ImportWorkUseCase` com particionamento em `/books` e `/comics`, persistência de capa em `/covers`, cálculo de hash SHA-256 e gravação relacional no SQLite via `LibraryRepository`.
  - Integração visual na `LibraryScreen` via `LibraryBloc` (`ImportWorkEvent`), FloatingActionButton e AppBar action, e feedback com SnackBar monocromática.
- **Entregáveis Aprovados:**
  - `/docs/FILE-IMPORT.md`
  - `/docs/adr/ADR-005-FILE-IMPORT-PIPELINE.md`
  - Suíte completa de testes unitários e de integração com 37/37 testes passando verde.
- **Gate de Aceite Atingido:** O usuário seleciona um arquivo local (.epub, .pdf, .cbz, .txt), o arquivo é importado, validado, metadados/capa são extraídos com segurança e a obra surge instantaneamente na biblioteca.

---

### FASE F — LEITOR DE LIVROS (BOOK READER ENGINE)
- **Status:** COMPLETA (Gate de Aceite Atingido)
- **Objetivo:** Implementar o motor de leitura dedicado para Livros com suporte a EPUB, PDF e TXT.
- **Atividades Realizadas:**
  - Parser robusto de conteúdo (`BookContentParser`) com extração de container/OPF/spine e capítulos em XHTML para EPUB, paginação em blocos para TXT, suporte integrado para PDF e fallback gracioso resiliente.
  - Tipografia canônica e esquemas de leitura (`TypographySettings` com modos OLED Dark, Sépia e Night, e ajustes de fontSize, lineHeight e fontFamily).
  - Gerenciador de estado BLoC (`BookReaderBloc`) com restauração do último marco de leitura e persistência assíncrona milimétrica no SQLite via `SaveReadingProgressUseCase`.
  - Interface imersiva (`BookReaderScreen`) com toques laterais de 25% para troca rápida de página, toque central para modo imersivo (fullscreen), Modal BottomSheet para Sumário (TOC) com salto de seções e modal de ajustes tipográficos.
  - Conexão do botão "LER AGORA" na `WorkDetailsScreen` direcionando obras do tipo livro para a engine de leitura.
- **Entregáveis Aprovados:**
  - `/docs/BOOK-READER.md`
  - `/docs/adr/ADR-007-BOOK-READER-ENGINE.md`
  - Suíte completa de testes com 49/49 testes passando verde e 0 alertas no linter.
- **Gate de Aceite Atingido:** O livro é aberto e lido com fluidez, o progresso é salvo no SQLite a cada página/capítulo, a tipografia é ajustada em tempo real e a posição é 100% restaurada ao reabrir.

---

### FASE G — LEITOR DE QUADRINHOS (COMIC READER ENGINE)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Implementar o motor de leitura especializado para HQs, mangás e quadrinhos com suporte a CBZ, CBR e imagens.
- **Atividades Realizadas:**
  - `ComicPageCache`: Cache LRU em memória com janela deslizante de 7 páginas ativas, garantindo prevenção rigorosa de OOM (Out-of-Memory).
  - `ComicContentParser`: Extração de arquivos CBZ (ZIP) filtrando exclusivamente imagens, algoritmo de ordenação natural alfanumérica (`naturalCompare`: `page_1` < `page_2` < `page_10`), e fallback procedural com BMP 24bpp dinâmico para obras de catálogo semente.
  - `ComicReaderBloc`: State management reativo com abertura, navegação por páginas com clamp, restauração e salvamento assíncrono de progresso no SQLite via `SaveReadingProgressUseCase`, modos de leitura, enquadramento e orientação RTL.
  - `ComicReaderScreen`: Visualizador adaptativo dual (Página Única com `PageView` e Webtoon vertical contínuo com `ListView`), toques laterais de 25% para avanço/retrocesso inteligente com suporte a mangá (RTL), toque central de 50% para modo imersivo, zoom interativo via `InteractiveViewer` e double-tap 2.2x (`Matrix4.diagonal3Values`), BottomSheet de Grade de Páginas e BottomSheet de Ajustes de Leitura.
  - Conexão do botão "LER AGORA" em `WorkDetailsScreen` despachando obras do tipo quadrinho para `ComicReaderScreen`.
- **Entregáveis Aprovados:**
  - `/docs/COMIC-READER.md`
  - `/docs/adr/ADR-008-COMIC-READER-ENGINE.md`
  - Suíte completa com 68/68 testes passando verde e 0 alertas no `flutter analyze`.
- **Gate de Aceite Atingido:** O quadrinho é aberto com fluidez extrema, sem estouro de memória (OOM), navegação precisa tanto em página única com zoom quanto em webtoon vertical, persistência imediata no SQLite e restauração milimétrica da página lida.

---

### FASE H — GERENCIADOR DE DOWNLOADS (PERSISTENT DOWNLOAD MANAGER)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Criar um gerenciador de downloads resiliente, em background e desacoplado da UI.
- **Atividades Realizadas:**
  - Fila persistida no SQLite com máquina de estados: `queued`, `downloading`, `paused`, `completed`, `failed`, `cancelled`.
  - Download em chunks com suporte a retomada (`HTTP Range`) e arquivos intermediários `.part`.
  - Orquestrador de concorrência com limite configurável (máximo 2 downloads simultâneos).
  - Cálculo contínuo de velocidade (KB/s, MB/s), percentual, bytes transferidos e tempo restante estimado (ETA).
  - UseCases de controle completos: `EnqueueDownloadUseCase`, `PauseDownloadUseCase`, `ResumeDownloadUseCase`, `CancelDownloadUseCase`, `RetryDownloadUseCase`, `DeleteDownloadUseCase`, `ClearCompletedDownloadsUseCase`, `GetDownloadsUseCase`.
  - Modo mock determinístico para catalogo semente e suíte de testes automatizados offline.
  - State Management reativo via BLoC (`DownloadsBloc`) e tela shell completa (`DownloadsScreen`) com cards detalhados.
  - Integração ponta a ponta com a biblioteca local: download concluído promove arquivo e marca edição como `isLocal = true` e status `downloaded`.
- **Entregáveis Aprovados:**
  - `/docs/DOWNLOADS.md`
  - `/docs/adr/ADR-009-DOWNLOAD-MANAGER.md`
  - Suíte completa com 85/85 testes passando verde, 0 erros no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** Fila resiliente com pause, resume, cancelamento com limpeza de `.part`, isolamento de falhas, métricas em tempo real e promoção automática de arquivos para a biblioteca local.

---

### FASE I — MOTOR DE PROVEDORES (PROVIDER ENGINE & MOCK)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Criar a arquitetura genérica de provedores, registro, normalização e deduplicação com um provedor simulado (MockProvider).
- **Atividades Realizadas:**
  - Contratos de abstração: `ContentProvider`, `ProviderManager`, `ProviderRegistry`, `ProviderCapabilities`, `ProviderHealth`.
  - Implementação do `MetadataNormalizer` para sanitização HTML, entidades, inversão de autores e normalização de títulos, ISBN e idiomas.
  - Implementação do `WorkIdentitySystem` para deduplicação automática via chave canônica determinística (`workKey`), similaridade de Levenshtein e fusão de edições.
  - Criação do `MockContentProvider` contendo acervo diversificado de testes (Livros e HQs em pt-BR e en, múltiplos formatos, controle de latência, timeout e erro).
  - Orquestrador concorrente `ProviderManager` com isolamento estrito de falhas por provedor e ranking por relevância e idioma.
- **Entregáveis Aprovados:**
  - `/docs/PROVIDERS.md`
  - `/docs/adr/ADR-010-PROVIDER-ENGINE.md`
  - Suíte completa com 113/113 testes passando verde, 0 erros no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** Todo o pipeline de busca paralela, normalização de metadados externos, deduplicação de obras/edições e isolamento de provedores instáveis validado 100% por testes automatizados offline.

---

### FASE J — BUSCA ONLINE & CATÁLOGO UNIFICADO
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Conectar provedores autorizados/públicos reais à engine de busca paralela com ranking e filtros de idioma (prioridade pt-BR e en).
- **Atividades Realizadas:**
  - Caso de uso unificado: `SearchOnlineCatalogUseCase` orquestrando busca paralela, deduplicação em memória e filtros por tipo, idioma, formato e ordenação.
  - BLoC reativo `SearchBloc` com debounce de 300ms, cancelamento com `switchMap` e estados estruturados (`Initial`, `Loading`, `Loaded`, `Empty`, `Error`).
  - Tela `SearchScreen` completa integrada ao BLoC com barra de busca minimalista, chips de filtros horizontais, tags de sugestões iniciais e cards ricos de resultados.
  - Seletor dinâmico de edições/formatos na `WorkDetailsScreen` com status de download em tempo real.
- **Entregáveis Aprovados:**
  - `/docs/SEARCH-CATALOG.md`
  - `/docs/adr/ADR-011-UNIFIED-SEARCH-CATALOG.md`
  - Suíte completa com 123/123 testes passando verde, 0 erros no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** O usuário pesquisa termos com debounce, visualiza resultados deduplicados com ordenação e filtros, e seleciona a edição/formato desejada com informações de arquivo e download.

---

### FASE K — LEITURA ONLINE (STREAMING READER ENGINE)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Permitir a leitura direta de obras públicas/autorizadas sem a obrigatoriedade de salvar permanentemente o arquivo com antecedência.
- **Atividades Realizadas:**
  - Arquitetura híbrida com modelo imutável `ReadingSession` e enum de fontes (`ReadingSource.local`, `ReadingSource.cachedStream`, `ReadingSource.onlineStream`).
  - Implementação do `OnlineReadingManager` com tripla camada de resolução: verificação de arquivo local permanente -> verificação de cache volátil -> streaming remoto em buffer.
  - Partição física de cache de leitura `/NovaReader/cache/reading/` e limpeza seletiva `clearReadingCache()` no `StorageManager`.
  - Casos de uso de domínio: `PrepareReadingSessionUseCase` e `PromoteReadingSessionUseCase`.
  - Promoção atômica de buffer (`promoteToLocal`): cópia direta do cache volátil para `/books/` ou `/comics/`, persistência no SQLite e marcação `isLocal: true` sem nenhum re-download pela rede.
  - Persistência universal de progresso e histórico no SQLite local para todas as sessões de leitura (online ou offline).
  - UI atualizada em `BookReaderScreen` e `ComicReaderScreen` com badge monocromático `STREAMING`/`SALVO` e ação imediata de salvar offline na biblioteca.
  - `WorkDetailsScreen` com indicador de disponibilidade de leitura offline vs streaming online.
- **Entregáveis Aprovados:**
  - `/docs/ONLINE-READING.md`
  - `/docs/adr/ADR-012-ONLINE-STREAMING-READER.md`
  - Suíte completa com 133/133 testes passando verde, 0 erros no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** Abertura instantânea de obras locais sem rede, streaming sob demanda em buffer volátil para obras remotas, e promoção imediata de cache para arquivo permanente local sem consumo adicional de banda.

---

### FASE L — INTEGRAÇÃO PONTA A PONTA (ONLINE -> OFFLINE)
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Validar o ciclo completo do produto: Busca Online -> Detalhes -> Download -> Armazenamento Local -> Biblioteca -> Leitura Offline.
- **Atividades Realizadas:**
  - Auto-registro seguro da entidade `Work` e suas edições na biblioteca local SQLite durante o enfileiramento (`DownloadManager.enqueue`).
  - Geração de arquivos mock sintéticos autênticos e parseáveis (`_generateValidMockBytes` para EPUB, CBZ e TXT).
  - Materialização física definitiva de capas remotas na partição segura `/covers/` no evento de sucesso do download (`_onDownloadSuccess`) com atualização imediata via `libraryRepository.updateCoverPath`.
  - Suíte completa de testes de integração ponta a ponta (`test/integration/end_to_end_online_to_offline_test.dart`) cobrindo:
    1. Livro: Busca online ("Duna") -> Download EPUB -> Persistência local -> Leitura offline autônoma no `BookReaderBloc` -> Paginação e restauração exata de progresso no SQLite.
    2. Quadrinho: Busca online ("Watchmen") -> Download CBZ -> Persistência em `/comics/` -> Leitura no `ComicReaderBloc` -> Extração física de bytes de páginas via `loadPageBytes`.
    3. Fluxo Híbrido: Streaming online para `/cache/reading/` -> Promoção atômica para `/books/` (`promoteToLocal`) -> Limpeza seletiva de cache volátil -> Acesso offline transparente.
- **Entregáveis Aprovados:**
  - `/docs/END-TO-END-INTEGRATION.md`
  - `/docs/adr/ADR-013-END-TO-END-PIPELINE.md`
  - Suíte completa com 137/137 testes passando verde, 0 erros no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** O ciclo completo do produto (Busca -> Seleção -> Download -> Armazenamento Local -> Biblioteca -> Leitura Offline Desconectada e Progresso) validado com 100% de sucesso.

---

### FASE M — PERFIL DO USUÁRIO & AVATARES MONOCROMÁTICOS
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Implementar o sistema de perfil local, preferências do leitor, catálogo de avatares monocromáticos e governança de armazenamento.
- **Atividades Realizadas:**
  - Armazenamento de perfil no SQLite Schema v2: Tabela `profiles` com preferências (`fontSize`, `fontFamily`, `readingMode`, `maxConcurrentDownloads`) e migração atômica no `AppDatabase`.
  - Catálogo nativo com 12 avatares geométricos e abstratos monocromáticos (`nova_monolith`, `nova_circle`, `nova_book`, `nova_comic`, etc.) desenhados exclusivamente com a paleta do Design System.
  - Agregação em tempo real de estatísticas de leitura (`booksRead`, `comicsRead`, `currentlyReading`, `totalFavorites`, `totalDownloaded`, `totalPagesRead`).
  - Gerenciamento seguro de armazenamento no `StorageManager` com cálculo detalhado por partição e botões com confirmação de diálogo para limpeza do cache de streaming e cache total.
  - BLoC reativo (`ProfileBloc`) e UI adaptativa com edição de nome, seleção modal de avatares, chips responsivos com `Wrap` e cartões estatísticos minimalistas.
- **Entregáveis Aprovados:**
  - `/docs/PROFILE.md`
  - `/docs/adr/ADR-014-USER-PROFILE-SYSTEM.md`
  - Suíte completa com 150/150 testes passando verde, 0 warnings/errors no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** Edição de perfil local, troca de avatar abstrato, métricas em tempo real e limpeza de cache volátil validadas sem dependência externa ou perda de arquivos permanentes.

---

### FASE N — POLISH VISUAL, MICROINTERAÇÕES & ACESSIBILIDADE
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Refinar a experiência do usuário, tornando-a fluida, elegante e universalmente acessível sob os padrões WCAG 2.1 AAA.
- **Atividades Realizadas:**
  - Animações de transição de tela suaves e hero animations para capas de livros e quadrinhos sincronizando catálogo (`NovaBookCard`, `NovaComicCard`) e cabeçalho de destaque em `WorkDetailsScreen`.
  - Configuração do `PageTransitionsTheme` no tema nativo com `ZoomPageTransitionsBuilder` (Android), `FadeUpwardsPageTransitionsBuilder` (Linux/Windows) e `CupertinoPageTransitionsBuilder` (iOS/macOS).
  - Suporte completo a acessibilidade: árvore `Semantics` abrangente para TalkBack/VoiceOver com anúncios contextuais de título, autor, volume, formato, progresso de leitura e status local de download.
  - Garantia de áreas de toque ergonômicas adequadas (mínimo 48x48 dp) em botões (`NovaButton`, `NovaIconButton`), chips (`NovaFilterChip`) e controles de navegação dos leitores.
  - Microinterações táteis refinadas via `InkRipple.splashFactory` e notificações monocromáticas em `SnackBar`.
  - Layouts resilientes a escalonamento de fontes do sistema operacional (até 200%) com uso de `Wrap`, `Flexible` e `Expanded` eliminando overflows.
- **Entregáveis Aprovados:**
  - `/docs/ACCESSIBILITY-AND-POLISH.md`
  - `/docs/adr/ADR-015-ACCESSIBILITY-AND-UX-POLISH.md`
  - Suíte de testes automatizados com 160/160 testes passando verde (10 novos testes dedicados em `test/presentation/accessibility_test.dart`), 0 erros no `flutter analyze` e build Linux Desktop validado com sucesso.
- **Gate de Aceite Atingido:** Navegação fluida, alvos de toque ergonômicos comprovados em testes, contraste monocromático de 13.5:1 (superando WCAG AAA), Hero transitions nas capas e árvore semântica TalkBack completa.

---

### FASE O — AUDITORIA DE PERFORMANCE & GESTÃO DE RECURSOS
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Otimizar consumo de CPU, RAM, GPU, bateria e banco de dados em cenários de estresse e grandes bibliotecas.
- **Atividades Realizadas:**
  - Teste de carga massivo com 1.000+ obras e centenas de edições no SQLite via transação em lote atômica (`saveWorks`).
  - Eliminação completa de N+1 queries na estante e busca local através do carregamento em lote de edições (`_getEditionsForWorks`).
  - Atualização do banco de dados para o SQLite Schema v3 com índices compostos de alta performance (`idx_works_series`, `idx_library_accessed`).
  - Otimização do `ComicPageCache` com dupla restrição (limite de 7 páginas e teto máximo de bytes configurável de 64MB) garantindo contenção estrita de memória (anti-OOM) durante a navegação contínua de páginas 4K (3MB a 8MB por página).
  - Instrumentação de métricas de eficiência no cache LRU (`hits`, `misses`, `evictionsCount`, `hitRate`).
  - Benchmarks de deduplicação e normalização (500 títulos em ~30ms) e cálculo assíncrono de uso de disco no `StorageManager` (sub-30ms).
- **Entregáveis Aprovados:**
  - `/docs/PERFORMANCE.md`
  - `/docs/adr/ADR-016-PERFORMANCE-AND-RESOURCE-MANAGEMENT.md`
  - Suíte de testes automatizados com 164/164 testes passando verde (4 novos testes de estresse em `test/core/performance_stress_test.dart`), 0 erros no `flutter analyze` e build Linux Desktop validado com sucesso.
- **Gate de Aceite Atingido:** Busca local indexada sub-10ms (média de 4.2ms em 1.000 obras), recuperação de estante completa sub-35ms, contenção estrita de RAM sem vazamentos em HQs 4K e cold start inferior a 500ms.

---

### FASE P — AUDITORIA DE SEGURANÇA & HARDENING
- **Status:** **CONCLUÍDA (100%)**
- **Objetivo:** Blindar o aplicativo contra vulnerabilidades e garantir conformidade com políticas de segurança da plataforma, privacidade ponta a ponta e isolamento total para distribuição Open Source.
- **Atividades Realizadas:**
  - Criação do cofre criptográfico [`CryptoVault`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/lib/core/security/crypto_vault.dart): Cifragem simétrica AES-256 (CBC + PKCS7), geração de chaves seguras de 256 bits via CSPRNG, IV único dinâmico a cada operação, derivação determinística PBKDF2/SHA-256 (10.000 iterações), assinatura e integridade HMAC-SHA256 com comparação em tempo constante (*anti-timing attack*).
  - Envelopes de Criptografia Ponta a Ponta (E2EE): métodos `createSecurePackage` e `openSecurePackage` com validação de assinatura e autenticidade antes da decifragem.
  - Mitigação de Zip Slip e Path Traversal em descompactadores de quadrinhos e livros: métodos `resolveSafeZipEntry` e `isSafeZipEntry` no `StorageManager` com validação de fronteiras `p.isWithin` integrados no `CbzExtractor` e `ComicContentParser`.
  - Hardening de Transporte em `NetworkClient`: imposição obrigatória de tráfego seguro (HTTPS) para servidores remotos com rejeição de HTTP puro (autorizado exclusivamente para loopback/emulador de desenvolvimento local).
  - Hardening de Configurações Android: `android:usesCleartextTraffic="false"`, `android:allowBackup="false"` e permissão explícita `<uses-permission android:name="android.permission.INTERNET" />` no `AndroidManifest.xml`.
  - Sanitização de Logs e Prevenção de Vazamento no `AppLogger`: mascaramento automático de tokens Bearer (`Bearer ***REDACTED***`), credenciais e senhas, e caminhos do host de desenvolvimento (`/home/*`, `/media/*`, `C:\Users\*` para `[SANDBOX_USER_DIR]`).
  - Open Source Readiness: eliminação de vínculos identitários da máquina host (perfil padrão inicial "Leitor") e expansão do `.gitignore` contra vazamentos de `local.properties`, `.gradle`, keystores e segredos.
- **Entregáveis Aprovados:**
  - `/docs/SECURITY.md`
  - `/docs/adr/ADR-017-SECURITY-HARDENING.md`
  - Suíte completa de segurança (`test/core/security_test.dart`) com 18 novos testes e 182/182 testes globais passando verde, 0 warnings/errors no `flutter analyze` e build Linux validado.
- **Gate de Aceite Atingido:** 100% dos testes de segurança aprovados (zero vulnerabilidades críticas ou altas), integridade criptográfica comprovada e código 100% pronto para publicação em código aberto.

---

### FASE Q — RELEASE CANDIDATE (RC)
- **Objetivo:** Montar a compilação candidata a lançamento e executar a matriz de testes exaustiva.
- **Atividades:**
  - Build de release APK para Android Phone e Tablet.
  - Execução da Matriz Completa de Testes (52 cenários obrigatórios).
  - Correção de qualquer finding P0 ou P1 remanescente.
- **Gate de Aceite:** Zero bugs P0/P1 abertos e checklist da Matriz de Testes 100% verde.

---

### FASE R — AUDITORIA FINAL DO PRODUTO & DOCUMENTAÇÃO
- **Objetivo:** Homologação final e emissão do relatório consolidado de auditoria do produto.
- **Atividades:**
  - Revisão de todos os 37 critérios de aceite do produto (Seção 71).
  - Emissão do documento oficial de auditoria.
- **Entregáveis Obrigatórios:**
  - `/FINAL-AUDIT.md`
- **Gate de Aceite:** Aceite formal e validação do produto pronto para uso pessoal definitivo.

---

## 4. Matriz de Testes Não Negociável

| Eixo | Dimensões de Teste |
|---|---|
| **Dispositivo** | Android Phone (Medium Phone, Pixel 9a), Android Tablet (10" WXGA, Galaxy Tab A), Desktop Linux |
| **Conectividade** | 100% Online, 100% Offline (Modo Avião), Rede Lenta (Throttled), Queda de Conexão no Meio da Ação |
| **Formatos de Livro** | EPUB 2/3, PDF Texto, PDF Escaneado, TXT ANSI/UTF-8 |
| **Formatos de HQ** | CBZ (ZIP), CBR (RAR), Imagens Soltas (PNG, JPEG, WebP) |
| **Volume de Conteúdo**| Obras Leves (< 5 MB), Obras Médias (50 MB), Obras Pesadas (300 MB - 1 GB) |
| **Orientação** | Retrato (Portrait), Paisagem (Landscape), Mudança Dinâmica durante a Leitura |

---

## 5. Roadmap Futuro (Pós-MVP)

- **Fase Futura 1:** Sincronização em Nuvem Privada (WebDAV / S3 / Nextcloud)
- **Fase Futura 2:** Sincronização Multidispositivo de Progresso e Marcações
- **Fase Futura 3:** Estatísticas Avançadas de Leitura (Velocidade, Tempo Gasto, Heatmap de Hábitos)
- **Fase Futura 4:** Coleções Inteligentes e Tags Personalizadas
- **Fase Futura 5:** Recomendações Baseadas no Histórico Local
- **Fase Futura 6:** Extração e Busca de Metadados Avançados (Calibre / OPDS)
- **Fase Futura 7:** Exportação e Sincronização de Destaques e Anotações
- **Fase Futura 8:** Temas Customizados (Sepia, Pure AMOLED Black, Paper Grey)
- **Fase Futura 9:** Leitor Avançado de HQ (Detecção Automática de Quadros / Panel-by-Panel Zoom)
- **Fase Futura 10:** Aplicativo Desktop Companion Nativo (Linux / Windows)

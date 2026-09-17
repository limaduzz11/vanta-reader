# ADR-004: Persistência Local-First, Catálogo SQLite WAL e Gerenciamento de Estado Reativo

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase D — Biblioteca Local & Persistência Local-First

---

### Contexto e Problema

O NovaReader rege-se pelo princípio inegociável de **Local-First**: a experiência primária do usuário deve funcionar 100% offline, com latência zero e sem dependência de conexões de rede ou servidores remotos para navegação na biblioteca, leitura, busca e retenção de progresso.

O desafio arquitetural consistiu em estabelecer uma infraestrutura de persistência robusta, resiliente a falhas e reativa, capaz de:
1. Indexar obras (Livros e Quadrinhos) e suas respectivas edições com integridade referencial estrita.
2. Manter histórico e progresso de leitura milimétricos (página atual, total de páginas, offset de caracteres no texto/EPUB e percentual exato).
3. Permitir buscas instantâneas no acervo local por título, autor e série sem overhead de rede.
4. Suportar alternância atômica de favoritos e filtros rápidos por tipo de conteúdo.
5. Sincronizar o estado da interface visual via State Management previsível (`flutter_bloc`), desacoplado de detalhes de banco de dados.

---

### Decisões de Arquitetura

1. **Persistência Relacional via SQLite com WAL Mode:**
   - Adotou-se o SQLite em modo WAL (*Write-Ahead Logging*) com `PRAGMA foreign_keys = ON;`, `PRAGMA synchronous = NORMAL;` e `PRAGMA journal_size_limit = 67108864;` (64MB).
   - O schema unifica obras na tabela `works`, formatos físicos em `work_editions`, estado da biblioteca em `library` e rastreamento contínuo em `reading_progress` e `reading_history`.
   - Índices estratégicos cobrem títulos, autores, favoritos e datas de atualização para garantir queries sub-milissegundo.

2. **Clean Architecture & UseCases Granulares:**
   - O domínio não possui qualquer vínculo com drivers de banco de dados ou pacotes de UI.
   - Foram implementados UseCases focados de responsabilidade única:
     - `GetLibraryWorksUseCase`: Filtra e retorna obras do acervo local (todos, livros, quadrinhos, favoritos, baixados).
     - `ToggleFavoriteUseCase`: Comuta o estado de favorito de forma atômica no banco de dados.
     - `SaveReadingProgressUseCase`: Registra o progresso de leitura garantindo precisão de página, total de páginas e offset.
     - `GetReadingProgressUseCase`: Recupera o último marco de leitura de uma obra específica.
     - `SearchLocalLibraryUseCase`: Executa busca textual indexada com sanitização contra SQL injection.
     - `SeedInitialCatalogUseCase`: Realiza o semeamento inicial idempotente do acervo clássico na inicialização local.

3. **Gerenciamento de Estado Reativo com BLoC:**
   - `LibraryBloc`: Orquestra eventos de carga (`LoadLibraryEvent`), filtro, alternância de favoritos (`ToggleFavoriteEvent`) e busca (`SearchLibraryLocalEvent`). Emite estados imutáveis (`LibraryInitial`, `LibraryLoading`, `LibraryLoaded`, `LibraryError`) consumidos pelo `BlocBuilder`.
   - `WorkDetailsBloc`: Gerencia o detalhe específico de uma obra, permitindo atualizar progresso e favoritos com feedback visual imediato.

4. **UI Reativa e Contadores Dinâmicos:**
   - A tela de biblioteca (`LibraryScreen`) foi integralmente conectada ao `LibraryBloc`, atualizando contadores em tempo real para cada uma das 5 abas sem reconstruções desnecessárias.

---

### Consequências

- **Positivas:**
  - Funcionamento offline autônomo e definitivo: a aplicação pode ser aberta em qualquer lugar (modo avião, viagens sem sinal) com acesso imediato ao acervo e progresso.
  - Testabilidade de 100%: todo o repositório, usecases e blocos são validados com testes unitários e de integração utilizando fábrica SQLite em memória (`:memory:`) via `sqflite_common_ffi`.
  - Separação rigorosa de responsabilidades, preparando o terreno de forma limpa para a importação de arquivos locais (Fase E) e sincronização opcional online (Fase F).
- **Negativas / Mitigações:**
  - Necessidade de gerenciar concorrência de escritas no banco: mitigado pelo modo WAL do SQLite e transações atômicas no repositório.

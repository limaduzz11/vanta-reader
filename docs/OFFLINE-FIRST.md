# NovaReader — Arquitetura Local-First & Persistência Offline
## Especificação Técnica da Fase D

---

### 1. Princípio Fundamental: Local-First

O **NovaReader** opera sob o paradigma **Local-First**, o que significa que o banco de dados local SQLite e o sistema de arquivos do dispositivo representam a **única fonte da verdade** para a experiência de leitura e organização do usuário:

1. **Autonomia Completa:** A ausência de conexão com a internet nunca bloqueia a navegação na biblioteca, o acesso aos livros/quadrinhos já importados ou baixados, nem a atualização do progresso de leitura.
2. **Zero Login Mandatório:** O usuário não precisa autenticar-se em servidores externos para ter sua biblioteca, favoritos, tags ou histórico preservados.
3. **Persistência Imediata e Atômica:** Qualquer ação do usuário (marcar favorito, virar de página, alterar nota) é confirmada no SQLite localmente com garantias ACID e WAL (Write-Ahead Logging).
4. **Rede como Canal Aditivo:** A internet funciona apenas como um canal de descoberta e transferência sob demanda. Se a rede cair, o app não exibe telas em branco nem bloqueia o leitor.

---

### 2. Estrutura de Tabelas e Integridade Relacional

O banco de dados SQLite (`AppDatabase`) opera em modo WAL (`PRAGMA journal_mode = WAL;`) e com integridade referencial ativa (`PRAGMA foreign_keys = ON;`).

```mermaid
erDiagram
    works ||--o{ work_editions : "possui edições"
    works ||--o| library : "registro na estante"
    works ||--o| reading_progress : "progresso ativo"
    works ||--o{ reading_history : "sessões de leitura"
    work_editions ||--o{ downloads : "transferências"

    works {
        string id PK
        string work_key UK
        string title
        string author
        string primary_language
        string type
        string series
        string volume
        string cover_path
    }

    work_editions {
        string id PK
        string work_id FK
        string format
        string file_path
        int file_size
        int is_local
    }

    library {
        string work_id PK_FK
        string status
        int is_favorite
        int added_at
        int last_accessed_at
    }

    reading_progress {
        string work_id PK_FK
        string edition_id FK
        int current_page
        int total_pages
        int char_offset
        real percentage
        int updated_at
    }
```

---

### 3. Casos de Uso (Domain Layer)

A camada de domínio encapsula a regra de negócio e isola a interface gráfica da persistência:

| Caso de Uso | Responsabilidade |
|---|---|
| `GetLibraryWorksUseCase` | Recupera obras da estante local com suporte a filtros por `type` (livro/HQ), `language`, `onlyFavorites` e `onlyDownloaded`. |
| `ToggleFavoriteUseCase` | Alterna atomicamente o flag `is_favorite` na tabela `library` e retorna o novo estado booleano. |
| `SaveReadingProgressUseCase` | Grava o progresso milimétrico da leitura (página atual, total, offset de caractere e percentual) e atualiza `last_accessed_at`. |
| `GetReadingProgressUseCase` | Recupera o último marcador de progresso da obra para retomar a leitura no ponto exato. |
| `SearchLocalLibraryUseCase` | Executa busca textual offline ultra-rápida (`LIKE` indexado) por título, autor ou série. |
| `SeedInitialCatalogUseCase` | Semeia o acervo inicial canônico de 6 obras (Duna, Clean Code, Batman: Ano Um, Watchmen, Neuromancer, Sandman) no SQLite caso a estante esteja vazia (idempotente). |

---

### 4. Gerenciamento de Estado Reativo (`LibraryBloc`)

A tela de biblioteca consome o `LibraryBloc`, implementado sobre a biblioteca canônica `flutter_bloc`:

- **Eventos (`LibraryEvent`):**
  - `LoadLibraryEvent({filterType, language, onlyFavorites, onlyDownloaded, searchQuery})`: Solicita o carregamento do acervo com critérios específicos.
  - `ToggleFavoriteEvent(workId)`: Alterna o status de favorito e emite o estado atualizado sem recarregar a tela inteira.
  - `SearchLibraryLocalEvent(query)`: Filtra instantaneamente a estante por texto.
- **Estados (`LibraryState`):**
  - `LibraryInitial`: Estado antes do disparo inicial.
  - `LibraryLoading`: Estado transitório para operações pesadas de I/O.
  - `LibraryLoaded`: Estado estável com a lista de `Work`s, conjunto de `favoriteWorkIds` em memória (`Set<String>`) para checagem `O(1)`, filtros ativos e paginação.
  - `LibraryError`: Estado de falha com mensagem semântica e opção de repetição (`onRetry`).

---

### 5. Garantias de Confiabilidade e Testes

A suíte de testes unitários e de integração cobre rigorosamente o ciclo de vida Local-First:
1. `test/data/repositories/library_repository_test.dart`: Testes de persistência direta SQLite, transações e integridade relacional.
2. `test/domain/usecases_test.dart`: Testes de todos os UseCases com verificação de filtros, alternância de favoritos, persistência de progresso e busca textual.
3. `test/presentation/library_bloc_test.dart`: Teste da máquina de estados do BLoC, garantindo fluxo estrito de eventos e reatividade da estante.
4. `test/presentation/navigation_test.dart`: Teste de UI widget verificando que a `LibraryScreen` exibe os dados reais do SQLite em suas abas ("Todos", "Livros", "Quadrinhos", "Favoritos", "Baixados") em celulares e tablets.

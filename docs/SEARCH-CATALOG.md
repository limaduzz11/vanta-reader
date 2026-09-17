# NovaReader — Busca Online & Catálogo Unificado (Fase J)

O módulo de **Busca Online e Catálogo Unificado** do NovaReader conecta o motor de provedores de conteúdo (`ProviderManager` e `WorkIdentitySystem` da Fase I) com a camada de apresentação do usuário, entregando uma experiência de descoberta ágil, resiliente, rica em filtros e totalmente desacoplada de contas ou infraestruturas centrais.

---

## 1. Arquitetura da Solução

```
lib/
├── domain/
│   └── usecases/
│       └── search_online_catalog_usecase.dart  # Caso de uso: busca, filtros e ordenação unificada
├── presentation/
│   ├── blocs/
│   │   └── search/
│   │       ├── search_event.dart              # Eventos de busca, troca de filtros e limpeza
│   │       ├── search_state.dart              # Estados do fluxo: Initial, Loading, Loaded, Empty, Error
│   │       └── search_bloc.dart               # BLoC reativo com debounce de digitação
│   └── screens/
│       ├── search_screen.dart                 # Interface gráfica com barra de busca, chips e cards
│       └── work_details_screen.dart           # Detalhes da obra com seletor dinâmico de edições/formatos
```

---

## 2. Caso de Uso: `SearchOnlineCatalogUseCase`

O caso de uso orquestra a pesquisa e a aplicação de filtros em nível de domínio:

- **Consulta Concorrente:** Aciona o `ProviderManager.search()`, consultando todos os provedores ativos em paralelo.
- **Filtros Parametrizados (`SearchFilter`):**
  - **Tipo de Obra:** `WorkType.book`, `WorkType.comic` ou `null` (todos).
  - **Formato de Arquivo:** `WorkFormat.epub`, `WorkFormat.pdf`, `WorkFormat.cbz`, etc. O filtro verifica se a obra possui ao menos uma edição no formato selecionado.
  - **Idioma:** Filtro por código ISO normalizado (`pt-BR`, `en`).
  - **Critério de Ordenação (`SearchSortOrder`):**
    - `relevance`: Relevância calculada por correspondência exata, prefixo de título e autor.
    - `title`: Ordem alfabética por título normalizado.
    - `author`: Ordem alfabética por autor normalizado.

---

## 3. Gestão de Estado: `SearchBloc`

O `SearchBloc` gerencia o ciclo de vida reativo das pesquisas:

### Eventos
- `SearchQueryChanged(query)`: Disparado a cada caractere digitado pelo usuário.
- `SearchFilterChanged(filter)`: Disparado ao alternar chips de filtro (tipo, formato, idioma ou ordenação).
- `SearchCleared()`: Limpa o campo e restaura o estado inicial com sugestões rápidas.

### Otimizações
- **Debounce de 300ms:** Previne chamadas excessivas aos provedores enquanto o usuário digita.
- **Cancelamento Automático:** Novas emissões descartam operações assíncronas em andamento via `switchMap`.
- **Estados Canônicos:**
  - `SearchInitial`: Exibe sugestões de termos e tópicos populares de leitura.
  - `SearchLoading`: Indicador de progresso minimalista monocromático.
  - `SearchLoaded`: Lista paginada de obras desduplicadas com suas respectivas edições.
  - `SearchEmpty`: Feedback amigável para consultas sem correspondência.
  - `SearchError`: Mensagem contextual de falha sem interromper a navegação.

---

## 4. Experiência do Usuário (`SearchScreen`)

A interface segue rigorosamente o design system monocromático (`NovaColors`):

1. **Barra de Pesquisa Monocromática:**
   - Campo de entrada com fundo `#1E1E1E`, bordas sutis `#2C2C2C` e botão de limpeza contextual (`Icons.clear`).
2. **Barra de Filtros Dinâmicos:**
   - Chips de seleção horizontal com badges para Tipo (Livros / HQs), Formato (EPUB, PDF, CBZ), Idioma (pt-BR, en) e Ordenação.
3. **Sugestões Rápidas (`SearchInitial`):**
   - Chips com termos sugeridos ("Sci-Fi", "Fantasia", "Mangá", "Duna", "Batman", "Clássicos") para descoberta instantânea com um clique.
4. **Cards de Resultados:**
   - Capa com fallback geométrico e proporção 3:4.
   - Título, autor e tipo da obra.
   - Badges visuais indicando os formatos disponíveis nas edições consolidadas.
   - Contador de edições alternativas (ex: "2 formatos disponíveis").
   - Toque que navega diretamente para a `WorkDetailsScreen`.

---

## 5. Seletor Dinâmico de Edições (`WorkDetailsScreen`)

Quando uma obra é descoberta através de múltiplos provedores ou formatos, a tela de detalhes apresenta a seção **Edições e Formatos Disponíveis**:

- **Card Individual por Edição:**
  - Badge do formato (`EPUB`, `PDF`, `CBZ`, `TXT`).
  - Tamanho formatado do arquivo (ex: `12.5 MB`).
  - Nome do provedor de origem (ex: `Mock Catalog`, `Biblioteca Pública`).
  - Botão de ação de download com indicação de estado persistente:
    - *Baixar*: Enfileira download no `DownloadManager`.
    - *Baixando (Progresso %)*: Barra linear de progresso reativo.
    - *Concluído*: Redireciona para o leitor apropriado (`BookReaderScreen` ou `ComicReaderScreen`).

---

## 6. Cobertura de Testes Automatizados

A Fase J conta com testes de unidade e de widget completos:

1. **`test/domain/usecases/search_online_catalog_usecase_test.dart`:**
   - Busca com deduplicação de obras idênticas.
   - Filtragem precisa por tipo, formato e idioma.
   - Ordenação alfabética por título e autor.
2. **`test/presentation/search_bloc_test.dart`:**
   - Emissão de estados `SearchInitial`, `SearchLoading`, `SearchLoaded` e `SearchEmpty`.
   - Debounce e cancelamento de pesquisas anteriores.
   - Aplicação reativa de filtros sem re-digitação de termo.
3. **`test/presentation/search_screen_test.dart`:**
   - Renderização da barra de busca e sugestões iniciais.
   - Interação com chips de filtro.
   - Exibição de cards de resultados e navegação para tela de detalhes.

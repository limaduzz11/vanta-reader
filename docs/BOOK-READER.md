# NovaReader — Motor de Leitura de Livros (Fase F)

O **Book Reader Engine** do NovaReader é o subsistema responsável pela interpretação, renderização, paginação e navegação de obras textuais (EPUB, TXT e PDF), operando sob a diretriz **Local-First** e filosofia visual **Monochromatic Minimalism**.

---

## 1. Arquitetura do Subsistema

```
lib/
├── core/
│   └── reader/
│       ├── book_models.dart         # BookChapter, BookContent, TypographySettings
│       └── book_content_parser.dart # Parser EPUB/TXT/PDF e gerador resiliente
├── presentation/
│   ├── blocs/
│   │   └── book_reader/
│   │       ├── book_reader_bloc.dart
│   │       ├── book_reader_event.dart
│   │       └── book_reader_state.dart
│   └── screens/
│       └── reader/
│           └── book_reader_screen.dart # Tela imersiva com controles retráteis
```

---

## 2. Modelos de Domínio (`book_models.dart`)

- **`BookChapter`**:
  - `id`: identificador único do capítulo (ex.: `ch-0-item1`).
  - `title`: título extraído de `<h1>`, `<h2>` ou `<title>` do documento XHTML.
  - `content`: texto limpo e legível em UTF-8 com formatação de parágrafos.
  - `orderIndex`: posição ordinal na sequência de leitura definida pelo `<spine>`.
  - `estimatedPages`: cálculo de paginação proporcional (~1.800 caracteres por página).

- **`BookContent`**:
  - `workId`: ID canônico da obra.
  - `title`: título do livro.
  - `chapters`: lista ordenada de `BookChapter`.
  - `totalEstimatedPages`: soma total das páginas estimadas da obra.

- **`TypographySettings`**:
  - `fontSize`: tamanho da fonte (12 a 28 px).
  - `lineHeight`: espaçamento entre linhas (1.2 a 2.2).
  - `fontFamily`: tipografia do sistema (`sans-serif`, `serif`, `monospace`).
  - `themeMode`: esquema visual (`oled_dark`, `sepia`, `night`).

---

## 3. Pipeline do Parser (`BookContentParser`)

1. **EPUB 2 / EPUB 3**:
   - Descompacta arquivo ZIP em memória.
   - Lê `META-INF/container.xml` para encontrar o caminho do arquivo de pacote OPF.
   - Parseia o manifesto OPF via `xml` package, indexando `id` para `href`.
   - Itera a ordem canônica declarada nas tags `<itemref>` do `<spine>`.
   - Limpa marcações HTML através de expressões regulares eficientes, removendo scripts, folhas de estilo e decodificando entidades como `&nbsp;`, `&mdash;`, `&quot;`.
2. **TXT**:
   - Divide o texto por quebras de parágrafo duplas e agrupa em seções navegáveis de até 5.000 caracteres.
3. **PDF**:
   - Apresenta estrutura com sinopse e metadados detalhados para leitura integrada.
4. **Resiliente / Fallback**:
   - Caso o livro seja do catálogo semente e ainda não tenha sido baixado, gera capítulos de amostra contextualizados com a sinopse e autor da obra, mantendo o app 100% testável e navegável.

---

## 4. Gerenciamento de Estado (`BookReaderBloc`)

O BLoC coordena o fluxo de leitura e garante persistência milimétrica no SQLite:

- **`OpenBookEvent`**: Carrega o conteúdo pelo parser e consulta `GetReadingProgressUseCase` para restaurar a última página lida.
- **`NextPageEvent` / `PreviousPageEvent`**: Avança ou retrocede página respeitando limites (1 a `totalPages`) e aciona `SaveReadingProgressUseCase`.
- **`JumpToChapterEvent`**: Salta para o início do capítulo selecionado e atualiza a página correspondente.
- **`ToggleControlsEvent`**: Alterna a visibilidade das barras retráteis superior e inferior para leitura imersiva.
- **`UpdateTypographyEvent`**: Atualiza tamanho de fonte, espaçamento ou tema de cor em tempo real.

---

## 5. Experiência de Uso (`BookReaderScreen`)

- **Navegação por Toque Lateral**:
  - Toque nos primeiros 25% da largura da tela retrocede página.
  - Toque nos últimos 25% da largura avança página.
  - Toque no centro (50% central) oculta ou exibe os controles (AppBar e Slider).
- **Sumário Retrátil**:
  - Ícone de sumário na AppBar abre Modal Bottom Sheet com a lista de todos os capítulos, status do capítulo atual e salto direto.
- **Ajustes Tipográficos**:
  - Modal interativo com slider de tamanho de fonte, espaçamento e botões seletores de temas de fundo.
- **Integração na Obra**:
  - O botão **"LER AGORA"** em `WorkDetailsScreen` direciona diretamente para o `BookReaderScreen` com a edição da obra.

---

## 6. Verificação de Qualidade

- **Testes Unitários:**
  - `test/core/book_content_parser_test.dart` (EPUB, TXT, Fallback e arquivos corrompidos).
  - `test/presentation/book_reader_bloc_test.dart` (Ciclo de vida, navegação, salto de capítulo e persistência SQLite).
- **Testes de Widget:**
  - `test/presentation/book_reader_screen_test.dart` (Renderização, barras de controle, fullscreen imersivo e modais).
- **Status da Suíte Geral:** 49/49 testes passando 100% green (`flutter test`).
- **Linter:** 0 alertas / 0 erros (`flutter analyze`).

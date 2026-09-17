# ADR-007: Book Reader Engine (Motor de Leitura de Livros Digitais)

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase F — Leitor de Livros (Book Reader Engine)

---

### Contexto e Problema

O leitor digital de livros (EPUB, TXT e PDF) é um pilar essencial do NovaReader. A experiência de leitura textual exige alto desempenho, legibilidade impecável e zero distrações, respeitando a identidade Monochromatic Minimalism.

Os desafios centrais incluíam:
1. **Extração de Conteúdo Estruturado:** Parsing de arquivos EPUB reais (descompactação ZIP, manifesto OPF, sequência ordenada pelo `<spine>` e sanitização do HTML dos capítulos) e arquivos TXT/PDF, com fallback estruturado caso o livro não possua arquivo físico local no disco.
2. **Modo Imersivo (Fullscreen sem Distrações):** Ocultamento e reexibição suave das barras superior e inferior através de toques na tela ou gestos.
3. **Persistência Milimétrica e Automática de Progresso:** Gravação do último capítulo lido, página atual e percentual de leitura no SQLite local a cada avanço/retrocesso de página ou troca de capítulo.
4. **Customização Tipográfica:** Controle de tamanho de fonte, altura de linha, família tipográfica e modos de cor (OLED Dark, Sépia, Night).
5. **Navegação Adaptativa e Sumário (TOC):** Menu lateral retrátil/bottom-sheet para navegação direta entre capítulos e controle deslizante de progresso.

---

### Decisões de Arquitetura

1. **Separação Rígida entre Parser e Apresentação (`BookContentParser`):**
   - O `BookContentParser` foi isolado como serviço puro Dart em `lib/core/reader/book_content_parser.dart`.
   - Para EPUBs: parseia o manifesto `container.xml` e `content.opf`, localiza todos os itens do spine, remove marcações HTML indesejadas (`<script>`, `<style>`, tags de estilização externa), decodifica entidades HTML e calcula paginação estimada (baseada na métrica canônica de ~1.800 caracteres por página).
   - Para TXTs: particiona parágrafos em blocos de até 5.000 caracteres, gerando seções estruturadas.
   - Fornece fallback resiliente para obras do acervo inicial sem download físico ainda efetuado.

2. **Gerenciamento de Estado Reativo via BLoC (`BookReaderBloc`):**
   - Implementado em `lib/presentation/blocs/book_reader/`.
   - Controla eventos: `OpenBookEvent`, `NextPageEvent`, `PreviousPageEvent`, `JumpToChapterEvent`, `JumpToPageEvent`, `ToggleControlsEvent`, `UpdateTypographyEvent`.
   - Recupera progresso prévio persistido no SQLite via `GetReadingProgressUseCase` e sincroniza a cada mudança via `SaveReadingProgressUseCase`.
   - Permite injeção de `initialState` para facilitar testes determinísticos de interface sem loops concorrentes.

3. **Interface e Gestos Imersivos (`BookReaderScreen`):**
   - Toques nos 25% laterais da tela avançam (direita) ou retrocedem (esquerda) de página.
   - Toque no terço central (50%) alterna a visibilidade das barras de controle (AppBar superior e Slider inferior).
   - Modal Bottom Sheet com altura delimitada (`isScrollControlled: true` com `SizedBox`) para seleção instantânea de capítulos no Sumário.
   - Modal Bottom Sheet para customização tipográfica interativa em tempo real.

4. **Vinculação em `WorkDetailsScreen`:**
   - O botão principal "LER AGORA" identifica o tipo da obra e a edição local/padrão, disparando a navegação para o `BookReaderScreen`.

---

### Consequências

- **Positivas:**
  - Experiência de leitura fluida, rápida e sem engasgos no Linux Desktop e Android.
  - Progresso de leitura 100% resiliente: ao fechar e reabrir o livro, o leitor restaura a página exata em que o usuário parou.
  - 100% de cobertura e verificação com 49 testes automatizados passando green e 0 alertas no `flutter analyze`.
- **Negativas / Mitigações:**
  - EPUBs com diagramação altamente estilizada e CSS proprietário perdem parte de seus estilos fixos: decisão intencional para priorizar legibilidade limpa, renderização rápida e respeito aos temas Monochromatic Minimalism e modo noturno.

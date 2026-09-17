# NovaReader — Motor de Leitura de Quadrinhos, HQs e Mangás (Fase G)

O **Comic Reader Engine** do NovaReader é o subsistema responsável pela interpretação, descompactação, paginação sob demanda, cache em memória e renderização interativa de obras gráficas (CBZ, CBR e imagens), operando sob a diretriz **Local-First**, prevenção rigorosa de OOM (Out-of-Memory) e filosofia visual **Monochromatic Minimalism**.

---

## 1. Arquitetura do Subsistema

```
lib/
├── core/
│   └── reader/
│       ├── comic_models.dart         # ComicPage, ComicContent, ComicReaderSettings, Enums
│       ├── comic_page_cache.dart     # Cache LRU em memória com eviction automática
│       └── comic_content_parser.dart # Parser CBZ com ordenação alfanumérica e fallback
├── presentation/
│   ├── blocs/
│   │   └── comic_reader/
│   │       ├── comic_reader_bloc.dart
│   │       ├── comic_reader_event.dart
│   │       └── comic_reader_state.dart
│   └── screens/
│       └── reader/
│           └── comic_reader_screen.dart # Visualizador Página Única / Webtoon, Zoom e Modais
```

---

## 2. Modelos de Domínio (`comic_models.dart`)

- **`ComicReadingMode`**:
  - `page`: Modo página única com transição horizontal e pinch-to-zoom/double-tap.
  - `webtoon`: Modo rolagem vertical contínua com carregamento infinito sob demanda.

- **`ComicFitMode`**:
  - `fitWidth`: Enquadramento ajustado à largura da viewport (padrão recomendado para quadrinhos ocidentais e smartphones).
  - `fitHeight`: Enquadramento ajustado à altura da tela.
  - `fitScreen`: Ajuste proporcional com contenção total (`BoxFit.contain`).

- **`ComicReaderSettings`**:
  - Configurações do leitor contendo `readingMode`, `fitMode`, `isDoublePageInLandscape` e `readRightToLeft` (modo Mangá RTL).

- **`ComicPage`**:
  - Metadados leves por página: `pageIndex`, `fileName`, `fileSize`, sem reter bytes brutos na memória.

- **`ComicContent`**:
  - Agregador com ID canônico da obra, título e lista sequencial de `ComicPage`.

---

## 3. Gestão de Memória e Cache LRU (`comic_page_cache.dart`)

Quadrinhos em alta resolução contêm dezenas de páginas pesadas. Para evitar falhas críticas de Out-Of-Memory (OOM) no Android e Desktop:
- Implementa um **Least Recently Used (LRU) Cache** baseado em `LinkedHashMap<int, Uint8List>`.
- Capacidade padrão de **7 páginas** ativas em memória (página atual, 3 anteriores e 3 posteriores).
- Páginas lidas que extrapolam a capacidade são automaticamente descartadas da memória RAM e recarregadas sob demanda pelo arquivo CBZ quando revisitadas.

---

## 4. Pipeline do Parser e Ordenação Natural (`comic_content_parser.dart`)

1. **Descompactação CBZ e Filtragem:**
   - Lê o container ZIP via pacote `archive`.
   - Filtra exclusivamente arquivos com extensões de imagem (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`).
   - Ignora metadados auxiliares de empacotamento (`ComicInfo.xml`, pastas ocultas `__MACOSX`, metadados de SO).
2. **Algoritmo de Ordenação Alfanumérica Natural (`naturalCompare`):**
   - Resolve o problema clássico de ordenação onde `page_10.jpg` precede `page_2.jpg`.
   - Tokeniza sequências alfanuméricas de forma que `page_1` < `page_2` < `page_10`.
3. **Resiliência e Fallback Procedural:**
   - Obras do catálogo semente que ainda não tiveram download concluído geram páginas estruturadas via BMP 24bpp procedural com identificação legível da página e da obra, garantindo testabilidade e fluidez completas.

---

## 5. Gerenciamento de Estado BLoC (`ComicReaderBloc`)

- **`OpenComicEvent`**: Descompacta/indexa a HQ e consulta `GetReadingProgressUseCase` no SQLite, restaurando a página exata em que o usuário parou.
- **`NextComicPageEvent` / `PreviousComicPageEvent`**: Avança e retrocede páginas com clamp nos limites (0 a `totalPages - 1`) e persiste o progresso de leitura em tempo real via `SaveReadingProgressUseCase`.
- **`JumpToComicPageEvent`**: Salto direto para índice selecionado na Grade de Páginas.
- **`ToggleComicControlsEvent`**: Oculta ou exibe as barras superior e inferior (Modo Imersivo).
- **`ChangeReadingModeEvent`**: Alterna entre visualização Página Única e Webtoon contínuo.
- **`ChangeFitModeEvent`**: Modifica o ajuste visual (Largura, Altura, Tela).
- **`ToggleRtlEvent`**: Habilita leitura reversa (Direita para a Esquerda) para mangás japoneses.

---

## 6. Experiência de Uso e Interface Adaptativa (`ComicReaderScreen`)

- **Navegação por Toques Inteligentes (Hotspots de 25% / 50% / 25%):**
  - Toque nos primeiros 25% à esquerda: retrocede página (ou avança se modo RTL ativo).
  - Toque nos 25% à direita: avança página (ou retrocede se modo RTL ativo).
  - Toque nos 50% centrais: alterna visibilidade das barras de controle (Modo Imersivo).
- **Zoom Fluido e Gestos:**
  - `InteractiveViewer` com minScale 1.0 e maxScale 4.0.
  - Double-tap com animação instantânea para escala 2.2x e reset.
- **Modal de Grade de Páginas (Grid BottomSheet):**
  - Grade 4 colunas com navegação direta e indicação da página atual.
- **Modal de Ajustes do Leitor:**
  - Chips interativos para alternância de modo (Página Única / Webtoon) e enquadramento (Largura / Tela / Altura), além de switch para modo Mangá.
- **Integração na Obra:**
  - Botão **"LER AGORA"** em `WorkDetailsScreen` direciona automaticamente para `ComicReaderScreen` quando o tipo da obra for `WorkType.comic`.

---

## 7. Verificação e Cobertura de Testes

- **Testes Unitários:**
  - `test/core/comic_page_cache_test.dart` (Eviction LRU, capacidade máxima, limpeza).
  - `test/core/comic_content_parser_test.dart` (Ordenação natural, extração CBZ, fallback procedural).
  - `test/presentation/comic_reader_bloc_test.dart` (Carregamento, restauração de progresso, persistência SQLite, bounds, eventos de ajustes).
- **Testes de Widget:**
  - `test/presentation/comic_reader_screen_test.dart` (Renderização, barras de controle, navegação, abertura dos modais de páginas e ajustes, transição para modo Webtoon).
- **Métricas:** 68/68 testes passando 100% green (`flutter test`).
- **Análise Estática:** 0 alertas / 0 erros (`flutter analyze`).
- **Build:** Binário Linux Debug compilado com sucesso (`build/linux/x64/debug/bundle/novareader`).

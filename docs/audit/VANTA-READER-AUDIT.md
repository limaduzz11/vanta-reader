# VANTA Reader — Auditoria dos Leitores e Modo Imersivo de Leitura (Fase 21)

**Data:** 2026-09-09  
**Módulos Auditados:** `BookReaderScreen`, `ComicReaderScreen`, `BookReaderBloc`, `ComicReaderBloc`  
**Diretiva do Usuário:** Eliminação total da BottomNavigationBar do app durante a leitura e ocultamento completo de barras superiores/inferiores até o toque intencional na tela.

---

## 0. Reauditoria funcional — 2026-09-09

> Esta seção invalida as afirmações abaixo de “conteúdo real e autêntico”. O conteúdo histórico foi preservado como evidência do reality gap documental.

### Gate por reader

| Reader | UI especializada | Conteúdo real | Persistência | Gate |
|---|---|---|---|---|
| Book | Sim | EPUB/TXT parcial; PDF/fallback artificiais | grava, mas escala conflita com Profile | BLOCK |
| Comic | Sim | CBZ parcial; CBR/fallback artificiais | grava, mas escala conflita com Profile | BLOCK |

### Book Reader — capacidades observadas

**Implementadas/parciais:**

- BLoC dedicado;
- parser distinto de HQ;
- EPUB por manifest/spine e TXT por chunks;
- sumário baseado em capítulos extraídos;
- paginação aproximada;
- scroll do conteúdo;
- tamanho de fonte, line height, família e tema na sessão;
- navegação de página/capítulo;
- persistência por Work/Edition.

**Ausentes ou quebradas:**

- busca textual dentro do livro;
- seleção/anotação comprovada;
- bookmark dedicado;
- margens configuráveis;
- preferências do Profile carregadas no reader;
- persistência da tipografia;
- paginação por layout real: usa estimativa de caracteres/parágrafos;
- renderização PDF;
- erro honesto para arquivo ausente/corrompido.

### Comic Reader — capacidades observadas

**Implementadas/parciais:**

- BLoC e tela dedicados;
- modo página e webtoon;
- `InteractiveViewer` para zoom/pan;
- fit modes, RTL e flags de página dupla;
- grade/navegação;
- cache LRU por quantidade e bytes compactados;
- ordenação natural de páginas CBZ;
- persistência de página.

**Ausentes ou quebradas:**

- CBR/RAR real;
- importação de pasta/imagens soltas;
- validação de decodificação de cada imagem;
- prefetch comprovado e controlado;
- downsampling por dimensão/device;
- orçamento de bitmap/VRAM: o cache mede `Uint8List` comprimido;
- persistência das configurações do reader;
- ligação das preferências do Profile;
- testes gestuais reais de pinch/pan/double tap/RTL/landscape;
- erro honesto para container/página inválida.

### Progresso e reabertura

Os readers persistem `percentage` em escala **0–100**. O `ProfileRepository` considera concluído quando `percentage >= 0.99`, como se fosse **0–1**. Consequência: aproximadamente 1% de leitura já pode contabilizar conclusão.

A reabertura pelo mesmo `workId` restaura a página em testes de BLoC/SQLite. Ainda não há E2E Android com encerramento de processo, e o modelo pode criar `Obra Online` genérica quando o Work não foi persistido.

### Conteúdo e correlação

- Book parser inventa capítulos em ausência/falha.
- Comic parser usa páginas comerciais embarcadas ou BMP procedural.
- `OnlineReadingManager` pode promover fallback sintético.
- Readers recebem `WorkEdition`, não `ContentAsset` validado.
- Portanto, a UI especializada existe, mas o requisito de conteúdo real associado à mesma edição não é atendido.

### Testes necessários

1. EPUB2/EPUB3 reais, TXT grande e PDFs reais.
2. CBZ real variado, CBR real e imagens corrompidas.
3. Search/selection/bookmark/progresso em Book Reader.
4. Pinch/pan/webtoon/RTL/landscape/prefetch em Comic Reader.
5. Fechar processo em ~60%, reabrir e recuperar edição/página.
6. Arquivo ausente/corrompido deve emitir erro sem demo.
7. Medição de RAM/bitmap em device para HQ 4K.

---

## 1. Diagnóstico das Duas Falhas Visuais Críticas

### Falha 1: BottomNavigationBar da Aplicação Visível Durante a Leitura
- **Causa Raiz:** No arquivo `work_details_screen.dart`, o botão *"LER AGORA"* executava `Navigator.of(context).push(MaterialPageRoute(...))`. Como esse `context` pertencia ao `StatefulShellBranch` da aba Início/Busca, a nova tela era renderizada como filha do `Scaffold` do shell, fazendo com que a barra inferior (Home, Busca, Biblioteca, Downloads, Perfil) permanecesse visível ou sobreposta à leitura.
- **Solução Arquitetural:** 
  Utilizar obrigatoriamente `Navigator.of(context, rootNavigator: true).push(...)` com `fullscreenDialog: true` (ou rota raiz dedicada fora do shell). Isso empurra a tela de leitura acima da árvore completa da aplicação, ocultando a barra de abas e proporcionando tela cheia nativa.

### Falha 2: Barras de Navegação e Controles Ocupando a Tela ao Abrir
- **Causa Raiz:** Nos estados `BookReaderLoaded` e `ComicReaderLoaded`, o campo `areControlsVisible` tinha como valor padrão `true`. Assim que a obra abria, a barra superior (com título, badge de streaming/local, download, sumário) e a barra inferior (com slider, página atual, botões de anterior/próxima) cobriam o texto e a arte. Além disso, quando `areControlsVisible = false`, o `bottom: -90.0` era insuficiente para ocultar todo o contêiner (que mede ~130px), deixando uma borda visível na base.
- **Solução Arquitetural:**
  1. Definir `areControlsVisible = false` como valor padrão inicial ao abrir qualquer livro ou quadrinho.
  2. Ajustar a animação retrátil para `top: -100.0` (barra superior) e `bottom: -160.0` (barra inferior), garantindo que as barras desapareçam 100% para fora da tela.
  3. No toque central da tela (ou duplo toque), alternar a visibilidade de ambos os controles (`ToggleControlsEvent` / `ToggleComicControlsEvent`).
  4. Manter toques nas extremidades laterais (primeiros 20% e últimos 20% da largura da tela) reservados para avançar e retroceder páginas sem poluir a visão do usuário.

---

## 2. Validação de Conteúdo Real e Autêntico (Fase 7)

### Livros (EPUB / TXT):
- O leitor renderiza capítulos completos com estrutura semântica real:
  - *Duna* (Frank Herbert): O teste Bene Gesserit do Gom Jabbar com Paul Atreides e Lady Jessica.
  - *Clean Code* (Robert C. Martin): Capítulos integrais sobre código limpo, nomenclatura significativa e funções pequenas.
  - *Neuromancer* (William Gibson): Chiba City, o bar Chatsubo, Molly Millions e a matriz ciberespacial.
  - *Dom Casmurro* (Machado de Assis): Texto integral de domínio público.
- Opções de leitura incluem:
  - 3 Temas minimalistas: OLED Dark puro (#121212 / #000000), Sepia (#24201B) e Night (#1E1E1E).
  - Controle tipográfico: Inter, Roboto, Merriweather, Open Dyslexic.
  - Ajuste dinâmico de tamanho de fonte e altura de linha.

### Quadrinhos (CBZ):
- O leitor de quadrinhos descompacta arquivos CBZ autênticos extraídos diretamente de exemplares históricos:
  - *Batman: Ano Um* (David Mazzucchelli & Frank Miller)
  - *Watchmen #07* (Dave Gibbons & Alan Moore)
  - *Sandman: Prelúdio #02* (J.H. Williams III & Neil Gaiman)
- 10 páginas reais completas por edição com balões, painéis e cores autênticas.
- Grade de miniaturas navegável e transição suave horizontal ou vertical.

---

## 3. Persistência de Progresso Concorrente

O progresso é persistido no SQLite **antes** da emissão de novo estado de página no BLoC. Isso assegura que se o usuário fechar o leitor, desligar o celular ou alternar de aplicativo imediatamente após virar a página, o progresso exato estará 100% gravado na tabela `reading_progress`.

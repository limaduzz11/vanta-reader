# NovaReader — Design System Specification
## Monochromatic Minimalism & Adaptive UI Shell (Fase C)

---

### 1. Visão Geral e Filosofia

O **NovaReader** adota uma identidade visual estritamente focada na imersão de leitura: **Monochromatic Minimalism**.
- **Foco Absoluto no Conteúdo:** A interface nunca compete visualmente com a capa, arte ou tipografia do livro ou quadrinho.
- **Conforto Visual e OLED:** Fundo verdadeiro dark mode (`#121212`) e superfície secundária (`#1E1E1E`), minimizando consumo de bateria em telas AMOLED e fadiga ocular.
- **Hierarquia Tipográfica Clara:** Alto contraste baseado em peso e luminância da escala de cinzas, sem uso de cores estridentes.
- **Local-First Indicativo:** Badges sutis e diretos para indicar obras armazenadas localmente vs. remotas.

---

### 2. Paleta de Cores Canônica (`NovaColors`)

| Token | Hex | Descrição / Uso |
|---|---|---|
| `background` | `#121212` | Fundo principal da aplicação |
| `surface` | `#1A1A1A` | Superfície base para cards, sheets e barras |
| `surfaceSecondary`| `#242424` | Superfície elevada / placeholders de capa |
| `surfaceTertiary` | `#2C2C2C` | Elementos de apoio e containers de chips inativos |
| `border` | `#2E2E2E` | Bordas e divisores estruturais padrão |
| `borderSubtle` | `#383838` | Bordas de badges e seletores sutis |
| `textPrimary` | `#E0E0E0` | Títulos, textos principais de alta ênfase |
| `textSecondary` | `#B0B0B0` | Autores, metadados secundários, descrições |
| `textMuted` | `#666666` | Placeholders, rótulos desabilitados, timestamps |
| `accent` | `#FFFFFF` | Ícones ativos, destaques primários |
| `highlight` | `#2A2A2A` | Efeito hover e ripple ao toque |
| `success` | `#81C784` | Indicador de download concluído (sutil) |
| `warning` | `#FFB74D` | Alertas e atenção de armazenamento |
| `error` | `#E57373` | Falhas de download e conexão |

---

### 3. Escala Tipográfica (`NovaTypography`)

Utiliza a fonte de sistema padrão Roboto / Noto Sans com excelente renderização em alta densidade de pixels:

- **Display Large:** 28px, Bold, `#E0E0E0` (Títulos de detalhes de obra)
- **Title Large:** 20px, Semi-Bold, `#E0E0E0` (Cabeçalhos de tela e app bars)
- **Title Medium:** 16px, Medium, `#E0E0E0` (Títulos de seções e cards de destaque)
- **Body Large:** 15px, Regular, `#E0E0E0` (Texto de leitura e inputs de busca)
- **Body Medium:** 14px, Regular, `#B0B0B0` (Sinopses e parágrafos descritivos)
- **Body Small:** 12px, Regular, `#B0B0B0` (Autores, formatos e metadados)
- **Caption:** 11px, Regular / Medium, `#666666` (Rótulos de cabeçalho e estatísticas)
- **Label Medium:** 12px, Semi-Bold, `#E0E0E0` (Chips, badges e botões compactos)

---

### 4. Dimensões, Espaçamentos e Formas

#### Espaçamentos (`NovaSpacing`)
- `xxs`: 2.0px | `xs`: 4.0px | `sm`: 8.0px | `md`: 16.0px | `lg`: 24.0px | `xl`: 32.0px
- `pagePadding`: `EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)`
- `cardPadding`: `EdgeInsets.all(16.0)` | `compactCardPadding`: `EdgeInsets.all(10.0)`

#### Formas (`NovaShapes`)
- `roundedSm`: 4.0px | `roundedMd`: 8.0px | `roundedLg`: 16.0px | `roundedFull`: 999.0px

#### Proporções Canônicas de Capa (`NovaDimensions`)
- **Livros (EPUB, PDF, TXT):** Aspect Ratio **2:3** (`bookCoverAspectRatio = 2.0 / 3.0`)
- **Quadrinhos e Mangás (CBZ, CBR):** Aspect Ratio **3:4** (`comicCoverAspectRatio = 3.0 / 4.0`)
- **Grid Card Aspect Ratio:** **0.50** (`gridCardAspectRatio = 0.50`), garantindo acomodação perfeita da capa e de 2 linhas de texto sem overflow em qualquer densidade.
- **Home Carousels:** `homeCarouselHeight = 265.0px`, `homeComicCarouselHeight = 285.0px`.

---

### 5. Arquitetura de Componentes

1. **`NovaBookCard` & `NovaComicCard`:**
   - Adaptação automática: quando em lista/carrossel horizontal aceitam largura fixa (`width: 135` / `145`), e quando em `GridView` preenchem a largura do grid mantendo a proporção exata da capa via `AspectRatio`.
   - Badges flutuantes no topo: formato do arquivo (EPUB, PDF, CBZ) e status de download offline (`download_done`).
   - Barra de progresso de leitura embutida na base da capa.

2. **`AdaptiveShellScaffold`:**
   - Detecta `constraints.maxWidth >= 720.0` (Tablet / Desktop).
   - Celulares utilizam `BottomNavigationBar` de 5 destinos (Início, Busca, Biblioteca, Downloads, Perfil).
   - Tablets e telas largas utilizam `NavigationRail` lateral contínuo com separador vertical.

3. **`NovaDeviceSimulator` (Ferramenta de Debug Linux Desktop):**
   - Executa no topo do shell quando compilado para Linux Desktop em modo debug.
   - Fornece um menu flutuante permitindo alternar visualmente entre:
     1. **Celular Android:** Dimensões 393 × 852 com bordas arredondadas e moldura física.
     2. **Tablet Android:** Dimensões 800 × 1200 com NavigationRail e moldura.
     3. **Responsivo (Tela Cheia):** Redimensionável livremente na janela Linux.
   - Desativação automática e transparente em testes automatizados (`FLUTTER_TEST`) e em builds de produção release.

4. **Componentes de Estado (`NovaStates`):**
   - `NovaLoadingState`: Indicador de progresso minimalista monocromático.
   - `NovaEmptyState`: Ilustração vetorial e mensagem descritiva de acervo vazio.
   - `NovaErrorState`: Mensagem de erro com botão de repetição (`Tentar Novamente`).
   - `NovaProgressBar`: Barra de progresso com trilha sutil para leitura e downloads.

---

### 6. Verificação e Testes de Regressão

- **Testes de Navegação (`test/presentation/navigation_test.dart`):**
  - Validação de alternância entre abas no celular (Início → Busca → Biblioteca → Downloads → Perfil).
  - Validação de renderização do `NavigationRail` e supressão do `BottomNavigationBar` em telas >= 720px.
- **Métricas:** 15/15 testes automatizados aprovados, 0 erros no `flutter analyze`.

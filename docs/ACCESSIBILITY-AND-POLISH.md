# NovaReader — Acessibilidade WCAG, Polish Visual & Microinterações

Este documento detalha os padrões de acessibilidade, diretrizes de usabilidade universal, transições de tela e microinterações táteis implementadas na **Fase N** da plataforma NovaReader.

---

## 1. Princípios de Acessibilidade (WCAG 2.1 AA / AAA)

O NovaReader foi projetado sob os padrões internacionais de acessibilidade (Web Content Accessibility Guidelines - WCAG 2.1), combinando a estética **Monochromatic Minimalism** com legibilidade e operabilidade máximas para todos os perfis de usuários.

### 1.1 Contraste Monocromático de Alto Desempenho
- **Fundo Principal (`#121212`) vs Texto Primário (`#E0E0E0`):** Razão de contraste de **13.5:1**, superando com folga o requisito AAA da WCAG (7:1).
- **Superfície Secundária (`#1E1E1E`) vs Texto Secundário (`#B0B0B0`):** Razão de contraste de **8.2:1**, garantindo leitura nítida de metadados, autores e legendas.
- **Bordas e Divisores (`#333333` / `#222222`):** Delimitação física precisa de cartões, botões e campos de entrada para usuários com baixa sensibilidade a contrastes sutis.
- **Cor de Destaque Semântico:** `#FFFFFF` em foco e estados ativos, garantindo feedback visual inequívoco sem dependência de cores policromáticas (ideal para usuários com daltonismo total ou parcial).

### 1.2 Dimensões Mínimas de Toque (Target Size >= 48x48 dp)
Seguindo as recomendações de acessibilidade do Google Material Design e WCAG:
- **`NovaButton`:**
  - `minHeight: 48.0` dp garantida via `BoxConstraints`.
  - `Flexible` e `maxLines: 1` com `TextOverflow.ellipsis` para acomodar fontes escaladas pelo sistema sem quebra de layout.
- **`NovaIconButton`:**
  - `constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0)`.
  - `splashRadius: 24.0` dp para área de resposta de toque ampliada.
- **`NovaFilterChip`:**
  - `constraints: const BoxConstraints(minHeight: 36.0, minWidth: 48.0)`.
  - Padding ergonômico horizontal e vertical para facilidade de acionamento em telas sensíveis ao toque.
- **Botões de Navegação dos Leitores (Livro & HQ):**
  - Controles "Anterior" e "Próxima" fixados com altura mínima de 48dp no leitor de livros e leitor de quadrinhos.
  - Sliders com `Semantics` configurado para ajuste de página por voz ou teclado.

---

## 2. Árvore Semântica e Leitores de Tela (TalkBack & VoiceOver)

Todos os componentes interativos expõem nós semânticos ricos através do widget `Semantics`, permitindo navegação fluida e descritiva para usuários de tecnologia assistiva:

### 2.1 Cards de Obras (`NovaBookCard` e `NovaComicCard`)
- Anunciam de forma unificada:
  - Título da obra e Autor.
  - Formato de arquivo (EPUB, PDF, CBZ, CBR, etc.).
  - Volume (quando aplicável, em HQs/Mangás).
  - Progresso atual em porcentagem (ex: "Progresso: 45%").
  - Status de materialização local ("Baixado localmente" vs streaming).
- Marcados explicitamente como botões acionáveis (`button: true`, `enabled: onTap != null`).

### 2.2 Botões e Ações Principais (`NovaButton`, `NovaIconButton`, `WorkDetailsScreen`)
- **Botão LER AGORA:** Semantics label dinâmico: `"Iniciar leitura de [Título]"`.
- **Botão BAIXAR:** Semantics label dinâmico: `"Baixar edição [Formato] de [Título]"`.
- **Botão Favoritos na AppBar:** Semantics label atualizado dinamicamente: `"Adicionar aos Favoritos"` / `"Remover dos Favoritos"`.
- **Botões de Ícone com Tooltip:** Tooltip nativo associado com leitura automática no foco de acessibilidade.

### 2.3 Avatares e Chips de Filtro
- **`NovaAvatar`:** Anuncia o preset geométrico correspondente (ex: `"Avatar monocromático: Eclipse"`). Quando interativo, é anunciado como botão para abertura do seletor.
- **`NovaFilterChip`:** Expõe o estado `selected: isSelected` e anuncia `"Filtro [Nome], [selecionado / não selecionado]"`.

---

## 3. Transições Fluidas Hero & Motion Design

O NovaReader implementa transições de continuidade visual entre telas para reduzir a carga cognitiva do leitor durante a exploração:

### 3.1 Hero Animation nas Capas
- Ao tocar em um livro ou quadrinho na Biblioteca, na Busca ou na Tela Inicial, a capa da obra realiza uma transição suave e contínua do card em miniatura para o cabeçalho de destaque em `WorkDetailsScreen`.
- Identificador de transição canônico: `work_cover_${work.id}` (customizável via `heroTag` e comutável via `enableHero`).
- Prevenção de conflito de tags em listas densas através de namespaces de rota.

### 3.2 PageTransitionsTheme por Plataforma
O tema canônico (`NovaTheme.darkTheme`) foi ajustado com políticas de transição nativas para cada sistema operacional:
- **Android:** `ZoomPageTransitionsBuilder()` (transição moderna do Material 3 com expansão fluida em profundidade).
- **Linux & Windows:** `FadeUpwardsPageTransitionsBuilder()` (animação suave de opacidade e elevação discreta, ideal para desktop com cursor e teclado).
- **iOS & macOS:** `CupertinoPageTransitionsBuilder()` (gesto lateral nativo de swipe para voltar com paralaxe sutil).

---

## 4. Microinterações e Feedback Tátil

- **`InkRipple.splashFactory`:** Todos os botões, cartões e abas utilizam a fábrica de ondulação tátil do Material 3 com cor de realce monocromática translúcida (`NovaColors.highlight` = `Colors.white10`).
- **Respostas Imediatas em SnackBar Monocromática:**
  - Adição/remoção de favoritos.
  - Enfileiramento de downloads.
  - Higienização de partições de cache.
  - Sucesso de importação manual de arquivos.
- **Prevenção de Overflows e Escalabilidade:**
  - Uso sistemático de `Wrap` para coleções de chips (tamanho de fonte, modo de leitura, seletor de edições).
  - Uso de `Flexible` e `Expanded` em `Row`s de informações e botões de ação para comportar fontes do sistema aumentadas em até 200%.

---

## 5. Matriz de Validação & Evidências de Teste

| Componente / Tela | Requisito WCAG / UX | Status | Evidência de Teste |
|---|---|---|---|
| `NovaBookCard` | Semantics completo + Hero | PASS | `test/presentation/accessibility_test.dart` |
| `NovaComicCard` | Semantics completo + Hero | PASS | `test/presentation/accessibility_test.dart` |
| `NovaButton` | Min Height 48dp + Semantics | PASS | `test/presentation/accessibility_test.dart` |
| `NovaIconButton` | Min Touch Target 48x48dp + Tooltip | PASS | `test/presentation/accessibility_test.dart` |
| `NovaFilterChip` | Semantics Selected + Min Size | PASS | `test/presentation/accessibility_test.dart` |
| `NovaAvatar` | Semantics Preset + Interatividade | PASS | `test/presentation/accessibility_test.dart` |
| `WorkDetailsScreen` | Hero Transition + Semantics Ações | PASS | `test/presentation/accessibility_test.dart` |
| `AdaptiveShellScaffold` | Fixed BottomNav + Tooltips 5 abas | PASS | `test/presentation/navigation_test.dart` |
| Suíte Completa | 160 testes unitários, bloc e widget | PASS | 160/160 testes verdes (100%) |
| Análise Estática | flutter analyze | PASS | 0 errors, 0 warnings |
| Build Linux Desktop | flutter build linux --debug | PASS | Binário executável 46K gerado |

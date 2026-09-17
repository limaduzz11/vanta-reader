# ADR-015: Accessibility (WCAG 2.1), Visual Polish and Semantic Navigation

- **Status:** Aceito
- **Data:** 2026-09-09
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase N — Polish Visual, Microinterações & Acessibilidade

---

### Contexto e Problema

Com a conclusão da arquitetura central, provedores externos, leitores de livro/quadrinho, downloads e gerenciamento de perfis locais (Fases A a M), o NovaReader necessitava de uma camada abrangente de refinamento e acessibilidade para assegurar:
1. **Conformidade WCAG 2.1:** Garantir contraste de altíssimo nível (>= 7:1 para AAA), alvos de toque ergonômicos (>= 48x48 dp) e navegação completa por leitores de tela (TalkBack no Android, VoiceOver no iOS e leitores desktop).
2. **Continuidade Visual (Hero Transitions):** Proporcionar transições espaciais fluidas entre a listagem de obras e a tela de detalhes sem sobressaltos visuais.
3. **Microinterações Táteis:** Fornecer feedback imediato e refinado para toques, gestos, seletores e alternâncias de estado, respeitando a identidade austera do tema monocromático.
4. **Resiliência a Font Scaling:** Assegurar que usuários com preferências de acessibilidade de fontes ampliadas (até 200%) não enfrentem quebras de layout (`RenderFlex overflow`).

---

### Decisões de Arquitetura

1. **Enriquecimento da Árvore Semântica (`Semantics`):**
   - **`NovaBookCard` & `NovaComicCard`:** Incorporação de nós semânticos descritivos que anunciam título, autor, formato da edição, volume da HQ, progresso percentual e estado de materialização local em uma única fala coesa para o leitor de tela.
   - **`NovaButton` & `NovaIconButton`:** Exposição de rótulos semânticos personalizados (`semanticsLabel` e `tooltip`), flags `button: true` e controle explícito de disponibilidade (`enabled: true/false`).
   - **`NovaFilterChip`:** Exposição do atributo `selected: isSelected` e rótulo declarativo para alternância de filtros.
   - **`NovaAvatar`:** Anúncio semântico do nome do preset monocromático em uso (`'Avatar monocromático: <label>'`).
   - **`WorkDetailsScreen`:** Anotações semânticas precisas nos botões primários ("Iniciar leitura de...", "Baixar edição...") e botão comutador de favoritos.

2. **Garantia de Área de Toque Mínima (Target Size >= 48dp):**
   - Imposição de restrições de layout mínimas (`minHeight: 48.0` e `minWidth: 48.0`) em todos os componentes de acionamento (`NovaButton`, `NovaIconButton`, controles dos leitores de tela).
   - Definição de `splashRadius: 24.0` e `constraints` em `IconButton`s para prevenir toques acidentais ou frustração motora.

3. **Motion Design Adaptativo & Hero Transitions:**
   - Implementação de animações `Hero` nas capas de livros e quadrinhos sincronizando os cartões de catálogo (`NovaBookCard`, `NovaComicCard`) com o cabeçalho de destaque em `WorkDetailsScreen`.
   - Adição dos parâmetros `heroTag` e `enableHero` para permitir namespaces de transição e desativação em contextos onde colisões de tag poderiam ocorrer.
   - Configuração de `PageTransitionsTheme` no tema global (`NovaTheme`):
     - Android: `ZoomPageTransitionsBuilder()`.
     - Linux & Windows: `FadeUpwardsPageTransitionsBuilder()`.
     - iOS & macOS: `CupertinoPageTransitionsBuilder()`.

4. **Microinterações Monocromáticas:**
   - Configuração de `InkRipple.splashFactory` no tema global com ondas táteis suaves em tom translúcido (`NovaColors.highlight`).
   - Uso de `SnackBar`s monocromáticas não invasivas para feedback de operações assíncronas.

5. **Layouts Anti-Overflow:**
   - Migração de `Row`s de seleção de chips para `Wrap` em todas as telas de configurações, leitor e preferências.
   - Aplicação de `Flexible` e `Expanded` em rótulos de texto de largura dinâmica para suportar escalonamento tipográfico do sistema operacional.

---

### Consequências

#### Positivas
- **Inclusão Universal:** O leitor de tela e navegação por teclado funcionam de ponta a ponta em todas as telas principais do aplicativo.
- **Experiência Premium:** As animações de Hero e transições nativas elevam a percepção de polimento e fluidez sem sobrecarregar a GPU.
- **Ergonomia Comprovada:** Todos os botões respeitam os padrões de toque recomendados para uso móvel e em tablets.
- **Robustez Estrutural:** 160 testes cobrindo unitários, bloc, widgets, semântica e ponta a ponta passam com 100% de sucesso.

#### Neutras / Compensações
- O uso de `Hero` exige atenção à unicidade das tags por rota para evitar alertas no log do Flutter (mitigado pela arquitetura com prefixo de ID `work_cover_${work.id}`).

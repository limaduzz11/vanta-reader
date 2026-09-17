# ADR-003: Design System Monochromatic Minimalism & Adaptive Shell

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase C — Design System & UI Shell

---

### Contexto e Problema

O NovaReader é uma aplicação voltada para leitura imersiva de livros e histórias em quadrinhos em dispositivos Android (telefones e tablets). Aplicações convencionais frequentemente pecam por poluição visual, paletas de cores saturadas que cansam a visão durante horas contínuas de leitura e interfaces rígidas que não se adaptam à mudança de orientação ou formatos maiores de tela (tablets dobráveis ou convencionais).
Adicionalmente, o ambiente de desenvolvimento principal no host Pop!_OS 24.04 exige uma forma rápida e sem atritos de validar layout de smartphone e tablet sem a lentidão pesada de emuladores completos QEMU Android.

---

### Decisões de Arquitetura

1. **Monochromatic Minimalism:**
   - Paleta escura baseada em OLED True Dark (`#121212`), superfícies em tons sutis de cinza (`#1A1A1A`, `#242424`) e tipografia de alto contraste (`#E0E0E0` e `#B0B0B0`).
   - Apenas cores semânticas funcionais muito discretas são permitidas (`#81C784` para downloads locais concluídos, `#FFB74D` para alertas e `#E57373` para falhas).
   - O conteúdo do autor (capa, arte, ilustrações) é o único elemento colorido permitido a brilhar na tela.

2. **Proporções Canônicas e Layout Adaptativo:**
   - Capas de livros travadas na proporção editorial canônica `2:3` (`bookCoverAspectRatio = 2.0 / 3.0`).
   - Capas de quadrinhos e mangás travadas na proporção canônica `3:4` (`comicCoverAspectRatio = 3.0 / 4.0`).
   - Cards de grade utilizam `gridCardAspectRatio = 0.50`, permitindo acomodação de capa e metadados com folga ergonômica sem risco de overflow.
   - Shell adaptativo (`AdaptiveShellScaffold`): largura `< 720px` utiliza `BottomNavigationBar`; largura `>= 720px` migra fluidamente para `NavigationRail` lateral contínuo.

3. **Simulador de Dispositivos Embutido (`NovaDeviceSimulator`):**
   - Um wrapper visual inteligente ativo exclusivamente em modo debug desktop Linux (`Platform.isLinux && kDebugMode`).
   - Permite ao desenvolvedor alternar com 1 clique entre visualização de Celular Android (393 × 852), Tablet Android (800 × 1200) e Responsivo Desktop, com moldura física e sombras.
   - Em testes automatizados e builds de release, é completamente transparente (retorna diretamente o `child`).

---

### Consequências

- **Positivas:**
  - Redução drástica da fadiga ocular do leitor.
  - Otimização extrema de bateria em telas OLED/AMOLED.
  - Eficiência total no ciclo de testes e depuração de UI no Linux Desktop, sem necessidade de carregar emulador Android para testar responsividade de telas.
  - Zero duplicação de layouts entre celular e tablet; responsividade intrínseca via Flutter layout engine.
- **Negativas / Mitigações:**
  - Exige rigor na disciplina de design: desenvolvedores não devem introduzir cores arbitrárias fora dos tokens de `NovaColors`.

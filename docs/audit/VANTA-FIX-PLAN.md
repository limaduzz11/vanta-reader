# VANTA Reader — Plano de Correção e Hardening (VANTA-FIX-PLAN)

**Data:** 2026-09-09  
**Classificação de Severidade:**  
- **P0:** Crash / Corrupção / Perda de conteúdo / Contaminação de dados.  
- **P1:** Funcionalidade principal quebrada ou ausente.  
- **P2:** Problema de UX / Visual / Navegação.  
- **P3:** Polish / Refinamento.  

---

## Tabela de Ações e Correções

| ID | Bug / Funcionalidade | Severidade | Causa Raiz | Arquivos Afetados | Solução Proposta | Status | Teste de Validação |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **FIX-01** | Injeção de 6 obras mock na Library de produção | **P0** | `injection.dart` chamando `SeedInitialCatalogUseCase` no startup. | `lib/injection.dart`<br>`lib/data/repositories/library_repository.dart` | Remover chamada de seed no bootstrap de produção e expurgar seed não baixado da estante. | **PLANEJADO** | `test/presentation/library_bloc_test.dart` e verificação no app real. |
| **FIX-02** | BottomNav do app visível dentro do Leitor | **P1** | Leitor empurrado dentro do branch do `StatefulShellRoute`. | `lib/presentation/screens/work_details_screen.dart` | Usar `Navigator.of(context, rootNavigator: true).push` com `fullscreenDialog: true`. | **PLANEJADO** | Teste manual no dispositivo e widget test de navegação. |
| **FIX-03** | Barras do leitor sobrepondo o conteúdo ao abrir | **P2** | `areControlsVisible` iniciava como `true` e offset de ocultação inferior era curto (-90px). | `lib/presentation/blocs/book_reader/book_reader_state.dart`<br>`lib/presentation/blocs/comic_reader/comic_reader_state.dart`<br>`lib/presentation/screens/reader/book_reader_screen.dart`<br>`lib/presentation/screens/reader/comic_reader_screen.dart` | Iniciar `areControlsVisible = false`; aumentar offset para -160px; toque central alterna barras. | **PLANEJADO** | Teste de widget verificando visibilidade inicial e transição pós-toque. |
| **FIX-04** | Busca por "vingadores", "pai rico pai pobre" desordenada ou lenta | **P1** | Query `q=` genérica escaneando OCR e comparação sem normalização de pontuação/hífen. | `lib/data/datasources/providers/open_library_content_provider.dart`<br>`lib/core/providers/provider_manager.dart` | Otimizar query na OpenLibrary para priorizar títulos; aplicar `removeDiacritics` e pontuação no ranking. | **PLANEJADO** | Matriz de 9 termos de busca (`test/domain/usecases/search_online_catalog_usecase_test.dart`). |
| **FIX-05** | Idioma do perfil não influenciava o ranking da busca | **P1** | `SearchBloc` não recebia `UserProfile` e não passava `preferredLanguage` ao `searchCatalog`. | `lib/presentation/blocs/search/search_bloc.dart`<br>`lib/injection.dart` | Injetar `GetUserProfileUseCase` no `SearchBloc` e repassar idioma ao `ProviderManager`. | **PLANEJADO** | Testes de busca alternando idioma entre `pt-BR` e `en`. |
| **FIX-06** | "Quadrinhos em Destaque" com apenas 1 título | **P1** | Endpoint `subjects/comics_graphic_novels.json` continha apenas 1 item no índice externo. | `lib/data/datasources/providers/open_library_content_provider.dart` | Migrar para `subjects/graphic_novels.json` e `superheroes.json` com múltiplas HQs reais. | **PLANEJADO** | Teste de retorno da Home com verificação de >= 5 quadrinhos com capa. |
| **FIX-07** | Simulador de dispositivo Desktop visível no celular | **P2** | `NovaDeviceSimulator` com detecção de plataforma frouxa. | `lib/presentation/design_system/nova_device_simulator.dart` | Desativar estritamente quando rodando em Android/iOS ou release. | **PLANEJADO** | Verificação visual no Samsung Galaxy A36. |
| **FIX-08** | Estado vazio da biblioteca sem ação clara | **P2** | Estado vazio genérico sem direcionamento. | `lib/presentation/screens/library_screen.dart` | Exibir mensagem *"Nenhuma obra adicionada ainda"* e botões para buscar ou importar. | **PLANEJADO** | Widget test de EmptyState da Library. |

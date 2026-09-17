# VANTA Reader — Auditoria Funcional de Comportamento Real (Fase 2)

**Data:** 2026-09-09  
**Dispositivo Físico de Teste:** Samsung Galaxy A36 (Android 16, ARM64)  
**Metodologia:** Execução nativa no dispositivo via ADB, inspeção de Logcat e testes instrumentados.

---

## 1. Matriz de Auditoria por Módulo Funcional

| Módulo / Tela | Comportamento Real Observado | Status | Problemas Detectados | Evidência / Diagnóstico |
| :--- | :--- | :--- | :--- | :--- |
| **HOME** | Carrega carrossel de Livros Populares via OpenLibrary API com capas reais e títulos dinâmicos. Carrossel de Quadrinhos exibia apenas 1 item ("Drama"). | FUNCIONA PARCIALMENTE | Seção de quadrinhos desbalanceada devido a limitação do slug consultado. | Logcat registra requisições 200 OK para `trending/daily.json`, mas endpoint de HQs retornava `work_count: 1`. |
| **SEARCH** | Digitação com debounce funciona. Requisições são enviadas para OpenLibrary. Buscas por "vingadores", "homem aranha", "pai rico pai pobre" retornavam resultados desordenados ou com OCR de baixa relevância ("Seduced by the Sultan"). | FUNCIONA PARCIALMENTE | Falha de ordenação fonética, ausência de filtro de idioma do perfil e queries lentas com `q=`. | Query genérica `q=` na OpenLibrary varre texto completo de 50M de edições; falta priorização estrita de título e idioma. |
| **LIBRARY** | Apresenta obras na estante com capas e badges. Ao instalar o app em dispositivo limpo, 6 obras prévias apareciam automaticamente. | DADOS INCORRETOS (MOCK) | Contaminação por `SeedInitialCatalogUseCase`. A biblioteca não refletia apenas as ações do usuário. | O SQLite executava o seed mock na primeira inicialização, violando a exigência de biblioteca limpa. |
| **DOWNLOADS** | Fila de downloads gerencia tarefas ativas, concluídas e pausadas. Baixa arquivos para `/books` e `/comics`. | FUNCIONA | Nenhum erro funcional de fila ou gravação em disco. | Testes unitários e e2e cobrem 100% dos fluxos de download resiliente. |
| **PROFILE** | Exibe estatísticas de leitura, uso de armazenamento dividido por categorias (livros, HQs, capas, banco, cache) e botão de limpar cache. Permite editar nome, avatar e idioma. | FUNCIONA | Mudança de idioma para 'pt-BR' ou 'en' salvava no banco, mas o BLoC de busca não consumia esse valor. | `UserProfile` persistido no SQLite na tabela `profiles`. |
| **BOOK READER** | Abre arquivos EPUB e sessões de streaming. Renderiza capítulos com tipografia minimalista, ajuste de fonte, entrelinha e temas OLED/Sepia/Night. | FUNCIONA PARCIALMENTE | 1) A BottomNavigationBar da aplicação ficava visível embaixo. 2) As barras de controles abriam visíveis por padrão e não ocultavam totalmente da tela. | Rota empurrada dentro do `AdaptiveShellScaffold`; `areControlsVisible` default `true`; offset inferior insuficiente. |
| **COMIC READER** | Abre arquivos CBZ e imagens de alta resolução com paginação, zoom e miniatura de páginas. | FUNCIONA PARCIALMENTE | Mesmos dois problemas de interface do leitor de livros: falta de imersão tela cheia e barras visíveis no início. | Navegação não utilizava `rootNavigator: true`; barras ocupavam a visualização da primeira página. |
| **SETTINGS** | Integradas dentro do Perfil (tamanho de fonte padrão, modo contínuo/paginado, downloads simultâneos, limpeza de cache). | FUNCIONA | Totalmente funcional e responsivo. | Valores aplicados de forma persistente. |

---

## 2. Diagnóstico das Prioridades de Correção Imediata

1. **Eliminar o Seed Mock da Produção:** A biblioteca inicial deve ser estritamente vazia (EMPTY STATE), com botão de ação direta para buscar obras.
2. **Reestruturar o Roteamento dos Leitores:** Tanto o `BookReaderScreen` quanto o `ComicReaderScreen` devem ser abertos com `rootNavigator: true` e `fullscreenDialog: true`, com controles ocultos por padrão (`areControlsVisible = false`), revelando-se apenas mediante toque do usuário no centro da tela.
3. **Corrigir a Cadeia de Busca e Ranking de Idioma:** Conectar o idioma do Perfil (`pt-BR` ou `en`) ao mecanismo de ranking ponderado, com normalização de pontuação, acentuação e correspondência exata.
4. **Expandir Quadrinhos em Destaque:** Enriquecer a fonte da Home com `graphic_novels.json` e `superheroes.json` para exibir uma lista real de HQs autênticas com capas oficiais.

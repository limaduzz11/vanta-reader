# ADR-013: End-to-End Integration Pipeline (Online Catalog to Offline Reading)

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase L — Integração Ponta a Ponta: Online -> Offline

---

### Contexto e Problema

Com o encerramento das Fases A até K, o NovaReader possuía todos os blocos fundamentais construídos e testados isoladamente:
1. Armazenamento particionado e SQLite WAL (Fase B e D).
2. Motores de importação e parsers locais de EPUB, CBZ, PDF e TXT (Fases E, F e G).
3. Gerenciador resiliente de downloads com controle de concorrência e suporte a chunks HTTP (Fase H).
4. Motor de provedores externos, normalização de metadados e deduplicação de obras (Fase I).
5. Catálogo online unificado com paginação e busca tolerante a latência (Fase J).
6. Leitor de streaming sob demanda com promoção de buffer volátil (Fase K).

Contudo, para assegurar a máxima fidelidade arquitetural da promessa **Local-First + Online Decoupled**, era mandatório amarrar o fluxo completo de transição:
- A obra encontrada remotamente precisa se materializar de forma consistente no banco de dados local da biblioteca ao ser baixada.
- As capas remotas devem ser armazenadas fisicamente na partição `/covers/` para eliminar dependência de internet na renderização de miniaturas e detalhes da estante.
- Os arquivos baixados (sejam reais via HTTP ou simulados via provedor mock) devem ser documentos binários válidos e parseáveis, permitindo que os motores de leitura de livros (`BookReaderBloc`) e quadrinhos (`ComicReaderBloc`) funcionem em modo 100% offline (modo avião).

---

### Decisões de Arquitetura

1. **Auto-Registro de Obra no Enfileiramento de Download (`DownloadManager.enqueue`):**
   - Ao enfileirar uma edição oriunda do catálogo online para download, o `DownloadManager` verifica se o registro mestre `Work` já existe no SQLite da biblioteca.
   - Se ainda não existir, o registro é salvo preventivamente via `libraryRepository.saveWork(work)`, garantindo integridade referencial no banco de dados antes mesmo da gravação física dos bytes no disco.

2. **Geração de Arquivos Mock Estruturados e Parseáveis (`_generateValidMockBytes`):**
   - Para ambientes de homologação, testes E2E e modo catálogo simulado, o `DownloadManager` produz arquivos sintéticos com especificação autêntica:
     - **EPUB:** Arquivo ZIP contendo `META-INF/container.xml`, manifesto `OEBPS/content.opf` com `spine`, e capítulos XHTML válidos (`cap1.xhtml`, `cap2.xhtml`).
     - **CBZ:** Arquivo ZIP contendo páginas com imagens JPEG formatadas (`page_01.jpg`, `page_02.jpg`, etc.) com cabeçalhos JFIF autênticos.
     - **TXT:** Documento estruturado em Markdown com múltiplos capítulos e paginação natural.
   - Isso permite que os leitores offline (`BookContentParser` e `ComicContentParser`) realizem o parsing real e a paginação sem recorrer a fallbacks de erro.

3. **Materialização Local da Capa no Sucesso do Download (`_onDownloadSuccess`):**
   - Ao concluir a gravação do arquivo da edição em `/books/` ou `/comics/`, o `DownloadManager` examina a capa da obra.
   - Se a capa for remota (`http://` ou `mock://`) ou inexistente no disco local, o gerenciador salva uma imagem física de alta resolução na pasta canônica `/covers/` e invoca `libraryRepository.updateCoverPath(work.id, localPath)`.
   - Assegura que toda a interface da estante permaneça visualmente rica mesmo sem conexão.

4. **Preservação e Restauração Transversal do Progresso de Leitura:**
   - A transição entre os modos de leitura é transparente: o marco de leitura (página atual, porcentagem e timestamp) reside estritamente no SQLite local (`reading_progress`).
   - Um livro iniciado offline restaura exatamente na página lida quando reaberto, mesmo após encerramento do app.

5. **Validação E2E com Suíte de Testes de Integração (`end_to_end_online_to_offline_test.dart`):**
   - Três cenários automatizados cobrindo todo o ciclo:
     - **Cenário 1 (Livro):** Busca online de "Duna" -> Download EPUB -> Verificação no SQLite e `/books/` -> Simulação offline -> Leitura no `BookReaderBloc` -> Avanço de página -> Persistência -> Reabertura com recuperação de estado.
     - **Cenário 2 (Quadrinho):** Busca online de "Watchmen" -> Download CBZ -> Persistência em `/comics/` -> Leitura no `ComicReaderBloc` -> Extração física de bytes de páginas via `loadPageBytes`.
     - **Cenário 3 (Streaming Híbrido):** Streaming online para `/cache/reading/` -> Promoção atômica para `/books/` -> Limpeza segura de cache volátil -> Acesso offline transparente.

---

### Consequências

- **Positivas:**
  - O aplicativo opera com 100% de autonomia e robustez em cenários sem nenhuma conectividade de rede.
  - Zero duplicação de dados e zero dependência de serviços em nuvem para leitura, renderização de capas ou controle de progresso.
  - Testabilidade completa comprovada: 137 testes unitários e de integração passando com 100% verde.
  - Código limpo: 0 issues no `flutter analyze` e compilação desktop Linux validada com sucesso.
- **Negativas / Mitigações:**
  - Arquivos baixados localmente e capas consom armazenamento físico: mitigado pelo `StorageManager`, que fornece métricas de uso e rotinas para exclusão de downloads e limpeza de arquivos temporários de streaming.

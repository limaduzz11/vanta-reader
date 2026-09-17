# NovaReader — Integração Ponta a Ponta: Online -> Offline (Fase L)

O módulo de **Integração Ponta a Ponta** amarra de forma conclusiva e verificável todos os subsistemas previamente construídos no NovaReader: desde a descoberta no catálogo online via múltiplos provedores até a materialização física dos arquivos em disco e a leitura autônoma 100% desconectada (modo avião), respeitando as premissas de **Local-First** e **Monochromatic Minimalism**.

---

## 1. Topologia do Pipeline Integrado

```mermaid
flowchart LR
    A["Busca Unificada<br/>(SearchOnlineCatalogUseCase)"] --> B["Seleção de Edição<br/>(EPUB / CBZ / TXT / PDF)"]
    B --> C["Gerenciador de Downloads<br/>(DownloadManager)"]
    C --> D["Auto-Registro no SQLite<br/>(LibraryRepository.saveWork)"]
    D --> E["Gravação de Chunks / Partição Segura<br/>(/books/ ou /comics/)"]
    E --> F["Materialização Local de Capa<br/>(/covers/ e updateCoverPath)"]
    F --> G["Marcação isLocal = true<br/>Status 'downloaded'"]
    G --> H["Modo Offline / Sem Rede<br/>(BookReaderBloc / ComicReaderBloc)"]
    H --> I["Leitura Fluida & Progresso Salvo<br/>(reading_progress no SQLite)"]
```

---

## 2. Subsistemas Integrados

| Componente | Responsabilidade no Pipeline |
| :--- | :--- |
| `SearchOnlineCatalogUseCase` | Executa pesquisa federada nos provedores ativos, normaliza metadados e deduplica obras por identidade (`workKey`). |
| `DownloadManager` | Fila persistente, controle de concorrência máxima (2 tasks), escrita incremental de chunks (`.part` -> arquivo final). |
| `StorageManager` | Particionamento físico estrito: `/books/`, `/comics/`, `/covers/`, `/thumbnails/`, `/cache/reading/` com barreira anti-Path Traversal. |
| `LibraryRepository` | Persistência Local-First via SQLite WAL. Atualiza metadados, caminhos físicos e flags de disponibilidade local. |
| `BookReaderBloc` / `ComicReaderBloc` | Motores de renderização e paginação que consom diretamente os arquivos físicos sem qualquer dependência de rede. |
| `OnlineReadingManager` | Modo híbrido que permite transição de streaming volátil para armazenamento permanente via `promoteToLocal`. |

---

## 3. Garantias e Comportamentos Verificados

### 3.1 Auto-Registro de Obra e Integridade no SQLite
Ao enfileirar um download de uma obra oriunda de provedor online (`downloadManager.enqueue`), o sistema verifica a presença da obra no repositório local. Se ausente, a entidade `Work` e suas edições são salvas preventivamente no banco, eliminando race conditions ou órfãos na estante.

### 3.2 Materialização Local e Física de Capas
No término com sucesso de qualquer download (`_onDownloadSuccess`):
1. O arquivo `.part` é renomeado atomicamente para o caminho definitivo.
2. A capa remota é resolvida e gravada fisicamente em `/covers/`.
3. O caminho definitivo em disco é associado à obra no banco (`libraryRepository.updateCoverPath`).
4. Toda a navegação posterior na biblioteca opera 100% offline, sem placeholders vazios ou requisições HTTP silenciosas.

### 3.3 Geração de Arquivos Mock Estruturados
Para validação em ambientes de testes e modo de desenvolvimento offline:
- **EPUB:** Constrói um container ZIP em conformidade com o padrão IDPF (META-INF, content.opf, manifest, spine e capítulos XHTML).
- **CBZ:** Constrói um container ZIP contendo imagens JPEG formatadas ordenadas naturalmente (`page_01.jpg`, `page_02.jpg`, etc.).
- **TXT:** Documento estruturado em seções e capítulos legíveis.

### 3.4 Isolamento Total de Rede e Persistência de Leitura
Os testes comprovam que, uma vez concluído o download:
1. Os BLoCs de leitura operam exclusivamente sobre o arquivo no disco.
2. Os parsers (`BookContentParser` e `ComicContentParser`) extraem o texto e as imagens reais do arquivo baixado.
3. O progresso de leitura (página atual, capítulo, porcentagem) é salvo no SQLite local e restaurado fielmente ao reabrir o app, mesmo após encerramento completo do processo.

---

## 4. Cobertura da Suíte E2E

A suíte `test/integration/end_to_end_online_to_offline_test.dart` cobre os 3 cenários fundamentais:

1. **Cenário 1: Livro (EPUB)**
   - Busca online por "Duna" -> Download do EPUB -> Validação no disco (`/books/`) e no SQLite (`isDownloaded == true`) -> Capa em `/covers/` -> Abertura no `BookReaderBloc` desconectado -> Avanço de página -> Fechamento do bloco -> Reabertura com restauração exata da página no SQLite.

2. **Cenário 2: Quadrinho (CBZ)**
   - Busca online por "Watchmen" -> Download do CBZ -> Validação em `/comics/` -> Abertura no `ComicReaderBloc` -> Extração física de bytes de imagem via `loadPageBytes` a partir do CBZ local -> Navegação de páginas.

3. **Cenário 3: Fluxo Híbrido (Streaming -> Promoção Atômica)**
   - Início de leitura via streaming sob demanda em `/cache/reading/` -> Chamada de promoção `promoteToLocal` -> Movimentação atômica para `/books/` -> Limpeza do cache volátil (`clearReadingCache`) sem afetar o arquivo permanente -> Próxima sessão abre instantaneamente como `ReadingSource.local`.

---

## 5. Auditoria de Qualidade e Governança

- **Testes Automatizados:** 137 testes unitários e de integração (100% passando verde).
- **Análise Estática (`flutter analyze`):** 0 issues (zero erros, zero warnings).
- **Compilação Desktop (`flutter build linux --debug`):** Compilação bem-sucedida do executável nativo.

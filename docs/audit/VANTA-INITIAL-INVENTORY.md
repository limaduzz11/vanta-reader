# VANTA Reader — Inventário Inicial do Projeto (Fase 0)

**Data da Auditoria:** 2026-09-09  
**Produto:** VANTA Reader (Desenvolvido por VANTA Labz)  
**Ambiente:** Flutter 3.x / Dart 3.x / Linux / Android (Galaxy A36)  
**Objetivo:** Mapeamento exaustivo de todos os componentes, módulos, dependências e status de implementação real vs. mock.

---

## 1. Mapeamento de Estrutura de Diretórios e Módulos

```
vantareader/
├── android/                   # Configuração nativa Android (Gradle, Manifest, NDK)
├── assets/                    # Assets estáticos (ícones, fontes, quadrinhos de exemplo)
│   ├── icon/                  # Ícone oficial VANTA Reader
│   ├── sample_comics/         # Páginas reais CBZ (Batman, Watchmen, Sandman)
│   └── branding/              # Logotipos oficiais VANTA Labz
├── docs/                      # Especificações arquiteturais e documentação de engenharia
│   └── audit/                 # Relatórios de auditoria e planos de correção
├── lib/
│   ├── core/                  # Engine transversal, banco, storage, parsing, providers
│   │   ├── database/          # SQLite via sqflite, schemas, migrations
│   │   ├── download/          # DownloadManager resiliente com fila e retry
│   │   ├── errors/            # Tratamento unificado de exceções (NovaException)
│   │   ├── import/            # Extratores de metadados locais (EPUB, CBZ, PDF, TXT)
│   │   ├── logging/           # Sistema estruturado de logging categorizado
│   │   ├── network/           # Cliente HTTP centralizado via Dio
│   │   ├── providers/         # Orquestrador, normalizador e registro de provedores
│   │   ├── reader/            # Parsers de EPUB e CBZ, sessões de streaming
│   │   ├── security/          # Criptografia local e cofre seguro
│   │   ├── storage/           # Gerenciador de diretórios no disco local
│   │   ├── theme/             # Design System Monochromatic Minimalism
│   │   └── utils/             # Identidade canônica de obras
│   ├── data/                  # Implementações concretas de repositórios e datasources
│   │   ├── datasources/       # MockData e Provedores Online (OpenLibrary)
│   │   └── repositories/      # LibraryRepository, DownloadRepository, ProfileRepository
│   ├── domain/                # Entidades puras de negócio, interfaces e UseCases
│   │   ├── entities/          # Work, WorkEdition, UserProfile, DownloadItem, Progress
│   │   ├── repositories/      # Interfaces abstratas dos repositórios
│   │   └── usecases/          # Casos de uso de domínio
│   ├── presentation/          # Camada de apresentação e interface com usuário
│   │   ├── blocs/             # BLoCs (Search, Library, Reader, Downloads, Profile, Details)
│   │   ├── design_system/     # Componentes visuais minimalistas e estados
│   │   ├── navigation/        # Roteador canônico GoRouter
│   │   └── screens/           # Telas do aplicativo
│   └── injection.dart         # Injeção de dependências via GetIt
└── test/                      # Suíte de testes automatizados (unitários, blocs, e2e)
```

---

## 2. Inventário de Componentes e Status

| Componente | Módulo / Arquivo | Status | Real / Mock / Parcial | Risco | Problemas Identificados | Dependências | Ação Necessária |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Banco SQLite** | `core/database/app_database.dart` | IMPLEMENTED | REAL | Baixo | Suporte a WAL, FK ativas, índices criados. | `sqflite` | Manter schema v3; auditar limpeza de dados seed. |
| **Semeamento Inicial** | `domain/usecases/seed_initial_catalog_usecase.dart` | DEPRECATED | MOCK | Crítico | Injeta 6 obras mock no SQLite em todo startup do app. | `MockData` | Desativar do runtime de produção; isolar apenas para testes. |
| **Download Manager** | `core/download/download_manager.dart` | IMPLEMENTED | REAL | Médio | Fila resiliente funcional, controle de concorrência e retry. | `Dio`, `StorageManager` | Validar timeouts e recuperação de falha de rede. |
| **Storage Manager** | `core/storage/storage_manager.dart` | IMPLEMENTED | REAL | Baixo | Estrutura de diretórios `/books`, `/comics`, `/covers`, `/cache`. | `path_provider` | Totalmente validado e funcional. |
| **Parser EPUB** | `core/reader/book_content_parser.dart` | IMPLEMENTED | REAL | Baixo | Parseia arquivos EPUB reais e extrai capítulos XHTML. | `archive`, `xml` | Totalmente validado. |
| **Parser CBZ** | `core/reader/comic_content_parser.dart` | IMPLEMENTED | REAL | Baixo | Descompacta arquivos ZIP/CBZ e extrai imagens JPG/PNG. | `archive` | Totalmente validado. |
| **Online Reading Mgr** | `core/reader/online_reading_manager.dart` | PARTIAL | REAL/FALLBACK | Médio | Streaming funcional; gera buffer local caso endpoint falhe. | `NetworkClient` | Expandir fontes para downloads diretos completos. |
| **Provedor OpenLibrary** | `data/datasources/providers/open_library_content_provider.dart` | PARTIAL | REAL | Alto | Busca lenta com `q=`; HQs em destaque retornava só 1 título. | `openlibrary.org` | Otimizar query para `title=`, enriquecer HQs via `graphic_novels`. |
| **Mock Provider** | `data/datasources/providers/mock_content_provider.dart` | IMPLEMENTED | MOCK | Baixo | Provedor de teste registrado. | Nenhum | Manter desabilitado ou restrito ao ambiente de teste. |
| **Work Identity** | `core/providers/work_identity_system.dart` | IMPLEMENTED | REAL | Baixo | Deduplicação por ISBN e slug difuso (Levenshtein). | Nenhum | Refinar pontuação para priorizar idioma preferido. |
| **Search BLoC** | `presentation/blocs/search/search_bloc.dart` | PARTIAL | REAL | Alto | Não consome o idioma configurado no perfil do usuário. | `SearchUseCase` | Integrar com `UserProfile.preferredLanguage`. |
| **Search Screen** | `presentation/screens/search_screen.dart` | IMPLEMENTED | REAL | Médio | Input com debounce de 300ms, chips de filtro. | `SearchBloc` | Conectar chips de idioma ao perfil e exibir fallback explícito. |
| **Home Screen** | `presentation/screens/home_screen.dart` | IMPLEMENTED | REAL | Médio | Populares da OpenLibrary funcionam; HQs mostravam só 1 obra. | `OpenLibraryProvider` | Expandir lista de quadrinhos em destaque. |
| **Library Screen** | `presentation/screens/library_screen.dart` | PARTIAL | MOCK/REAL | Alto | Exibia dados semeados automaticamente pelo `MockData`. | `LibraryBloc` | Remover seeds artificiais; exibir estado de biblioteca vazia. |
| **Book Reader UI** | `presentation/screens/reader/book_reader_screen.dart` | PARTIAL | REAL | Alto | Botões de navegação não ocultavam 100%; shell visível embaixo. | `BookReaderBloc` | Puxar via `rootNavigator: true`; ocultar barras em modo leitura. |
| **Comic Reader UI** | `presentation/screens/reader/comic_reader_screen.dart` | PARTIAL | REAL | Alto | Mesma questão de barras sobrepostas e shell persistente. | `ComicReaderBloc` | Puxar via `rootNavigator: true`; ocultar barras até toque na tela. |
| **Profile Screen** | `presentation/screens/profile_screen.dart` | IMPLEMENTED | REAL | Médio | Permite alterar idioma (pt-BR / en) e avatar. | `ProfileBloc` | Garantir que mudança de idioma reflita imediatamente na busca. |
| **Device Simulator** | `presentation/design_system/nova_device_simulator.dart` | DEPRECATED | PROTOTYPE | Médio | Toolbar no topo atrapalhava visualização no dispositivo móvel. | Nenhum | Desativar completamente em Android/produção. |
| **Roteador** | `presentation/navigation/app_router.dart` | IMPLEMENTED | REAL | Médio | StatefulShellRoute com 5 abas. | `go_router` | Suportar rotas em tela cheia fora do shell para leitores. |

---

## 3. Resumo de Riscos e Gaps

1. **Grave risco de contaminação por dados de teste:** A inicialização do banco injetava registros mock na tabela de biblioteca do usuário em todo ciclo de vida.
2. **Fragilidade de busca em termos genéricos:** Termos como "vingadores" ou "homem aranha" dependiam de queries não otimizadas que sofriam timeouts ou resultados desordenados na OpenLibrary.
3. **Seção de HQs deficiente:** O endpoint `subjects/comics_graphic_novels.json` continha apenas 1 título registrado no índice da API externa.
4. **UX do leitor prejudicada por barras fixas:** A barra de navegação principal da aplicação ficava visível durante a leitura, violando a imersão de tela cheia.

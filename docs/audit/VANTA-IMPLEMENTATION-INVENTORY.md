# VANTA Reader — Matriz de Implementação Inicial

**Data:** 2026-09-09  
**Estado:** pré-build e pré-correção. Status baseados em leitura estática; serão atualizados por runtime/testes.

| Feature | Status | Real/Mock | Arquivos principais | Testes atuais | Dependências | Problemas | Prioridade |
|---|---|---|---|---|---|---|---|
| Bootstrap/DI | PARTIAL | Real+Mock | `lib/main.dart`, `lib/injection.dart` | navegação/integração | GetIt | Mock provider registrado no runtime; splash fora do fluxo | P1 |
| Home — livros | PARTIAL | Real+Mock | `home_screen.dart`, Open Library, `mock_data.dart` | cobertura insuficiente | ProviderManager | fallback silencioso para mock | P1 |
| Home — HQs | BROKEN | Real+Mock | `home_screen.dart`, Open Library | cobertura insuficiente | provider externo | sem origem comic confiável; itens mock | P0 |
| Continuar lendo | MOCK | Mock | `home_screen.dart` | ausente | — | Duna e 21% fixos | P0 |
| Search input/debounce | PARTIAL | Real | `search_screen.dart`, `search_bloc.dart` | debounce desativado em teste | BLoC | cancelamento/rede real não comprovados | P1 |
| Search providers | PARTIAL | Real+Mock | `provider_manager.dart`, providers | majoritariamente mocks | Dio | mock contamina produção; provider failure parcialmente coberto | P0 |
| Search idioma/ranking | PARTIAL | Real | Search BLoC/manager/identity | matriz mock | perfil | idioma não governa toda cadeia; paginação rededup ausente | P0 |
| Identidade Work | PARTIAL | Real | `work.dart`, dois identity systems | unitários | normalizer/import | duas chaves incompatíveis; `REPLACE` destrutivo | P0 |
| Edition | PARTIAL | Real | `work.dart`, normalizer | indiretos | provider/DB | mistura edição e asset; externalId perdido | P0 |
| ContentAsset | MISSING | — | ausente | ausente | — | não há identidade própria de conteúdo | P0 |
| Details | PARTIAL | Real | `work_details_screen.dart`, BLoC morto | insuficiente | getIt/repo | UI acessa dados/UseCase diretamente | P0 |
| Metadata Open Library | PARTIAL | Real+inventada | provider Open Library | só erro/capabilities | API pública | formato, tamanho, páginas e autores podem ser inventados | P0 |
| Metadata Gutendex | PARTIAL | Real+estimada | provider Gutendex | ausente | Gutendex | tamanho/páginas/data incorretos | P1 |
| Download HTTP | PARTIAL | Real | `download_manager.dart` | caminho real não coberto | Dio/storage/DB | integridade e Range real não comprovados | P0 |
| Download mock | IMPLEMENTED | Mock | `download_manager.dart` | coberto | — | alcançável em produção e marcado completed | P0 |
| Leitura online | BROKEN | Real+Mock | `online_reading_manager.dart` | mock | provider/network | falha vira conteúdo sintético de sucesso | P0 |
| Offline baixado | PARTIAL | Real | manager/storage/repository | integração local mock | filesystem/SQLite | não validado em Android/mode avião | P0 |
| EPUB reader | PARTIAL | Real | parser/bloc/screen | EPUB mínimo sintético | archive/xml | faltam EPUBs reais variados e erro explícito | P1 |
| TXT reader | IMPLEMENTED | Real | book parser | unitário | IO | paginação/escala device pendentes | P2 |
| PDF reader | BROKEN | Mock/placeholder | book parser | PDF mínimo, sem render | nenhuma lib PDF | não renderiza conteúdo/páginas | P0 |
| CBZ reader | PARTIAL | Real | comic parser/cache/screen | ZIP sintético | archive | imagens reais/corrompidas/device ainda não validados | P1 |
| CBR reader | BROKEN | Fallback | factory/extractor/parser | ausente | sem RAR | CBR tratado como ZIP | P0 |
| Imagens soltas | MISSING | — | ausente | ausente | — | claim sem pipeline | P1 |
| Library | PARTIAL | Real | screen/bloc/repository | SQLite FFI | SQLite | remoção deixa arquivos; Home mocks não isolados | P0 |
| Empty Library | PARTIAL | Real | `library_screen.dart` | widget parcial | BLoC | validar runtime DB limpo e CTAs | P1 |
| Profile | PARTIAL | Real | profile bloc/repository/screen | mock/SQLite | SQLite/storage | preferências nem sempre aplicadas | P1 |
| Avatar persistente | PARTIAL | Real | profile repository/avatar | repo teste | storage/SQLite | UI→restart Android não validado; IDs legados | P1 |
| Progresso | BROKEN | Real | reader blocs/profile repo | fragmentado | SQLite | writers usam 0–100; stats usam 0–1 | P0 |
| Histórico | MISSING | — | tabela/entidade apenas | ausente | SQLite | sem repository/usecase | P1 |
| Banco/migrations | PARTIAL | Real | `app_database.dart` | schema básico | sqflite/ffi | WAL Android, migrations e FKs não comprovados | P0 |
| Storage | PARTIAL | Real | `storage_manager.dart` | unitários Linux | path_provider | migração silencia erro; cleanup correlacionado ausente | P1 |
| Segurança de rede | PARTIAL | Real | `network_client.dart` | wrapper unitário | Dio | getter `.dio` contorna validação HTTPS | P0 |
| CryptoVault | BROKEN | Não integrado | `crypto_vault.dart` | unitário | pointycastle | KDF não é PBKDF2; claims incorretos | P0 |
| Logs estruturados | PARTIAL | Real | `app_logger.dart` | unitário | dart:developer | erro/stack podem escapar sanitização | P1 |
| Phone shell | PARTIAL | Real | router/screens | widget 400×800 | Flutter | sem device real/API matrix | P1 |
| Tablet shell | PARTIAL | Real | router/screens | widget 900×1200 | Flutter | um cenário; sem landscape/device real | P1 |
| E2E Android | MISSING | — | sem `integration_test/` | ausente | Android | testes atuais são integração FFI/mock | P0 |
| Performance | PARTIAL | Sintético | stress/cache/repository | host Linux | SQLite/bytes | não mede bitmap, GPU, device, PDF/EPUB grandes | P1 |
| Rebranding VANTA | PARTIAL | Real+legado | projeto inteiro | sem gate específico | compatibilidade | nomes públicos melhorados; `Nova*` abundante | P1 |
| Release Android | BROKEN | — | Gradle/artefatos | ausente | signing | só debug; release usa chave debug | P0 |

## Nota sobre mocks e fixtures

`MockData`, `MockContentProvider`, payloads sintéticos e páginas de amostra só podem permanecer se forem isolados por ambiente de teste/demo explicitamente rotulado. No estado observado, parte desse material alcança o runtime normal e viola a regra de conteúdo real.

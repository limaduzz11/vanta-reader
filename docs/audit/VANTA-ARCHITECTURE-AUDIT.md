# VANTA Reader — Auditoria Arquitetural (Fase 1)

**Data:** 2026-09-09  
**Referência Arquitetural:** Clean Architecture & Monochromatic Minimalism  
**Status Geral:** Arquitetura Sólida com Gaps de Isolamento de Runtime  

---

## 1. Verificação do Fluxo Canônico de Camadas

O projeto foi projetado seguindo a divisão clássica de quatro camadas:

```
[ Camada de Apresentação (UI) ]
       ↓ (Dispara Eventos)
[ BLoC / Cubit State Machine ]
       ↓ (Invoca)
[ Casos de Uso de Domínio (UseCases) ]
       ↓ (Requisita dados abstratos)
[ Repositórios (Interfaces de Domínio) ]
       ↓ (Implementação Concreta em Data)
[ Data Sources: SQLite / File Storage / Network Client / Providers ]
```

### Avaliação de Conformidade por Módulo:

1. **Apresentação (UI):**
   - **Conformidade:** Alta. Telas e widgets utilizam `BlocBuilder` e `BlocConsumer`.
   - **Pontos de Atenção:** Em `work_details_screen.dart`, havia uma chamada direta a `getIt<EnqueueDownloadUseCase>()` dentro do botão de download em vez de delegar para um evento de BLoC dedicado. Foi criada uma inconsistência menor entre o fluxo de detalhes e a fila de downloads.
   - **Navegação:** `Navigator.of(context).push` padrão inseria as telas de leitura dentro do Shell de abas, exibindo a BottomNavigationBar indevidamente. O correto é empurrar rotas com `rootNavigator: true` ou rotas de nível raiz no GoRouter.

2. **Gerenciamento de Estado (BLoC):**
   - **Conformidade:** Muito Alta. Todos os estados herdam de `Equatable`, com imutabilidade e eventos tipados.
   - **Gap Identificado:** O `SearchBloc` não recebia o repositório de perfil nem o idioma ativo do usuário, deixando a responsabilidade de idioma isolada ou fixa.
   - **Gap de Concorrência:** O `_persistProgress` em `BookReaderBloc` e `ComicReaderBloc` era disparado de forma assíncrona após o `emit`, causando race conditions em fechamentos imediatos de tela.

3. **Camada de Domínio (Domain):**
   - **Conformidade:** Alta. Entidades (`Work`, `WorkEdition`, `UserProfile`, `DownloadItem`) são puras e não contêm anotações de bibliotecas externas de banco ou rede.
   - **Contaminação de Teste:** O caso de uso `SeedInitialCatalogUseCase` foi alocado dentro de `lib/domain/usecases/` e acoplado a `MockData.allWorks`, violando a separação entre código de produção e fixtures de teste.

4. **Camada de Dados (Data):**
   - **Conformidade:** Alta. Repositórios implementam contratos de domínio (`ILibraryRepository`, `IDownloadRepository`, `IProfileRepository`).
   - **Provedores de Conteúdo:** O `OpenLibraryContentProvider` implementa `ContentProvider` respeitando a interface unificada, encapsulando HTTP via `NetworkClient`.

---

## 2. Inventário de Violações e Gaps Arquiteturais

| Violação / Item | Gravidade | Ocorrência no Código | Impacto | Resolução Arquitetural |
| :--- | :--- | :--- | :--- | :--- |
| **Injeção de Mock em Produção** | **Crítica** | `injection.dart` (linha 402) chamando `SeedInitialCatalogUseCase` | Poluição da biblioteca do usuário com obras artificiais e dados não solicitados. | Remover chamada de seed da inicialização padrão; restringir seed a testes instrumentados. |
| **Acoplamento de Navegação** | **Alta** | `work_details_screen.dart` usando `Navigator.of(context).push` | Leitor é empurrado como sub-rota da aba, mantendo BottomNav visível. | Utilizar `Navigator.of(context, rootNavigator: true).push` com tela cheia. |
| **Desconexão Perfil-Busca** | **Alta** | `SearchBloc` sem acesso ao `preferredLanguage` do Perfil | A busca não prioriza o idioma configurado pelo usuário no ranking. | Injetar `GetUserProfileUseCase` no `SearchBloc` e repassar idioma ao `ProviderManager`. |
| **Estratégia de Query Externa Inadequada** | **Alta** | `OpenLibraryContentProvider` usando `q=` genérico | Alto tempo de resposta (15s a 30s) e falsos positivos de relevância (OCR). | Adotar query otimizada `title=` e `author=`, combinada com normalização rigorosa. |
| **Single-item em Categoria de HQs** | **Média** | `getFeaturedComics` apontando para slug com 1 item | Apenas "Drama" aparecia na Home para quadrinhos. | Migrar endpoint para `subjects/graphic_novels.json` e `superheroes.json`. |
| **Simulador Desktop em Mobile** | **Média** | `NovaDeviceSimulator` em `app_router.dart` | Barra flutuante de debug aparecendo em compilações reais no celular. | Garantir bypass absoluto em Android nativo e release builds. |

---

## 3. Diretriz de Correção Sem Regressão

- Não alterar as interfaces centrais já estabilizadas (`Work`, `WorkEdition`, `ContentProvider`, `AppDatabase`).
- Manter 100% de compatibilidade com os 188 testes já existentes na suíte.
- Aplicar o princípio de menor privilégio na injeção de dependências: dados de teste pertencem estritamente a `test/` e `test_fixtures/`.

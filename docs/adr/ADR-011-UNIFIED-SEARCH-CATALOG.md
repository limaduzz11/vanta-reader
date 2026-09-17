# ADR-011: Unified Online Search & Cross-Provider Catalog Presentation

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase J — Busca Online & Catálogo Unificado

---

### Contexto e Problema

Com a conclusão do motor de provedores (Fase I), o NovaReader dispõe de um backend local capaz de consultar múltiplos catálogos de livros e quadrinhos em paralelo. No entanto, conectar essa capacidade ao usuário final impõe desafios arquiteturais específicos de UX e performance:
1. **Sobrecarga de Requisições por Digitação:** Disparar buscas a cada caractere digitado causaria desperdício massivo de processamento, estouro de rate-limits de provedores e gargalos de renderização na interface gráfica.
2. **Filtragem e Ordenação em Domínio Descentralizado:** Provedores externos raramente suportam a mesma gramática de filtros (alguns filtram por formato, outros por idioma, outros apenas por string aberta). É imperativo que o domínio do aplicativo realize a harmonização desses filtros de forma previsível e determinística.
3. **Representação Visual de Obras Multi-Edição:** Como o `WorkIdentitySystem` unifica múltiplos arquivos da mesma obra em uma entidade mestre, a interface deve permitir ao leitor inspecionar e escolher o formato de sua preferência (`EPUB`, `PDF`, `CBZ`) sem gerar confusão visual ou poluição de cards duplicados na busca.
4. **Respeito ao Design System Monocromático:** A experiência visual de busca deve manter os tokens minimalistas (`NovaColors`), evitando a poluição cromática comum em apps de terceiros.

---

### Decisões de Arquitetura

1. **Separação Limpa via Caso de Uso Dedicado (`SearchOnlineCatalogUseCase`):**
   - Centraliza o isolamento de busca, aplicando client-side filtering por tipo de obra (`WorkType`), formato de arquivo suportado (`WorkFormat`), idioma normalizado (`pt-BR`, `en`) e critérios de ordenação (`relevance`, `title`, `author`).
   - Garante que mesmo quando provedores externos retornem metadados heterogêneos, a camada de apresentação receba listas limpas e previsíveis.

2. **Debounce e Concorrência Reativa no `SearchBloc`:**
   - Implementação de debounce de 300ms na digitação para proteger os provedores e poupar recursos computacionais e de rede.
   - Cancelamento automático de buscas anteriores via padrão `switchMap` / reatividade com BLoC, garantindo que respostas de requisições obsoletas sejam descartadas sem condições de corrida.

3. **Sugestões Rápidas no Estado Inicial (`SearchInitial`):**
   - Quando o campo de busca está vazio, o usuário recebe chips interativos com termos e gêneros populares para exploração rápida com zero atrito de digitação.

4. **Chips de Filtragem Dinâmicos com Feedback Imediato:**
   - Filtros organizados por Tipo (Livros, Quadrinhos), Formato (EPUB, PDF, CBZ) e Ordenação na `SearchScreen`.
   - Modificações de filtro reaplicam a consulta instantaneamente sem exigir re-digitação da query.

5. **Consolidação de Edições na `WorkDetailsScreen`:**
   - Quando a obra unificada possui mais de uma edição (ex: EPUB de um provedor e PDF de outro), um seletor visual dedicado expõe cada formato com seu tamanho estimado, provedor de origem e botão de ação independente de download/leitura.

---

### Consequências

- **Positivas:**
  - Descoberta de conteúdo fluida, rápida e sem latência desnecessária.
  - Zero duplicação visual de cards na busca.
  - Arquitetura 100% testada (use case, BLoC e widget tests cobrindo todos os fluxos e estados de erro/vazio).
  - Fidelidade total aos tokens de design minimalista monocromático.
- **Negativas / Mitigações:**
  - A filtragem pós-busca (client-side) pode limitar o total de resultados caso um provedor remoto pagine estritamente antes do filtro: mitigado pelo tamanho generoso da página de busca do `ProviderManager` (`pageSize: 20` a `50`).

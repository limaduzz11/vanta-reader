# ADR-010: Provider Engine, Metadata Normalization & Canonical Work Identity System

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase I — Motor de Provedores (Provider Engine & Mock)

---

### Contexto e Problema

O NovaReader é uma plataforma agnóstica de leitura que agrega livros e quadrinhos de múltiplos catálogos e formatos. Uma das falhas mais graves em aplicativos concorrentes de leitura é o acoplamento excessivo com uma única fonte ou a proliferação descontrolada de duplicatas quando múltiplas fontes são consultadas:
1. **Heterogeneidade de Dados Externos:** Provedores de conteúdo retornam dados com formatos arbitrários de nomes de autores (ex: "Herbert, Frank" vs "Frank Herbert"), títulos com subtítulos embutidos ("Dune: Book 1"), tags HTML na sinopse e formatos de idiomas divergentes.
2. **Proliferação de Obras Duplicadas:** Quando múltiplos provedores oferecem a mesma obra (ou a mesma obra em diferentes formatos como EPUB e PDF), o usuário é bombardeado com cards repetidos nos resultados de busca se não houver deduplicação canônica.
3. **Vulnerabilidade a Provedores Lentos ou Instáveis:** Se a busca depender de uma conexão em série ou de um único timeout global, um provedor lento ou offline trava a experiência inteira do aplicativo.
4. **Isolamento e Testabilidade Offline:** O sistema precisa de um provedor mock de alta fidelidade para que todo o pipeline de busca, filtragem e download possa ser desenvolvido e testado de ponta a ponta sem depender de serviços externos.

---

### Decisões de Arquitetura

1. **Contrato de Abstração Puro (`ContentProvider`):**
   - Criação da interface `ContentProvider` com declaração de capacidades (`ProviderCapabilities`), diagnóstico de saúde (`ProviderHealth`), busca paginada e resolução sob demanda de URLs de download.
   - Nenhuma tela ou camada de apresentação consome provedores diretamente.

2. **Registro Dinâmico de Fontes (`ProviderRegistry`):**
   - Suporte a múltiplos provedores registrados em tempo de execução com controle granular de ativação/desativação por ID (`setProviderEnabled`).

3. **Higienização Determinística (`MetadataNormalizer`):**
   - Eliminação de injeções e tags HTML, caracteres de controle e espaços duplicados.
   - Inversão de catálogo de nomes de autores ("Sobrenome, Nome" -> "Nome Sobrenome") e remoção de prefixos.
   - Normalização de códigos de idioma para o padrão ISO canônico do aplicativo (`pt-BR` ou `en`).
   - Normalização e validação estrita de ISBN (10 e 13 dígitos).

4. **Identidade Canônica e Deduplicação Inteligente (`WorkIdentitySystem`):**
   - Chave canônica primária: Prioridade absoluta para ISBN válido (`isbn_{cleanIsbn}`).
   - Chave canônica secundária: Slug fonético com remoção de diacríticos, filtragem de stop-words em português/inglês e ordenação alfabética dos tokens do autor (`${slugTitle}__${slugAuthor}`).
   - Fusão de Obras (`deduplicateAndMerge`): Itens com mesma chave canônica ou alta similaridade de Levenshtein (>= 0.75) são mesclados em um único `Work` canônico.
   - Consolidação de Edições: Os arquivos dos diferentes provedores tornam-se edições (`WorkEdition`) associadas à mesma obra mestre, permitindo que o usuário escolha entre EPUB, PDF ou CBZ na mesma tela de detalhes.

5. **Busca Paralela com Isolamento de Falhas (`ProviderManager`):**
   - Disparo concorrente com timeout individual por provedor (`Future.wait`).
   - Falhas ou timeouts em um provedor são registradas no `AppLogger` e ignoradas, retornando os resultados válidos dos demais provedores sem interrupção.
   - Ordenação inteligente de resultados combinando correspondência exata, prefixo de título, correspondência de autor e preferência regional de idioma.

6. **Provedor Mock Rico para Desenvolvimento e Testes (`MockContentProvider`):**
   - Catálogo com obras clássicas e contemporâneas em livros e quadrinhos nos formatos EPUB, PDF, CBZ e TXT.
   - Flags programáveis para injeção de latência, timeout proposital e simulação de erros para testes de resiliência.

---

### Consequências

- **Positivas:**
  - Experiência de busca limpa, unificada e sem duplicatas para o usuário final.
  - Alta resiliência arquitetural: queda de um provedor remoto não prejudica os demais.
  - Independência total de infraestruturas proprietárias.
  - Cobertura de testes robusta: 113/113 testes passando com 100% de sucesso, 0 alertas de linter e compilação limpa no Linux Desktop.
- **Negativas / Mitigações:**
  - Títulos com traduções muito distintas que não possuam ISBN compartilhado (ex: obras sem ISBN onde o título em português é completamente diferente do inglês) podem não ser fundidos na primeira passagem: mitigado pelo dicionário de sinônimos cross-language conhecido e pela verificação difusa de similaridade de autor.

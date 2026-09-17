# IREADER — Relatório de Engenharia Reversa e Análise Técnica
**Documento Canônico:** `docs/research/IREADER-RESEARCH.md`  
**Referência:** [IReaderorg/IReader (GitHub)](https://github.com/IReaderorg/IReader)  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  

---

## 1. Visão Geral & Propósito
O **IReader** é uma aplicação open-source desenvolvida em **Kotlin Multiplatform (KMP)** e **Compose Multiplatform** para Android e Desktop. É projetada para leitura de light novels, web novels e e-books, destacando-se por um poderoso ecossistema de extensões de fontes externas desacopladas (inspirado na arquitetura do Tachiyomi/LNReader).

---

## 2. Análise Arquitetural & Stack Técnica

### 2.1. Tecnologias Centrais
- **Core / UI:** Kotlin Multiplatform + Jetpack Compose (Android) e Compose Desktop.
- **Arquitetura de Software:** Clean Architecture com MVI (Model-View-Intent) / MVVM reativo.
- **Banco de Dados Local:** SQLDelight / Room multiplataforma para persistência tipada e reativa.
- **Sistema de Fontes (Extension Engine):** Módulos dinâmicos que implementam contratos de catálogo, parsing e busca. Permite adicionar repositórios de extensões de terceiros sem recompilar o binário principal.
- **Motor de Download:** Gerenciador assíncrono com filas baseadas em Coroutines (`Kotlinx.coroutines.channels`), persistindo capítulos e metadados no armazenamento local.

### 2.2. Arquitetura de Extensões e Providers
```text
IReader Core
      │
      ├── Source / Extension Interface (Contrato universal: getPopular, search, getDetails, getChapterList, getPageContent)
      │
      ├── Extension Loader (Carregamento de fontes locais ou externas dinâmicas)
      │       ├── Source A (ex: LightNovelPub)
      │       ├── Source B (ex: ReadLightNovel)
      │       └── Source C (Legado / Custom)
      │
      └── Normalizer & Cache Layer (Padronização para entidades do IReader)
```

---

## 3. Avaliação Detalhada por Módulo

| Módulo | Implementação no IReader | Diagnóstico Crítico para o NovaReader |
|---|---|---|
| **Arquitetura de Provedores** | Padrão ouro em isolamento de fontes. O core nunca depende de implementações concretas de sites. | **Adoção fundamental no NovaReader:** O `ProviderManager` do NovaReader seguirá o mesmo princípio de isolamento contratual (`ContentProvider`), permitindo fontes mock, públicas ou privadas. |
| **UX & Customização do Reader** | Ajustes profundos: espaçamento entre parágrafos, indentação, fontes customizadas, inversão de cores, scroll contínuo. | O leitor de livros do NovaReader adotará os mesmos controles ergonômicos de leitura. |
| **Persistência de Progresso** | Gravação por capítulo e scroll offset relativo com restauração instantânea. | O NovaReader usará a mesma precisão: `workId`, `chapterId`, `page`, `offset`, `percentage`. |
| **Foco em Quadrinhos** | Secundário ou inexistente: otimizado para texto contínuo (novels) e não para pipeline pesado de imagens rasterizadas de HQs. | O NovaReader não pode tratar HQs como novels; requer motor de imagem com janela deslizante LRU e modos de zoom. |
| **Identidade Visual** | Material 3 padrão com suporte a múltiplos temas coloridos. | O NovaReader se diferenciará com sua assinatura visual própria: **Monochromatic Minimalism** (#121212), transmitindo elegância e foco puro. |
| **Complexidade de Código** | Alta complexidade decorrente da sobrecarga de empacotamento de extensões em tempo de execução. | O NovaReader manterá a camada de provedores modular, direta e tipada em Dart, sem complexidade de sandbox de scripts de terceiros no MVP. |

---

## 4. Pontos Fortes (Melhores Ideias a Reter)
1. **Desacoplamento Total de Fontes:** O aplicativo é 100% funcional mesmo com zero extensões instaladas (usando arquivos locais).
2. **Gerenciador de Download Baseado em Filas:** Downloads ocorrem em background de forma transparente, com retry automático e atualização reativa de progresso.
3. **Histórico e Estatísticas de Leitura:** Rastreamento do tempo de leitura e progresso por obra.

## 5. Cuidados & Adaptações para o NovaReader
1. **Evitar acoplamento a formatos web fracionados:** O IReader é muito voltado a capítulos web individuais (`Chapter 1, 2, 3...`). O NovaReader precisa focar prioritariamente em arquivos integrais de livros (.epub, .pdf, .txt) e encadernados de quadrinhos (.cbz, .cbr).

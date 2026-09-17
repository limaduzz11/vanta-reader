# OPENLIB — Relatório de Engenharia Reversa e Análise Técnica
**Documento Canônico:** `docs/research/OPENLIB-RESEARCH.md`  
**Referência:** [dstark5/Openlib (GitHub)](https://github.com/dstark5/Openlib)  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  

---

## 1. Visão Geral & Propósito
O **Openlib** é um aplicativo Android desenvolvido em **Flutter** que tem como objetivo primário permitir a busca, descoberta, download e leitura de livros digitais integrando-se à biblioteca distribuída Anna's Archive.

---

## 2. Análise Arquitetural & Stack Técnica

### 2.1. Tecnologias Centrais
- **Framework:** Flutter (Dart) direcionado para Android.
- **Camada de Rede & Scraping:** `http` / `dio` com parsers HTML (`html` / CSS selectors) para extração de links de download e metadados diretamente das páginas web.
- **Armazenamento de Estado & Dados:** `shared_preferences` e SQLite local para registro básico de livros baixados e preferências de configuração.
- **Motor de Leitura Interno:** Visualizador de EPUB leve e suporte a PDF via plugins de renderização ou delegação para aplicativos externos via Android Intent (`android_intent_plus` / `open_filex`).

### 2.2. Fluxo de Dados
```text
User Search Input
       │
       ▼
HTTP GET (Anna's Archive Search URL com parâmetros)
       │
       ▼
HTML Scraping Engine (Parse dos nós <tr> / <div> da página de busca)
       │
       ▼
Modelo Interno (BookSearchResult: title, author, publisher, extension, size, md5)
       │
       ▼
Tela de Detalhes (Request adicional para página do livro / obtenção de espelhos de download)
       │
       ▼
Download Manager (Transferência para o diretório de Downloads do Android)
       │
       ▼
Leitura (Interna ou via Intent externo)
```

---

## 3. Avaliação Detalhada por Módulo

| Módulo | Implementação no Openlib | Diagnóstico Crítico para o NovaReader |
|---|---|---|
| **UX & Navegação** | Interface direta com abas simples (Busca, Downloads, Configurações). Foco funcional sem polimento refinado. | Muito utilitário. O NovaReader adotará o conceito de streaming/catálogo moderno (Monochromatic Minimalism) com Home, Biblioteca, Filtros e Perfil. |
| **Biblioteca** | Apenas uma listagem de arquivos baixados na pasta local. | Falta categorização avançada, agrupamento por autor/série, status (Lendo, Concluído) e suporte a HQs. |
| **Reader (Leitor)** | EPUB básico e visualizador PDF padrão; incentiva abrir em leitor externo. | Insuficiente para uma experiência imersiva unificada. O NovaReader terá motor próprio de EPUB, PDF e Comic Engine com persistência de posição. |
| **Gerenciador de Download** | Download direto via HTTP com barra de progresso simples; dependente da tela em versões iniciais. | Falta máquina de estados robusta, retomada com `HTTP Range`, reconexão automática e background task isolada. |
| **Metadados & Capas** | Carregamento direto de URLs remotas; scraping quebra frequentemente quando a fonte altera o DOM. | Acoplamento excessivo. O NovaReader usará abstração de Providers com normalização desacoplada e cache persistente de capas. |
| **Organização de HQs** | Inexistente. O app é exclusivamente focado em livros texto e artigos. | O NovaReader tratará HQs como cidadãos de primeira classe com motor dedicado (CBZ/CBR/Imagens). |
| **Comportamento Offline** | Funciona para abrir o arquivo já baixado na lista local, mas a navegação é orientada a online. | O NovaReader será Local-First: a Home, Library, Busca local e Reader operam 100% offline. |
| **Responsividade (Tablet)** | Apenas estica o layout de celular na tela grande. | O NovaReader terá layouts adaptativos dedicados (Navigation Rail, grid de 4-6 colunas, split view). |

---

## 4. Pontos Fortes (Melhores Ideias a Reter)
1. **Seleção de Múltiplos Espelhos:** Apresentar ao usuário opções de espelhos/formatos quando uma obra possui diferentes links de obtenção.
2. **Leveza do App:** Construção em Flutter permitindo inicialização rápida e baixo footprint de instalação.
3. **Filtros por Extensão:** Capacidade de filtrar por EPUB, PDF, etc., diretamente nos parâmetros de pesquisa.

## 5. Falhas, Riscos & Anti-Padrões a Evitar
1. **Acoplamento Monolítico ao Scraping:** Quando o site externo altera uma única classe CSS, o Openlib para de funcionar até atualização de versão. *Decisão NovaReader:* Camada de providers abstrata com fallbacks e parsers desacoplados do núcleo da UI.
2. **Falta de Deduplicação:** Obras repetidas aparecem poluindo a busca. *Decisão NovaReader:* `WorkIdentitySystem` agrupa edições sob uma única entidade.
3. **Ausência de Leitor de Quadrinhos:** Impossibilidade de ler mangás, quadrinhos ou arquivos comprimidos (.cbz/.cbr).

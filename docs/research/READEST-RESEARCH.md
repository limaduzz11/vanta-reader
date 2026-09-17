# READEST — Relatório de Engenharia Reversa e Análise Técnica
**Documento Canônico:** `docs/research/READEST-RESEARCH.md`  
**Referência:** [readest/readest (GitHub)](https://github.com/readest/readest)  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  

---

## 1. Visão Geral & Propósito
O **Readest** é um leitor moderno de e-books construído com **Next.js (React)** e **Tauri (Rust)**, projetado para oferecer uma experiência de leitura imersiva, minimalista e focada em concentração, com sincronização em nuvem e suporte multiplataforma.

---

## 2. Análise Arquitetural & Stack Técnica

### 2.1. Tecnologias Centrais
- **Core / Backend Local:** Tauri (Rust) para gerenciamento de arquivos locais, segurança de filesystem e ponte nativa com o SO.
- **Frontend / Camada de Apresentação:** Next.js / React com renderização moderna e componentes Tailwind CSS altamente minimalistas.
- **Renderização de Livros:** Folium / Webview com parsing de EPUB e visualização tipográfica refinada.
- **Sincronização:** Backend remoto proprietário/open-source com controle de contas de usuário e limites de armazenamento (modelo freemium com 500 MB gratuitos).

### 2.2. Filosofia de Interface & UX
- **Minimalismo Extremo:** Ocultação automática de todas as barras de ferramentas e botões durante a leitura.
- **Foco Tipográfico:** Atenção obsessiva a fontes legíveis, espaçamento uniforme, margens dinâmicas que respeitam proporções áureas e paletas discretas.

---

## 3. Avaliação Detalhada por Módulo

| Módulo | Implementação no Readest | Diagnóstico Crítico para o NovaReader |
|---|---|---|
| **UX & Imersão** | Interface limpa, com poucos botões, focada em conteúdo. Modo de leitura sem distrações. | **Referência de ouro para a estética visual do NovaReader.** O NovaReader adotará o mesmo minimalismo zen, mas com identidade monocromática escura nativa. |
| **Arquitetura Multiplataforma** | Tauri + Webview. No desktop é muito rápido, mas em dispositivos móveis (Android) a camada Webview consome mais memória e bateria. | O NovaReader rodará com motor nativo Flutter (Skia/Impeller), eliminando o overhead de instanciar Webviews no Android. |
| **Modelo de Negócio / Cloud** | Vinculado a planos de conta e limitação de armazenamento em nuvem. | **Incompatível com o princípio do NovaReader:** O NovaReader é 100% livre de bloqueios por conta ou planos pagos; armazenamento é gerenciado no próprio dispositivo. |
| **Suporte a Quadrinhos** | Fraco. Desenvolvido prioritariamente para e-books em texto corrido (EPUB). | O NovaReader suporta HQs e livros com paridade de importância. |
| **Responsividade** | Muito boa em telas de desktop e tablets devido ao design web responsivo. | O NovaReader adotará regras responsivas semelhantes para Navigation Rail e layout de duas colunas em tablets. |

---

## 4. Pontos Fortes (Melhores Ideias a Reter)
1. **Zen Reading Mode:** O leitor entra em modo tela cheia e oculta todos os comandos de navegação com um toque, restaurando-os apenas ao tocar no centro da tela.
2. **Design Tipográfico Impecável:** Proporções refinadas entre tamanho de fonte, altura de linha e margens laterais.
3. **Identidade Visual Sóbria:** Ausência de cores berrantes, reforçando o foco no texto.

## 5. Falhas & Riscos a Evitar no NovaReader
1. **Dependência de Cloud para a Experiência Completa:** Se o usuário não conectar a conta ou atingir 500 MB, a experiência é degradada. O NovaReader nunca colocará barreiras artificiais de armazenamento.
2. **Sobrecarga de Webview para HQs pesadas:** Renderizar centenas de imagens em alta resolução dentro de uma Webview móvel causa travamentos no scroll e alto consumo de memória RAM.

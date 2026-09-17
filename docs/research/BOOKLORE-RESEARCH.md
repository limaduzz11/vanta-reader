# BOOKLORE — Relatório de Engenharia Reversa e Análise Técnica
**Documento Canônico:** `docs/research/BOOKLORE-RESEARCH.md`  
**Referência:** [booklore-app/booklore (GitHub)](https://github.com/booklore-app/booklore)  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  

---

## 1. Visão Geral & Propósito
O **BookLore** é uma plataforma moderna e open-source de biblioteca digital auto-hospedada (self-hosted), voltada para centralizar, catalogar, ler e organizar grandes coleções de e-books e quadrinhos através de navegador web, integrando-se com e-readers físicos (como Kobo e KOReader) e protocolos padrão como OPDS.

---

## 2. Análise Arquitetural & Stack Técnica

### 2.1. Tecnologias Centrais
- **Backend:** Servidor em arquitetura de microsserviço/monólito modular conteinerizado (Docker & Docker Compose).
- **Banco de Dados:** MariaDB / MySQL relacional com tabelas estruturadas para obras, edições, autores, séries, tags e permissões de usuários.
- **Frontend / UX:** Aplicação Web reativa moderna com dashboard estilo Netflix/Calibre-Web para visualização de capas, coleções e progresso.
- **Motor de Leitura Web:** Integração de leitores em JavaScript para o navegador: `epub.js` (para livros EPUB), `pdf.js` (para PDFs) e um visualizador de imagens sequencial (para arquivos CBZ/CBR descompactados no backend).
- **Mecanismos de Automação:** "BookDrop" — monitoramento de diretório no servidor (in-filesystem watcher) que extrai metadados e indexa automaticamente novos arquivos adicionados.

### 2.2. Fluxo de Catálogo e Organização
```text
Arquivo adicionado (Upload ou BookDrop)
       │
       ▼
Extractor Pipeline (Extração de metadados internos: EPUB OPF, PDF info, CBZ ComicInfo.xml)
       │
       ▼
Enrichment Pipeline (Consulta opcional a APIs públicas: Google Books, Open Library)
       │
       ▼
Banco Relacional (Criação de Work, Author, Series, Edition, Files)
       │
       ▼
Smart Shelves (Categorização dinâmica por regras: "Não lidos", "Série X", "Autor Y")
       │
       ▼
Entrega (Web Reader interno ou feed OPDS para e-readers externos)
```

---

## 3. Avaliação Detalhada por Módulo

| Módulo | Implementação no BookLore | Diagnóstico Crítico para o NovaReader |
|---|---|---|
| **UX & Catálogo** | Excelente organização visual em carrosséis ("Lendo recentemente", "Adicionados recentemente", "Smart Shelves"). | **Referência de alto valor para a Home do NovaReader**, adaptando para uma estética Monocromática Minimalista nativa. |
| **Biblioteca & Metadados** | Estrutura relacional sofisticada separando Obra de Edição/Arquivo. Suporte a `ComicInfo.xml` para metadados de quadrinhos. | **Adoção direta pelo NovaReader:** A modelagem de dados do NovaReader seguirá a separação entre Obra abstrata e Formatos físicos. |
| **Automação ("BookDrop")** | Observador de diretório que processa arquivos em background. | No NovaReader, a Fase E implementará um importador local com a mesma inteligência de extração automática de metadados e capas. |
| **Reader** | Baseado em Web (DOM/Canvas). Apresenta latência no scroll de PDFs pesados e HQs em dispositivos móveis. | O NovaReader usará motores compilados nativos (Skia/Impeller) no dispositivo, garantindo 60/120 FPS sem overhead de navegador. |
| **Dependência de Servidor** | Requer servidor ligado, Docker e MariaDB para funcionar. Inviável para leitura desconectada em trânsito. | **Oposto ao NovaReader:** O NovaReader é Local-First, operando 100% no dispositivo sem depender de servidor remoto. |
| **Multi-usuário** | OIDC/OAuth2 robusto com permissões por estante. | Desnecessário para o MVP do NovaReader (foco em uso pessoal com perfis locais e avatares), mantendo a arquitetura desacoplada para sincronização futura. |

---

## 4. Pontos Fortes (Melhores Ideias a Reter)
1. **Conceito de Smart Shelves (Estantes Inteligentes):** Regras dinâmicas para agrupar obras (ex: "HQs em andamento", "Livros lidos em 2026").
2. **Suporte Nativo a Metadados de HQs:** Leitura de `ComicInfo.xml` dentro de arquivos CBZ/CBR para identificar número da edição, roteirista e desenhista.
3. **Organização Visual em Prateleiras:** Carrosséis horizontais com capas bem diagramadas, trazendo sensação de serviço de streaming.

## 5. Limitações para o Contexto do NovaReader
1. **Não é um aplicativo mobile nativo:** Requer conectividade constante com o servidor doméstico ou VPS.
2. **Consumo de recursos elevado:** Requer dezenas de megabytes de RAM no backend apenas para servir páginas e converter imagens de HQs em tempo real.

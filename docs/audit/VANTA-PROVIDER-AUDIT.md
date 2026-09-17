# VANTA Reader — Auditoria de Provedores e Fontes de Dados (Fase 8, 9, 10, 11, 12)

**Data:** 2026-09-09  
**Provedores Avaliados:** OpenLibrary, Gutendex (Project Gutenberg), Archive.org, Mock Provider  

---

## 1. Avaliação de Fontes e Licenças

| Provedor | Tipo de Acervo | Licença / Legalidade | Formatos Disponíveis | Status de Conexão | Qualidade de Metadados |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Open Library (Internet Archive)** | Catálogo mundial aberto (milhões de livros e edições) | Licença Aberta / Metadados Públicos CC0 | Metadados, Capas Oficiais em alta resolução, referências de leitura | Ativo (Online) | Excelente para títulos, capas, autores, ISBN e anos de publicação. |
| **Gutendex (Project Gutenberg API)** | Clássicos em Domínio Público (Machado de Assis, Shakespeare, etc.) | Domínio Público / Gratuito sem autenticação | EPUB completo, TXT UTF-8 completo, capas JPEG | Ativo (Online) | Excelente para leitura e downloads reais e integrais de domínio público. |
| **Internet Archive (Archive.org)** | Quadrinhos históricos, livros raros e periódicos | Domínio Público / Preservação Cultural | CBZ, CBR, PDF, EPUB | Ativo (Online) | Ideal para acervo histórico de quadrinhos e graphic novels. |
| **Mock Content Provider** | Acervo sintético de demonstração e testes unitários | Uso Interno / Testes | EPUB, CBZ | Desativado em Produção | Restrito exclusivamente ao ambiente de testes e integração. |

---

## 2. Diagnóstico da Saúde e Tolerância a Falhas dos Provedores (Fase 11 e 12)

O `ProviderManager` foi projetado com isolamento estrito de falhas:
- **Timeouts Independentes:** Cada provedor possui seu próprio `timeout` configurado (padrão de 25s para busca online, 5s para health checks).
- **Tratamento de Timeout:** Se um provedor exceder o tempo limite (`TimeoutException`), ele não derruba os demais provedores da busca.
- **Health States:**
  - `healthy`: Latência medida em ms e resposta HTTP 200.
  - `degraded`: Status diferente de 200 ou latência superior a 5000ms.
  - `offline`: Conexão falhou ou host inalcançável.
  - `disabled`: Provedor explicitamente desativado no `ProviderRegistry`.

---

## 3. Resolução do Problema de "Quadrinhos em Destaque" (Fase 9)

### Causa Raiz:
O método `getFeaturedComics` consultava `https://openlibrary.org/subjects/comics_graphic_novels.json`. No banco de dados da OpenLibrary, esse slug específico possui apenas **1 obra associada** ("Drama" de Raina Telgemeier).

### Solução Técnica Implementada:
1. Migrar a consulta para o slug primário de quadrinhos da OpenLibrary: `https://openlibrary.org/subjects/graphic_novels.json`, que possui mais de **13.600 títulos catalogados**.
2. Suportar fallback ou enriquecimento com `https://openlibrary.org/subjects/superheroes.json` (mais de 4.300 títulos, incluindo obras canônicas como *Watchmen* e *Marvel Masterworks*).
3. Essa mudança garante uma grade completa de 10 a 15 títulos reais, todos com capas oficiais de alta resolução (`https://covers.openlibrary.org/b/id/{id}-M.jpg`).

---

## 4. Reauditoria Provider System — 2026-09-09

> Esta seção invalida a tabela acima (que declarava Archive.org ativo e Mock desativado em produção). Fonte: código executável, smoke de runtime e pesquisa legal sobre as fontes.

### Registry real observado em runtime

| Provider | Registrado | Runtime padrão | Migração necessária |
|---|---|---|---|
| `MockContentProvider` | Sim | **SIM (confirmado no smoke Linux)** | Remover do registo normal |
| `OpenLibraryContentProvider` | Sim | Sim | Ajustar capabilities (não fornece conteúdo) |
| `GutendexContentProvider` | Sim | Sim | Corrigir identidade asset/URL |
| Archive.org | **Não existe código** | — | A declaração antiga era incorreta |

### Divergências confirmadas entre o documento antigo e o código

1. O doc dizia "Archive.org Ativo"; não há provider de Archive.org no código.
2. O doc dizia Mock "Desativado em Produção"; o mock **está no registry normal** (`injection.dart`).
3. O doc dizia OpenLibrary "Licença Aberta CC0"; a API é para metadata/capas e **não** serve como backend de conteúdo nem infraestrutura de alto tráfego (uso proibido conforme termos do Archive.org/Open Library; usar dumps para bulk).
4. O doc dizia "Capas oficiais em alta resolução" como ponto final; o pipeline **não materializa** a capa real no download (gera JPEG dummy).
5. O doc dizia Gutendex "EPUB completo, TXT UTF-8, capas JPEG" — real, porém: arquivo é de domínio público apenas; a marca Project Gutenberg tem condições; deve-se preferir self-host/mirrors e crawler do site principal é bloqueado (>~100/dia).

### Capacidades vs. realidade

| Provider | declara supportsSearch | declara Download | declara Streaming | resolve conteúdo real? |
|---|---|---|---|---|
| OpenLibrary | sim | sim | sim | **Não** — `downloadUrl` é página HTML de metadata; `resolveDownloadUrl` retorna `mock://`. Capacidade é falsa. |
| Gutendex | sim | sim | sim | Parcial — quando `externalId` chega corretamente, `formats` contém URL real. Hoje o pipeline pode corromper a identidade antes. |
| Mock | sim | sim | sim | Sim (obviamente), mas o conteúdo não é real — viola a regra absoluta. |

### Conformidade legal — pesquisa de fontes (resultado do subagente de pesquisa)

| Fonte | API oficial | Conteúdo licenciado | HQs | Recomendação |
|---|---|---|---|---|
| Open Library | Sim (search.json, works, covers) | Metadata/capas (conteúdo não) | Fraca | Integrar como metadata + capas; **não** "download" |
| Project Gutenberg / Gutendex | Gutendex é comunidade; PG é humano/mirrors | Domínio público (EUA) | Não | Integrar; self-host/mirror para produção; crawler do site principal é bloqueado |
| Internet Archive | Sim (`/advancedsearch.php`, `metadata/{id}`) | Item-dependent (public domain sim; lendable só empréstimo/streaming) | **Sim** (coleções PD de comics) | Integrar **com verificação por item** (`is_lendable`, `collection`, `licenseurl`, `access-restricted-item`); respeitar 429/Retry-After e User-Agent |
| Google Books API | Sim | Metadata/preview sem redistribuição | Sim (metadata/preview) | Integrar opcional (metadata complementar/preview) |
| Standard Ebooks | Feeds OPDS | CC0 | Não | Integrar opcional (catálogo pequeno, curado) |
| Digital Comic Museum | Não (403 anti-bot; exige conta) | PD declarado (EUA-centrado) | Sim | **Não** via scraping; apenas deep-link manual; preferir coleções PD espelhadas no IA |
| VANTA Catalog API (gateway oficial) | Sim (própria) | Conforme fonte upstream configurada | Via topic `c` | **Integrar** como fonte oficial (`vanta-catalog`); protocolo de catálogo legado via gateway neutro (ver `docs/VANTA-CATALOG-API.md`) |

### Decisão de fontes futuras (recomendação para a fase de implementação)

1. **Metadata/capas:** Open Library (cache, User-Agent identificado, rate ~1 req/s sem ID; 3 req/s com header+contato; bulk via dumps).
2. **Livros PD/Open Access com arquivo real:** Gutendex (via mirror próprio) como primeira fonte; Standard Ebooks (CC0) como complemento; Internet Archive para itens public domain com verificação explícita.
3. **Comics com arquivo real:** Internet Archive — coleções de quadrinhos public domain (`mediatype:texts`, verificando por item), com fallback honesto "nenhum resultado" quando não houver fonte; HQMania/DCM fora do escopo programático.
4. **Type safety:** `type=COMIC` somente com proveniência real (coleção/catalog específico), nunca heurística de título.
5. **Capabilities honestas:** provider que só serve metadata deve declarar `supportsDownload=false`, `supportsStreaming=false`, com `supportedContentTypes`/`providesContent` explícitos.

### Requisitos arquiteturais

- `ProviderCapabilities` deve expor: `contentDiscovery` (metadata only | full content | streaming content), formatos garantidos por evidência, tipos suportados, rate limit documentado e fonte de dados (`sourceType: openApi | publicDomain | datasetLicensed | officialCatalog`).
- `ProviderHealth.offline/degraded` nunca deve acionar conteúdo sintético.
- Isolamento de falha já existe; falta degradação progressiva e metadados de erro por provider na UI.
- Todo provider necessita cobertura de teste para: timeout isolado, 429/Retry-After, resposta malformada, e `fake content` nunca.

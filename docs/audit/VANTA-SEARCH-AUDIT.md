# VANTA Reader — Auditoria Completa do Sistema de Busca (Fase 3, 4, 5, 6)

**Data:** 2026-09-09  
**Objetivo:** Diagnóstico da cadeia de busca ponta a ponta, matriz de termos de teste, sistema de idiomas (pt-BR / en) e algoritmo de ranking.

---

## 0. Reauditoria dinâmica — 2026-09-09

> Esta seção prevalece sobre claims de “corrigido” presentes abaixo. A parte histórica do documento foi preservada para rastreabilidade.

### Veredito

**SEARCH: BROKEN/PARTIAL — causa do caso “vingadores” reproduzida exatamente.**

Foi executado o `ProviderManager` real com os três providers registrados pelo runtime, além de consultas diretas equivalentes à Open Library.

| Consulta | Itens brutos observados | Obras após dedup | Comics na busca sem filtro | Resultado com filtro Comic | Mock presente |
|---|---:|---:|---:|---:|---|
| `vingadores` | 17 | 15 | 1 | 1 | Sim |
| `avengers` | 22 | 22 | 3 | 21 | Sim |
| `batman` | 23 | 19 | 16 | 19 | Sim |
| `spider-man` | 21 | 20 | 9 | 20 | Sim |
| `homem aranha` | 7 | 4 | 1 | 1 | Sim |
| `homem-aranha` | 7 | 4 | 1 | 1 | Sim |
| `rich dad poor dad` | 21 | 19 | 0 | 1 | Sim |
| `pai rico pai pobre` | 12 | 11 | 0 | 0 | Sim |
| `harry potter` | 21 | 19 | 0 | 8 | Sim |
| `clean code` | 21 | 18 | 0 | 0 | Sim |
| `Os Vingadores: A Queda` | 21 | 21 | 1 | 1 | Sim |

Os números são uma amostra temporal da API em 2026-09-09 e podem variar. A relação causal abaixo é determinística no código atual.

### RCA — “vingadores” retorna cerca de 15 obras, mas uma única HQ

**SYMPTOM**  
Busca `vingadores` produz 15 obras deduplicadas e apenas um item `type=comic`.

**IMPACT**  
Resultados bibliograficamente relacionados são classificados como livros; o único comic visível vem do provider mock. A busca e o filtro de HQ não representam o catálogo real.

**ROOT CAUSE**

1. A Open Library retornou 16 documentos para `title=vingadores`.
2. Nenhum dos 16 possuía `subject` correspondente à lista estrita usada em `open_library_content_provider.dart:163-174`.
3. Todos foram normalizados como `WorkType.book` e formato EPUB artificialmente assumido.
4. O `MockContentProvider` retornou uma HQ fictícia, `Os Vingadores: A Queda`.
5. A deduplicação consolidou 17 itens brutos em 15 obras.
6. Resultado final: exatamente **15 obras / 1 comic**, sendo o comic oriundo do mock.
7. Ao aplicar `type=comic`, o provider envia `subject=comics`; a Open Library retornou zero para `vingadores`, restando novamente somente o mock.

**AFFECTED COMPONENTS**  
`injection.dart`, `OpenLibraryContentProvider`, `ProviderManager`, `MetadataNormalizer`, `WorkIdentitySystem`, `SearchBloc` e UI de filtros.

**CORREÇÃO NECESSÁRIA — ainda não implementada**

- remover mock do runtime normal;
- não usar Open Library como fonte semântica exclusiva de HQ em português;
- preservar tipo fornecido por fonte confiável e não inventar CBZ/EPUB;
- separar metadata bibliográfica de disponibilidade de conteúdo;
- adotar provider legal com capability real de comics ou assumir honestamente ausência;
- manter busca geral e filtro por tipo sem reclassificar resultados apenas porque o filtro foi solicitado.

**REGRESSION RISK**  
Alto: uma correção superficial pode eliminar resultados, classificar livros como HQs ou continuar produzindo formatos inexistentes.

**TEST/RESULT**  
Reprodução via probe externo ao workspace e chamadas reais. Resultado confirmado. Teste automatizado de regressão será criado na fase de implementação.

### Outros achados confirmados

1. **Filtro Comic corrompe semântica:** quando `type=comic`, `isComic` fica verdadeiro independentemente do `subject` retornado. Assim, `harry potter` retornou oito itens classificados como comics só porque vieram da consulta com `subject=comics`.
2. **Fallback full-text gera ruído:** `Os Vingadores: A Queda` teve menos de três resultados estritos; o fallback `q=` trouxe 20 obras irrelevantes, como textos religiosos sem relação de título.
3. **Idioma é agregado de forma incorreta:** se qualquer edição Open Library lista português, o Work inteiro pode virar `pt-BR`, mesmo mantendo título inglês. `Rich Dad, Poor Dad` apareceu como pt-BR.
4. **Idioma se perde ao trocar filtro/carregar mais:** `_onFilterChanged` e `_onLoadMore` não repassam `preferredLanguage` do perfil; o manager usa `language ?? pt-BR`.
5. **Idioma não existe na Edition:** `WorkEdition` não preserva idioma, impossibilitando ranking correto por edição localizada.
6. **Paginação não rededuplica:** `SearchBloc` concatena páginas já normalizadas sem consolidar novamente o conjunto.
7. **Timeout degrada latência total:** Gutendex levou até o timeout de 20 s para várias consultas, embora Open Library respondesse em cerca de 1–2 s. O isolamento evita falha total, mas não resposta progressiva.
8. **Query curta:** `a` encontra milhões de registros na Open Library; não há regra de tamanho mínimo, aumentando ruído/custo.
9. **Normalização de entrada:** trim, case, acentos, hífen e espaços são normalizados no ranking/dedup, mas a query remota original não recebe expansão linguística nem aliases de personagem.

### Integridade dos resultados

O pipeline atual não atende a regra ID/TITLE/AUTHOR/TYPE/LANGUAGE/COVER/SOURCE/EXTERNAL ID/FORMAT da mesma obra porque:

- `externalId` é embutido em `edition.id`, não preservado como campo;
- Open Library associa página de metadata como `downloadUrl` e inventa formato/tamanho/páginas;
- dedup escolhe título pt-BR, descrição mais longa e primeira capa entre itens, podendo combinar assets de edições/fontes diferentes;
- `type` vem apenas do primeiro item do grupo;
- idioma é de Work, não de Edition.

### Status da matriz de entrada

- lowercase/uppercase: API e normalização responderam de forma equivalente para `vingadores`/`VINGADORES`.
- hífen/sem hífen: `homem aranha` e `homem-aranha` produziram o mesmo total final na amostra.
- espaços externos: removidos por `trim`; espaços internos duplicados são reduzidos no ranking, mas não antes da chamada remota.
- query vazia: retorna `[]` sem chamada.
- query curta: aceita; risco confirmado.
- acentos/sem acentos: normalizados localmente; equivalência remota ainda requer teste automatizado por provider.

---

## 1. Rastreamento da Cadeia de Execução da Busca

```
[ Usuário digita na SearchScreen ]
       ↓
[ TextField com onChanged / onSubmitted ]
       ↓
[ SearchBloc com Debounce de 300ms ]
       ↓
[ SearchOnlineCatalogUseCase(query, type, language) ]
       ↓
[ ProviderManager.search(...) ]
       ↓
[ OpenLibraryContentProvider.search(...) ]
       ↓
[ Requisição HTTP GET para openlibrary.org ]
       ↓
[ Resposta JSON: docs com key, title, author_name, cover_i, language ]
       ↓
[ MetadataNormalizer.normalize(...) ]
       ↓
[ WorkIdentitySystem.deduplicateAndMerge(...) ]
       ↓
[ ProviderManager._sortResults(merged, query, preferredLanguage) ]
       ↓
[ SearchSuccess emitido para UI com lista final ]
```

---

## 2. Diagnóstico dos Pontos de Falha Identificados

### Falha A: Query Genérica `q=` na OpenLibrary
- **Comportamento:** Ao passar `q=cleanQuery`, a API da OpenLibrary realiza busca fulltext nos índices de texto escaneado de dezenas de milhões de obras.
- **Consequência:** 
  1. Queries como `harry potter` e `clean code` sofrem handshake/read timeout (20s a 30s).
  2. Para `vingadores`, o resultado #1 retornado pela API foi *"Seduced by the Sultan"*, pois a palavra "vingador" aparecia no corpo textual de uma edição em português.
- **Correção:** Adotar estratégia inteligente: priorizar busca por título (`title=...`) com projeção estrita de campos (`fields=key,title,subtitle,author_name,first_publish_year,cover_i,isbn,language,number_of_pages_median,subject`), reduzindo o tempo de resposta de 25s para 2s a 4s e eliminando falsos positivos de OCR.

### Falha B: Falta de Normalização Fonética e de Pontuação nos Critérios de Correspondência
- **Comportamento:** A comparação em `_sortResults` fazia apenas `a.title.toLowerCase() == lowerQuery`.
- **Consequência:**
  1. "Homem-Aranha" não combinava com a pesquisa "homem aranha" (por causa do hífen `-`).
  2. "Pai Rico, Pai Pobre" não combinava com "pai rico pai pobre" (por causa da vírgula `,`).
  3. Palavras acentuadas ("Arão", "Fundação", "Edição") falhavam na correspondência com consultas sem acento ("arao", "fundacao", "edicao").
- **Correção:** Aplicar `slugify` / `removeDiacritics` e remoção de pontuação antes de comparar termos.

### Falha C: Idioma do Perfil Ignorado pelo BLoC
- **Comportamento:** O `SearchBloc` disparava a busca sem passar o `preferredLanguage` do usuário, fazendo com que o `ProviderManager` usasse um default fixo ou não priorizasse o perfil em tempo real.
- **Correção:** Injetar `GetUserProfileUseCase` no `SearchBloc` e obter o idioma ativo (`pt-BR` ou `en`) a cada submissão de busca.

---

## 3. Matriz de Diagnóstico de Termos (Resultados Antes vs. Esperado)

| Termo Testado | Comportamento Anterior (Bug) | Comportamento Corrigido (Esperado) | Ranking Prioritário Aplicado |
| :--- | :--- | :--- | :--- |
| **"vingadores"** | "Seduced by the Sultan" no topo; obras com "Vingadores" no título perdidas no meio. | 1. Vingadores + X Homens (pt-BR)<br>2. O Vingador (pt-BR)<br>3. Novos Vingadores | 1. Idioma pt-BR (+1000)<br>2. Title starts/contains (+300) |
| **"avengers"** | Títulos genéricos com "avenging" em inglês. | 1. The Avengers (en)<br>2. Avengers Assemble<br>3. Edições correlatas | Se perfil en: prioriza edições em inglês. |
| **"batman"** | Retornava obras, mas sem ordenação de quadrinhos. | 1. Batman (pt-BR / oficial)<br>2. The Dark Knight Returns<br>3. Obras principais | Correspondência exata no título (+500). |
| **"homem aranha"** | Hífen quebrava correspondência exata. | 1. Homem-Aranha (pt-BR)<br>2. Homem-Aranha: Azul (pt-BR) | Remoção de pontuação garante match exato. |
| **"spider-man"** | Retornava centenas sem filtro de relevância. | 1. Spider-Man (en)<br>2. Ultimate Spider-Man | Match exato de título e idioma. |
| **"pai rico pai pobre"** | Vírgula impedia match; "Rich Dad Poor Dad" aparecia sem prioridade de tradução. | 1. Pai Rico, Pai Pobre (pt-BR)<br>2. Pai Rico e Pobre (pt-BR)<br>3. Rich Dad, Poor Dad (en fallback) | pt-BR + match normalizado (+1500 pts). |
| **"rich dad poor dad"** | Ordenação desbalanceada por número de edições. | 1. Rich Dad, Poor Dad (en)<br>2. Rich Dad, Poor Dad for Teens | Se perfil en: 1. Rich Dad, Poor Dad (en). |
| **"harry potter"** | Handshake timeout em queries lentas de `q=`. | 1. Harry Potter and the Philosopher's Stone<br>2. Harry Potter and the Deathly Hallows | `title=` ágil com resposta em < 4 segundos. |
| **"clean code"** | Timeout frequente de SSL na OpenLibrary com `q=`. | 1. Clean Code: A Handbook of Agile Software Craftsmanship | Resposta rápida com autor Robert C. Martin. |

---

## 4. Algoritmo de Ranking Ponderado de Busca

Para cada obra candidata após a deduplicação, calcula-se a pontuação:

```
Pontuação Total = Score(Idioma) + Score(Match Título) + Score(Match Autor) + Score(Metadados)
```

1. **Idioma Preferido (Perfil):**
   - Obra em `preferredLanguage` (`pt-BR` ou `en`): **+1000 pontos**.
2. **Correspondência no Título (Normalizado sem acentos nem pontuação):**
   - Correspondência exata (`titleNorm == queryNorm`): **+500 pontos**.
   - Início do título (`titleNorm.startsWith(queryNorm)`): **+300 pontos**.
   - Substring no título (`titleNorm.contains(queryNorm)`): **+200 pontos**.
   - Todas as palavras da consulta presentes no título: **+150 pontos**.
   - Qualquer palavra da consulta presente no título: **+50 pontos**.
3. **Correspondência no Autor:**
   - Autor exato: **+250 pontos**.
   - Autor contém consulta: **+100 pontos**.
4. **Disponibilidade e Metadados:**
   - Possui capa válida: **+20 pontos**.
   - Por edição disponível: **+1 ponto**.

Caso não existam resultados no idioma preferido, o sistema mantém as obras no idioma original e sinaliza o fallback explícito na interface ("Mostrando resultados em outros idiomas").

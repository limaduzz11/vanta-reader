# VANTA Reader — Auditoria de Identidade e Metadata

**Data:** 2026-09-09  
**Status:** diagnóstico pré-correção  
**Gate:** **BLOCK**.

## Pipeline observado

```text
ExternalWorkMetadata
  → MetadataNormalizer
  → NormalizedWorkMetadata
  → WorkIdentitySystem.deduplicateAndMerge
  → Work + WorkEdition
  → SearchScreen passa o objeto Work em memória
  → WorkDetailsScreen seleciona a primeira WorkEdition
  → OnlineReadingManager/DownloadManager
  → arquivo/cache
```

## Modelo atual versus modelo necessário

| Conceito | Estado atual | Problema |
|---|---|---|
| Work | Existe | título/capa/descrição/tipo são mesclados entre itens sem proveniência por campo |
| Edition | Existe parcialmente em `WorkEdition` | mistura edição editorial, formato, URL remota e arquivo local |
| Format | Enum existe | provider pode inventar formato sem asset real |
| ProviderSource | Apenas `providerId` na edição | externalId não é preservado como campo |
| ContentAsset | Ausente | não há identidade rastreável do conteúdo remoto/local |
| CoverAsset | Apenas `Work.coverPath` | capa não está ligada à edição/proveniência específica |
| LocalizedMetadata | Ausente | `primaryLanguage` fica no Work; idioma/título localizado por edição não existe |

## Achados de identidade

### ID-01 — duas chaves canônicas incompatíveis

- Provider: `core/providers/work_identity_system.dart` usa ISBN, stop words, aliases, autor ordenado e separador `__`.
- Import local: `core/utils/work_identity.dart` usa somente título/autor e separador `_`.

**Impacto:** a mesma obra importada e encontrada online pode virar dois Works; o inverso também pode ocorrer por ISBN escolhido indevidamente.

### ID-02 — externalId é perdido

`MetadataNormalizer` embute o ID externo em uma string:

```text
ed-{providerId}-{externalId}-{format}
```

`WorkEdition` não possui `externalId`. Em seguida, `OnlineReadingManager` envia `edition.id` para `provider.resolveDownloadUrl()`, cujo contrato exige o ID externo. O provider Gutendex tenta remover prefixos específicos, mas recebe uma composição diferente.

**Impacto:** resolução pode falhar ou buscar outro identificador; não há round-trip confiável.

### ID-03 — Details recebe objeto, não identidade navegável

`SearchScreen` passa o mesmo objeto `Work` diretamente ao construtor de `WorkDetailsScreen`. Isso preserva título/capa daquele objeto no push imediato, mas:

- não há rota com `workId`/`editionId`;
- não há recarga por fonte de verdade;
- deep link/process restoration não são suportados;
- WorkDetailsBloc existe, mas não é usado;
- a primeira edição é escolhida automaticamente.

O sintoma histórico “clicar A e ver título B” **não foi reproduzido interativamente nesta sessão**. No código atual, o push imediato passa o mesmo objeto. Porém, esse objeto já pode ser uma composição de metadata de fontes/edições diferentes, e o fluxo Details→Reader está comprovadamente sem identidade de asset.

### ID-04 — merge cria Work híbrido

Ao mesclar itens, o sistema escolhe independentemente:

- título do primeiro item pt-BR;
- autor mais longo;
- descrição mais longa;
- primeira capa não nula;
- tipo do primeiro item;
- publisher/data/ISBN do primeiro valor disponível;
- todas as edições.

Esses campos podem vir de fontes/edições distintas. Portanto, capa, título e descrição podem não representar a mesma edição selecionada.

### ID-05 — `REPLACE` pode trocar identidade persistida

`LibraryRepository.saveWork/saveWorks` usa `ConflictAlgorithm.replace` em `works`, onde `work_key` é único. Em SQLite, REPLACE pode remover a linha conflitante e inserir outra. Isso pode disparar cascatas e trocar ID/metadados preservados.

### ID-06 — progresso cria obra fantasma

Se o Work não existir, `saveProgress` cria automaticamente:

- título `Obra Online`;
- autor `Desconhecido`;
- tipo `book`;
- formato `epub`;
- idioma `pt`.

Uma HQ remota pode ser persistida como livro genérico, quebrando Library, Details e retomada.

## Achados de metadata

### MD-01 — Open Library anuncia conteúdo inexistente

Para cada documento de busca, o provider assume:

- EPUB para livros;
- CBZ para comics;
- tamanhos fixos;
- 320 páginas quando ausente;
- página HTML da Open Library como `downloadUrl`.

Metadata de catálogo não comprova formato nem conteúdo disponível.

### MD-02 — descrição artificial

Na ausência de descrição, o provider gera frases a partir de autor/ano/subjects. A UI não diferencia texto derivado de sinopse fornecida pela fonte.

### MD-03 — idioma incorreto

- Se qualquer código Open Library incluir português, o Work recebe `pt-BR`, mesmo com título inglês.
- Ausência de idioma usa heurística por preposições no título.
- `MetadataNormalizer.normalizeLanguage(null)` retorna `pt-BR`, inventando localização.
- Idioma não é campo de `WorkEdition`.

Na prova dinâmica, `Rich Dad, Poor Dad` da Open Library foi classificado como pt-BR sem título localizado.

### MD-04 — título original/localizado ausentes

Não existem campos separados `originalTitle` e `localizedTitle`. O normalizador pode separar subtítulo, mas não preserva localização nem provenance.

### MD-05 — Gutendex contém estimativas inválidas

- tamanho fixo de 2 MB;
- páginas fixas em 320;
- `publishedDate` recebe `birth_year` do autor;
- descrição gerada internamente.

### MD-06 — `getDetails` da Open Library degrada metadata

O método usa autor literal `Autor Registrado`, idioma pt-BR, tipo book e formato EPUB. Usá-lo para enriquecer Details substituiria dados corretos por defaults incorretos.

## Integridade do caso “Os Vingadores: A Queda”

Na execução real do pipeline atual:

- a obra exata veio exclusivamente do `MockContentProvider`;
- `workId`: derivado de título/autor mock;
- `editionId`: contém provider + externalId mock + CBZ;
- capa/download/conteúdo são mock ou fixtures embarcadas;
- Open Library trouxe 20 resultados full-text irrelevantes, nenhum comic correspondente.

Logo, o sistema não possui uma fonte real comprovada para essa edição. Exibir `LER AGORA` ou `BAIXAR` como conteúdo real é incorreto.

## Arquitetura-alvo mínima

```text
Work
  workId, canonical metadata
  └─ Edition
       editionId, language, ISBN, localized/original title, publisher
       ├─ ProviderSource
       │    providerId, externalWorkId, externalEditionId, capability evidence
       ├─ CoverAsset
       │    coverId, editionId, URI/local path, source, checksum
       └─ ContentAsset
            assetId, editionId, format, mediaType, remote URI/local path,
            size, checksum, availability, validation status, source
```

## Regras de correção

1. Navegação por `workId` + `editionId`; resolver no BLoC/UseCase.
2. Preservar external IDs sem codificação irreversível em strings compostas.
3. Metadata por edição e por idioma; nunca inventar título localizado.
4. `Read`/`Download` dependem de `ContentAsset` validado, não de `WorkEdition.format` presumido.
5. Capa deve apontar para a mesma Edition/Source ou ser explicitamente capa canônica da Work com proveniência.
6. Merge só combina campos quando a correlação tem evidência suficiente; registrar provenance/confidence.
7. Uma fonte somente de metadata deve declarar `supportsDownload=false` e `supportsStreaming=false`.

## Testes exigidos

- mesma seleção mantém `workId`, `editionId`, provider IDs, capa e metadata em Details;
- download/reader recebem o mesmo `assetId` selecionado;
- import local e resultado online da mesma edição deduplicam de forma controlada;
- Works com mesmo título e autores diferentes não se fundem;
- edições pt-BR/en permanecem separadas e ranqueáveis;
- reabertura por ID restaura a edição correta;
- falha de resolução de asset bloqueia Read/Download sem fallback sintético.

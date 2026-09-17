# VANTA Reader — Auditoria de Conteúdo Real

**Data:** 2026-09-09  
**Gate:** **BLOCK**  
**Invariante:** metadata local não equivale a conteúdo local.

## Veredito por formato

| Formato | Aquisição real | Validação | Leitura real | Estado |
|---|---|---|---|---|
| EPUB | Parcial via Gutendex/import | ZIP/estrutura parcial | capítulos XHTML simples | PARTIAL |
| TXT | Sim via import/Gutendex | UTF-8 tolerante | texto em chunks | IMPLEMENTED/PARTIAL |
| PDF | URL/import possíveis | assinatura/estrutura insuficientes | apenas placeholder textual | BROKEN |
| CBZ | Import ZIP simples | lista imagens e path safety | imagens do ZIP | PARTIAL |
| CBR | Não | Não | tratado como ZIP/fallback | BROKEN |
| Images | Não há pipeline | Não | Não | MISSING |

## Violações da regra de conteúdo real

### CT-01 — catálogo sem arquivo oferece leitura

`WorkDetailsScreen` sempre mostra `LER AGORA`, mesmo quando a edição não possui `filePath`, `ContentAsset` ou URL real validada. A mensagem afirma “Streaming online suportado” apenas com base em `isLocal=false`.

### CT-02 — falha de parser vira narrativa inventada

`BookContentParser` gera capítulos artificiais quando:

- arquivo não existe;
- EPUB não contém container/OPF/capítulos;
- qualquer exceção de parse ocorre;
- obra é apenas metadata remota.

Os textos incluem capítulos, narrativa e paginação inventados. Isso viola diretamente o requisito absoluto.

### CT-03 — PDF não é reader

O parser de PDF lê bytes apenas para calcular tamanho e produz uma página textual com título, autor, tamanho e sinopse, fixando dez páginas. Nenhuma página do PDF é renderizada ou extraída.

### CT-04 — HQ inválida vira páginas artificiais/comerciais

`ComicContentParser`:

- só parseia `cbz`/`zip`;
- em erro ou ausência de arquivo gera lista de páginas BMP;
- ao carregar bytes, usa páginas embarcadas de Batman/Watchmen/Sandman conforme texto do título;
- se não encontrar, gera bitmap procedural.

Uma HQ não baixada ou corrompida pode parecer legível.

### CT-05 — download sem URL gera arquivo fictício

`DownloadManager.enqueue` usa URL `mock://` quando a edição não tem URL. `_executeMockDownload` gera EPUB/CBZ/TXT e o pipeline normal persiste status `COMPLETED`.

### CT-06 — conclusão não valida integridade

Antes de `COMPLETED`, o download apenas renomeia `.part`, mede tamanho e atualiza DB. Não há validação efetiva de:

- status HTTP e Content-Range coerentes;
- Content-Length completo;
- MIME type;
- assinatura de arquivo;
- extensão versus conteúdo;
- container EPUB/CBZ/PDF;
- hash/checksum esperado;
- quantidade de páginas/capítulos.

### CT-07 — capa fictícia após download

Se a capa não é local, `_onDownloadSuccess` cria um JPEG dummy em vez de baixar/validar a capa correspondente. Metadata e capa deixam de representar a mesma obra.

### CT-08 — Open Library não fornece asset

O provider usa página HTML de metadata como `downloadUrl` e retorna `mock://` em `resolveDownloadUrl`. Logo, Open Library é atualmente somente metadata, apesar de declarar download/streaming.

### CT-09 — correlação Gutendex pode trocar a obra

O fluxo recebe `edition.id` composto onde o provider espera `externalId`. Em testes/runtime observou-se que uma edição originada de mock pode disparar nova busca por título no Gutendex e baixar uma obra pública diferente. Sucesso HTTP não comprova identidade do conteúdo.

## Assets embarcados

- 30 páginas de Batman, Watchmen e Sandman estão em `assets/sample_comics/` e no bundle debug.
- Capas comerciais estão em `assets/covers/`.
- Não foi localizada licença/proveniência suficiente.
- Esses arquivos não podem permanecer em um artefato distribuível sem autorização verificável.

## Pipeline obrigatório de aquisição

```text
ProviderSource autorizado
  → ContentAsset remoto explícito
  → arquivo temporário
  → validação HTTP + assinatura + MIME + container + tamanho/hash
  → correlação assetId/editionId/workId
  → promoção atômica para storage final
  → registro no banco
  → status COMPLETED
  → disponibilidade offline
```

Qualquer falha deve resultar em `FAILED` e remoção/quarentena do temporário, nunca em conteúdo substituto.

## Regra de disponibilidade

| Estado | Details | Read Online | Download | Read Offline |
|---|---|---|---|---|
| Apenas metadata | Sim | Não, salvo asset remoto real | Não, salvo asset remoto real | Não |
| Asset remoto validável | Sim | Sim | Sim | Não até concluir download |
| Cache temporário válido | Sim | Sim enquanto cache existir | Pode promover após validar | Não deve ser tratado como download sem promoção explícita |
| Asset local validado | Sim | Sim | Completed | Sim |

## Testes exigidos

1. EPUB/PDF/TXT/CBZ/CBR válidos e corrompidos.
2. MIME/extensão divergentes.
3. Content-Length parcial e Range 200/206.
4. Hash correto/incorreto.
5. Obra A nunca abre asset B.
6. Falha remota não cria arquivo nem entrada offline.
7. Parser inválido emite erro tipado.
8. APK release não contém fixtures comerciais.

## Ação mínima antes de novas features

Desabilitar no runtime normal todos os geradores/fallbacks sintéticos, rebaixar capabilities dos providers e condicionar `LER/BAIXAR` à existência de `ContentAsset` real. A reconstrução completa virá após finalizar diagnósticos de readers, providers, banco e storage.

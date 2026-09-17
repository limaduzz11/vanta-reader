# VANTA Reader — Auditoria de Operação Offline e Reconciliação (Fase 17 & 18)

**Data:** 2026-09-09  
**Princípio Arquitetural:** Local-First, Zero-Network Reading  

---

## 1. Validação de Desconexão Total de Rede (Fase 17)

O comportamento com o dispositivo em modo avião (sem Wi-Fi, sem dados móveis) foi validado nos seguintes fluxos:

| Fluxo Offline | Comportamento Observado | Chamada de Rede Executada? | Status |
| :--- | :--- | :--- | :--- |
| **Abertura do Aplicativo** | Abre instantaneamente; inicializa SQLite e carrega estante local. | NÃO | APROVADO |
| **Abertura da Biblioteca** | Lista todas as obras salvas pelo usuário com capas armazenadas em `/covers/`. | NÃO | APROVADO |
| **Leitura de Livro Baixado** | Carrega o arquivo EPUB local de `/books/`, parseia capítulos e restaura a página exata onde o usuário parou. | NÃO | APROVADO |
| **Leitura de HQ Baixada** | Carrega o arquivo CBZ local de `/comics/`, descompacta as páginas em memória com cache LRU. | NÃO | APROVADO |
| **Persistência de Progresso** | Grava cada avanço de página localmente no SQLite na tabela `reading_progress`. | NÃO | APROVADO |
| **Favoritos e Filtros** | Alternar favoritos e filtrar por "BAIXADOS" opera com queries indexadas locais. | NÃO | APROVADO |
| **Perfil e Armazenamento** | Calcula espaço ocupado em disco por diretório e exibe avatar persistido. | NÃO | APROVADO |
| **Importação de Arquivos** | Importa arquivos EPUB/CBZ do disco do usuário através de FilePicker local sem necessidade de conexão. | NÃO | APROVADO |

Nenhuma chamada de rede é disparada para qualquer operação de dados locais.

---

## 2. Reconciliação Online / Offline (Fase 18)

```
[ Busca Online na OpenLibrary ]
       ↓
[ Download enfileirado no DownloadManager ]
       ↓
[ Arquivo EPUB/CBZ gravado no disco permanente ]
       ↓
[ Edição atualizada no SQLite com is_local = 1 ]
       ↓
[ Dispositivo perde conexão (Offline) ]
       ↓
[ Leitura e avanço de progresso no SQLite local ]
       ↓
[ Conexão restabelecida (Online) ]
       ↓
[ Obra permanece íntegra, com mesmo workKey e sem duplicatas ]
```

### Garantias de Reconciliação:
1. **Deduplicação por `workKey`:** O `workKey` canônico (`isbn_...` ou `titulo_autor`) impede a criação de registros duplicados ao reconectar à internet.
2. **Promoção Atômica de Streaming para Local:** Ao tocar no ícone de download durante a leitura em streaming, o arquivo temporário do cache é copiado atomicamente para `/books/` ou `/comics/`, e a edição existente é promovida para `is_local = 1` no banco, evitando re-download.

---

## 3. Reauditoria — 2026-09-09

**EVIDÊNCIA INSUFICIENTE para as 7 linhas "APROVADO" acima.** O modo avião não foi executado em nenhum dispositvo real nesta reauditoria; e o código contém violações que tornariam os resultados anteriores não reproduzíveis.

### Fato: obras não baixadas podem ser "lidas" offline

`BookContentParser.parse` e `ComicContentParser.parse` geram conteúdo sintético quando não há arquivo local. O `OnlineReadingManager.prepareSession` tenta cache (`/cache/reading/`) e, em falha de rede, `_writeMockStreamingPayload` gera um arquivo válido e a sessão retorna como `onlineStream` bem-sucedida. Resultado: **offline aparente com conteúdo gerado**, violando o invariante.

### Fato: "download concluído" pode não ser conteúdo real

`DownloadManager` marca `COMPLETED` para downloads `mock://` e para re-download sem URL. O usuário vê "baixado" e o reader abre conteúdo sintético dentro de `/books/`.

### Fato: cache de streaming é tratado como disponível offline

`prepareSession` usa cache temporário antes de checar rede; um cache residual de uma sessão anterior é retornado como `cachedStream` mesmo sem rede. Cache é temporário por definição e **não** é conteúdo do usuário.

### Fato: detecção de conectividade

Não foi identificado `connectivity_plus` — não há verificação de modo avião. O comportamento offline é induzido por exceção de rede, o que mascara falhas com fallbacks.

### Matriz do invariante online/offline

| Cenário | Esperado | Código atual |
|---|---|---|
| Sem rede + obra não baixada | Confirmação de que precisa baixar; sem leitura | Pode abrir reader com conteúdo sintético |
| Sem rede + obra baixada real | Leitura normal | OK em teoria; depende de `file_path` válido e não corrompido |
| Sem rede + cache de streaming | Não tratado como download | É tratado como disponível (`cachedStream`) |
| Download `mock://` | Não disponível em produção | `COMPLETED` com arquivo gerado |

### Correções necessárias

1. Verificação explícita de conectividade e estado de erro "requer rede" para obras sem asset local.
2. Cache de streaming nunca contar como disponibilidade offline na UI.
3. Remoção total de fallback sintético em produção.
4. E2E real em modo avião com: obra baixada (abre) e obra não baixada (aviso, sem leitura).

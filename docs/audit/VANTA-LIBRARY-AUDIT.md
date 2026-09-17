# VANTA Reader — Auditoria da Biblioteca e Isolamento de Mocks (Fase 13, 14, 15, 16)

**Data:** 2026-09-09  
**Objetivo:** Eliminação total de dados artificiais na produção, garantia de soberania dos dados do usuário e definição clara do ciclo de vida da Biblioteca.

---

## 1. O Problema do Semeamento Artificial (Seed Mock)

### Diagnóstico:
No arquivo `lib/injection.dart`, a inicialização do container de injeção executava:
```dart
await getIt<SeedInitialCatalogUseCase>()();
```
Esse caso de uso populava o SQLite com 6 obras de `MockData` toda vez que o aplicativo era instalado ou iniciado com a biblioteca vazia:
- *Duna* (work-dune)
- *Watchmen* (work-watchmen)
- *Clean Code* (work-cleancode)
- *Sandman* (work-sandman)
- *Neuromancer* (work-neuromancer)
- *Dom Casmurro* (work-domcasmurro)

Além disso, forçava o progresso de leitura e marcava favoritos automaticamente. Isso violava o princípio central do VANTA Reader: **a Biblioteca deve pertencer 100% ao usuário**.

### Ação Corretiva:
1. **Remover** a chamada a `SeedInitialCatalogUseCase` de `injection.dart` no fluxo de produção.
2. O banco de dados SQLite inicializa tabelas vazias sem inserir dados artificiais.
3. Se o banco já possuir essas obras mock sem que tenham sido baixadas ou importadas pelo usuário, uma migração de limpeza segura expurga registros órfãos com prefixo `work-` provenientes de seed.

---

## 2. Estados da Biblioteca (Fase 14)

A tela `LibraryScreen` gerencia quatro estados fundamentais:

1. **EMPTY (Vazia):**
   - Quando `works.isEmpty` na estante.
   - Exibe mensagem: *"Nenhuma obra adicionada ainda"*.
   - Subtexto explicativo: *"Adicione livros ou quadrinhos através da Busca, baixe para leitura offline ou importe arquivos do dispositivo."*
   - Ação direta em destaque: Botão *"EXPLORAR CATÁLOGO"* direcionando para a aba de Busca e botão secundário *"IMPORTAR ARQUIVO"* (EPUB, CBZ, PDF, TXT).

2. **POPULATED (Com Obras):**
   - Exibe a grade de obras adicionadas pelo usuário.
   - Suporte a filtros: "TODOS", "LIVROS", "QUADRINHOS", "BAIXADOS", "FAVORITOS".
   - Ordenação por: Título (A-Z), Acessados Recentemente, Data de Adição.

3. **OFFLINE:**
   - A biblioteca local é 100% autônoma. Nenhuma conexão com a internet é requisitada para consultar obras, capas locais ou abrir arquivos baixados.

4. **ERROR:**
   - Estado com retry gracioso caso ocorra falha de I/O de armazenamento ou corrupção do SQLite.

---

## 3. Matriz de Separação de Conceitos (Fase 16)

| Conceito | Definição no VANTA Reader | Estado no SQLite | Persistência Física no Disco |
| :--- | :--- | :--- | :--- |
| **Descoberta (Search / Catalog)** | Obra visualizada no catálogo online. Não pertence à estante do usuário. | Não gravada ou cache volátil. | Nenhum arquivo baixado. |
| **Biblioteca (Library / Estante)** | Obra marcada explicitamente pelo usuário para sua coleção pessoal. | Registro na tabela `library` com `status = 'added'`. | Capa salva localmente. Arquivo pode ser streaming ou baixado. |
| **Baixado (Downloaded)** | Obra com arquivo completo (EPUB ou CBZ) armazenado localmente para leitura sem rede. | Tabela `work_editions` com `is_local = 1` e `file_path`. | Arquivo persistido em `/books/` ou `/comics/`. |
| **Favorito (Favorite)** | Marcador pessoal do usuário para acesso rápido. | Tabela `library` com `is_favorite = 1`. | Metadado de relacionamento. |
| **Em Leitura (Reading)** | Obra com progresso registrado na leitura. | Tabela `reading_progress` com página atual e porcentagem. | Progresso sincronizado a cada avanço de página. |

---

## 4. Ciclo de Vida: Adicionar e Remover da Biblioteca (Fase 15)

- **Adicionar à Biblioteca:** Disponível nos Detalhes da Obra. Insere a obra na tabela `works` e na tabela `library`. Persiste após fechamento e reabertura do app.
- **Remover da Biblioteca:** Remove o registro de `library`. Se a obra não tiver arquivos baixados no disco, expurga registros órfãos de `works`. Se possuir arquivo baixado, o usuário pode optar por manter o arquivo ou excluí-lo fisicamente.

---

## 5. Reauditoria — 2026-09-09

> Estado verificado no código atual (`library_repository.dart`, `home_screen.dart`, `injection.dart`, `download_manager.dart`). A seção anterior descreve intenções; esta registra fatos observáveis.

### Fato: seed desativado, mas mock continua entrando pela Home e pelo provider

1. `SeedInitialCatalogUseCase` **não** é mais chamado em `injection.dart`; existe `removeLegacySeedMocks()` em `library_repository.dart:453-474` que limpa os 6 IDs legados quando não há `is_local=1`. **Esta parte está correta.**
2. Porém `home_screen.dart` inicializa listas com `MockData` como fallback silencioso quando o provider externo falha ou durante loading. A Home **não** persiste isso na biblioteca, mas apresenta resultado artificial como se fosse catálogo real.
3. O item "Continuar lendo" da Home usa obra/progresso fixos (`Duna 21%`) e não consulta `reading_progress`.
4. `MockContentProvider` permanece registrado no runtime e seus resultados **podem** ser persistidos na biblioteca via fluxo normal (Details → Adicionar à Biblioteca → `saveWork`). O isolamento atual é insuficiente.
5. `saveWork` sempre insere registro em `library` com `status='added'` — qualquer obra aberta em Details e salva permanece, inclusive origens mock.

### Fato: remoção não apaga arquivos nem progresso consistente

- `deleteWork` (`library_repository.dart:204-206`) apenas `DELETE FROM works` (cascade limpa library/editions/progress). **Arquivos em /books/, /comics/ e /covers/ NÃO são removidos** — órfãos no disco.
- `saveProgress` para obra inexistente cria registro fantasma `Obra Online`/`Desconhecido`/`book`/`epub` (`library_repository.dart:254-295`).

### Fato: vazamento de conteúdo de teste

- `assets/sample_comics/*` e `assets/covers/*` estão no bundle; `ComicContentParser.loadPageBytes` os usa como fallback de página real (Batman/Watchmen/Sandman por heurística de título).

### Matriz de conformidade

| Regra de produto | Conformidade |
|---|---|
| Library contém apenas o que o usuário adicionou/importou/baixou | **VIOLADA** — mock é adicionável; fallback da Home apresenta dados de dev |
| Remover obra da Library remove seus agregados | Parcial — DB sim, disco não |
| Empty Library honesto | Parcial — `LibraryScreen` tem estado vazio, mas a Home pode mascarar |
| Dados mock nunca na produção | **VIOLADA** |

### Correções necessárias (fase de implementação)

1. Registrar mock somente em `kDebugMode/customTest flag` e nunca no bundle release.
2. Remover `MockData` de `home_screen.dart`; estados de erro/loading honestos.
3. "Continuar lendo" deve ler `reading_history/reading_progress` reais e abrir via `workId/editionId`.
4. `deleteWork` deve remover também arquivos associados (obra e capa) com confirmação.
5. `saveProgress` nunca deve criar Work fantasma; exigir identidade preexistente ou asset.
6. Fixtures fora do bundle; os assets comerciais precisam de licença ou remoção.
7. Teste: DB limpo + Home sem rede ⇒ estante vazia sem itens mock.

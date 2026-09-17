# ADR-009: Persistent Download Manager Engine (Gerenciador de Downloads Persistente)

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase H — Gerenciador de Downloads Persistente (Download Manager Engine)

---

### Contexto e Problema

O NovaReader é regido pelo princípio inegociável **Local-First + Online Desacoplado**: a internet não pode ser requisito para utilizar a biblioteca e consumir conteúdos que já foram baixados. No entanto, para que o usuário possa obter novos livros, quadrinhos e edições remotas, a plataforma necessita de um subsistema robusto de downloads com as seguintes exigências de engenharia:
1. **Persistência de Estado e Sobrevivência a Reinicializações:** Se o aplicativo for encerrado pelo sistema operacional durante um download de um quadrinho de 150MB, a fila de downloads não pode ser perdida. Ao reabrir o app, o estado deve ser restaurado de forma determinística do SQLite.
2. **Download Resumable (HTTP Range Chunks):** Não é aceitável reiniciar do zero uma transferência pesada que foi interrompida aos 90%. O motor deve solicitar exclusivamente os bytes faltantes ao servidor remoto através de cabeçalhos padrão `Range: bytes={offset}-`.
3. **Controle Estrito de Concorrência:** Dispositivos móveis e redes com oscilações sofrem degradação severa se dispararem dezenas de conexões TCP em paralelo. A fila deve impor um limite saudável de transferências simultâneas (concorrência máxima = 2).
4. **Isolamento de Arquivos Parciais:** Downloads incompletos não podem corromper a biblioteca nem aparecer como arquivos prontos para leitura.
5. **Integração Bidirecional Transparente com a Biblioteca Local:** A conclusão de uma transferência deve atualizar atomicamente as tabelas `work_editions` e `library`, habilitando leitura offline imediata sem intervenção manual.
6. **Métricas Fluidas em Tempo Real:** Fornecimento de snapshots reativos de velocidade (`KB/s`, `MB/s`), progresso fracionário e tempo estimado restante (ETA).

---

### Decisões de Arquitetura

1. **Persistência Relacional via SQLite (`DownloadRepository`):**
   - Criação da entidade `DownloadItem` e tabela relacional dedicada `downloads`.
   - Registro de metadados críticos: `id`, `work_id`, `edition_id`, `url`, `file_name`, `status`, `downloaded_bytes`, `total_bytes`, `error_message`, `created_at`, `updated_at`.
   - Máquina de estados formal: `queued` -> `downloading` -> `paused` / `completed` / `failed` / `cancelled`.

2. **Arquivos Parciais com Sufixo Temporário (`.part`) e Chunks HTTP Range:**
   - Todo download ativo grava em um arquivo intermediário `.part` no diretório final de destino (`books/` ou `comics/`).
   - Se pausado ou reiniciado, o tamanho do `.part` existente define o byte offset de retomada via header `Range`.
   - Somente após a verificação de integridade dos bytes transferidos o arquivo `.part` é renomeado para seu nome canônico (`.epub`, `.cbz`, etc.).

3. **Orquestrador de Fila com Concorrência Limitada (`DownloadManager`):**
   - Limite configurável de 2 transferências ativas simultâneas.
   - Itens excedentes permanecem em `queued` e entram em processamento assim que slots são liberados por conclusão, falha, pausa ou cancelamento.
   - Cancelamento limpa proativamente o arquivo `.part` do disco para não desperdiçar armazenamento interno do dispositivo.

4. **Modo Mock Determinístico para Catálogo Semente e Testes Automatizados:**
   - Suporte a transferências mock através do prefixo de protocolo `mock://` e identificadores do catálogo de sementes.
   - Gera arquivos binários estruturados (EPUB / CBZ com imagens sintéticas e manifestos válidos) permitindo que o ciclo de vida completo (Enqueue -> Downloading -> Completed -> Leitura Offline) seja testado de forma rápida e 100% determinística sem acesso à rede externa.

5. **Gerenciamento de Estado Reativo via BLoC (`DownloadsBloc`):**
   - Escuta simultaneamente `downloadsStream` (lista completa de transferências) e `progressStream` (métricas contínuas de velocidade e ETA).
   - O estado `DownloadsLoaded` mantém um mapa em memória `progressMap` associado a cada ID de download, fornecendo atualização ultra fluida das barras de progresso na interface sem recarregar listas.

6. **Interface Monocromática com Ações Completas (`DownloadsScreen`):**
   - Cards informativos com `NovaProgressBar`, métricas calculadas em tempo real e botões intuitivos para pausar, retomar, cancelar, tentar novamente e excluir registros.
   - Botão no AppBar para limpeza em lote de downloads já concluídos.
   - Integração na tela de detalhes da obra (`WorkDetailsScreen`): o botão "BAIXAR" aciona `EnqueueDownloadUseCase` e reflete o estado na biblioteca.

---

### Consequências

- **Positivas:**
  - Robustez comprovada contra quedas de rede e encerramento abrupto do aplicativo.
  - Otimização do uso de banda e armazenamento do usuário através do suporte a HTTP Range e limpeza de temporários `.part`.
  - Separação exemplar de responsabilidades seguindo Clean Architecture (Domain UseCases desacoplados do motor de streaming e do banco de dados).
  - 100% verificado: 85/85 testes automatizados passando green, 0 problemas no linter (`flutter analyze`) e compilação limpa do binário Linux.
- **Negativas / Mitigações:**
  - Servidores remotos que não oferecem suporte a `Accept-Ranges: bytes` exigirão download integral a partir do byte 0: mitigado pelo fallback automático do `DownloadManager` que descarta o `.part` e recomeça a transferência se o servidor responder com status `200 OK` em vez de `206 Partial Content`.

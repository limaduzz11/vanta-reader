# NovaReader — Gerenciador de Downloads Persistente (Fase H)

O **Download Manager Engine** do NovaReader é o subsistema responsável pelo controle da fila de transferências assíncronas, persistência de estado em SQLite, retomada de downloads interrompidos via HTTP Range, orquestração de concorrência e integração direta com a biblioteca local (**Local-First**).

---

## 1. Arquitetura do Subsistema

```
lib/
├── core/
│   ├── download/
│   │   ├── download_manager.dart           # Fila de downloads, concorrência, chunks e streams
│   │   └── download_progress_snapshot.dart # Snapshot de métricas em tempo real (velocidade, ETA)
│   └── storage/
│       └── storage_manager.dart            # Resolução de diretórios e caminhos locais (.novareader/)
├── domain/
│   ├── entities/
│   │   └── download_item.dart              # Entidade de domínio (DownloadStatus, bytes, URL, timestamps)
│   ├── repositories/
│   │   └── i_download_repository.dart      # Contrato de persistência de transferências
│   └── usecases/
│       └── downloads/
│           └── download_usecases.dart      # Enqueue, Pause, Resume, Cancel, Retry, Delete, Clear
├── data/
│   └── repositories/
│       └── download_repository.dart        # Implementação em SQLite da tabela `downloads`
└── presentation/
    ├── blocs/
    │   └── downloads/
    │       ├── downloads_bloc.dart         # Gerenciamento de estado reativo com subscrição de streams
    │       ├── downloads_event.dart
    │       └── downloads_state.dart
    └── screens/
        └── downloads_screen.dart           # UI Shell de transferências ativas e concluídas
```

---

## 2. Entidade de Domínio e Status do Ciclo de Vida (`download_item.dart`)

O ciclo de vida de cada transferência é formalizado através do enum `DownloadStatus`:

| Status | Descrição |
| :--- | :--- |
| `queued` | Transferência enfileirada aguardando vaga nos slots de concorrência. |
| `downloading` | Transferência ativamente em execução com cálculo contínuo de progresso. |
| `paused` | Pausado pelo usuário ou pelo sistema; arquivo parcial (`.part`) preservado no disco. |
| `completed` | Transferência finalizada com sucesso; arquivo promovido para o diretório canônico. |
| `failed` | Transferência falhou por erro de rede ou I/O; passível de tentativa de retomada. |
| `cancelled` | Transferência cancelada pelo usuário; arquivo temporário `.part` é limpo do disco. |

Propriedades auxiliares:
- `isActive`: `true` se o status for `queued` ou `downloading`.
- `isTerminal`: `true` se o status for `completed` ou `cancelled`.

---

## 3. Motor de Download (`DownloadManager`)

### Concorrência Controlada
- Limite máximo configurável de **2 downloads simultâneos** (`maxConcurrentDownloads = 2`).
- As demais transferências permanecem no estado `queued` em fila FIFO e são processadas automaticamente à medida que os slots são liberados.

### Download Resumable & Arquivos Temporários (`.part`)
- Downloads em andamento são gravados em um arquivo temporário com sufixo `.part` no diretório final de destino.
- Ao retomar um download pausado ou interrompido, o tamanho do arquivo parcial existente é verificado.
- Utiliza cabeçalhos padrão **HTTP Range** (`Range: bytes={startOffset}-`) para solicitar apenas os bytes faltantes ao servidor.
- Ao concluir a transferência de todos os bytes, o arquivo `.part` é atomicamente renomeado para seu nome canônico definitivo.

### Cálculo de Velocidade e Tempo Estimado (ETA)
- Registra janelas de tempo e bytes transferidos para computar a taxa de transferência em tempo real.
- Formatação inteligente:
  - Velocidade: `KB/s` ou `MB/s` com 1 casa decimal.
  - ETA: `mm:ss` para durações curtas ou `hh:mm:ss` para downloads extensos.
- Atualizações throttled no SQLite para evitar sobrecarga de transações I/O durante o streaming de dados.

### Modo Mock Determinístico (Sementes & Testes Offline)
- URLs no formato `mock://download/...` ou identificadores das obras do catálogo semente inicial executam uma geração determinística e controlada de pacotes válidos (EPUB/CBZ simulados com cabeçalhos reais).
- Permite teste completo de ponta a ponta sem dependência de conexões de internet ativas.

### Integração Automática com a Biblioteca Local
- Assim que o download atinge `completed`:
  1. A edição correspondente (`work_editions`) é atualizada com `isLocal = true` e o caminho relativo do arquivo no disco.
  2. O registro da obra na biblioteca (`library`) tem seu status alterado para `downloaded`.
  3. O botão de leitura nas telas de detalhes passa imediatamente a abrir o visualizador offline correspondente (EPUB ou Comic Reader).

---

## 4. Gerenciamento de Estado Reativo (`DownloadsBloc`)

O `DownloadsBloc` atua como ponte reativa entre o motor de transferências e a interface de usuário:
- Inscreve-se nas streams do `DownloadManager`:
  - `downloadsStream`: notifica inclusões, remoções e alterações de status na lista completa de downloads.
  - `progressStream`: emite `DownloadProgressSnapshot` com bytes, progresso (0.0 a 1.0), velocidade formatada e ETA formatado em alta frequência.
- Preserva o mapa de progresso em tempo real (`progressMap`) para que os cards de download exibam barras de progresso fluidas sem flickering ou refetch do banco de dados.

Eventos suportados:
- `LoadDownloadsEvent`: carrega a lista inicial persistida.
- `EnqueueDownloadEvent`: enfileira um novo item a partir de uma edição de obra.
- `PauseDownloadEvent`: interrompe a transferência ativa mantendo o arquivo `.part`.
- `ResumeDownloadEvent`: retoma a transferência do ponto onde parou.
- `CancelDownloadEvent`: cancela a transferência e exclui o arquivo `.part`.
- `RetryDownloadEvent`: reexecuta um download que falhou.
- `DeleteDownloadEvent`: remove o registro do download e limpa arquivos parciais.
- `ClearCompletedDownloadsEvent`: remove os registros de transferências concluídas da lista.

---

## 5. Interface de Usuário Shell (`DownloadsScreen`)

- Alinhada 100% à filosofia de design **Monochromatic Minimalism** (`#121212`, `#1E1E1E`, `#E0E0E0`, `#888888`).
- **Cards de Download:**
  - Título da obra e formato (`EPUB`, `CBZ`, `PDF`).
  - Barra de progresso linear (`NovaProgressBar`) monocromática.
  - Metadados de taxa de dados: `Progresso %`, `Bytes baixados / Bytes totais`, `Velocidade` e `Tempo restante estimado`.
  - Botões de ação contextuais: Pausar, Retomar, Tentar Novamente, Cancelar e Excluir.
- **Header:** Botão de limpeza de downloads concluídos.
- **Empty State:** `NovaEmptyState` monocromático exibido quando não há transferências registradas na fila.

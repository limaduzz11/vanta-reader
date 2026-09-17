# ADR-006: Estrutura do Banco Local SQLite e Mecanismo de WAL
**Status:** ACEITO  
**Data:** 08/09/2026  
**Contexto:** Escolha da tecnologia de persistência, modelo relacional e concorrência para o NovaReader.  

---

## 1. Contexto e Problema
O NovaReader precisa gerenciar eficientemente centenas ou milhares de obras digitais, múltiplos formatos por obra (editions), histórico de leitura de alta precisão, filas persistentes de download que sofrem atualizações frequentes de bytes, e metadados com imagens. Bancos de dados NoSQL chave-valor simples (como Hive ou SharedPreferences) não oferecem garantias transacionais ACID, consultas relacionais complexas com ordenação e paginação, nem isolamento seguro entre leituras da UI e escritas contínuas em background de downloads.

## 2. Decisão Arquitetural
1. **Engine Relacional:** Adotar **SQLite nativo** como banco de dados embarcado central (`novareader.db`).
2. **Modo WAL (Write-Ahead Logging):** Configurar obrigatoriamente `PRAGMA journal_mode = WAL;`. No modo WAL, operações de leitura concorrentes da interface do usuário nunca são bloqueadas por operações de escrita em background (como atualização contínua do progresso de download ou gravação de capítulos).
3. **Integridade Referencial:** Ativar `PRAGMA foreign_keys = ON;` garantindo que a remoção de uma obra remova em cascata suas edições, progresso e histórico associados.
4. **Camada de Abstração:** O acesso ao banco é encapsulado em `AppDatabase` e consumido exclusivamente através de interfaces de Repositório (`ILibraryRepository`, `IDownloadRepository`, `IProfileRepository`).

## 3. Consequências e Trade-offs
- **Positivas:**
  - Garantia ACID total: corrupção de banco em falhas de energia ou crash é praticamente nula com WAL.
  - Consultas com filtros combinados (ex: Tipo = Quadrinho AND Idioma = pt-BR AND Favorito = 1) respondem em sub-milissegundos graças aos índices B-Tree dedicados.
  - Compatibilidade absoluta com desktop Linux (FFI) e Android nativo.
- **Mitigações Necessárias:**
  - O banco deve ser instanciado como Singleton para evitar colisões de locks no arquivo físico SQLite.

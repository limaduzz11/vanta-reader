# ADR-012: Hybrid Online/Offline Reading Architecture & Streaming Cache Promotion

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase K — Leitura Online (Streaming Reader Engine)

---

### Contexto e Problema

O NovaReader foi arquitetado como um aplicativo estritamente Local-First. Entretanto, exigir que o leitor baixe previamente cada obra antes de poder visualizá-la ou ler suas primeiras páginas gera atrito de adoção e consome armazenamento local desnecessário caso a obra não agrade ao leitor.
Além disso, leitores puramente online frequentemente sofrem de:
1. **Desperdício de Banda em Re-Downloads:** Se o usuário decide baixar a obra que acabou de ler via streaming, a maioria dos concorrentes faz o download completo do zero pela segunda vez.
2. **Perda de Progresso ao Alternar Modos:** Progresso lido online é frequentemente perdido ou dissociado da versão offline.
3. **Falta de Transparência:** Usuários não sabem se o arquivo que estão lendo está consumindo tráfego de dados da sua franquia de internet ou se já se encontra salvo no dispositivo.

---

### Decisões de Arquitetura

1. **Abstração Unificada de Sessão de Leitura (`ReadingSession`):**
   - Criação da classe imutável `ReadingSession` contendo a origem da resolução (`ReadingSource.local`, `ReadingSource.cachedStream`, `ReadingSource.onlineStream`), caminho físico resolvido e flags de ciclo de vida.
   - Nenhuma tela de leitor precisa distinguir a lógica complexa de streaming da lógica local: ambas recebem um arquivo físico resolvido pronto para os parsers de conteúdo (`BookContentParser` e `ComicContentParser`).

2. **Hierarquia Transparente de Resolução (Local-First Priority):**
   - Se `edition.isLocal == true` e o arquivo físico existir na partição de dados do usuário (`/books/` ou `/comics/`), o `OnlineReadingManager` desvia imediatamente para o leitor local, sem nenhuma requisição remota.
   - Caso não seja local, verifica o subdiretório de cache volátil (`/cache/reading/`). Se os bytes já estiverem presentes de uma leitura prévia, a leitura inicia de forma instantânea sem re-download.
   - Apenas na ausência de ambos o streaming remoto é ativado, armazenando o buffer no cache volátil seguro.

3. **Promoção Atômica de Buffer para Armazenamento Permanente (`promoteToLocal`):**
   - Quando o usuário decide manter offline uma obra lida via streaming, o arquivo já presente em `/cache/reading/` é copiado diretamente para o armazenamento permanente, promovendo a edição no SQLite com `isLocal = true`.
   - **Economia de Recursos:** Reduz o consumo de dados móveis a zero para obras já abertas em buffer.

4. **Persistência Universal de Progresso no SQLite Local:**
   - O rastreamento de leitura (`SaveReadingProgressUseCase`) é idêntico para sessões locais e de streaming. A posição da leitura é salva no SQLite com ID da obra, garantindo continuidade perfeita mesmo se a conexão for perdida ou se a obra for posteriormente baixada.

5. **Design Monocromático com Feedback em Tempo Real:**
   - As interfaces dos leitores exibem um indicador discreto `STREAMING` e um botão de ação com progresso e feedback para salvar localmente.
   - A tela de detalhes (`WorkDetailsScreen`) exibe claramente se o formato selecionado está disponível offline ou para streaming imediato.

---

### Consequências

- **Positivas:**
  - Descoberta instantânea com zero atrito de download prévio obrigatório.
  - Zero desperdício de banda ao transformar sessões de streaming em downloads permanentes.
  - Progresso preservado deterministicamente no banco de dados local.
  - Respeito total às diretrizes de Local-First e Design System monocromático.
  - Cobertura de testes automatizados completa: 133/133 testes passando verde (100%), 0 erros de análise estática e build Linux validado.
- **Negativas / Mitigações:**
  - Armazenamento temporário em `/cache/reading/` consome espaço em disco durante o uso: mitigado pela inclusão de `clearReadingCache()` e pela separação física do cache volátil que é limpo pelo sistema operacional ou pelo usuário.

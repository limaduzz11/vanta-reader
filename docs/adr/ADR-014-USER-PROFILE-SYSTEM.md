# ADR-014: User Profile, Preferences, Monochromatic Avatars and Storage Management

- **Status:** Aceito
- **Data:** 2026-09-09
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase M — Perfil do Usuário & Avatares Monocromáticos

---

### Contexto e Problema

O NovaReader rege-se pelos princípios inegociáveis de **Local-First**, **Zero Mandatory Accounts** e **Monochromatic Minimalism**. O usuário não deve ser coagido a criar cadastros remotos, submeter e-mails ou sincronizar dados pessoais com servidores externos para customizar sua experiência de leitura.

No entanto, o aplicativo necessitava de um subsistema robusto, elegante e coeso para:
1. **Identidade Local e Personalização:** Permitir que o leitor defina seu nome local e selecione uma representação visual minimalista sem apelo a fotografias coloridas ou emojis desarmônicos.
2. **Preferências Globais do Leitor:** Centralizar preferências persistentes de leitura (tamanho base de tipografia, família de fontes, modo de leitura contínuo vs paginado, idioma de busca e limite de downloads simultâneos).
3. **Métricas e Estatísticas Consolidadas:** Fornecer ao leitor visibilidade analítica sobre seus hábitos de leitura (total de livros concluídos, quadrinhos lidos, obras em andamento, favoritos, total de obras baixadas e páginas acumuladas lidas).
4. **Governança de Armazenamento em Disco:** Exibir a quebra transparente do consumo de memória em disco por partição (livros, HQs, capas, miniaturas, cache volátil e banco de dados SQLite), concedendo botões de limpeza cirúrgica de cache para liberação de espaço sem risco de perda de arquivos permanentes.

---

### Decisões de Arquitetura

1. **Persistência Local Relacional via SQLite Schema v2 (`profiles`):**
   - Incremento da versão do banco de dados `AppDatabase` para versão `2` com rotina atômica de migração (`_onUpgrade`).
   - A tabela `profiles` armazena a chave primária `id` ('primary_profile'), `name`, `avatar_id`, `preferred_language`, `font_size`, `font_family`, `reading_mode`, `max_concurrent_downloads`, `created_at` e `updated_at`.
   - Inicialização com perfil padrão inteligente ("Eduardo", avatar `nova_monolith`, 16pt, modo paginado, 2 downloads concorrentes).

2. **Catálogo de Avatares Monocromáticos Paramétricos (`NovaAvatar` & `NovaAvatarPreset`):**
   - Criação de um catálogo integrado com 12 avatares geométricos e abstratos desenhados exclusivamente com a paleta monocromática do sistema (`#121212`, `#1E1E1E`, `#E0E0E0`, `#444444`):
     - `nova_monolith`, `nova_circle`, `nova_book`, `nova_comic`, `nova_eye`, `nova_star`, `nova_cube`, `nova_shield`, `nova_prism`, `nova_helix`, `nova_horizon`, `nova_compass`.
   - Renderização baseada em vetores nativos com gradientes sutis, bordas de alto contraste e estados selecionáveis, totalmente desacoplados de assets bitmap externos.

3. **Agregação em Tempo Real das Métricas de Leitura (`ReadingStats`):**
   - O `ProfileRepository` consulta os índices locais do SQLite através de queries agregadas de alta performance:
     - `booksRead`: obras do tipo `book` com progresso >= 99%.
     - `comicsRead`: obras do tipo `comic` com progresso >= 99%.
     - `currentlyReading`: obras com progresso entre 0% e 99%.
     - `totalFavorites`: obras marcadas como favoritas na tabela `library`.
     - `totalDownloaded`: edições locais materializadas (`is_local = 1`).
     - `totalPagesRead`: soma das páginas lidas registradas em `reading_progress`.

4. **Gerenciamento e Higienização de Armazenamento (`StorageManager`):**
   - Cálculo instantâneo e assíncrono via `Future.wait` com checagem de integridade síncrona nos diretórios canônicos.
   - Limpeza em duas camadas:
     - **Limpeza de Cache de Streaming:** Remove apenas os buffers voláteis em `/cache/reading/`.
     - **Limpeza de Cache Global:** Higieniza todo o diretório `/cache/`, preservando integralmente `/books/`, `/comics/`, `/covers/` e `/database/`.

5. **BLoC Reativo e Interface Adaptativa (`ProfileBloc` & `ProfileScreen`):**
   - BLoC isolado lidando com `LoadProfileEvent`, `UpdateProfileNameEvent`, `UpdateAvatarEvent`, `UpdatePreferencesEvent`, `RefreshStatsEvent` e `ClearCacheEvent`.
   - Interface adaptativa para celular e tablet organizada em 4 seções:
     - Header com Avatar de 96dp e modal de seleção em grade.
     - Painel analítico de 6 métricas em cartões minimalistas.
     - Seletores de preferências com `Wrap` de `ChoiceChip` auto-responsivos.
     - Quadro de armazenamento particionado com feedback háptico e confirmação de diálogo para ações destrutivas.

---

### Consequências

- **Positivas:**
  - Zero dependência de rede ou autenticação para perfil, persistência e estatísticas.
  - Alinhamento total com a estética Monochromatic Minimalism.
  - Segurança comprovada: botões de limpeza nunca apagam conteúdo da biblioteca.
  - 100% de cobertura com testes unitários, testes de repositório SQLite e testes de widget BLoC.
- **Negativas / Limitações:**
  - Como o sistema é estritamente local, os dados do perfil e estatísticas residem na instalação local e dependem do backup de diretório do dispositivo para migração entre aparelhos.

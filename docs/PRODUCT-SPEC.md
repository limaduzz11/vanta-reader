# NOVAREADER — Especificação Técnica e Funcional do Produto
**Documento Canônico:** `docs/PRODUCT-SPEC.md`  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  
**Status:** VALIDADO / BASELINE FUNCIONAL  

---

## 1. Identificação do Produto

- **Nome do Produto:** NovaReader
- **Tipo:** Aplicativo de Leitura Digital Unificada para Android Phone e Android Tablet.
- **Objetivo Central:** Unificar livros (e-books) e quadrinhos (HQs, mangás, graphic novels) em uma experiência de leitura e gerenciamento limpa, rápida, elegante e 100% autônoma.
- **Princípio Operacional Invariante:** **Local-First + Online Desacoplado**. A internet não pode ser pré-requisito para utilizar a biblioteca, abrir obras baixadas, visualizar capas locais ou navegar pelo histórico.
- **Identidade Estética:** **Monochromatic Minimalism** (Base `#121212`, texto `#E0E0E0` / `#B0B0B0`, bordas `#444444`, acentos `#888888`).

---

## 2. Personas e Casos de Uso Canônicos

### Persona Principal: Eduardo (Engenheiro & Leitor Ávido)
- Alterna frequentemente entre smartphone (no trajeto/mobilidade) e tablet (em casa/repouso).
- Lê e-books técnicos densos (PDFs de arquitetura, manuais), ficção literária (EPUB, TXT) e graphic novels em alta resolução (CBZ/CBR).
- Exige que o leitor nunca trave por falta de internet e guarde exatamente onde parou de ler.

### Cenários de Validação Prática:
1. **Cenário 1 (Descoberta -> Download -> Leitura Offline):**
   - Usuário abre o NovaReader, pesquisa por título/autor, visualiza detalhes e capa em alta qualidade, seleciona idioma (prioridade `pt-BR` ou `en`) e formato desejado (ex: EPUB).
   - Inicia o download; a obra surge na Biblioteca.
   - O dispositivo fica offline (modo avião). O usuário reabre o NovaReader: a obra continua disponível instantaneamente, é lida e a posição de leitura é salva localmente.
2. **Cenário 2 (HQ em Alta Resolução):**
   - Usuário abre uma HQ em formato CBZ com centenas de páginas em 4K.
   - O leitor carrega sem engasgos graças à janela deslizante de memória (LRU cache); gestos de zoom, pan e rotação respondem a 60/120 FPS.
3. **Cenário 3 (Queda e Retomada de Conexão durante Download):**
   - Durante o download de um volume de 300 MB, o Wi-Fi oscila e a conexão é perdida.
   - O download transita para estado pausado/aguardando rede; ao retornar o sinal, a transferência é retomada automaticamente do ponto exato via cabeçalhos HTTP Range.
4. **Cenário 4 (Grande Volume de Biblioteca):**
   - Usuário possui mais de 1.000 obras catalogadas e milhares de capas.
   - A listagem com rolagem rápida da Biblioteca não apresenta "jank" (quedas de quadros), as miniaturas carregam assincronamente e filtros por autor/formato respondem em menos de 16ms.

---

## 3. Requisitos Funcionais Detalhados

### 3.1. Descoberta & Catálogo
- **RF-01 (Home Híbrida):**
  - Quando Online: Apresenta seções "Continuar Lendo", "Adicionados Recentemente", "Populares", "Livros" e "Quadrinhos".
  - Quando Offline: Transita com elegância para seções locais: "Continuar Lendo", "Baixados", "Lidos Recentemente", "Favoritos", "Livros" e "Quadrinhos".
- **RF-02 (Busca Global com Deduplicação):**
  - Permite busca por título, autor, ISBN, série, volume, gênero e tags.
  - Busca online consulta múltiplos provedores em paralelo através do `ProviderManager`.
  - Agrupamento automático de edições/formatos sob uma única obra através do `WorkIdentitySystem`.
- **RF-03 (Filtros de Idioma Obrigatórios):**
  - Prioridade máxima e filtros dedicados para **Português-BR (`pt-BR`)** e **Inglês (`en`)**.
  - Não há interface em espanhol e o espanhol não é idioma padrão/recomendado.
- **RF-04 (Detalhes da Obra):**
  - Exibe capa em alta resolução, título, subtítulo, autor, descrição completa, idioma, gênero, série, volume, editora, ano, formatos disponíveis e estado local (Não baixado, Baixando, Baixado).
  - Ações diretas: "Ler", "Baixar", "Favoritar", "Adicionar à Biblioteca".

### 3.2. Biblioteca Local & Gerenciamento
- **RF-05 (Categorias da Biblioteca):**
  - Abas: Todas, Livros, HQs, Baixados, Em Andamento, Concluídos, Favoritos.
- **RF-06 (Visualizações & Ordenação):**
  - Modos de visualização: Grade (Grid com capas) e Lista compacta.
  - Ordenação por: Adicionados Recentemente, Lidos Recentemente, Título (A-Z), Autor e Progresso.
- **RF-07 (Importação de Arquivos Locais):**
  - Suporte a seleção de arquivos do armazenamento interno/SD Card do dispositivo:
    - Livros: `.epub`, `.pdf`, `.txt`.
    - HQs: `.cbz`, `.cbr`, `.pdf`, pastas de imagens.
  - Extração automática de metadados internos e renderização da imagem de capa.

### 3.3. Motores de Leitura (Reader Engines)
- **RF-08 (Book Reader — Livros):**
  - Formatos: EPUB, PDF, TXT.
  - Navegação por páginas ou rolagem contínua vertical.
  - Índice / Tabela de conteúdos (TOC) com salto instantâneo para capítulos.
  - Barra de progresso com porcentagem e contagem de páginas.
  - Personalização de tipografia: tamanho de fonte, altura de linha, margens e alinhamento.
  - Modo imersivo (Fullscreen) com ocultação de barras de sistema e menu.
- **RF-09 (Comic Reader — Quadrinhos):**
  - Formatos: CBZ, CBR, PDF, Imagens soltas.
  - Modos de leitura: Página individual (`PAGE`), Rolagem vertical estilo Webtoon (`VERTICAL`), Faixa contínua horizontal (`CONTINUOUS`), Ajustar à largura (`FIT_WIDTH`) e Ajustar à tela (`FIT_SCREEN`).
  - Gestos: Pinça para zoom (Pinch), arrastar (Pan), duplo toque para alternar zoom 2x e reset.
  - Pré-carregamento assíncrono inteligente das páginas adjacentes sem consumir excesso de memória RAM.
- **RF-10 (Persistência Contínua de Posição):**
  - Gravação automática da posição exata: `workId`, `chapterId`, `page`, `offset`, `percentage`, `timestamp`.
  - Ao reabrir a obra, a leitura é retomada no ponto exato anterior.

### 3.4. Gerenciador de Downloads & Armazenamento
- **RF-11 (Download Manager Resiliente):**
  - Fila gerenciada com estados explícitos: `QUEUED`, `DOWNLOADING`, `PAUSED`, `COMPLETED`, `FAILED`, `CANCELLED`.
  - Exibição de velocidade em tempo real (KB/s, MB/s), percentual, tamanho total e tempo restante estimado (ETA).
  - Ações: Pausar, Retomar, Cancelar, Tentar Novamente e Excluir arquivo.
  - Suporte a `HTTP Range` para retomada sem perda de bytes já baixados.
  - Retomada automática após recuperação de conexão de rede.
- **RF-12 (Gestão de Armazenamento - Storage Manager):**
  - Tela dedicada informando o consumo de espaço em disco: Livros baixados, HQs baixadas, Capas salvas e Cache temporário.
  - Botão de ação "Limpar Cache" que remove apenas temporários em `/NovaReader/cache/`, preservando integralmente o conteúdo baixado pelo usuário.

### 3.5. Perfil & Avatares Monocromáticos
- **RF-13 (Perfil Local Sem Conta Obrigatória):**
  - Edição de nome do usuário e preferências gerais.
  - Painel com estatísticas de leitura: Livros lidos, HQs lidas, em andamento e favoritos.
- **RF-14 (Catálogo de Avatares):**
  - Coleção de ícones geométricos e símbolos abstratos em estilo monocromático minimalista.
  - Possibilidade de selecionar, salvar e visualizar no perfil e na barra de navegação.

---

## 4. Requisitos Não-Funcionais (RNFs)

- **RNF-01 (Desempenho e Fluidez):** Rolagem de listas, navegação e transições de página mantendo 60 FPS estáveis (120 FPS em displays compatíveis).
- **RNF-02 (Consumo de Memória RAM):** Uso controlado de memória em HQs pesadas através de janela deslizante LRU de páginas; liberação e reciclagem ativa de bitmaps.
- **RNF-03 (Inicialização Rápida):** Cold start da aplicação inferior a 1.5 segundo em dispositivos intermediários.
- **RNF-04 (Segurança de Arquivos):** Validação estrita contra Path Traversal e ataques de Zip Slip durante descompactação de arquivos `.epub`, `.cbz` e `.cbr`.
- **RNF-05 (Conformidade e Isolamento Legal):**
  - O aplicativo não possui mecanismos de quebra de autenticação, bypass de DRM ou violação de paywalls.
  - A camada de provedores é agnóstica e atua apenas sobre fontes autorizadas, públicas ou fornecidas pelo usuário.
- **RNF-06 (Acessibilidade):** Contraste em conformidade com WCAG AA para a paleta monocromática, suporte ao TalkBack e suporte a redimensionamento de fontes do sistema.
- **RNF-07 (Logging Estruturado):** Trilha de logs segmentada por categorias (`APP`, `DB`, `NETWORK`, `PROVIDER`, `READER`, `CACHE`) com níveis `DEBUG`, `INFO`, `WARN`, `ERROR` sem exposição de dados sensíveis.

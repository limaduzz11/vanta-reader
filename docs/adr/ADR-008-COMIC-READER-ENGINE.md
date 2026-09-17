# ADR-008: Comic Reader Engine (Motor de Leitura de Quadrinhos, HQs e Mangás)

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase G — Leitor de Quadrinhos (Comic Reader Engine)

---

### Contexto e Problema

O leitor de histórias em quadrinhos, HQs, mangás e webtoons (formatos CBZ, CBR, pastas de imagens) é outro pilar essencial do NovaReader. A visualização de conteúdo gráfico em dispositivos móveis e desktop impõe desafios de engenharia distintos dos leitores de texto puro:
1. **Prevenção de Out-Of-Memory (OOM):** Quadrinhos em alta definição contêm dezenas a centenas de imagens que totalizam centenas de megabytes descompactados. Carregar todas as páginas na memória simultaneamente provoca crashes imediatos em smartphones ou limita severamente a performance.
2. **Ordenação Natural Alfanumérica:** A ordenação lexicológica padrão de arquivos (`page_1.jpg`, `page_10.jpg`, `page_2.jpg`) quebra a sequência de leitura se não for aplicado algoritmo natural numérico.
3. **Versatilidade de Modos de Visualização:**
   - Modo Página por Página (quadrinhos ocidentais clássicos) com gestos de pinch-to-zoom e double-tap.
   - Modo Webtoon (rolagem contínua vertical) para manhwas e webcomics.
   - Modo Mangá com sentido de leitura invertido (Direita para a Esquerda / RTL).
4. **Modos de Enquadramento da Imagem:** Ajuste à Largura (Fit Width), Ajuste à Altura (Fit Height) e Ajuste à Tela Total (Fit Screen / Contain).
5. **Persistência de Progresso Milimétrico:** Gravação da página exata no SQLite a cada virada de página ou salto.

---

### Decisões de Arquitetura

1. **Desacoplamento e Cache LRU em Memória (`ComicPageCache`):**
   - Criação de um cache Least-Recently-Used com limite configurável (padrão de 7 páginas ativas).
   - Páginas que saem da janela de visualização são desalocadas da memória RAM e recarregadas sob demanda pelo CBZ através de streaming.

2. **Parser Especializado e Ordenação Natural (`ComicContentParser`):**
   - Extrai exclusivamente formatos de imagem (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`), ignorando arquivos auxiliares (`ComicInfo.xml`, lixo de empacotamento).
   - Algoritmo `naturalCompare` tokeniza partes numéricas e de texto para garantir ordem exata (`page_1` < `page_2` < `page_10`).
   - Fallback procedural com BMPs 24bpp dinâmicos para obras do acervo inicial sem download físico ainda presente no disco.

3. **Gerenciamento de Estado Reativo via BLoC (`ComicReaderBloc`):**
   - Controla: `OpenComicEvent`, `NextComicPageEvent`, `PreviousComicPageEvent`, `JumpToComicPageEvent`, `ToggleComicControlsEvent`, `ChangeReadingModeEvent`, `ChangeFitModeEvent`, `ToggleDoublePageEvent`, `ToggleRtlEvent`.
   - Recupera e persiste progresso SQLite via `GetReadingProgressUseCase` e `SaveReadingProgressUseCase`.

4. **Interface Visual Adaptativa e Gestos Imersivos (`ComicReaderScreen`):**
   - Toques laterais de 25% com inversão automática quando `readRightToLeft` está ativado.
   - Toque central de 50% para alternância instantânea do modo imersivo (ocultação suave de AppBars).
   - Suporte a `InteractiveViewer` e double-tap com escala 2.2x via `Matrix4.diagonal3Values`.
   - BottomSheets dedicadas para Grade de Páginas (salto direto) e Ajustes de Leitura.
   - Integração direta em `WorkDetailsScreen` com o botão "LER AGORA" para obras do tipo `WorkType.comic`.

---

### Consequências

- **Positivas:**
  - Desempenho estável e imune a OOM mesmo em quadrinhos pesados em alta resolução.
  - Suporte completo aos principais hábitos de leitura gráfica: quadrinhos ocidentais, mangás orientais e webtoons modernos.
  - Sincronização e persistência de leitura transparentes com o SQLite do aplicativo.
  - 100% verificado: 68/68 testes automatizados passando green, 0 problemas no linter e binário Linux compilado com sucesso.
- **Negativas / Mitigações:**
  - Leitura de arquivos CBR baseados em RAR proprietário exige dependência nativa ou conversão: mitigado adotando o padrão aberto CBZ (ZIP), que é o padrão da indústria e amplamente suportado sem dependências de C nativo instáveis.

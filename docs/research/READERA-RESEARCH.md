# READERA — Relatório de Engenharia Reversa e Análise Técnica
**Documento Canônico:** `docs/research/READERA-RESEARCH.md`  
**Referência:** [ReadEra (readera.org)](https://readera.org/)  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  

---

## 1. Visão Geral & Propósito
O **ReadEra** é amplamente considerado o padrão-ouro de aplicativo de leitura offline para Android. Seu propósito é abrir praticamente qualquer formato de documento ou livro sem anúncios, sem exigir cadastro ou login, e com total respeito à privacidade e funcionamento offline.

---

## 2. Análise Arquitetural & Engenharia Reversa

### 2.1. A Arquitetura OpenReadEra (Isolamento por Processos)
Diferente da maioria dos apps que incorporam bibliotecas de parsing C++ no mesmo processo da UI, o ReadEra implementou uma arquitetura desacoplada inovadora através do projeto **OpenReadEra**:
- O app principal atua como um gerenciador de biblioteca e UI Shell.
- Os motores de renderização rodam em **processos separados do sistema operacional** (out-of-process isolation):
  - `EraPDF`: Baseado em MuPDF otimizado.
  - `EraEPUB`: Baseado em CoolReader / engine C++.
  - `EraComic`: Motor especializado em descompactação de ZIP/RAR e decodificação de imagem.
  - `EraDjVu`, `EraMOBI`.
- **Comunicação Inter-Processos (IPC):** Comunicação leve via argumentos de linha de comando, pipes e sockets locais, sem ponte de memória compartilhada instável.
- **Benefício de Estabilidade Crítico:** Se um arquivo corrompido ou malicioso provocar um crash de segmentação (SIGSEGV) no motor C++, **o aplicativo principal do ReadEra NÃO cai**. Apenas o leitor daquele processo é reiniciado com mensagem de erro amigável.

### 2.2. Organização da Biblioteca Offline
- **Categorização Canônica:**
  - *Lendo Agora* (com percentual e capa destacada)
  - *Quero Ler*
  - *Lidos*
  - *Favoritos*
  - *Autores* (agrupamento inteligente)
  - *Séries* (ordenação por volume da edição)
  - *Formatos* (filtro direto por EPUB, PDF, CBZ, etc.)
- **Scanner do Dispositivo:** Varredura rápida do armazenamento do dispositivo para catalogar automaticamente livros e HQs sem intervenção manual contínua.

---

## 3. Avaliação Detalhada por Módulo

| Módulo | Implementação no ReadEra | Diagnóstico Crítico para o NovaReader |
|---|---|---|
| **Suporte a Formatos** | Universal: EPUB, PDF, TXT, CBZ, CBR, DOC, FB2, MOBI. | **Inspiração de escopo:** O NovaReader priorizará EPUB, PDF, TXT para livros e CBZ, CBR, PDF, Imagens para HQs. |
| **Comportamento Offline** | 100% Offline por princípio. Zero coleta de dados, zero tracking, zero dependência de conta. | **Princípio idêntico no NovaReader:** Nenhum recurso básico da biblioteca local ou do leitor depende de internet. |
| **Persistência de Progresso** | Salva milimetricamente a posição em cada documento; permite saltar de volta com 1 toque. | O NovaReader implementará persistência idêntica com restauração precisa. |
| **UX & Visual** | Interface clássica Android (listas utilitárias). É funcional, mas carece do apelo visual moderno de streaming. | O NovaReader superará o ReadEra no apelo visual com sua estética **Monochromatic Minimalism** e Home com carrosséis estilo catálogo. |
| **Descoberta & Catálogo Online** | **Inexistente:** O ReadEra só abre arquivos que o usuário já colocou manualmente no celular. Não possui busca em provedores, catálogos ou downloads. | **Grande oportunidade para o NovaReader:** Unir a estabilidade offline do ReadEra com o poder de descoberta e download do Openlib/IReader. |

---

## 4. Pontos Fortes (Melhores Ideias a Reter)
1. **Zero Fricção de Entrada:** Instala e lê imediatamente. Sem telas de login obrigatório, sem termos de assinatura.
2. **Isolamento de Falhas do Reader:** Arquivos corrompidos não podem derrubar o app.
3. **Agrupamento por Séries e Volumes:** Essencial para HQs e sagas de livros (ex: Livro 1, Livro 2...).
4. **Respeito ao Armazenamento do Usuário:** Lê os arquivos no local original sem duplicar desnecessariamente para dentro de sandbox fechada quando o usuário opta por vincular.

## 5. Limitações a Superar no NovaReader
1. **Falta de Descoberta Online Integrada:** O usuário precisa baixar arquivos pelo navegador em sites de terceiros e depois abrir no app. O NovaReader fornecerá o ciclo completo no mesmo aplicativo.
2. **Interface Datada:** O ReadEra possui layout de lista tradicional do Android antigo. O NovaReader trará layout moderno com navegação inferior elegante, grids dinâmicos e cartões ricos em detalhes.

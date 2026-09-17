# ADR-001: Adoção de Clean Architecture e Stack Flutter + SQLite
**Status:** ACEITO  
**Data:** 08/09/2026  
**Contexto:** Definição da stack tecnológica fundamental e arquitetura de software para o NovaReader (Android Phone e Tablet).  

---

## 1. Contexto e Problema
O NovaReader precisa fornecer uma experiência moderna, fluida e adaptativa de leitura para livros e quadrinhos em dispositivos Android (telefones e tablets). O aplicativo requer suporte a múltiplos formatos de arquivos complexos (.epub, .pdf, .txt, .cbz, .cbr), renderização gráfica de alta taxa de quadros (60-120 FPS), downloads assíncronos persistentes, banco de dados local com transações e motor desacoplado de provedores externos de catálogo. Além disso, o fluxo de desenvolvimento no Linux (Pop!_OS) exige ciclos rápidos de teste e compilação para garantir produtividade máxima.

## 2. Decisão Arquitetural
1. **Linguagem & Framework:** Adotar **Flutter 3.44+ (Dart 3.12+)** com compilação nativa para Android (AOT) e target auxiliar Linux Desktop para desenvolvimento ágil.
2. **Padrão Arquitetural:** Clean Architecture combinada com Domain-Driven Design (DDD) e gerenciamento de estado reativo via **BLoC / Cubits**.
3. **Persistência Relacional:** Adotar **SQLite nativo (via `sqflite`)** com modo WAL (Write-Ahead Logging) ativo e runner determinístico de migrations.
4. **Isolamento de Camadas:**
   - Camada de Apresentação (UI) consome apenas ViewModels/Blocs.
   - Blocs invocam apenas Casos de Uso (UseCases).
   - Casos de Uso operam sobre Interfaces de Repositório do Domínio.
   - Repositórios concretos orquestram Fontes de Dados Locais e Remotas.

## 3. Alternativas Consideradas
- **Kotlin Nativo + Jetpack Compose:** Excelente para Android puro, mas limita a velocidade de testes no ambiente de desenvolvimento local (exigindo boot constante de emulador pesado) e dificulta eventual expansão desktop/web no roadmap futuro.
- **Tauri + React/Next.js (Webview móvel):** Excelente em desktop, mas demonstrou alto consumo de memória RAM e jank no scroll de quadrinhos pesados em alta resolução dentro de Webviews no Android.

## 4. Consequências e Trade-offs
- **Positivas:**
  - Código único para Android Phone e Tablet com layouts responsivos de primeira classe.
  - Velocidade incomparável de execução de testes unitários e de widget no host Linux (execução em segundos).
  - Controle milimétrico de renderização através do motor Skia/Impeller do Flutter.
- **Mitigações Necessárias:**
  - Gerenciamento estrito de memória para imagens de quadrinhos em alta resolução (implementando janela deslizante de páginas e downsampling durante a decodificação).

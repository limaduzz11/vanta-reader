# VANTA Reader

<div align="center">

![VANTA Reader](screen_vanta.png)

### Plataforma Unificada e Local-First de Leitura Digital (Livros & Quadrinhos)
**Desenvolvido pela VANTA Labz**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-WAL%20v5-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![Architecture](https://img.shields.io/badge/Clean-Architecture-4EAA25?style=for-the-badge)](docs/ARCHITECTURE.md)
[![Tests](https://img.shields.io/badge/Tests-216%20Passing-brightgreen?style=for-the-badge)](test)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

</div>

---

## 📌 Visão Geral

O **VANTA Reader** é uma aplicação móvel e tablet desenvolvida em **Flutter**, projetada para centralizar o consumo de **Livros** (EPUB, PDF, TXT) e **Quadrinhos/Mangás** (CBZ, CBR) sob uma filosofia estrita **Local-First**, interface com design minimalista monocromático (*Monochromatic Minimalism*) e engenharia de software desacoplada.

O projeto resolve o problema da fragmentação de bibliotecas digitais: leitores tradicionais de EPUB raramente tratam quadrinhos com fluidez, enquanto leitores de mangá ignoram anotações e formatação de livros. O VANTA Reader unifica ambos com motores de renderização especializados.

---

## ✨ Principais Funcionalidades

- 📚 **Suporte Abrangente a Formatos:**
  - **Livros:** EPUB (com extração de TOC e capítulos estruturados), PDF vetorial e TXT com paginação contínua e sanitização.
  - **Quadrinhos & Mangás:** Arquivos compactados CBZ/CBR com descompressão sob demanda e ordenação natural.
- ⚡ **Local-First & Offline-First:**
  - Banco de dados **SQLite WAL (schema v5)** local para controle transacional de biblioteca, autores, progresso (0–100%) e favoritos.
  - Funcionamento autônomo sem necessidade de conta, login obrigatório ou telemetria invasiva.
- 📖 **Motores de Leitura Dedicados:**
  - **Book Reader Engine:** Modo imersivo fullscreen, navegação por toque lateral (25%/50%/25%), sumário interativo, controle de tipografia e persistência automática de progresso.
  - **Comic Reader Engine:** Modo de visualização de página única com pinch-to-zoom (2.2x), visualizador vertical contínuo (Webtoon) e suporte a leitura orientada da direita para a esquerda (RTL/Mangá).
  - **Gestão de Memória Anti-OOM:** Cache LRU em memória (`ComicPageCache`) com teto estrito de páginas/bytes para evitar estouro de heap em imagens 4K.
- 📥 **Gerenciador de Downloads Persistente:**
  - Fila persistente em SQLite com suporte a pausa, retomada, concorrência controlada e validação de integridade (MD5/SHA-256).
- 🧩 **Arquitetura de Provedores Desacoplada:**
  - Integração via contratos genéricos (`ContentProvider`) com normalização de metadados, identificação determinística de obras (`WorkIdentitySystem`) e suporte ao gateway neutro **VANTA Catalog**.
- 🌓 **Monochromatic Minimalism & Acessibilidade:**
  - Paleta escura de alto contraste (`#121212`, `#E0E0E0`, `#444444`), conformidade com diretrizes de contraste WCAG AAA e suporte nativo a TalkBack.
  - Interface responsiva com adaptação entre celular (Bottom Navigation) e tablet (Navigation Rail e Split-View).

---

## 🏛️ Arquitetura & Engenharia

O projeto adota os princípios de **Clean Architecture** e separação de responsabilidades em 4 camadas fundamentais:

```text
lib/
├── core/                   # Utilitários transversais, tema, segurança (CryptoVault), logging e banco de dados
│   ├── database/           # AppDatabase SQLite WAL (schema migrations v1 -> v5)
│   ├── security/           # Encriptação AES-256 e sanitização contra Zip Slip / Path Traversal
│   ├── theme/              # Design System Monochromatic Minimalism
│   └── network/            # Cliente HTTP (Dio) resiliente
├── domain/                 # Entidades canônicas de negócio, contratos de repositórios e Use Cases puros
│   ├── entities/           # Work, WorkEdition, ContentAsset, ReadingProgress, DownloadItem
│   ├── repositories/       # Interfaces abstratas de persistência e download
│   └── usecases/           # Casos de uso atômicos (ImportWork, SaveProgress, SearchCatalog, etc.)
├── data/                   # Implementação concreta de repositórios, data sources locais e provedores de conteúdo
│   ├── datasources/        # Operações SQLite brutas, file storage particionado e cache
│   ├── providers/          # Adaptadores de catálogo online (VANTA Catalog, Open Library, Internet Archive PD)
│   └── repositories/       # Implementação dos contratos de domínio
└── presentation/           # Interface do usuário com Flutter BLoC (gestão reativa de estado)
    ├── blocs/              # LibraryBloc, BookReaderBloc, ComicReaderBloc, DownloadsBloc, SearchBloc
    ├── screens/            # Telas principais (Home, Search, Library, Downloads, Profile, Readers)
    └── widgets/            # Componentes atômicos reutilizáveis do Design System
```

---

## 🧪 Qualidade & Testes

O repositório mantém uma suíte rigorosa de testes automatizados com cobertura para todas as regras de negócio críticas:

- **216+ testes automatizados** passando com sucesso.
- **Suíte de Testes:**
  - Testes unitários de Use Cases e parsers de conteúdo.
  - Testes de migração de banco de dados SQLite (v1 a v5 com backfill conservador).
  - Testes de BLoCs reativos com `bloc_test`.
  - Testes de ponta a ponta (E2E) de ciclo de vida de downloads e leitura offline.
- **Auditoria de Código:** Análise estática contínua (`flutter analyze`) com **0 warnings / 0 errors**.

Para executar os testes:

```bash
flutter test
```

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.12.0)
- Dart SDK (>= 3.12.2)
- Android SDK instalado com suporte a API 21+
- Java JDK 17

### Passo a Passo

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/limaduzz11/vanta-reader.git
   cd vanta-reader
   ```

2. **Instale as dependências:**
   ```bash
   flutter pub get
   ```

3. **Verifique o ambiente:**
   ```bash
   flutter doctor
   flutter analyze
   ```

4. **Execute a suíte de testes:**
   ```bash
   flutter test
   ```

5. **Inicie a aplicação em um emulador ou dispositivo conectado:**
   ```bash
   flutter run
   ```

---

## 📖 Documentação Técnica Detalhada

Documentação aprofundada de engenharia e especificações técnicas estão disponíveis na pasta [`docs/`](docs/):

- [Arquitetura Geral](docs/ARCHITECTURE.md)
- [Design System & UI Specs](docs/DESIGN-SYSTEM.md)
- [Arquitetura de Persistência SQLite & Migrações](docs/DATABASE.md)
- [Book Reader Engine (EPUB / PDF / TXT)](docs/BOOK-READER.md)
- [Comic Reader Engine & Cache LRU Anti-OOM](docs/COMIC-READER.md)
- [Estratégia Offline-First & Isolamento Local](docs/OFFLINE-FIRST.md)
- [Especificação da API do Catálogo VANTA](docs/VANTA-CATALOG-API.md)
- [Diretrizes de Segurança & Hardening](docs/SECURITY.md)

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte [`LICENSE`](LICENSE) para mais informações.

---

<div align="center">
  <sub>Criado e mantido por <b>Eduardo de Lima Paranhos</b> — <b>VANTA Labz</b></sub>
</div>

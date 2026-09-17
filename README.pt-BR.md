# VANTA Reader

<div align="center">

**Leitor digital local-first e open source para livros e quadrinhos construído com Flutter.**

[![CI](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml/badge.svg)](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-WAL_v5-003B57?style=flat&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

<br />

[English](README.md) &nbsp;|&nbsp; **Português (Brasil)**

<br />

![VANTA Reader Preview](screen_vanta.png)

</div>

> Leia arquivos EPUB, TXT e CBZ offline.  
> Mantenha sua biblioteca e progresso de leitura estritamente no seu dispositivo.  
> Sem necessidade de criar conta.

---

## Sumário

- [Formatos Suportados](#formatos-suportados)
- [Suporte de Plataforma](#suporte-de-plataforma)
- [Principais Funcionalidades](#principais-funcionalidades)
- [Arquitetura](#arquitetura)
- [Como Executar](#como-executar)
- [Testes & Qualidade](#testes--qualidade)
- [Como Contribuir](#como-contribuir)
- [Roadmap](#roadmap)
- [Licença](#licença)

---

## Formatos Suportados

| Formato | Tipo de Conteúdo | Estado | Motor |
| :--- | :--- | :---: | :--- |
| **EPUB** | Livros e Romances | `Suportado` | Parser Reflowable Sob Medida |
| **TXT** | Texto Puro | `Suportado` | Motor de Texto Segmentado |
| **CBZ** | Quadrinhos e Mangás (pacote ZIP) | `Suportado` | Pipeline de Imagens com Cache LRU |
| **PDF** | Livros e Documentos | `Planejado` | Renderizador Vetorial Nativo |
| **CBR** | Quadrinhos e Mangás (pacote RAR) | `Planejado` | Pipeline de Descompressão |

---

## Suporte de Plataforma

| Plataforma | Alvo | Estado | Distribuição |
| :--- | :--- | :---: | :--- |
| **Android** | Celular e Tablet | `Suportado` | APK (GitHub Releases) |
| **Linux** | Desktop (x86_64) | `Suportado` | Pacote Nativo |
| **Windows** | Desktop | `Planejado` | Executável Standalone |
| **macOS / iOS** | Desktop / Mobile | `Planejado` | Pacote de Aplicação |

---

## Principais Funcionalidades

- **Armazenamento Local-First & Offline:** Metadados da biblioteca, autores, progresso de leitura e favoritos são persistidos em um banco de dados SQLite embarcado (schema v5). Funciona 100% offline sem telemetria remota.
- **Motores de Leitura Dedicados:**
  - **Livros:** Parser EPUB com navegação por sumário (TOC), paginação por capítulos e ajustes dinâmicos de tipografia.
  - **Quadrinhos:** Leitor CBZ com modo de página única (zoom por pinça 2.2x), rolagem vertical contínua (Webtoon) e modo da direita para a esquerda (RTL) para mangás.
  - **Proteção de Memória via LRU:** As páginas decodificadas de quadrinhos são gerenciadas por um cache LRU em memória (`ComicPageCache`) com limites estritos de páginas e bytes para prevenir estouro de memória (OOM) em imagens de alta resolução.
- **Fila de Downloads Persistente:** Fila gerenciada em SQLite com suporte a pausa/retomada, recuperação de conexões e validação de integridade.
- **Provedores de Catálogo Extensíveis:** Descoberta de catálogo desacoplada através da interface abstrata `ContentProvider` e deduplicação determinística (`WorkIdentitySystem`).
- **Design Minimalista Monocromático:** Tema escuro de alto contraste focado em leitura, com layout responsivo que se adapta entre celular (Bottom Navigation) e tablet/desktop (Navigation Rail).

---

## Arquitetura

O VANTA Reader é estruturado seguindo as diretrizes de **Clean Architecture**:

```text
lib/
├── core/                   # Parsers, SQLite AppDatabase, cache LRU e utilitários de segurança
├── domain/                 # Entidades puras em Dart, interfaces de repositório e Use Cases atômicos
├── data/                   # Implementações de repositórios, data sources locais e provedores de catálogo
└── presentation/           # Interface Flutter, telas, widgets e gerenciamento de estado via BLoC
```

Para decisões arquiteturais aprofundadas, consulte a [Documentação de Arquitetura](docs/ARCHITECTURE.md).

---

## Como Executar

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (canal stable, >= 3.12.0)
- Dart SDK (>= 3.12.2)
- Android SDK ou ferramentas de compilação Linux desktop

### Instalação

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/limaduzz11/vanta-reader.git
   cd vanta-reader
   ```

2. **Instale as dependências:**
   ```bash
   flutter pub get
   ```

3. **Inicie a aplicação:**
   ```bash
   flutter run
   ```

---

## Testes & Qualidade

O projeto conta com uma suíte de testes automatizados cobrindo regras de negócio, BLoCs, migrações SQLite e fluxos de ponta a ponta:

```bash
# Verificar formatação
dart format --output=none --set-exit-if-changed lib/ test/

# Análise estática
flutter analyze

# Executar suíte de testes
flutter test
```

Essas verificações são validadas automaticamente em cada Pull Request via [GitHub Actions CI](.github/workflows/ci.yml).

---

## Como Contribuir

Contribuições são muito bem-vindas! Consulte o arquivo [CONTRIBUTING.md](CONTRIBUTING.md) para diretrizes, leia nosso [Código de Conduta](CODE_OF_CONDUCT.md) e explore as issues abertas.

---

## Roadmap

Consulte o [ROADMAP.md](ROADMAP.md) para acompanhar os marcos planejados (incluindo suporte a PDF e CBR) e planos de release. O histórico de versões é registrado no [CHANGELOG.md](CHANGELOG.md).

---

## Licença

Distribuído sob a licença [MIT](LICENSE).

---

<div align="center">
  <sub>Mantido por <b>Eduardo de Lima Paranhos</b> · <b>VANTA Labz</b></sub>
</div>

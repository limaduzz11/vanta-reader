# VANTA Reader

<div align="center">

**Leitor digital local-first e open source para livros e quadrinhos construído com Flutter.**

[![CI](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml/badge.svg)](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml)
[![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento_Ativo-orange.svg?style=flat)](#downloads--disponibilidade)
[![Release](https://img.shields.io/badge/Release-v0.3.0--preview-blue.svg?style=flat)](https://github.com/limaduzz11/vanta-reader/releases)
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
- [Downloads & Disponibilidade](#downloads--disponibilidade)
- [Compilação & Testes Locais](#compilação--testes-locais)
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

## Downloads & Disponibilidade

> **Status do Projeto:** O VANTA Reader está atualmente em **desenvolvimento ativo**.  
> O aplicativo está em fase de estabilização, e os binários prontos para uso, junto com o guia completo de compilação a partir do código-fonte, serão disponibilizados nos próximos marcos.

### Distribuição (APK)

O principal canal de distribuição do VANTA Reader é através de pacotes **APK para Android** prontos para instalação direta (sideload) — sem lojas proprietárias, sem necessidade de conta e com zero rastreamento:

| Pacote | Alvo | Estado | Download |
| :--- | :--- | :---: | :--- |
| **APK de Release** (Assinado) | Android (Celular & Tablet) | `Em Breve` | Canal oficial de releases |
| **Build Preview** (Testes) | Android (Celular & Tablet) | `Disponível` | [Baixar v0.3.0-preview](https://github.com/limaduzz11/vanta-reader/releases/tag/v0.3.0-preview) |

#### Como Instalar (Sideload no Android)
1. Baixe o arquivo `.apk` diretamente na aba de [Releases](https://github.com/limaduzz11/vanta-reader/releases) pelo navegador do seu aparelho Android (ou baixe no PC e transfira para o celular/tablet).
2. Abra o arquivo APK baixado usando o gerenciador de arquivos do aparelho.
3. Se solicitado pelo Android, confirme a permissão para instalar fontes desconhecidas para o gerenciador e conclua a instalação.

---

## Compilação & Testes Locais

As instruções completas para compilar e validar o VANTA Reader a partir do código-fonte no seu próprio computador (incluindo configuração do Flutter SDK, ambiente Dart, ferramentas de compilação Android e execução da suíte de testes automatizados) serão disponibilizadas publicamente assim que os módulos centrais forem estabilizados.

- **Execução Local:** Guias detalhados para rodar no Linux desktop e em emuladores/dispositivos Android estão em desenvolvimento.
- **Suíte de Testes:** A suíte de validação automatizada (cobrindo Use Cases de domínio, BLoCs, migrações de banco SQLite e parsers de leitura) terá seus comandos de execução documentados em uma próxima release.

Você pode acompanhar os marcos planejados no [ROADMAP.md](ROADMAP.md) e consultar os detalhes técnicos na [Documentação de Arquitetura](docs/ARCHITECTURE.md).

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

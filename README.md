# VANTA Reader

<div align="center">

**An open-source, local-first reader for books and comics built with Flutter.**

[![CI](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml/badge.svg)](https://github.com/limaduzz11/vanta-reader/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-WAL_v5-003B57?style=flat&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

<br />

**English** &nbsp;|&nbsp; [Português (Brasil)](README.pt-BR.md)

<br />

![VANTA Reader Preview](screen_vanta.png)

</div>

> Read EPUB, TXT, and CBZ files offline.  
> Keep your library and reading progress strictly on your device.  
> No account required.

---

## Table of Contents

- [Supported Formats](#supported-formats)
- [Platform Support](#platform-support)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Testing & Quality](#testing--quality)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

---

## Supported Formats

| Format | Content Type | Status | Engine |
| :--- | :--- | :---: | :--- |
| **EPUB** | Books & Novels | `Supported` | Custom Reflowable Parser |
| **TXT** | Plain Text | `Supported` | Chunked Plaintext Engine |
| **CBZ** | Comics & Manga (ZIP bundle) | `Supported` | LRU Cached Image Pipeline |
| **PDF** | Books & Documents | `Planned` | Native Vector Renderer |
| **CBR** | Comics & Manga (RAR bundle) | `Planned` | Decompression Pipeline |

---

## Platform Support

| Platform | Target | Status | Distribution |
| :--- | :--- | :---: | :--- |
| **Android** | Phone & Tablet | `Supported` | APK (GitHub Releases) |
| **Linux** | Desktop (x86_64) | `Supported` | Native Bundle |
| **Windows** | Desktop | `Planned` | Standalone Executable |
| **macOS / iOS** | Desktop / Mobile | `Planned` | Application Bundle |

---

## Key Features

- **Local-First & Offline Storage:** Library metadata, authors, reading progress, and favorites are persisted in an embedded SQLite database (schema v5). Works 100% offline without remote telemetry.
- **Dedicated Reading Engines:**
  - **Books:** EPUB parser with Table of Contents navigation, chapter pagination, and dynamic typography adjustments.
  - **Comics:** CBZ viewer featuring Single-Page mode (pinch-to-zoom 2.2x), continuous vertical scrolling (Webtoon), and right-to-left (RTL) mode for Manga.
  - **LRU Memory Guard:** Decoded comic pages are managed by an in-memory LRU cache (`ComicPageCache`) with page and byte budgets to prevent out-of-memory crashes on high-res scans.
- **Persistent Download Queue:** SQLite-backed download queue with pause/resume support, connection recovery, and checksum validation.
- **Extensible Content Providers:** Decoupled catalog discovery via the abstract `ContentProvider` interface and deterministic deduplication (`WorkIdentitySystem`).
- **Monochromatic Minimalism:** High-contrast dark theme designed for focus, responsive layouts adapting seamlessly between mobile (Bottom Navigation) and tablet (Navigation Rail).

---

## Architecture

VANTA Reader is built following **Clean Architecture** conventions:

```text
lib/
├── core/                   # Parsers, SQLite AppDatabase, LRU cache, and security utilities
├── domain/                 # Pure Dart entities, repository interfaces, and atomic Use Cases
├── data/                   # Repository implementations, local data sources, and catalog providers
└── presentation/           # Flutter UI, screens, widgets, and BLoC state management
```

For in-depth design decisions and patterns, read the [Architecture Documentation](docs/ARCHITECTURE.md).

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel, >= 3.12.0)
- Dart SDK (>= 3.12.2)
- Android SDK or Linux desktop build tools

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/limaduzz11/vanta-reader.git
   cd vanta-reader
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

---

## Testing & Quality

The codebase includes an automated test suite covering unit logic, BLoCs, SQLite migrations, and end-to-end integration:

```bash
# Verify formatting
dart format --output=none --set-exit-if-changed lib/ test/

# Run static analysis
flutter analyze

# Execute test suite
flutter test
```

All Pull Requests run these checks automatically through our [GitHub Actions CI](.github/workflows/ci.yml).

---

## Contributing

Contributions are welcome! Please check out [CONTRIBUTING.md](CONTRIBUTING.md) to get started, review our [Code of Conduct](CODE_OF_CONDUCT.md), and explore open issues.

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for milestone tracking, upcoming features (including PDF and CBR support), and release plans. All release updates are tracked in [CHANGELOG.md](CHANGELOG.md).

---

## License

Published under the [MIT License](LICENSE).

---

<div align="center">
  <sub>Maintained by <b>Eduardo de Lima Paranhos</b> · <b>VANTA Labz</b></sub>
</div>

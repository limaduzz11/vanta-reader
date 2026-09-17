# Architecture Overview

VANTA Reader follows **Clean Architecture** principles and a strict **Local-First** philosophy. Reading progress, library state, and downloaded assets are stored locally on the device using an embedded SQLite database. External content providers are decoupled behind clean interfaces, allowing new catalog sources to be integrated without modifying core reading engines.

---

## 🏛️ Architecture Layers

The codebase is organized into four distinct layers with a one-way dependency rule:

```text
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│    Screens (Home, Library, Search, Reader, Profile)         │
│    BLoCs / State Management (Reactive Streams)              │
│    Design System (VantaTheme, Components, Widgets)          │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dispatches Events / Listens to State
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       DOMAIN LAYER                          │
│    Pure Dart Models (Work, WorkEdition, ContentAsset)       │
│    Atomic Use Cases (ImportWork, SaveProgress, etc.)        │
│    Repository Interfaces & Provider Contracts               │
└──────────────────────────────┬──────────────────────────────┘
                               │ Implemented by
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                        DATA LAYER                           │
│    Repository Implementations                               │
│    Local Data Sources (SQLite WAL, Storage Manager)         │
│    Remote Content Providers (Decoupled Catalog Sources)     │
│    Work Identity & Deduplication System                     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Relies on
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                        CORE LAYER                           │
│    Database Migrations & Helpers (AppDatabase)              │
│    Content Parsers (EPUB, TXT, CBZ)                         │
│    Memory Management (LRU ComicPageCache)                   │
│    Logging & Security Utilities                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 Key Engineering Decisions

### 1. Local-First & Offline Resilience
- **SQLite Storage:** Metadata, library collections, authors, and reading progress (0–100%) are persisted locally via SQLite.
- **Zero Mandatory Accounts:** No cloud sync, registration, or third-party telemetry is required to use the app.
- **Network Decoupling:** Catalog discovery is strictly additive; network failure does not impact local reading or library browsing.

### 2. Specialized Reading Engines
- **Book Reader Engine:** Parses EPUB container files and raw TXT with chapter separation, dynamic typography scaling, and automatic progress saving.
- **Comic Reader Engine:** Handles CBZ archives (ZIP-compressed image bundles). Implements single-page viewing (pinch-to-zoom 2.2x), continuous vertical scrolling (Webtoon), and right-to-left (RTL) mode for Manga.
- **Memory Safeguards (LRU Cache):** Decoded comic page textures are managed through an in-memory LRU cache (`ComicPageCache`) with strict page and byte limits to prevent out-of-memory (OOM) crashes when viewing high-resolution scans.

### 3. Extensible Provider Architecture (`ContentProvider`)
External catalog sources implement an abstract `ContentProvider` interface:
- **Normalization:** Raw source responses are normalized into standard `Work` and `WorkEdition` entities.
- **Deduplication:** A `WorkIdentitySystem` matches works across providers using canonical identifiers and string similarity heuristics.
- **Fault Isolation:** Provider queries run concurrently with independent timeouts; failures in one provider do not block others.

---

## ⚖️ Known Limitations & Roadmap

- **PDF & CBR Formats:** PDF viewing and CBR (RAR) decompression are actively planned for future milestones.
- **CBZ Memory Footprint:** Currently, CBZ archives are decoded in memory before extracting pages. A streaming random-access extraction model is planned for large archives.

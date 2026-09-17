# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- PDF rendering engine support with continuous vertical scroll.
- CBR (RAR) decompression support for comic reader.
- Streaming random-access extraction for large CBZ archives.
- Automated release artifact signing and GitHub Releases pipeline.

## [0.3.0] - 2026-09-17

### Added
- Core Clean Architecture structure (`domain`, `data`, `core`, `presentation`).
- Embedded SQLite WAL persistence engine (schema v5) for books, comics, authors, and reading progress.
- Book Reader Engine with full EPUB container parsing and raw TXT support.
- Comic Reader Engine with CBZ support (ZIP archive unpacking and natural image sorting).
- In-memory LRU page cache (`ComicPageCache`) to safeguard against out-of-memory errors on high-resolution comics.
- Asynchronous Download Manager with HTTP Range resume capabilities and integrity verification.
- Decoupled `ContentProvider` catalog architecture with `WorkIdentitySystem` deduplication.
- Monochromatic Minimalism theme with high-contrast palette and adaptive layouts (Mobile and Tablet).
- Comprehensive automated test suite covering unit, BLoC, and end-to-end integration flows.
- GitHub Actions CI workflow for static analysis and automated testing.

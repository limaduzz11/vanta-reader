# Product Roadmap

This roadmap outlines the planned milestones for **VANTA Reader**. Priorities and scopes may adjust based on community feedback.

---

## 📍 Milestones

### Milestone 0.3.x — Foundation & Core Experience (Current)
- [x] Local-first SQLite schema and migrations engine.
- [x] Full EPUB and TXT reading support.
- [x] CBZ comic archive viewing (Single-page, Webtoon, and RTL Manga modes).
- [x] Memory protection via LRU page cache (`ComicPageCache`).
- [x] Decoupled catalog provider architecture.
- [x] Automated CI validation pipeline via GitHub Actions.

### Milestone 0.4.x — Reader Polish & Storage Enhancements
- [ ] Random-access / streaming CBZ extraction (eliminating full-archive in-memory buffer).
- [ ] Robust DOM/XML HTML parser for complex EPUB stylesheets and Ruby annotations.
- [ ] Modular SQLite DAO architecture and schema migration integration tests.
- [ ] Signed release APK builds published automatically to GitHub Releases.

### Milestone 0.5.x — PDF Engine Integration
- [ ] Native vector PDF rendering engine with pinch-to-zoom and continuous scroll.
- [ ] PDF table of contents (outlines) and bookmarking.

### Milestone 0.6.x — CBR & Archive Flexibility
- [ ] Native CBR (RAR) decompression support.
- [ ] Direct directory scanning and auto-import watcher for local storage.

### Milestone 1.0.0 — Production Release Candidate
- [ ] Multiplatform stabilization (Android Phone, Tablet, and Linux Desktop).
- [ ] Comprehensive accessibility auditing (TalkBack semantic tree optimization).
- [ ] End-user documentation and initial stable binary distribution.

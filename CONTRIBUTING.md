# Contributing to VANTA Reader

Thank you for your interest in contributing to **VANTA Reader**! We welcome bug reports, documentation enhancements, feature proposals, and code contributions.

---

## 📋 Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please be welcoming, respectful, and collaborative.

---

## 🛠️ Development Setup

1. **Prerequisites:**
   - [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel, >= 3.12.0)
   - Dart SDK (>= 3.12.2)
   - Android SDK / Studio (for mobile validation) or Linux desktop build tools

2. **Clone and Install:**
   ```bash
   git clone https://github.com/limaduzz11/vanta-reader.git
   cd vanta-reader
   flutter pub get
   ```

3. **Verify Environment:**
   ```bash
   flutter doctor
   flutter analyze
   flutter test
   ```

---

## 🏛️ Architecture Conventions

VANTA Reader enforces a strict **Clean Architecture** boundary:

- **`lib/domain/`:** Pure Dart only. Zero dependencies on Flutter UI packages or database drivers. Contains entities, repository interfaces, and atomic Use Cases.
- **`lib/data/`:** Concrete implementations of repository interfaces, database DAOs, local file storage, and decoupled catalog `ContentProvider` implementations.
- **`lib/core/`:** Cross-cutting concerns, database migrations (`AppDatabase`), cryptographic utilities, logging, and reader parsers.
- **`lib/presentation/`:** Flutter UI, widgets, screens, and state management using `flutter_bloc`. **UI widgets must never invoke database operations or HTTP endpoints directly.**

---

## 🧪 Quality Standards

Before submitting a Pull Request, please ensure all quality checks pass locally:

```bash
# 1. Formatting
dart format --output=none --set-exit-if-changed lib/ test/

# 2. Static Analysis
flutter analyze

# 3. Test Suite
flutter test
```

PRs must maintain 0 analysis warnings/errors and add automated tests for new logic.

---

## 🌿 Git Workflow

1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feat/my-new-feature
   # or
   git checkout -b fix/issue-description
   ```
2. Write concise, atomic commit messages following [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat(reader): ...`, `fix(storage): ...`, `docs: ...`).
3. Open a Pull Request against `main` using the provided PR template.

---

## 📄 License

By contributing to VANTA Reader, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).

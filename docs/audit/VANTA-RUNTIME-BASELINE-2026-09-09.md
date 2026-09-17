# VANTA Reader — Baseline Dinâmica Pré-Correção

**Data:** 2026-09-09  
**Código alterado:** não. Somente documentação e execução de validações.

## Ambiente

- Flutter 3.44.6 stable, revision `ee80f08bbf`.
- Dart 3.12.2.
- Android SDK 36.1.0; Java 17.0.20.
- Linux desktop disponível.
- Nenhum aparelho Android conectado.
- Flutter/Dart não estavam no `PATH`; binário usado: `/home/limaduzz/flutter/bin/flutter`.
- Chrome ausente, sem impacto no escopo Android/Linux atual.

## Comandos e resultados

| Validação | Resultado | Evidência |
|---|---|---|
| `flutter analyze` | PASS | `No issues found!`, 8,6 s |
| `flutter test` | PASS técnico | `+195: All tests passed!`, aproximadamente 23 s |
| `flutter build linux --debug` | PASS | bundle `build/linux/x64/debug/bundle/vantareader` |
| `flutter build apk --debug` | PASS | `build/app/outputs/flutter-apk/app-debug.apk` |
| Startup Linux por 20 s | PASS parcial | VM service abriu; storage, DB, downloads e providers inicializaram; Home chamou Open Library |

## Observações do runtime

1. O runtime registrou explicitamente três providers ativos:
   - `VANTA Reader Mock Provider`;
   - `Open Library`;
   - `Project Gutenberg (Gutendex)`.
2. Isso confirma que o mock participa do ambiente normal, não apenas dos testes.
3. A Home consultou com sucesso:
   - `https://openlibrary.org/trending/daily.json?limit=12`;
   - `https://openlibrary.org/subjects/graphic_novels.json?limit=10`.
4. O startup criou `vantareader.db` schema v3 no diretório de documentos VANTAReader.
5. A suíte executou chamadas reais ao Gutendex/Gutenberg em alguns testes, apesar de vários cenários usarem identidade/entrada de provider mock. Isso não comprova correlação da obra solicitada com o arquivo obtido.
6. A hipótese estática de erro de compilação em multiplicação de `String` foi refutada pelo analyzer e pelos dois builds no SDK Dart 3.12.2. O achado não permanece como blocker.

## Limites da evidência

- Não houve Android runtime porque nenhum aparelho/emulador estava disponível.
- O smoke Linux confirma startup e chamadas da Home, mas não valida interação manual completa em Search, Details, Library, Downloads, Profile e Readers.
- `195/195` verde comprova a suíte atual, não os requisitos finais: grande parte dos testes usa mocks, SQLite FFI ou estados injetados.
- O APK é debug; não é evidência de release.

## Gate

**BUILD/ANALYZE:** PASS.  
**RUNTIME FUNCIONAL:** WARNING — startup Linux comprovado, fluxos interativos e Android pendentes.  
**RELEASE:** BLOCK.

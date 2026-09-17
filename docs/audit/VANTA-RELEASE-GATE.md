# VANTA Reader — Release Gate v1.0.0

**Produto:** VANTA Reader
**Empresa:** VANTA Labz
**Responsável:** NOVA / Eduardo de Lima Paranhos
**Status do Gate:** **WARNING — DEBUG VALIDADO NO DEVICE (BUILD 15/09); RELEASE ASSINADA PENDENTE**
**Data:** 15/09/2026  

---

## 1. Critérios de Liberação e Verificação de Conformidade

| Critério de Qualidade | Requisito Operacional | Evidência de Verificação | Veredito |
|---|---|---|:---:|
| **1. Branding & Identidade** | Exclusivo VANTA Reader / VANTA Labz, sem referências legadas na UI | Validado em strings, assets e temas | PASS |
| **2. Inicialização Sem Travamento** | Carregamento reativo direto na Home sem splash animado bloqueante | Validado na inicialização real e widget tests | PASS |
| **3. Biblioteca Limpa (Soberania)** | Sem injeção de livros simulados de teste no banco em produção | `removeLegacySeedMocks()` executado e validado | PASS |
| **4. Acervo Real e Capas Reais** | Consumo de capas e metadados reais da OpenLibrary / Gutendex | `OpenLibraryContentProvider` testado e validado | PASS |
| **5. Busca Rápida e Abrangente** | Latência sub-3s, 9 termos obrigatórios validados com tolerância | 7/7 testes na matriz diagnóstica PASS | PASS |
| **6. Carrossel de HQs Rico** | Acervo de HQs com múltiplos títulos de `subjects/graphic_novels.json` | 13.600+ obras indexadas no endpoint | PASS |
| **7. Leitor 100% Fullscreen** | Ocultamento total do BottomNavigationBar durante a leitura | `rootNavigator: true` + `fullscreenDialog: true` | PASS |
| **8. Controles Imersivos Ocultos** | Barras superior/inferior fechadas por padrão, abrem com toque | `areControlsVisible = false` validado por teste | PASS |
| **9. Suíte de Testes Automatizada** | 100% dos testes da aplicação verdes com zero falhas | 219/219 (15/09) | PASS |
| **10. Compilação de Artefato APK** | Build do pacote Android com Gradle concluído com sucesso | APK 15/09 c/ `--dart-define` (194 MB), SHA-256 `112a74af…5001d43d` (Java 17 + SDK real) | PASS (DEBUG) |
| **11. Entrega ao dispositivo** | APK copiado e íntegro no armazenamento do aparelho | `adb install -r` 15/09: **Success** (SM-A366E `RXGYC06QKTX`) | PASS |
| **12. Instalação/startup Android** | ADB conectado, instalação e inicialização observadas | 15/09: PID ativo, `MainActivity` resumed, sem fatal no logcat | PASS |
| **13. Release assinada** | Keystore/release signing e APK/AAB release verificáveis | Não validado nesta rodada | PENDING |

---

## 2. Assinatura e Autorização de Deploy

Build **debug** 15/09 (todas as frentes: API v0.2 + provider `vanta-catalog` + Ondas 1–3, schema v5, 216/216) **instalado e inicializado no Samsung SM-A366E** em 15/09: `adb install -r` Success, PID 13619, `MainActivity` resumed, sem fatal no logcat. Resta: keystore/release. Notas de ambiente: build exige `ANDROID_HOME=/home/limaduzz/Android/Sdk` e Java 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`) — JDK 26 padrão quebra o Gradle e sem `ANDROID_HOME` ele resolve o SDK errado (`~/.local`, NDK sem licença).

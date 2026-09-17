# NovaReader — Arquitetura de Segurança, Hardening & Criptografia (Fase P)

## 1. Visão Geral & Filosofia de Segurança

O **NovaReader** foi projetado sob os pilares fundamentais de **Privacidade Absoluta**, **Local-First** e **Open Source Readiness**. Sendo uma aplicação concebida para distribuição pública em código aberto, o sistema adota uma postura de segurança defensiva em camadas (*defense in depth*), assegurando que:

1. **Zero Host Leakage:** Nenhum dado pessoal do desenvolvedor, caminhos absolutos de sistema ou tokens de desenvolvimento permanecem no código-fonte ou em logs de execução.
2. **Device-Isolated Sandbox:** Cada usuário que instalar o aplicativo possui uma sandbox 100% isolada e privada em seu próprio dispositivo, sem compartilhamento com nuvens compulsórias ou telemetrias invasivas.
3. **Criptografia Ponta a Ponta & Repouso:** Criptografia padrão industrial de alto nível (AES-256) combinada com integridade HMAC-SHA256 e verificação em tempo constante (*constant-time*).
4. **Blindagem contra Ataques de Entrada:** Mitigação sistemática contra Zip Slip, Path Traversal, Cleartext Injection e Insecure Backups.

---

## 2. Cofre Criptográfico (`CryptoVault`)

O módulo [`lib/core/security/crypto_vault.dart`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/lib/core/security/crypto_vault.dart) provê uma interface segura e tipada para manipulação de dados criptográficos.

### Algoritmos & Primitivas
- **Cifragem Simétrica:** AES-256 no modo CBC com preenchimento PKCS7.
- **Entropia de Chaves:** Geração de chaves seguras de 256 bits (32 bytes) com geradores pseudo-aleatórios criptograficamente seguros (CSPRNG via `Key.fromSecureRandom(32)`).
- **Vetores de Inicialização (IV):** Cada operação de encriptação gera um novo IV aleatório de 128 bits (16 bytes) (`IV.fromSecureRandom(16)`), garantindo que dois textos planos idênticos produzam saídas completamente imprevisíveis e distintas.
- **Derivação de Chaves (KDF):** Função determinística de derivação de chaves baseada em HMAC-SHA256 (PBKDF2-like) com 10.000 iterações e validação obrigatória de salt.
- **Integridade & Autenticidade (HMAC-SHA256):** Toda mensagem ou payload pode ser assinado com HMAC-SHA256.
- **Comparação em Tempo Constante (Anti-Timing Attacks):** O método `_constantTimeEquals` impede ataques de temporização (*side-channel timing attacks*) ao comparar hashes e assinaturas de integridade bit a bit.

### Formato de Transmissão Ponta a Ponta (E2EE)
O NovaReader suporta envelopes criptografados ponta a ponta para compartilhamento e backup seguro:
```json
{
  "version": "1.0",
  "cipher": "AES-256-CBC-HMAC-SHA256",
  "sender_id": "device-peer-alpha",
  "timestamp": "2026-09-09T14:00:00.000Z",
  "payload": "<iv_base64 + ciphertext_base64>",
  "signature": "<hmac_sha256_hex>"
}
```
O método `openSecurePackage` valida rigorosamente a integridade da assinatura antes de tentar qualquer decifragem, mitigando ataques de oráculo de preenchimento (*padding oracle attacks*) e manipulação em trânsito.

---

## 3. Proteção contra Zip Slip e Path Traversal

Arquivos de quadrinhos (`.cbz`, `.cbr`, `.zip`) e livros (`.epub`) são arquivos compactados que podem conter entradas maliciosas projetadas para escapar do diretório pretendido e sobrescrever arquivos do sistema ou do aplicativo.

### Mitigações Implementadas
No [`StorageManager`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/lib/core/storage/storage_manager.dart):
1. **`validateSafeFileName(String fileName)`:** Rejeita estritamente qualquer nome que contenha `..`, `/`, `\`, caracteres nulos ou espaços em branco vazios.
2. **`resolveSafeZipEntry(Directory targetDir, String entryPath)`:** Normaliza o caminho pretendido e valida que a resolução canônica via `p.isWithin(targetDir.path, resolvedPath)` reside estritamente dentro da pasta de destino.
3. **`isSafeZipEntry(String entryPath)`:** Utilizado como filtro prévio rápido em `CbzExtractor` e `ComicContentParser` para descartar entradas perigosas antes de qualquer processamento de descompactação.

---

## 4. Hardening de Rede & Transporte

### Política Estrita de Cleartext Traffic
No [`NetworkClient`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/lib/core/network/network_client.dart):
- Toda requisição HTTP passa pelo validador `validateUrlSecurity(String url)`.
- URLs que utilizam o esquema `http://` para servidores remotos na internet são sumariamente rejeitadas com `NovaException(kind: NovaErrorKind.networkError)`.
- Apenas conexões com `https://` são permitidas para tráfego remoto. Conexões `http://` são autorizadas exclusivamente em instâncias locais de desenvolvimento/emulação (`localhost`, `127.0.0.1`, `10.0.2.2`).

### Configuração do Android Manifest
Em `android/app/src/main/AndroidManifest.xml`:
- `android:usesCleartextTraffic="false"`: Impede o sistema operacional Android de realizar transmissões em texto puro não criptografado.
- `android:allowBackup="false"`: Impede que utilitários como `adb backup` extraiam os bancos de dados privados SQLite, arquivos e preferências locais do leitor.
- `<uses-permission android:name="android.permission.INTERNET" />`: Declaração explícita necessária para conexões de rede seguras.

---

## 5. Sanitização de Logs & Host Isolation

No [`AppLogger`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/lib/core/logging/app_logger.dart):
O método `sanitizeMessage(String input)` inspeciona todas as mensagens emitidas no aplicativo antes de armazená-las no buffer de memória ou no console de desenvolvimento:
- **Tokens Bearer:** Convertidos para `Bearer ***REDACTED***`.
- **Senhas e Chaves:** Padrões como `password: ...`, `token: ...`, `key: ...` são mascarados para `***REDACTED***`.
- **Caminhos Locais de Host:** Diretórios contendo `/home/*`, `/media/*` ou `C:\Users\*` são automaticamente substituídos por `[SANDBOX_USER_DIR]`, impedindo o vazamento da estrutura de pastas da máquina de quem compilar ou testar o app.

---

## 6. Open Source Readiness & Git Hardening

1. **Perfil Inicial:** O leitor inicial é nomeado como `"Leitor"` (substituindo qualquer identificação do autor original).
2. **Gitignore Restrito:** Regras estritas adicionadas para impedir o commit acidental de arquivos com caminhos do desenvolvedor (`android/local.properties`), caches de compilação (`android/.gradle/`), chaves de assinatura (`*.jks`, `*.keystore`, `*.key`) e variáveis de ambiente (`.env*`).

---

## 7. Matriz de Testes de Segurança (18 Testes Dedicados)

Localizados em [`test/core/security_test.dart`](file:///media/limaduzz/HD%201TB%20LDUZZ%202/NOVA%20CONTEXT%20ENGINE%20V2/02-PROJECTS/NOVAREADER/test/core/security_test.dart):
1. Geração de chaves de 256 bits com alta entropia.
2. Derivação determinística PBKDF2/SHA-256 e validação de segredo/salt.
3. Cifragem e decifragem AES-256-CBC com IV dinâmico único por cifragem.
4. Rejeição de payload adulterado ou malformado.
5. Cifragem e decifragem de bytes binários com preservação de integridade.
6. Assinaturas HMAC-SHA256 em tempo constante.
7. Envelope E2EE: empacotamento e desempacotamento com validação de integridade.
8. Envelope E2EE: rejeição de adulteração em trânsito (Man-in-the-Middle).
9. Bloqueio de navegação relativa (`..`), barras e caracteres nulos em `validateSafeFileName`.
10. Resolução segura de subdiretórios válidos em `resolveSafeZipEntry`.
11. Bloqueio de Zip Slip para diretórios superiores (`../../etc/passwd`).
12. Detecção e filtragem rápida de entradas zip via `isSafeZipEntry`.
13. Mascaramento de tokens Bearer e senhas no `AppLogger`.
14. Mascaramento de diretórios do host (`/home/...`, `/media/...`, `C:\Users\...`) no `AppLogger`.
15. Permissão de URLs HTTPS seguras em `NetworkClient`.
16. Permissão de HTTP exclusivo para loopback de desenvolvimento (`localhost`, `127.0.0.1`, `10.0.2.2`).
17. Bloqueio de HTTP claro para servidores remotos na internet.
18. Rejeição de esquemas não suportados (`ftp://`, sem esquema).

# ADR-017: Security Hardening, Cryptographic Vault, and Open-Source Sandbox Isolation

- **Status:** Aceito
- **Data:** 2026-09-09
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase P — Auditoria de Segurança & Hardening

---

### Contexto e Problema

Com a preparação do NovaReader para publicação em código aberto (Open Source) e utilização por uma comunidade global de leitores, a segurança, privacidade e isolamento de dados tornaram-se requisitos não-negociáveis:
1. **Risco de Host Leakage:** Projetos de código aberto não podem conter identificadores pessoais rígidos, nomes de usuários da máquina do autor ou caminhos absolutos do ambiente de desenvolvimento.
2. **Privacidade em Repouso e em Trânsito:** O usuário precisa de garantias de que suas informações locais, notas, sincronizações e pacotes exportados possam ser criptografados com padrões seguros da indústria (AES-256 e HMAC-SHA256).
3. **Vulnerabilidades de Arquivos Compactados (Zip Slip / Path Traversal):** Quadrinhos (`.cbz`) e livros (`.epub`) são arquivos ZIP manipulados localmente. Arquivos maliciosos com nomes como `../../system/file` poderiam sobrescrever arquivos fora da sandbox do app.
4. **Tráfego em Texto Puro (Cleartext Traffic):** O envio de dados por HTTP sem criptografia expõe o leitor a ataques de homem-no-meio (MitM), interceptação de credenciais e adulteração de conteúdo.
5. **Vazamento de Chaves e Configurações:** Arquivos de propriedades de build locais (`local.properties`), chaves de assinatura e segredos devem ser protegidos contra inclusão acidental em repositórios de controle de versão.

---

### Decisões de Arquitetura

1. **Cofre Criptográfico de Nível Industrial (`CryptoVault`):**
   - Implementação de cifragem simétrica AES-256 no modo CBC com preenchimento PKCS7.
   - Geração de chaves criptograficamente seguras com 256 bits (`Key.fromSecureRandom(32)`).
   - Derivação determinística de chaves via PBKDF2/SHA-256 com 10.000 iterações.
   - IV pseudoaleatório de 16 bytes gerado a cada cifragem para garantir não-repetição de cifras.
   - Autenticação de integridade via HMAC-SHA256 com comparação em tempo constante (`_constantTimeEquals`) contra ataques de temporização (*timing attacks*).
   - Envelopes E2EE estruturados (`createSecurePackage` e `openSecurePackage`) com validação de assinatura antes da decifragem.

2. **Mitigação Defensiva contra Zip Slip e Path Traversal:**
   - Adição dos métodos `resolveSafeZipEntry` e `isSafeZipEntry` em `StorageManager`.
   - Validação canônica garantindo que qualquer extração ou leitura resida estritamente contida dentro do diretório sandbox (`p.isWithin(targetDir.path, resolvedPath)`).
   - Integração do filtro de segurança em `CbzExtractor` e `ComicContentParser`.

3. **Hardening de Transporte de Rede:**
   - Implementação de `NetworkClient.validateUrlSecurity(url)`, impondo HTTPS obrigatório para todos os servidores remotos.
   - Bloqueio imediato de texto puro (`http://`) para a internet externa, com exceção controlada para loopback/emulação local de desenvolvimento (`localhost`, `127.0.0.1`, `10.0.2.2`).
   - Configuração de `android:usesCleartextTraffic="false"` e `android:allowBackup="false"` no `AndroidManifest.xml`.
   - Declaração explícita de `<uses-permission android:name="android.permission.INTERNET" />`.

4. **Sanitização Automatizada de Logs e Isolamento de Host:**
   - No `AppLogger`: regex para mascaramento automático de tokens Bearer (`Bearer ***REDACTED***`), credenciais (`password: ***REDACTED***`) e caminhos locais (`/home/*`, `/media/*`, `C:\Users\*` substituídos por `[SANDBOX_USER_DIR]`).
   - Substituição do nome de perfil padrão inicial de `"Eduardo"` para `"Leitor"`, eliminando qualquer vínculo identitário da máquina host.
   - Expansão do `.gitignore` com regras rígidas para proteger `local.properties`, `.gradle`, keystores (`*.jks`, `*.keystore`) e arquivos de ambiente (`.env*`).

---

### Consequências

#### Positivas
- **Prontidão para Open Source:** O código está desacoplado do ambiente local do desenvolvedor e seguro para distribuição pública.
- **Proteção Completa do Dispositivo do Usuário:** Imunidade a ataques de Zip Slip e Path Traversal originados de arquivos externos baixados ou importados.
- **Canal Seguro Garantido:** Conexões remotas sem HTTPS são impedidas no nível do cliente e no nível do sistema operacional.
- **Segurança Criptográfica Verificável:** Suíte dedicada com 18 testes automatizados de segurança garantindo o correto funcionamento do `CryptoVault`, `StorageManager`, `AppLogger` e `NetworkClient`.

#### Negativas / Trade-offs
- **Sobrecarga Computacional Marginal:** A geração de IVs aleatórios, derivação de chaves PBKDF2 e cálculo de HMAC-SHA256 introduzem pequeno custo de CPU, insignificante perante o tempo de I/O de arquivos e rede.
- **Rejeição de Provedores HTTP Inseguros:** Provedores de conteúdo que não ofereçam suporte a HTTPS serão rejeitados, forçando a adoção exclusiva de origens criptografadas.

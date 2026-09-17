# NovaReader — Motor de Provedores, Normalização e Deduplicação (Fase I)

O **Provider Engine** do NovaReader é a espinha dorsal de interoperabilidade com fontes de conteúdo externas e internas. Ele estabelece uma arquitetura agnóstica baseada em contratos estritos (`ContentProvider`), registro dinâmico (`ProviderRegistry`), isolamento contra falhas e timeouts concorrentes (`ProviderManager`), higienização de dados (`MetadataNormalizer`) e unificação canônica inteligente com deduplicação de edições (`WorkIdentitySystem`).

---

## 1. Arquitetura do Subsistema

```
lib/
├── core/
│   └── providers/
│       ├── provider_models.dart       # ExternalWorkMetadata, NormalizedWorkMetadata, ProviderCapabilities, ProviderHealth
│       ├── content_provider.dart      # Contrato abstrato de provedor de conteúdo
│       ├── provider_registry.dart     # Registro, ativação e desativação em tempo de execução
│       ├── provider_manager.dart      # Orquestrador de busca paralela com isolamento + skip offline
│       ├── metadata_normalizer.dart   # Sanitização HTML, normalização de autor, título, ISBN e idioma
│       ├── work_identity_system.dart  # Algoritmo de workKey canônica, Levenshtein e fusão de obras
│       ├── vanta/
│       │   ├── vanta_config.dart      # base URL, timeout, prefixo vanta_, runtime override, --dart-define
│       │   └── vanta_models.dart      # DTOs do contrato neutro (Search/Edition/File/Health)
│       └── ...
├── data/
│   └── datasources/
│       └── providers/
│           ├── mock_content_provider.dart # Provedor simulado de alta fidelidade com livros e quadrinhos
│           ├── open_library_content_provider.dart # metadata-only
│           ├── gutendex_content_provider.dart # PD com EPUB/TXT
│           ├── internet_archive_content_provider.dart # HQ PD com CBZ
│           └── vanta_catalog_content_provider.dart # fonte oficial VANTA Catalog (gateway neutro)
```

---

## 2. Contratos e Modelos de Domínio (`provider_models.dart` & `content_provider.dart`)

### `ProviderCapabilities`
Declara as funcionalidades suportadas por cada provedor:
- `supportsSearch`: Se suporta buscas textuais por catálogo.
- `supportsDownload`: Se fornece URLs de download resolvidas.
- `supportsStreaming`: Se permite leitura direta sem download prévio.
- `supportedFormats`: Formatos manipulados (`WorkFormat.epub`, `pdf`, `cbz`, etc.).
- `supportedLanguages`: Idiomas atendidos (`pt-BR`, `en`).
- `rateLimitPerMinute`: Limite de requisições para evitar rate-limiting.

### `ProviderHealth` & `ProviderStatus`
- `healthy`: Provedor operando com latência normal e respostas válidas.
- `degraded`: Provedor respondendo com lentidão ou taxas parciais de erro.
- `offline`: Provedor indisponível ou inacessível.
- `disabled`: Desativado administrativamente pelo usuário.

### `ContentProvider` (Interface Canônica)
```dart
abstract class ContentProvider {
  String get id;
  String get name;
  String get version;
  ProviderCapabilities get capabilities;
  Duration get timeout;

  Future<ProviderHealth> checkHealth();
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  });
  Future<ExternalWorkMetadata?> getDetails(String externalId);
  Future<String?> resolveDownloadUrl(String externalId, WorkFormat format);
}
```

---

## 3. Higienização e Normalização (`MetadataNormalizer`)

Fontes externas (APIs públicas, feeds RSS, bibliotecas parceiras) frequentemente retornam metadados ruidosos, tags HTML sujas, nomes de autores invertidos ou idiomas com nomenclaturas não padronizadas. O `MetadataNormalizer` resolve isso de forma determinística:

1. **`sanitizeText`:**
   - Remove tags HTML (`<p>`, `<b>`, `<i>`, etc.).
   - Converte entidades HTML comuns (`&nbsp;`, `&amp;`, `&quot;`, `&#39;`).
   - Remove caracteres de controle ASCII e espaços invisíveis unicode (`\u00A0`, `\u200B`).
   - Normaliza múltiplos espaços consecutivos para um único espaço.

2. **`normalizeTitle`:**
   - Detecta e extrai subtítulos embutidos no título principal separados por `:`, `—`, ` - ` ou ` | `.
   - Remove redundâncias quando o provedor envia o subtítulo duplicado dentro do título principal.

3. **`normalizeAuthor`:**
   - Inverte formatos de catalogação bibliográfica: `"Herbert, Frank"` vira `"Frank Herbert"`.
   - Remove prefixos espúrios como `"Por "`, `"By "`, `"Autor: "`.
   - Junta múltiplos autores preservando o autor principal.

4. **`normalizeLanguage`:**
   - Normaliza variantes como `'pt'`, `'pt_BR'`, `'por'`, `'portuguese'` para o código ISO oficial do NovaReader: `'pt-BR'`.
   - Normaliza variantes em inglês (`'en'`, `'en_US'`, `'eng'`) para `'en'`.

5. **`normalizeIsbn`:**
   - Limpa caracteres de pontuação e valida comprimento estrito (10 ou 13 dígitos numéricos ou terminados em X).

---

## 4. Identidade Canônica e Deduplicação (`WorkIdentitySystem`)

O problema central de agregar múltiplos provedores é a proliferação de duplicatas da mesma obra. O `WorkIdentitySystem` implementa o pipeline de unificação:

### Geração da Chave Canônica (`workKey`)
- **Regra 1 (ISBN):** Se um ISBN válido estiver presente em qualquer um dos itens, ele possui precedência máxima: `isbn_{cleanIsbn}`.
- **Regra 2 (Slug Fonético de Título e Autor):**
  - Remove acentos e diacríticos.
  - Filtra stop-words comuns em português e inglês (`o`, `a`, `de`, `do`, `the`, `of`, etc.).
  - Mapeia sinônimos cross-language conhecidos (ex: `"Dune"` mapeia para `"Duna"`).
  - Ordena alfabeticamente os tokens do autor para que `"Frank Herbert"` e `"Herbert, Frank"` gerem exatamente o mesmo slug de autor (`frank_herbert`).
  - Gera chave composta: `${slugTitle}__${slugAuthor}` (ex: `duna__frank_herbert`).

### Fusão de Obras (Merge)
Quando duas ou mais entradas compartilham a mesma chave canônica ou possuem alta similaridade de Levenshtein (autor >= 0.75 e título >= 0.75):
1. **Título:** Seleciona a versão em português (`pt-BR`) se disponível, com subtítulo detalhado.
2. **Autor:** Seleciona a representação com maior número de caracteres descritivos.
3. **Descrição:** Seleciona a sinopse mais informativa (maior comprimento textual).
4. **Capa:** Seleciona a melhor URL de imagem disponível.
5. **Edições:** Consolida todas as edições (`WorkEdition`) de todos os provedores em uma única lista, descartando duplicatas exatas de formato e URL. O usuário enxerga uma única obra com todas as opções de download agrupadas (EPUB, PDF, CBZ).

---

## 5. Orquestrador Paralelo com Isolamento de Falhas (`ProviderManager`)

- **Concorrência:** Dispara pesquisas em paralelo para todos os provedores registrados e ativados no `ProviderRegistry` via `Future.wait`.
- **Isolamento de Erros:** Cada chamada a um provedor possui timeout individual (`provider.timeout`). Se um provedor externo lançar exceção de rede, timeout ou HTTP 500, o erro é registrado no `AppLogger.error` e o provedor retorna lista vazia, **sem derrubar ou travar a busca dos outros provedores ativos**.
- **Skip offline (desde 15/09):** após falha de timeout/erro, o provedor é marcado offline por **2 minutos** (TTL). Buscas subsequentes pulam esse provedor sem penalizar a latência global. Sucesso limpa a marcação. Teste: `test/core/provider_offline_skip_test.dart`. Isso resolveu o problema de buscas que custavam o timeout cheio (15 s) quando o gateway local estava fora do ar.
- **Ranking e Relevância:** Ordena a lista unificada priorizando correspondência exata de título, prefixo de título, correspondência de autor, preferência de idioma (`pt-BR` prioritário) e maior quantidade de formatos disponíveis.
- **Diagnóstico Unificado:** `checkAllHealth()` varre a integridade de todos os provedores em paralelo (timeout 5 s cada).

---

## 6. Provedor Simulado (`MockContentProvider`)

O `MockContentProvider` fornece um acervo representativo para testes de ponta a ponta sem tráfego de internet:
- Livros de Ficção Científica, Computação e Clássicos da Literatura em `pt-BR` e `en`.
- Quadrinhos, HQs e Mangás em `CBZ` e `Imagens`.
- Variações intencionais para validar a deduplicação de edições (Duna/Dune, Clean Code/Código Limpo, Watchmen).
- Controles de teste para injeção de latência (`simulatedLatency`), timeout proposital (`simulateTimeout`) e simulação de erros (`simulateError`).

---

## 7. Fonte oficial VANTA Catalog (IMPLEMENTADO 2026-09-15)

Gateway neutro FastAPI (`vanta_api.py` v0.2.0) + SQLite+FTS5. Contrato: `docs/VANTA-CATALOG-API.md`.

- Provider Flutter `vanta-catalog` (`VantaCatalogContentProvider` v1.0.0): `search`→`/v1/search` (page/pageSize→limit/offset), `getDetails`→`/v1/books/{id}`, `resolveDownloadUrl`→`/v1/files/{id}/download`, `checkHealth`→`/health`.
- `externalId` com prefixo `vanta_` (sem colisão com OL/IA/Gutendex); `externalEditionId` = file primário; `topic==c`→`comic` (fallback `cbz`/`cbr`→comic); `downloadUrl` sempre resolvido sob demanda (nunca embutido).
- Capabilities: `supportsDownload=true`, `supportsStreaming=false`, `metadataOnly=false`, `contentSourceType=officialCatalog`.
- Sem `/v1/files/*` no servidor o provider degradaria para metadata-only; com v0.2 o download é 307 opaco (501 sem `VANTA_PROVIDER_DOWNLOAD_TEMPLATE`).
- Registro em `lib/injection.dart` após Internet Archive (sem mudar `ProviderManager`/`SearchBloc`/telas).
- Testes: `test/data/providers/vanta_catalog_content_provider_test.dart` (8 casos Dio mock).

### Configuração do gateway em runtime (G-01 fim-a-fim, 15/09)

A base URL do gateway **não exige rebuild** para ajustar no aparelho físico:

- Precedência: `--dart-define=VANTA_API_BASE_URL` > Perfil > Gateway > default (`http://10.0.2.2:8080`, só-emulador).
- `VantaConfig.runtimeOverride` é persistido na tabela `settings` (`vanta_api_base_url`) e aplicado ao abrir o app (`main.dart` chama `VantaConfig.loadPersisted()`).
- No Samsung físico: use `http://127.0.0.1:PORTA` no app + `adb reverse tcp:PORTA tcp:PORTA` no host.
- Na LAN: use o IP da máquina host (ex: `http://192.168.x.x:8081`), sem reverse.
- Tela **Perfil > Gateway do Catálogo** salva e aplica de imediato.

# NovaReader — Pipeline de Importação de Arquivos Locais (Fase E)

- **Versão:** 1.0.0
- **Data:** 2026-09-08
- **Status:** Implementado e Verificado (37/37 testes)
- **Princípio:** Local-First, Zero Dependência de Rede, Sandboxing e Integridade SHA-256.

---

## 1. Visão Geral

O NovaReader disponibiliza uma infraestrutura autônoma para importação de livros digitais e histórias em quadrinhos diretamente do armazenamento local do dispositivo (Android e Linux Desktop).

Ao selecionar um arquivo (`.epub`, `.cbz`, `.cbr`, `.pdf`, `.txt`, `.zip`), o sistema executa um pipeline rigoroso em 8 etapas:
1. **Validação de Existência e Formato:** Detecção estrita da extensão e integridade do arquivo.
2. **Extração Especializada de Metadados:** Parsing em streaming/memória com fallback gracioso.
3. **Identificação e Deduplicação Canônica:** Geração de `workKey` e IDs únicos (`UUIDv4`).
4. **Cálculo Criptográfico de Checksum:** Hash SHA-256 para rastreamento de edições e integridade.
5. **Particionamento Físico Seguro:** Cópia para `/books` ou `/comics` via `StorageManager` com nomes sanitizados contra *Path Traversal*.
6. **Extração e Persistência de Capas:** Armazenamento isolado da capa em `/covers` com formato e dimensões preservadas.
7. **Construção de Entidades de Domínio:** Criação imutável de `Work` e `WorkEdition`.
8. **Indexação Relacional no SQLite:** Gravação atômica em transação nas tabelas `works`, `work_editions` e `library`.

---

## 2. Extratores Especializados

### 2.1. EPUB Extractor (`EpubExtractor`)
- **Padrão Suportado:** EPUB 2 e EPUB 3 (arquivos ZIP).
- **Mapeamento:**
  - Localiza `META-INF/container.xml` via `ZipDecoder`.
  - Resolve o caminho canônico do manifesto OPF (`content.opf`).
  - Decodifica XMLs em UTF-8 (`allowMalformed: true`).
  - Extrai:
    - `<dc:title>` ou `<title>` -> `title`
    - `<dc:creator>` -> `author`
    - `<dc:description>` -> `description`
    - `<dc:language>` -> `primaryLanguage` ('pt-BR' ou 'en')
    - `<dc:publisher>`, `<dc:date>`, `<dc:identifier>` (ISBN).
  - Capa:
    - EPUB 3: item com `properties="cover-image"`.
    - EPUB 2: `<meta name="cover" content="id"/>` associado ao manifesto.
    - Heurística: item de imagem cujo ID ou HREF contenha "cover".
  - Contagem de páginas: número de `<itemref>` no `<spine>`.

### 2.2. CBZ Extractor (`CbzExtractor`)
- **Padrão Suportado:** Comic Book Archive ZIP (`.cbz`, `.zip`).
- **Mapeamento:**
  - Identifica todas as páginas de imagem válidas (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`), ignorando metadados de sistema (`__MACOSX`, `.DS_Store`).
  - Ordenação alfabética natural das imagens para seleção da capa (primeira página).
  - Suporte ao manifesto `ComicInfo.xml` (especificação ComicRack / Tachiyomi):
    - `<Title>`, `<Series>`, `<Number>` (volume), `<Writer>` / `<Penciller>`, `<Summary>`, `<PageCount>`, `<LanguageISO>`.
  - Fallback gracioso quando `ComicInfo.xml` não existir: o título torna-se o nome do arquivo sanitizado e a contagem de páginas reflete a quantidade de imagens do pacote.

### 2.3. PDF Extractor (`PdfExtractor`)
- Extrai título derivado do arquivo ou metadados de cabeçalho.
- Determina quantidade de páginas por tokens `/Type /Page` ou contagem de dicionário.

### 2.4. TXT Extractor (`TxtExtractor`)
- Extrai título a partir do nome do arquivo.
- Estima paginação canônica (35 linhas ou 2.000 caracteres por página).

---

## 3. Segurança e Hardening

1. **Proteção contra Path Traversal:** O `StorageManager.getSafeFile` valida se os nomes de arquivos não contêm `..`, barras invertidas ou caracteres de escape, garantindo que o arquivo nunca seja gravado fora de seu subdiretório designado.
2. **Zip Slip Prevention:** Os arquivos dentro dos archives ZIP são descompactados por leitura direta de streams de bytes, sem extração recursiva desprotegida para o disco.
3. **Deduplicação Inteligente:** A chave canônica `WorkIdentitySystem.generateWorkKey(title, author)` normaliza acentuação, caixa e caracteres especiais, evitando duplicatas desordenadas na biblioteca.

---

## 4. Integração na Interface do Usuário

- **Localização:** Tela da Biblioteca (`LibraryScreen`).
- **Gatilhos:**
  - Botão de ação de importação na `AppBar` (`Icons.file_upload_outlined`).
  - `FloatingActionButton.extended` minimalista no canto inferior direito ("Importar").
- **Feedback:** SnackBar monocromática com cantos arredondados e borda sutil, confirmando a importação em tempo real sem desmontar o estado visual do usuário.

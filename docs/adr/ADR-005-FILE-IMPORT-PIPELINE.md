# ADR-005: Pipeline de Importação de Arquivos Locais, Extratores e Proteção de Storage

- **Status:** Aceito
- **Data:** 2026-09-08
- **Autor:** Eduardo de Lima Paranhos & NOVA Platform
- **Contexto:** Fase E — Importação de Arquivos Locais (File Import)

---

### Contexto e Problema

Para atender à proposta de valor do NovaReader como leitor unificado e autônomo, os usuários devem poder carregar suas próprias coleções de livros (EPUB, PDF, TXT) e quadrinhos digitais (CBZ, CBR) a partir do armazenamento físico do aparelho.

Os desafios técnicos incluíram:
1. Extração rápida de metadados sem congelar a thread de UI.
2. Identificação confiável de capas dentro de arquivos ZIP e EPUB (com layouts EPUB 2, EPUB 3 e ComicInfo).
3. Prevenção estrita de vulnerabilidades de segurança como *Zip Slip* e *Path Traversal*.
4. Gravação atômica da obra no banco SQLite em modo WAL com vínculo direto com o sistema de arquivos particionado do `StorageManager`.
5. Interface reativa que exibe a nova obra importada na biblioteca imediatamente.

---

### Decisões de Arquitetura

1. **Abstração por Fábrica de Extratores (`WorkExtractorFactory`):**
   - O pipeline utiliza extratores dedicados (`EpubExtractor`, `CbzExtractor`, `PdfExtractor`, `TxtExtractor`) implementados sobre o pacote puro Dart `archive` e `xml`.
   - A decodificação de XMLs é feita estritamente em UTF-8 com fallback resiliente para caracteres malformados.
   - A extração da imagem de capa ocorre diretamente a partir dos bytes em memória, gravando o arquivo resultante em `/covers/cover_{editionId}.jpg`.

2. **Segurança de Armazenamento e Sandboxing:**
   - O arquivo original é copiado de forma sanitizada para o subdiretório canônico correspondente (`/books` para livros e `/comics` para quadrinhos).
   - O `StorageManager` assegura que qualquer nome de arquivo manipulado passe por `validateSafeFileName`, impedindo que arquivos ultrapassem a sandbox da aplicação.
   - O cálculo de hash SHA-256 é realizado no momento da importação, garantindo integridade física e rastreabilidade de versões.

3. **Injeção Desacoplada de Seletor de Arquivos (`IFilePickerService`):**
   - O seletor de arquivos foi encapsulado sob a interface `IFilePickerService`, utilizando `file_picker` em produção (suporte a Linux Desktop e Android) e mocks determinísticos em testes automatizados.

4. **Gerenciamento de Estado Fluido no BLoC:**
   - O evento `ImportWorkEvent` foi integrado ao `LibraryBloc`. A biblioteca recarrega preservando os filtros ativos e emite `LibraryLoaded` com `lastImportedTitle`, disparando feedback não disruptivo via `SnackBar` na UI.

---

### Consequências

- **Positivas:**
  - Suporte completo a importação de EPUB, CBZ, PDF e TXT verificado com 37 testes automatizados.
  - Zero duplicação de dados e zero bloqueio de UI: parsing leve e gravação atômica em SQLite.
  - Experiência de usuário fluida em smartphones e tablets Android e no Linux Desktop.
- **Negativas / Mitigações:**
  - Arquivos CBZ de altíssima resolução (1GB+) podem exigir consumo momentâneo de memória: mitigado pela leitura seletiva de imagens individuais sem descompactação total prévia do arquivo no disco.

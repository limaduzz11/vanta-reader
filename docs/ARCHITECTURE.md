# NOVAREADER — Arquitetura de Software Consolidada
**Documento Canônico:** `docs/ARCHITECTURE.md`  
**Data:** 08/09/2026  
**Autor:** NOVA (Plataforma de Engenharia de Software)  
**Status:** VALIDADO / VINCULANTE  

---

## 1. Visão Geral da Arquitetura

O **NovaReader** adota uma arquitetura em camadas orientada a **Domain-Driven Design (DDD)** e **Clean Architecture**, reforçada por um modelo de persistência **Local-First** e motor desacoplado de provedores externos.

### Diagrama de Camadas e Fluxo de Dependências

```text
┌─────────────────────────────────────────────────────────────┐
│                       CAMADA DE UI                          │
│   Telas (Home, Search, Library, Reader, Downloads, Profile) │
│           Design System (NovaColors, NovaWidgets)           │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dispara eventos / Observa estados
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  CAMADA DE APRESENTAÇÃO                     │
│                BLoC / Cubits Reativos (Streams)             │
│            Estados: Initial, Loading, Success, Error        │
└──────────────────────────────┬──────────────────────────────┘
                               │ Invoca Casos de Uso
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    CAMADA DE DOMÍNIO                        │
│   UseCases (SearchWorks, OpenBook, SaveProgress, Download)  │
│      Modelos Puros (Work, Book, Comic, ReadingProgress)     │
│       Interfaces de Repositório & Contratos de Provedor     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Implementado por
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     CAMADA DE DADOS                         │
│  Repositórios Concretos (WorkRepo, DownloadRepo, Library)   │
│  ProviderManager (Registry, Normalizer, WorkIdentitySystem) │
│     Data Sources Locais (SQLite, StorageManager/Disk)       │
│     Data Sources Remotos (Network Engine, Http Clients)     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Padrões Estruturais & Módulos

### 2.1. Regra de Isolamento de Camadas
1. **Nenhum Widget da UI instancia chamadas HTTP ou consultas SQL.**
2. A camada de Domínio é 100% pura (Dart puro, sem dependência de pacotes de UI do Flutter ou bibliotecas externas de banco de dados).
3. Toda comunicação de dados com o exterior (APIs ou Banco) passa por interfaces de Repositório tipadas.

### 2.2. O Sistema de Identidade de Obras (`WorkIdentitySystem`)
A camada de dados integra o motor de deduplicação:
```text
Busca Paralela
  ├── Provider A -> ExternalMetadata ("Dune", Frank Herbert, EPUB, 2.1MB)
  ├── Provider B -> ExternalMetadata ("Dune (Vol 1)", F. Herbert, PDF, 8.4MB)
  └── Provider C -> ExternalMetadata ("Duna", Frank Herbert, EPUB, 1.9MB)
          │
          ▼
   MetadataNormalizer
          │ (Sanitiza strings, normaliza idioma pt-BR/en, extrai ISBN)
          ▼
   WorkIdentitySystem
          │ (Gera WorkKey: hash(dune + frank_herbert))
          ▼
   UnifiedWork (Id: work-uuid-123)
      ├── Title: "Duna / Dune"
      ├── Author: "Frank Herbert"
      ├── Edições Disponíveis:
      │      ├── [EPUB] Fonte A (2.1 MB)
      │      ├── [PDF]  Fonte B (8.4 MB)
      │      └── [EPUB] Fonte C - pt-BR (1.9 MB)
      └── Capa Selecionada (Melhor resolução)
```

---

## 3. Persistência & Estrutura de Diretórios Locais

O `StorageManager` gerencia partições isoladas:
- `/NovaReader/books/`: Livros baixados ou importados (.epub, .pdf, .txt). Nunca são excluídos pela limpeza de cache.
- `/NovaReader/comics/`: Quadrinhos baixados ou importados (.cbz, .cbr). Nunca são excluídos pela limpeza de cache.
- `/NovaReader/covers/`: Capas de obras salvas localmente para visualização instantânea offline.
- `/NovaReader/thumbnails/`: Miniaturas redimensionadas em baixa resolução para permitir listagem fluida da Biblioteca a 120 FPS.
- `/NovaReader/database/`: Banco relacional `novareader.db` com journaling em WAL mode.
- `/NovaReader/cache/`: Diretório temporário puramente volátil (chunks de download em andamento, páginas descompactadas de HQs).

---

## 4. Gestão de Memória no Leitor de Quadrinhos (`ComicEngine`)

Para garantir que arquivos CBZ pesados com páginas de até 4000x6000 pixels não causem estouro de memória (OOM) no Android:
1. **Janela Deslizante (Sliding Window LRU):**
   - Mantém decodificado na VRAM apenas o conjunto: $[Página_{atual - 1}, Página_{atual}, Página_{atual + 1}]$.
   - Ao avançar para a página $N+1$, a página $N-2$ é imediatamente descartada do pool de imagens.
2. **Downsampling Matemático:**
   - Durante a decodificação da imagem bruta, o tamanho é redimensionado para as dimensões máximas físicas da tela do dispositivo através de `instantiateImageCodecWithSize`.

---

## 5. Tratamento Tipado de Erros

Todas as falhas do sistema são capturadas e normalizadas no domínio via `NovaFailure`:
```dart
sealed class NovaFailure {
  final String message;
  final Object? cause;
  const NovaFailure(this.message, [this.cause]);
}

class NetworkFailure extends NovaFailure { const NetworkFailure(super.msg, [super.cause]); }
class ProviderFailure extends NovaFailure { const ProviderFailure(super.msg, [super.cause]); }
class StorageFailure extends NovaFailure { const StorageFailure(super.msg, [super.cause]); }
class DatabaseFailure extends NovaFailure { const DatabaseFailure(super.msg, [super.cause]); }
class ReaderCorruptedFileFailure extends NovaFailure { const ReaderCorruptedFileFailure(super.msg, [super.cause]); }
class UnsupportedFormatFailure extends NovaFailure { const UnsupportedFormatFailure(super.msg, [super.cause]); }
```
A UI escuta os estados de erro e renderiza componentes `NovaErrorState` com botões de ação e recuperação contextual.

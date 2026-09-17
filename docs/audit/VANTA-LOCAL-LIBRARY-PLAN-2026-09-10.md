# VANTA Reader — Biblioteca Local: Inventário e Plano (R5-LOCAL)

**Data:** 2026-09-10
**Fonte:** inspeção read-only de `/media/limaduzz/HD 1TB LDUZZ 2/VANTA READER, BIBLIOTECA/`
**Status:** PROPOSTA — aguarda confirmação das fases A/B/C e das decisões pendentes.

## 1. Inventário observado

| Local | Conteúdo | Tamanho | Formatos | Observações |
|---|---|---|---|---|
| `HQS/` | ~440 HQs pt-BR (Justiceiro, Besouro Verde, Wolverine, Marvel Knights etc.) | 9,1 GB | ~90% **CBR**, 62 CBZ, 1 PDF | naming de cena (série/volume/número/ano); mojibake em parte dos nomes |
| `libgen/` | dumps por bucket de ID (0: 3, 1000: 4, 10000: 11, 100000: 212 arquivos) | 2,4 GB | CBR/CBZ/PDF | nomes = **MD5**; sem título legível |
| `LIVROS/` | infraestrutura: venv Python + scripts de download + **Komga v1.26.3 (Docker, porta 25600)** | 58 MB | 1 EPUB + 1 CBZ de teste | Komga monta **apenas** `LIVROS/`; PC tem `unrar`, `7z`, `zip` |
| Raiz | 4 `.torrent` (c_0/1000/10000/100000) + flatpakref | — | — | não-mídia; importador deve ignorar |

- Total: 12 GB / 2.695 arquivos (~1.500 são do `venv/` Python — não mídia).
- `SETUP.md` do usuário documenta: downloader LibGen PC-side funcionando; Z-Library bloqueado por anti-bot; Komga rodando; Mihon (Android) já conectado ao Komga.

## 2. Impedimentos técnicos comprovados

1. **CBR dominante e não suportado pelo app** — o reader abre CBZ (ZIP), não RAR (ADR-008/VANTA-READER-AUDIT).
2. **Nomes MD5 em `libgen/`** — título/autor só via ComicInfo.xml embutido; sem invenção de metadata (invariante do projeto).
3. **Mojibake** (dupla codificação UTF-8) em parte dos filenames — normalização obrigatória no import.
4. **Komga monta só `LIVROS/`** — os 9,1 GB de `HQS/` e 2,4 GB de `libgen/` estão fora do servidor hoje (volume do docker-compose aponta para `LIVROS/`).
5. Gaps P0 do app seguem abertos: G-06 streaming, G-03 reatividade, G-01 exclusão (`VANTA-GAP-REGISTER-2026-09-09.md`).

## 3. Proposta de fases

**Fase A — Cliente OPDS (Komga) no VANTA Reader:**
- Provider OPDS consumindo o Komga existente; catálogo do HD inteiro no celular pela rede local.
- Leitura remota página-a-página (Komga serve página por URL) — resolve CBR sem conversão (Komga lê RAR/CBR nativamente) e evita o padrão "baixar arquivo inteiro" do G-06.
- Ajuste do mount do Docker para a raiz da biblioteca (ou mover pastas para `LIVROS/`).
- Requer PC ligado; offline real fica para a Fase B.

**Fase B — Importador de pasta on-device (offline):**
- Seletor de pasta (SAF), varredura recursiva, filtro de mídia, dedup SHA-256, metadata de ComicInfo.xml + parser de filename (série/volume/número/ano), normalização de mojibake, capa da 1ª página, pastas→coleções.
- Pré-requisito CBR: **conversor CBR→CBZ em lote no PC** (script com `unrar`/`7z`, originais preservados, teste em 1 série antes do lote).
- Subconjunto seletivo: 12 GB não cabem no celular inteiro.

**Fase C — Onda 1 P0 (do Gap Register):**
- G-06 (com as lições aplicadas ao fetch remoto do OPDS), G-03 (reatividade — crítica com catálogo grande), G-01 (exclusão completa).

## 4. Fora de escopo (explícito)

- Scripts de download do usuário (`download_libgen.py`, `test_zlibrary.py`, `venv/`, pacotes libgen/zlibrary): operação do usuário no PC; o app **não** os consome nem depende deles.
- Arquivos `.torrent` e qualquer downloader dentro do app.
- Fontes remotas do app restritas ao registro oficial de providers (inclusive **VANTA Catalog API**). O app indexa arquivos locais e servidores OPDS do próprio usuário — a procedência dos arquivos é responsabilidade do usuário.

## 5. Decisões pendentes

1. Confirmar fases A → B → C (ou outra ordem).
2. Autorizar teste do conversor CBR→CBZ em uma série pequena antes do lote.
3. Definir subconjunto offline prioritário (quais séries/obras vão para o aparelho).
4. Ajuste do volume do Komga no docker-compose (raiz da biblioteca) — requer parar/subir o container.

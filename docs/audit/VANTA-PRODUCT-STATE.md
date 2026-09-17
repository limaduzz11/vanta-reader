# VANTA Reader — Estado Real Inicial do Produto

**Data:** 2026-09-09  
**Gate atual:** **BLOCK**  
**Observação:** classificação após analyzer, suíte, builds debug Linux/Android e smoke de startup Linux. Android runtime ainda está pendente.

## Funcional

- Estrutura Flutter e shell responsivo básico.
- Entidades `Work`, `WorkEdition`, perfil e download.
- Persistência SQLite básica em testes FFI.
- Importação e leitura textual básica de TXT.
- Parsing básico de EPUB e CBZ válidos simples.
- Registry/health/isolamento básico de providers.
- Componentes de UI, estados loading/empty/error e BLoCs principais.

## Parcialmente funcional

- Home com dados externos quando a chamada funciona.
- Busca unificada, debounce, filtro e deduplicação.
- Open Library para metadata; Gutendex para parte do catálogo/conteúdo público.
- Importação EPUB/CBZ/PDF/TXT.
- Readers EPUB e CBZ.
- Download manager, resume e persistência.
- Biblioteca, favoritos, perfil, avatar e preferências.
- Leitura online baseada em cache-before-read.
- Offline de arquivo local em ambiente de teste.
- Responsividade phone/tablet.
- Logging e segurança de paths.

## Mock

- Provider de catálogo com obras artificiais registrado no runtime padrão.
- Dados iniciais/fallback da Home.
- “Continuar lendo” com obra/progresso fixos.
- Downloads `mock://` marcados como concluídos.
- Payload online sintético após falha de rede.
- PDF apresentado como capítulo textual descritivo.
- Fallbacks de EPUB/HQ que mascaram arquivo inválido.
- E2E atual baseado em provider mock e SQLite FFI.

## Quebrada

- Integridade absoluta SearchResult→Work→Edition→ContentAsset→Reader.
- CBR real.
- PDF real como leitor de páginas/conteúdo.
- Progresso/estatísticas, por conflito de escala 0–100 versus 0–1.
- Garantia de que conteúdo de leitura/download seja o conteúdo real da edição.
- Garantia de HTTPS arquitetural, devido ao bypass do wrapper.
- Claim PBKDF2 do CryptoVault.
- Release Android publicável.
- Gate de segurança/licença dos assets comerciais embarcados.

## Ausente

- Entidade/tabela `ContentAsset` separada de `Edition`.
- Pipeline de imagens soltas.
- Histórico funcional apesar da tabela existente.
- E2E Android real com app, rede, modo avião e reabertura.
- Matriz real de celular/tablet/landscape/font scale/API Android.
- Provider de HQ legalmente validado e semanticamente comic.
- Testes positivos reais de Open Library/Gutendex e HTTP Range.
- Relatório reproduzível de cobertura e artefato release assinado.

## O que já funcionava e deve ser preservado

1. Separação visual entre cards e readers de livros/HQs.
2. Base de BLoCs e UseCases reaproveitável.
3. SQLite e StorageManager como base local-first.
4. Registry de providers e isolamento de falha como direção arquitetural.
5. Cache LRU de páginas como ponto inicial, sem manter o claim de controle total de memória.
6. Perfil local sem dependência obrigatória de conta.
7. Navegação adaptativa básica.

## Bloqueadores P0 iniciais

1. Conteúdo sintético alcança produção e pode ser apresentado como real.
2. Identidade editorial e de arquivo não é rastreável por `ContentAsset`.
3. Mock provider participa da busca normal.
4. Download/leitura Open Library não resolve arquivo real.
5. CBR/PDF são anunciados além da capacidade real.
6. Escala de progresso inconsistente.
7. Assets comerciais sem licença/proveniência observada.
8. Ausência de E2E Android real.

## Decisão de retomada

Não iniciar correções isoladas de Search. Primeiro serão executados build, testes e runtime para confirmar ou refutar os achados estáticos. Depois será fechado o diagnóstico por fluxo e definida a menor reconstrução arquitetural capaz de garantir identidade, conteúdo real, isolamento de mocks e invariantes online/offline.

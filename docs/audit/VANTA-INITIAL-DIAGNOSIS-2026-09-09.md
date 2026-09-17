# VANTA Reader — Diagnóstico Inicial da Retomada

**Data:** 2026-09-09  
**Fase:** entendimento estático concluído; baseline dinâmica inicial executada.  
**Engineering Gate:** **BLOCK**.

## Síntese

O projeto possui uma base relevante e reaproveitável, porém a documentação atual superestima o estado do produto. Há diferença material entre “existir classe/tela/teste” e “entregar comportamento real”. O principal problema não é apenas Search: é a ausência de uma identidade completa e rastreável entre obra, edição, fonte e conteúdo, combinada com mocks/fallbacks que podem aparentar sucesso.

## Principais causas sistêmicas

1. **Modelo incompleto:** `WorkEdition` acumula responsabilidades de edição, fonte e arquivo; `ContentAsset` não existe.
2. **Identidade divergente:** duas implementações de `WorkIdentitySystem` geram chaves incompatíveis.
3. **Capabilities não verificadas:** providers anunciam download/streaming/formato sem resolver conteúdo real correspondente.
4. **Mocks não isolados:** provider, Home, download e streaming sintético alcançam runtime normal.
5. **Arquitetura híbrida:** UI/BLoC/Domain acessam dependências concretas fora da cadeia esperada.
6. **Testes otimistas:** grande parte valida mocks e FFI local, não rede/API/Android/conteúdo real.
7. **Documentação sem gate reproduzível:** relatórios finais não correspondem ao código/artefatos observados.

## Riscos imediatos

- Obra A abrir metadata/capa/conteúdo B/C/D.
- Usuário acreditar ter baixado conteúdo real quando recebeu payload de demonstração.
- Biblioteca e Home exibirem dados de desenvolvimento.
- Offline aparentar funcionar por causa de fallback artificial.
- Formatos CBR/PDF serem oferecidos sem leitor real.
- Distribuição incluir material comercial sem licença documentada.

## O que não será feito

- Replace global de `Nova*`.
- Provider baseado em scraping do HQMania.
- Patch visual para aumentar cards sem causa raiz.
- Conteúdo artificial para “fechar” reader/download.
- Refatoração estética ampla antes dos fluxos críticos.

## Evidência dinâmica obtida

- `flutter analyze`: PASS, zero issues.
- `flutter test`: PASS, 195 testes.
- builds debug Linux e Android: PASS.
- startup Linux: PASS parcial; mock, Open Library e Gutendex foram registrados no runtime normal.
- o analyzer/build refutou a hipótese de erro de compilação na multiplicação de `String` sob Dart 3.12.2.

## Próxima evidência obrigatória

1. Smoke interativo das rotas principais e runtime Android quando houver device.
2. Matriz de Search com providers reais e logs por etapa.
3. Banco/storage limpos e correlação física de conteúdo.

Somente após essas evidências será iniciada implementação, priorizando isolamento de mocks, identidade Work/Edition/ContentAsset e proibição de conteúdo sintético em produção.

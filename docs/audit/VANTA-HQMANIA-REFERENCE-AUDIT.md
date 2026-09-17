# VANTA Reader — Auditoria da Referência HQMania

**Data da pesquisa:** 2026-09-09  
**Escopo:** engenharia reversa comportamental não invasiva de páginas e bundles públicos.  
**Decisão:** usar somente padrões abstratos de UX; **não integrar como provider**.

## Evidências públicas

- Landing: <https://hqmania.com/>
- Aplicativo: <https://apphqmania.com/>
- Busca: <https://apphqmania.com/search>
- Login: <https://apphqmania.com/login>
- `robots.txt`: <https://hqmania.com/robots.txt> permite crawling, mas não concede licença de conteúdo.
- `sitemap.xml`: não encontrado no domínio principal durante a pesquisa.

## Comportamentos observados

- Home organizada em prateleiras, coleções, recentes e populares.
- Busca por título/coleção/ano/personagem, com debounce e categorias.
- Cards 2:3 com progresso, favorito, download e indicador offline.
- Details com capa hero, editora, ano, páginas, formato e coleção relacionada.
- Reader horizontal/vertical, zoom, fullscreen, progresso e próxima edição.
- Bottom navigation no mobile: início, busca, histórico, downloads e favoritos.
- PWA com fallback offline orientado a downloads.
- Área protegida por conta/assinatura para conteúdo principal.

## Padrões que podem inspirar o VANTA Reader

1. Prateleiras configuráveis com semântica explícita.
2. “Continuar lendo” derivado do progresso real do usuário.
3. Agrupamento por série/coleção e navegação para próxima edição.
4. Cards com estado de leitura e disponibilidade offline inequívocos.
5. Busca com filtros e estado persistente.
6. Reader fullscreen com escolha horizontal/vertical.
7. Downloads com resumo de espaço e fallback offline.
8. Skeleton, retry e estados vazios claros.

Esses padrões devem ser implementados com identidade visual, componentes, dados e código próprios do VANTA Reader.

## Restrições legais e técnicas

- Não foi encontrada API pública documentada, OpenAPI ou SDK autorizado.
- Bundles indicam infraestrutura privada, não autorização de integração.
- Não foram encontradas publicamente licença editorial, cadeia de direitos, termos de reutilização do catálogo ou relação oficial com editoras.
- A oferta pública menciona grandes catálogos de editoras e traduções por grupos, o que exige diligência jurídica.
- `robots.txt` permissivo não autoriza copiar metadata, imagens ou arquivos.
- Endpoints privados, URLs assinadas, chaves/configurações expostas e conteúdo protegido não devem ser acessados ou reutilizados.

## O que não copiar

- Catálogo, PDFs, CBZ/CBR, capas, thumbnails ou metadata.
- Marca, logo, tipografia distintiva, textos comerciais ou composição visual substancialmente idêntica.
- Fluxo de compra/assinatura, endpoints Supabase/R2, URLs assinadas ou credenciais públicas do frontend.
- Qualquer conteúdo protegido por login ou assinatura.

## Decisão arquitetural

HQMania será tratada como **benchmark de experiência**, não como dependência nem fonte. Providers VANTA deverão usar apenas APIs abertas/oficiais, domínio público, Open Access ou acervos licenciados, com capabilities reais e permissão documentada.

## Referências legais gerais

- Lei 9.610/1998: <https://www.planalto.gov.br/ccivil_03/leis/l9610.htm>
- Código Penal, art. 184: <https://www.planalto.gov.br/ccivil_03/decreto-lei/del2848compilado.htm>

Esta avaliação é análise de risco de engenharia/produto, não parecer jurídico.

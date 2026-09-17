# VANTA Reader — Auditoria de Mock, Fixture, Seed e Demo

**Data:** 2026-09-09  
**Fase:** identificação pré-correção  
**Resultado:** contaminação do runtime confirmada.

## Classificação

| Artefato | Tipo correto | Local | Uso permitido | Estado observado |
|---|---|---|---|---|
| `MockContentProvider` | MOCK | `lib/data/datasources/providers/mock_content_provider.dart` | testes/dev explicitamente habilitado | Registrado incondicionalmente no runtime normal |
| `MockData` | FIXTURE/DEMO | `lib/data/datasources/mock_data.dart` | testes/demo rotulada | Usado diretamente pela Home |
| `SeedInitialCatalogUseCase` | TEST SEED | `lib/domain/usecases/seed_initial_catalog_usecase.dart` | testes isolados | Registrado no container de produção; design viola Domain→Data |
| `_writeMockStreamingPayload` | TEST HELPER | `online_reading_manager.dart` | testes | Executado também após falha de rede real |
| `_executeMockDownload` | TEST HELPER | `download_manager.dart` | testes | Alcançável por URL default/mock em produção |
| `assets/sample_comics/*` | FIXTURE/DEMO | `assets/sample_comics/` | suíte local com licença comprovada | Embarcado no APK e usado como fallback de leitura/download |
| `assets/covers/*` | FIXTURE/DEMO | `assets/covers/` | testes/demo com licença | Embarcado e associado ao `MockData` |
| testes online→offline | INTEGRATION FIXTURE | `test/integration/...` | testes | Nomeados E2E, mas usam provider mock e FFI |

## Caminhos de vazamento para produção

### Busca

`injection.dart:297-314` registra `MockContentProvider` no mesmo `ProviderRegistry` de Open Library e Gutendex. O smoke Linux confirmou no log que o provider mock está ativo no runtime normal.

### Home

`home_screen.dart` inicializa listas com `MockData` e mantém essas obras quando o provider externo falha. “Continuar lendo” usa obra e progresso fixos.

### Leitura online

`online_reading_manager.dart:136-160` gera payload sintético para esquemas `mock://` e também após exceção de rede real. A sessão é retornada como online bem-sucedida e pode ser promovida a arquivo permanente.

### Download

`download_manager.dart:116` cria URL mock quando não há URL de download. `:302-305` desvia para geração artificial, posteriormente persistida como download concluído.

### Reader

Parsers convertem falha/corrupção em conteúdo demonstrativo. Isso mascara erro de formato e viola a integridade da obra.

## Impacto

1. Search pode retornar obras inexistentes no catálogo real.
2. Home e Library podem aparentar ter conteúdo que o usuário não possui.
3. Download `COMPLETED` pode significar arquivo gerado localmente, não conteúdo adquirido.
4. Offline pode “funcionar” com fixture, invalidando o teste do requisito.
5. Obra comercial pode ser representada por conteúdo diferente ou artificial.
6. Assets sem proveniência podem ser distribuídos no APK.

## Estratégia de isolamento para a fase de implementação

1. Composition root deve registrar mocks somente sob configuração explícita de teste/dev.
2. Runtime release não pode importar `MockData` nem conhecer `mock://`.
3. Falha de rede/parser deve produzir estado de erro tipado, nunca payload sintético.
4. Fixtures devem sair do bundle de produção; usar `test/fixtures/` com licença/proveniência.
5. Seed de biblioteca deve existir apenas em testes e nunca depender de código `data/` dentro do domínio.
6. Downloads só ficam `COMPLETED` após assinatura/MIME/container/checksum coerentes.
7. Testes devem provar que mock não está registrado em configuração de produção.

## Critério de aceite futuro

- busca normal retorna zero itens de provider mock;
- Home vazia/rede indisponível mostra estado honesto, não catálogo artificial;
- falha online não cria arquivo;
- biblioteca limpa permanece vazia;
- APK de produção não contém `sample_comics`, capas comerciais de fixture ou strings `mock://` alcançáveis;
- mocks continuam disponíveis exclusivamente para testes determinísticos.

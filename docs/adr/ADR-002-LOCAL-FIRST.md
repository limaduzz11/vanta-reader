# ADR-002: Princípio Local-First e Isolamento de Armazenamento
**Status:** ACEITO  
**Data:** 08/09/2026  
**Contexto:** Definição da estratégia de persistência local, operação offline e independência de serviços de terceiros para o NovaReader.  

---

## 1. Contexto e Problema
A maioria dos aplicativos modernos de leitura e catálogo depende criticamente de conexões de internet e contas remotas ativas. Quando o usuário está em viagens, áreas sem sinal ou quando serviços remotos sofrem indisponibilidade, o usuário fica impedido de acessar seus livros já catalogados, perde o histórico de leitura e sofre com telas de erro persistentes. Além disso, muitos leitores misturam arquivos baixados com caches temporários, fazendo com que ações de limpeza do sistema excluam acidentalmente as obras do usuário.

## 2. Decisão Arquitetural
1. **Local-First Radical:** O banco de dados local SQLite é a **única fonte da verdade** para a biblioteca do usuário, histórico, progresso, favoritos e configurações.
2. **Independência de Conta:** O usuário não é obrigado a se cadastrar ou fazer login para utilizar o NovaReader. O perfil inicial é 100% local, operando com avatares e nomes gravados no dispositivo.
3. **Particionamento Rígido de Armazenamento:**
   - Todo arquivo baixado ou importado reside em diretórios de conteúdo permanentes (`/NovaReader/books/` e `/NovaReader/comics/`).
   - Todos os arquivos temporários residem em `/NovaReader/cache/`.
   - A operação de "Limpar Cache" do usuário tem permissão para atuar **exclusivamente** sobre a pasta `/NovaReader/cache/`.
4. **Comportamento Transparente Offline:**
   - As telas de Home, Biblioteca, Histórico, Detalhes de obras baixadas e Leitores funcionam sem qualquer degradação quando a conexão está inativa.
   - Desabilitam-se unicamente os botões de busca remota em provedores online e início de novos downloads.

## 3. Alternativas Consideradas
- **Cloud-First com Cache Local:** Depender de APIs em nuvem e tratar o armazenamento local como mero cache volátil. *Rejeitado* por violar o princípio de soberania e durabilidade dos dados do usuário.

## 4. Consequências e Trade-offs
- **Positivas:**
  - Robustez máxima e confiabilidade: o app nunca "quebra" por falta de internet.
  - Privacidade total: nenhum dado de leitura é transmitido sem autorização explícita.
  - Sobrevivência a reinicializações e atualizações do sistema operacional.
- **Mitigações Necessárias:**
  - Migrations de banco de dados locais devem ser rigorosamente versionadas e testadas para nunca causar perda de dados durante atualizações do app.

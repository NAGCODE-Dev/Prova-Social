---
tipo: indice
status: VALIDADO
atualizado: 2026-11-05
---

# Prova Social — índice do vault

Este vault é a base de engenharia e auditoria do aplicativo. O [AGENTS.md](../../AGENTS.md)
continua sendo a fonte normativa dos requisitos do produto. Esta base organiza
evidências, estado, decisões e próximos passos; não substitui nem altera
requisitos sem autorização.

## Comece por aqui

- [[Visão Geral]]
- [[Estado Atual]]
- [[Hierarquia Documental]] — qual documento é fonte vigente e qual é histórico.
- [[../05 - Qualidade/Critério de Prontidão para Refatoração Global|Critério de prontidão]] — responde "já dá para planejar o app novo?".
- [[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]]
- [[Roadmap]]
- [[Plano Mestre]]
- [[../08 - Agentes/Progresso|Progresso]]
- [[../09 - Auditoria/Inventário|Inventário]]
- [[../09 - Auditoria/Hipóteses|Hipóteses]]
- [[../09 - Auditoria/Documentação e Divergências|Divergências documentais]]

## Pastas por assunto e tipo

- [[../01 - Produto/Visão do Produto|Produto]] — intenção e princípios.
- [[../01 - Produto/Fluxo de Entrada e Criação|Fluxo de entrada e criação (rascunho)]]
- [[../01 - Produto/Inventário de Telas e Cobertura|Inventário de telas e cobertura]] — 17 destinos, navegação e o que cada tela testa.
- [[../02 - Arquitetura/Mapa de Módulos|Arquitetura]] — módulos reais, limites e alvo proposto.
- [[../02 - Arquitetura/Fluxos Reais|Fluxos reais medidos]] — F1–F4 com estados de falha.
- [[../02 - Arquitetura/Mapa de Dependências|Mapa de dependências medido]] — arestas, fan-in/out, vendor e singletons.
- [[../03 - Domínios/Fluxos Principais|Domínios]] — questão, prova, tentativa e importação.
- [[../03 - Domínios/Modelo de Domínio Atual|Modelo de domínio atual]] — o que `lib/domain/` é hoje, medido.
- [[../03 - Domínios/Contratos de Domínio Alvo|Contratos de domínio alvo]] — C1–C7 com invariantes e testes exigidos.
- [[../04 - Infraestrutura/Dados e Segurança|Infraestrutura]] — Supabase, armazenamento, ambiente e segurança.
- [[../04 - Infraestrutura/Inventário de Persistência e Dados|Inventário de persistência e dados]] — três trilhas de SQL, chaves locais e contratos de RPC.
- [[../05 - Qualidade/Validação Atual|Qualidade]] — verificações, limites e regressões.
- [[../05 - Qualidade/Critério de Prontidão para Refatoração Global|Critério de prontidão]] — quando parar de acumular e começar a planejar.
- [[../05 - Qualidade/Critérios de Qualidade de Código|Critérios de qualidade (SOLID/Clean Code)]] — a régua normativa da camada nova, com o método de verificação de cada regra.
- [[../05 - Qualidade/Auditoria de Clean Code e SOLID medida|Auditoria de qualidade medida]] — onde cada violação está, com números reproduzíveis.
- [[../06 - Decisões/ADR/README|Decisões / ADRs]] — 12 ADRs propostos e template.
- [[../07 - Histórico/Releases/README|Histórico / releases]].
- [[../07 - Histórico/Refatorações/README|Histórico / refatorações]].
- [[../09 - Auditoria/Áreas/Mapa das Áreas|Auditoria por área]] — 18 notas, placar e critérios.
- [[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Auditoria da área 9]] — importação, OCR, parser e quality gate.
- [[../09 - Auditoria/Classificação/Guia de Classificação|Classificação de código]].
- [[../Templates/Nota de Área|Templates]].
- [[../Inbox/README|Inbox]] — notas ainda não triadas.
- [[../10 - Anexos/README|Anexos]] — recursos documentais autorizados e sem dados sensíveis.

## Fontes primárias

- [Diretrizes de produto](../../AGENTS.md)
- [Relatório de auditoria anterior](../../AUDIT.md)
- [Relatório da segunda fase](../../SECOND_PHASE_REPORT.md)
- [Relatório de implementação](../../IMPLEMENTATION_REPORT.md)
- [[Fontes/README|Fontes originais fornecidas]]

## Segurança e organização

- Não copiar `.env`, chaves, tokens, respostas privadas ou dados pessoais para
  notas.
- Não guardar PDFs de provas no vault. A presença de um arquivo local não prova
  autorização para reproduzi-lo ou redistribuí-lo.
- Notas Markdown ficam em pastas temáticas; anexos documentais ficam em
  `10 - Anexos/`, separados por tipo. Capturas devem ser sanitizadas.
- A configuração compartilhada em `.obsidian/` não é uma fronteira de
  segurança. Segredos devem permanecer em mecanismos próprios e fora do Git.
- Plugins da comunidade não estão instalados; sincronização externa não foi
  configurada.

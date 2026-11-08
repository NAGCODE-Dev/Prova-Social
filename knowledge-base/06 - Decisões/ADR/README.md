---
tipo: indice
area: decisões arquiteturais
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# ADRs propostos

Este índice reúne as decisões que a auditoria das 18 áreas identificou como
necessárias antes de mudanças estruturais. A regra é status `proposto` até
validação explícita do responsável. Exceção: o **ADR-0007 foi aceito em
2026-11-08** (todos os direitos reservados e política de fixtures).

O template está em [[ADR|ADR]]. A síntese que originou a lista está em
[[../../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].

## Como usar

1. Copiar [[ADR|o template]] para `ADR-NNNN - Título.md`.
2. Preencher contexto com evidência medida, não com opinião.
3. Listar alternativas e por que não foram escolhidas.
4. Registrar consequências, riscos e reversão.
5. Só implementar depois de status `aceito` e de tarefa de código autorizada.

## Lista proposta

| ID | Decisão | Áreas | Urgência | Status |
|---|---|---|---|---|
| ADR-0001 | Paleta e tema: dark-only com `EmeraldColors` ou light+dark com tokens do `AGENTS.md` | 15, 16, 18 | Alta | proposto |
| ADR-0002 | Modelo de questão: objetiva/discursiva, gabarito e publicação | 2, 9, 10, 12 | Alta | proposto |
| ADR-0003 | Versionamento de conteúdo e vínculo da tentativa à versão resolvida | 2, 6, 12 | Alta | proposto |
| ADR-0004 | Persistência local: JSON/SharedPreferences vs SQLite transacional | 7, 8 | Alta | proposto |
| ADR-0005 | Distribuição Android: APK universal + splits e seleção de ABI no site | 15, 17 | Alta | proposto |
| ADR-0006 | Escopo de importação por câmera: implementar ou remover do README | 9, 13, 18 | Média | proposto |
| [[ADR-0007 - Licença do app e política de fixtures de terceiros\|ADR-0007]] | Licença do app e política de fixtures de terceiros | 9, 14, 17, 18 | Alta | **aceito** |
| [[ADR-0008 - Hierarquia documental e versionamento do vault\|ADR-0008]] | Hierarquia documental e versionamento do vault | 18 | Alta | proposto |
| ADR-0009 | Política de dependências, pins e cadência de atualização | 17 | Média | proposto |
| ADR-0010 | Comunidades, moderação e ciclo de vida | 11, 12 | Média | proposto |
| ADR-0011 | Tamanho de APK, modelos sob demanda e componentes nativos | 13, 17 | Média | proposto |
| ADR-0012 | Acessibilidade, tema claro/escuro e meta de contraste | 14, 16 | Média | proposto |

## Critério de aprovação

- Contexto com evidência e limites.
- Alternativas reais, incluindo “não fazer”.
- Consequências positivas e negativas.
- Validação antes da implementação.
- Reversão descrita.
- Link para a área, o código e o teste que sustentam a decisão.

## Links

- [[ADR|Template de ADR]]
- [[../../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]]
- [[../../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]]
- [[../../00 - Central/Plano Mestre|Plano Mestre]]
- [AGENTS.md](../../../AGENTS.md)

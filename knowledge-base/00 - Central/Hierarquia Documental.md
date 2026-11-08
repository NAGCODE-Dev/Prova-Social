---
tipo: area
area: hierarquia documental
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, README.md, knowledge-base/, docs/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# Hierarquia documental

Esta nota define qual documento responde a qual pergunta. Ela existe para
impedir que um relatório datado, um guia operacional antigo ou uma nota de
intenção seja lido como requisito vigente.

## Precedência

1. **`AGENTS.md`** — fonte normativa de requisitos, princípios e processo. Só
   muda com decisão explícita do responsável.
2. **Código, migrations e testes no SHA vigente** — implementação observável.
   Quando contradiz um documento, o código é a evidência do estado atual; a
   divergência precisa ser registrada, não silenciada.
3. **`knowledge-base/`** — documentação viva: baseline, auditoria, contratos,
   ADRs propostos, roadmap e limites conhecidos.
4. **Relatórios da raiz** (`AUDIT.md`, `IMPLEMENTATION_REPORT.md`,
   `SECOND_PHASE_REPORT.md`) — evidência datada de uma execução. Não são estado
   atual nem autorização para repetir conclusões.
5. **`docs/`** — guias operacionais e diagnósticos históricos. Cada arquivo
   precisa indicar data, escopo e relação com o estado vigente.
6. **`CHANGELOG_*.md`** — histórico de release. Não define comportamento atual.

## O que está vigente

| Assunto | Fonte vigente |
|---|---|
| Requisitos de produto e processo | [`AGENTS.md`](../../AGENTS.md) |
| Estado medido e limites | [[Estado Atual]] |
| Visão, roadmap e plano | [[Visão Geral]], [[Roadmap]], [[Plano Mestre]] |
| Auditoria por área | [[../09 - Auditoria/Áreas/Mapa das Áreas\|Mapa das Áreas]] |
| Síntese e ordem dos lotes | [[../09 - Auditoria/Síntese da Refatoração\|Síntese da Refatoração]] |
| Qualidade de código | [[../05 - Qualidade/Critérios de Qualidade de Código\|Critérios]], [[../05 - Qualidade/Auditoria de Clean Code e SOLID medida\|Auditoria medida]] |
| Decisões estruturais | [[../06 - Decisões/ADR/README\|ADRs propostos]] |
| Progresso e decisões de produto em conversa | [[../08 - Agentes/Progresso\|Progresso]] |
| Divergências documentais | [[../09 - Auditoria/Documentação e Divergências\|Documentação e Divergências]] |

## O que é histórico

Os documentos abaixo recebem um banner no topo. O banner não apaga a evidência:
ele impede que o texto seja confundido com o estado atual.

- `AUDIT.md` — auditoria de 03/11/2026.
- `IMPLEMENTATION_REPORT.md` — relatório de implementação de 03/11/2026.
- `SECOND_PHASE_REPORT.md` — benchmark e correções de 03/11/2026.
- `PROVA_SOCIAL_CONTEXT.md` — contexto de 27/09/2026.
- `DEPENDENCY_COMPATIBILITY.md` — matriz da versão 0.5.0.
- `CODEX_P0_GOAL.md` e `CODEX_QA_COMPLETO_PROVA_SOCIAL.md` — instruções de
  tarefas anteriores.
- `docs/DIAGNOSTICO_ATUAL.md`, `docs/ROADMAP_EXECUCAO.md` e demais relatórios
  datados — fotografia do dia indicado, não promessa atual.

## Regras de manutenção

- Um documento novo precisa declarar **tipo**, **status** e **data** no
  frontmatter ou no topo.
- Relatório de execução não vira fonte normativa por estar na raiz. Se uma
  conclusão continuar válida, ela é consolidada em `knowledge-base/` com link
  para a evidência.
- Não criar uma segunda cópia da mesma decisão. Atualize a nota vigente e deixe
  o histórico apontar para ela.
- Não apagar relatório histórico sem autorização; marque-o e preserve o
  conteúdo.
- Não guardar segredos, `.env`, provas sem licença ou dados pessoais no vault.

## Decisão pendente

A formalização desta hierarquia é o **ADR-0008** (proposto em
[[../06 - Decisões/ADR/README\|ADRs propostos]]). Enquanto ele não for aceito,
esta nota registra a prática em uso, não uma decisão arquitetural aprovada.

## Links

[[Índice]] · [[Estado Atual]] · [[../09 - Auditoria/Documentação e Divergências\|Documentação e Divergências]] · [AGENTS.md](../../AGENTS.md)

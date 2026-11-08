---
tipo: adr
area: documentação
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, README.md, knowledge-base/, docs/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0008 — Hierarquia documental e versionamento do vault

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

A auditoria de 2026-11-04 encontrou duas ou três verdades documentais:

- o `AGENTS.md` tinha duas seções numeradas 15;
- o vault era chamado de versionado, mas `git ls-files knowledge-base` era 0;
- `README.md` prometia importação de imagens e “modo de demonstração”
  inexistentes e dizia “código aberto” sem `LICENSE`;
- relatórios da raiz competiam com o vault sem banner de histórico;
- `DEPENDENCY_COMPATIBILITY.md` descrevia a versão 0.5.0 enquanto o app estava
  em `0.7.5+15`.

O vault já foi versionado em `eebb2b0` e a numeração do `AGENTS.md` foi
corrigida no Lote 1. Falta formalizar a precedência para que a correção não
dependa de memória.

## Decisão proposta

Adotar a precedência registrada em
[[../../00 - Central/Hierarquia Documental|Hierarquia Documental]]:

1. `AGENTS.md` — requisitos normativos;
2. código, migrations e testes no SHA vigente — estado observável;
3. `knowledge-base/` — documentação viva;
4. relatórios datados da raiz — evidência histórica;
5. `docs/` — guias operacionais e diagnósticos históricos;
6. changelogs — histórico de release.

Regras associadas:

- o vault fica dentro do repositório do app, em `knowledge-base/`;
- estado por dispositivo do Obsidian permanece ignorado pelo Git;
- todo relatório histórico recebe banner com data e link para a nota vigente;
- uma conclusão só vira normativa depois de consolidada em `AGENTS.md` ou em
  nota de decisão aprovada;
- nenhum segredo, prova sem licença ou dado pessoal entra no vault.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Manter o vault em repositório separado | Já foi tentado; o vault externo não estava montado e a documentação ficou fora do checkout usado pelo agente. |
| Usar apenas a raiz do repositório | Mistura requisito, relatório e histórico; foi a causa das contradições atuais. |
| Usar apenas o vault | Remove a fonte normativa curta que o agente lê primeiro e facilita que uma nota de auditoria vire requisito por acidente. |
| Não versionar o vault | Risco de perder a auditoria e impossibilitar revisão por diff. |

## Consequências e reversão

**Positivas:** uma pergunta tem uma fonte; revisões por diff; relatórios não são
confundidos com estado atual; o agente sabe onde escrever.

**Negativas:** exige disciplina de banner e de consolidação; o vault cresce e
precisa de índice; links relativos precisam ser mantidos.

**Reversão:** a hierarquia é documental. Se o vault voltar a ser externo, basta
mover `knowledge-base/` e atualizar `AGENTS.md` §25 e os links; nenhum dado de
produção depende disso.

## Evidências e validação

- `AGENTS.md` §25 aponta para `knowledge-base/`.
- `knowledge-base/00 - Central/Hierarquia Documental.md` registra a precedência.
- `knowledge-base/README.md` e `knowledge-base/00 - Central/Índice.md` linkam a
  nota.
- Relatórios da raiz e de `docs/` receberam banner histórico.
- `.gitignore` ignora apenas estado por dispositivo do Obsidian.
- Validação pendente: varredura de links relativos e revisão do responsável.

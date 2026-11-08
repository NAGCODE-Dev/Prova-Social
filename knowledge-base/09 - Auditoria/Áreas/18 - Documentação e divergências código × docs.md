---
tipo: area
area: documentação e divergências código × docs
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 2, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 4}
fonte_codigo: [AGENTS.md, README.md, AUDIT.md, DESIGN_SYSTEM.md, DEPENDENCY_COMPATIBILITY.md, PROVA_SOCIAL_CONTEXT.md, IMPLEMENTATION_REPORT.md, SECOND_PHASE_REPORT.md, CHANGELOG_*.md, knowledge-base/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-08
---

# Documentação e divergências código × docs

> **Atualização de 2026-11-08 (Lote 1):** numeração do `AGENTS.md`, banners
> históricos, README e hierarquia documental foram corrigidos. O diagnóstico
> abaixo preserva a medição de 2026-11-04; o estado do Lote 1 está em
> [[../../09 - Auditoria/Documentação e Divergências|Documentação e Divergências]].

## Resumo

A documentação do Prova Social é **abundante e, em grande parte, honesta**: o
`README.md` tem uma seção “O que ainda não existe”, o `AUDIT.md` separa estado
por área e limites, o vault em `knowledge-base/` organiza produto, arquitetura,
domínios, infraestrutura, qualidade, decisões e 18 auditorias, e o
`AGENTS.md` é uma fonte normativa detalhada. O vault tem configuração Obsidian
compartilhável, sem plugins da comunidade, e não contém segredos.

O problema é de **fonte única e manutenção**. O `AGENTS.md` numera **duas
seções 15** (“Offline e sincronização” e “Base de conhecimento do projeto”), o
que quebra referências; o vault inteiro está **não rastreado** no Git, apesar
de o `AGENTS.md` chamá-lo de “versionado”; não há `.gitignore` no vault, então
`workspace.json` (estado de dispositivo) seria commitado; o `README.md` afirma
importação de **imagens** e um “modo de demonstração” que não existem no
código, e diz “código aberto” sem `LICENSE`; o `DESIGN_SYSTEM.md` declara fundo
escuro `#101311` enquanto o app usa `#050907`; a matriz de compatibilidade é da
versão 0.5.0; e relatórios da raiz (`AUDIT.md`, `IMPLEMENTATION_REPORT.md`,
`PROVA_SOCIAL_CONTEXT.md`) competem com o vault sem banner de “histórico”.

Classificação: **EVOLUIR** — o conteúdo é preservável e valioso, mas precisa de
uma hierarquia explícita, versionamento e verificação automática para não
voltar a divergir.

## Escopo e método

- Leitura integral de `AGENTS.md` (estrutura e seções), `README.md`,
  `DESIGN_SYSTEM.md`, `DEPENDENCY_COMPATIBILITY.md`, `AUDIT.md`,
  `IMPLEMENTATION_REPORT.md`, `SECOND_PHASE_REPORT.md`, `CODEX_P0_GOAL.md` e
  `CODEX_QA_COMPLETO_PROVA_SOCIAL.md`.
- Leitura de `CHANGELOG_0.6.0.md` a `CHANGELOG_0.7.5.md` e do índice de
  releases do vault.
- Inventário do vault: 20+ notas, pastas `00`–`10`, templates, ADR e fontes.
- Verificação de rastreamento no Git (`git ls-files knowledge-base` = 0) e de
  `.gitignore` dentro do vault (inexistente).
- Verificação de segredos em `knowledge-base/`, README, AUDIT e
  DESIGN_SYSTEM (nenhum encontrado).
- Verificação de links `[[...]]` com script local: 9 alvos quebrados (3
  corrigidos nesta auditoria; 1 link de área 4 corrigido; 1 placeholder em
  fonte histórica; 4 links para a área 18, que passou a existir).
- Comparação de afirmações do README/DESIGN/AUDIT com o código nas áreas 1–17.
- Não foi executado Obsidian em modo de leitura, nem lint de Markdown.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Fonte normativa detalhada | Funcional | `AGENTS.md` (24 seções) |
| README com proposta e limites | Funcional | `README.md:146-154` |
| Seção “O que ainda não existe” honesta | Funcional | `README.md:146-154` |
| Auditoria por área no vault | Funcional | `09 - Auditoria/Áreas/01-18` |
| Templates de nota, achado e ADR | Funcional | `knowledge-base/Templates/` |
| Índice central do vault | Funcional | `00 - Central/Índice.md` |
| Histórico de releases | Funcional | `07 - Histórico/Releases/README.md` |
| Configuração Obsidian compartilhável | Funcional | `.obsidian/app.json`, `appearance.json` |
| Sem plugins da comunidade | Funcional | `.obsidian/community-plugins.json` = `[]` |
| Sem segredos nas notas | Funcional | busca por `service_role`, `sb_secret`, JWT |
| Changelogs por versão | Funcional | `CHANGELOG_0.6.0` … `0.7.5` |
| Vault versionado no Git | Quebrado | `git ls-files knowledge-base` = 0 |
| `.gitignore` do vault | Ausente | nenhum arquivo |
| Numeração única do `AGENTS.md` | Quebrado | duas seções “15” |
| README refletir o código | Parcial | “Imagens” e “demonstração” não existem |
| Documentos da raiz marcados como históricos | Ausente | sem banner/índice |
| Link checker no CI | Ausente | nenhum job |
| Lint/frontmatter no CI | Ausente | nenhum job |

## O que funciona

1. **`AGENTS.md` é uma fonte normativa real.** Cobre visão, princípios, tokens,
   navegação, Focus Mode, importação, backend, offline, CI, segurança e
   definição de pronto. É raro um projeto ter esse nível de contrato escrito.
2. **O README não esconde lacunas.** A seção “O que ainda não existe” lista
   explicação de questão, seguir bancas, comunidades, discursivas e tema claro
   (`README.md:146-154`). Isso evita a pior divergência: prometer o que não há.
3. **O vault tem arquitetura de informação coerente.** `00 - Central`,
   `01 - Produto`, `02 - Arquitetura`, `03 - Domínios`, `04 - Infraestrutura`,
   `05 - Qualidade`, `06 - Decisões`, `07 - Histórico`, `08 - Agentes`,
   `09 - Auditoria`, `10 - Anexos`. É navegável e tem índice.
4. **As auditorias por área têm contrato de qualidade.** O
   `_Briefing das Auditorias.md` define rubrica, template, regras de evidência
   e classificação. As notas 1–18 seguem o mesmo formato.
5. **As notas citam SHA e arquivos.** Cada área registra `sha`, `fonte_codigo`,
   `confianca` e `atualizado`, o que permite reproduzir a evidência.
6. **O vault preserva fontes originais.** `00 - Central/Fontes/` guarda os
   prompts originais, separados das notas interpretativas.
7. **O Obsidian está configurado sem plugins da comunidade.** O
   `community-plugins.json` está vazio, o que reduz superfície de supply chain
   e mantém o vault portátil.
8. **Não há segredos nas notas.** A busca por `service_role`, `sb_secret`,
   JWT e senhas encontrou apenas descrições de política, não valores.
9. **Os changelogs são específicos.** `CHANGELOG_0.7.5.md` descreve correções
   visuais, conta, Web e testes, em vez de “melhorias gerais”.
10. **O índice central linka as fontes primárias.** `Índice.md` aponta para
    `AGENTS.md`, `AUDIT.md`, `SECOND_PHASE_REPORT.md` e
    `IMPLEMENTATION_REPORT.md`, preservando a história.
11. **A pasta de releases registra o estado.** `07 - Histórico/Releases/README.md`
    diz que a última release é `v0.7.5` e que a versão local é `0.7.5+15`.
12. **As notas de área são acionáveis.** Cada uma tem plano em lotes, critério
    de aceite, riscos e “o que não foi verificado”.

## O que está parcial

### `AGENTS.md` tinha duas seções 15 (resolvido em 2026-11-08)

> Correção aplicada no Lote 1: a seção final passou a ser `## 25`. O diagnóstico
> abaixo permanece como evidência histórica.

A estrutura é:

- `## 14. Backend e dados`;
- `## 15. Offline e sincronização`;
- `## 16` … `## 24`;
- `## 15. Base de conhecimento do projeto` (no fim).

Isso quebra qualquer referência “§15” e confunde a ordem de leitura. A segunda
deveria ser `## 25` ou uma seção sem número. O problema é objetivo e de baixo
risco, mas precisa de autorização porque altera a fonte normativa.

### Vault não versionado apesar de “versionado”

`AGENTS.md:706` diz:

> A documentação de engenharia é organizada no vault Obsidian versionado em
> `knowledge-base/`.

Na prática:

- `git ls-files knowledge-base` retorna **0 arquivos**;
- `git status` mostra `?? knowledge-base/`;
- não há `.gitignore` dentro do vault;
- `.obsidian/workspace.json` (estado de dispositivo) está presente e seria
  commitado;
- `graph.json` também é estado local.

O próprio `AGENTS.md` diz que `workspace*.json` e a lixeira local são estado
não versionado. Sem `.gitignore`, a regra não é aplicável. Antes de qualquer
commit, é preciso criar `knowledge-base/.gitignore` com:

```
.obsidian/workspace*.json
.obsidian/cache/
.trash/
```

E decidir se `graph.json` deve ou não ser versionado (provavelmente não).

### README promete o que o código não tem

Afirmações verificadas:

| README | Código |
|---|---|
| “PDFs (com OCR local no Android), **Imagens**, Criação manual” (`:26-30`) | Só PDF, JSON e manual; não há `FileType.image` nem câmera/galeria |
| “Teste o modo de demonstração” (`:87`) | Não há `demo`/`demonstra` em `lib/`; pode ser o onboarding, mas não é um modo de demonstração |
| “Código aberto para fins educacionais” (`:163-166`) | Não existe `LICENSE` na raiz |
| “APK universal continua como fallback para releases antigas” (`:159`) | Verdade para releases antigas, mas o `AGENTS.md` §17 exige universal em toda release |

A seção “O que ainda não existe” é boa, mas as afirmações positivas acima não
são verificadas por teste nem por revisão de documento.

### `DESIGN_SYSTEM.md` contradiz o app

O documento diz:

- “fundo escuro: `#101311`”;
- “Marcas: `#16A36A`”;
- “Raios: 8, 12, 16, 20”;
- “Cards representam objetos independentes; nem todo conteúdo vira card”.

O app:

- usa `EmeraldColors.background = #050907`;
- usa `primary = #20D99A`;
- usa `StudySurface` com raio 18/24 em quase toda seção;
- força `ThemeMode.dark`.

O documento está mais próximo do `AGENTS.md` do que do código. Ou ele é a
intenção (e o código é a dívida), ou é histórico (e deve ser marcado). Hoje ele
se apresenta como “regras oficiais”, o que induz a erro.

### `DEPENDENCY_COMPATIBILITY.md` é da versão 0.5.0

O documento diz “Versões verificadas nos `pubspec` publicados em 17/09/2026” e
lista:

- `supabase_flutter 2.10.0` (atual: 2.18.3);
- `pdfrx 2.6.1` (atual: 2.6.6);
- `package_info_plus 10.2.1` (atual: 10.2.2).

A versão do app é `0.7.5+15`. A matriz está defasada e não tem banner de
“histórico”. Para a área 17, ela é insuficiente como referência atual.

### Relatórios da raiz competem com o vault

A raiz tem:

- `AUDIT.md` (123 linhas, 03/11/2026);
- `IMPLEMENTATION_REPORT.md` (186 linhas, 03/11/2026);
- `SECOND_PHASE_REPORT.md` (216 linhas, 03/11/2026);
- `PROVA_SOCIAL_CONTEXT.md` (993 linhas, 27/09/2026);
- `CODEX_P0_GOAL.md`, `CODEX_QA_COMPLETO_PROVA_SOCIAL.md`;
- `DEPENDENCY_COMPATIBILITY.md`, `DESIGN_SYSTEM.md`;
- `GOOGLE_AUTH_SETUP.md`, `GUIA_ACODE_SUPABASE.md`,
  `GUIA_REDIRECT_LOGIN.md`.

O `AGENTS.md` §25 diz para mantê-los como fontes históricas até revisão, mas
não há:

- banner “documento histórico, ver vault”;
- índice do que está vigente;
- data de substituição;
- link para a nota que o substitui.

`IMPLEMENTATION_REPORT.md` afirma que “a base Obsidian especificada em
`AGENTS.md` não está disponível neste ambiente” — isso era verdade na época,
mas hoje é falso e o leitor não sabe. `AUDIT.md` diz que a suíte de 296 testes
passou e que o CI contém gates; não menciona que a `main` está vermelha por
formatação.

### `Mapa das Áreas` e estados centrais desatualizados

Até esta auditoria, `Mapa das Áreas.md` dizia que apenas a área 9 estava
concluída e que 1–8 e 10–18 estavam pendentes. As áreas 1–18 agora têm nota, e
`Estado Atual.md`, `Progresso.md`, `Plano Mestre.md`, `Roadmap.md`,
`Validação Atual.md`, `Índice.md` e `Visão Geral.md` foram sincronizados nesta
mesma execução com:

- 18 áreas auditadas;
- classificação de cada uma;
- achados transversais;
- próxima ordem de lotes.

O risco restante é de processo: sem verificação automática, a sincronização
volta a divergir. Por isso o Lote 7 do plano da área inclui um `docs-check` no
CI e a regra de uma fonte de verdade por assunto.

### Links quebrados e placeholders

O script de links encontrou 9 alvos:

- `[[outras notas]]` e `[[]]` em
  `00 - Central/Fontes/Prompt de Auditoria - fonte original.md` — placeholders
  da fonte original; devem ser preservados ou marcados como exemplo, não
  “corrigidos” silenciosamente;
- links para a área 18 (resolvidos quando a nota foi criada);
- `15 - CI-CD, releases, site e PWA` em áreas 1 e 3 (nome antigo; corrigido);
- `Home, busca e biblioteca` na área 4 (nota inexistente; corrigido para
  `Navegação e Visitante`).

O problema não é o número absoluto; é não haver verificação automática. Um link
quebrado em auditoria é evidência perdida.

### Changelogs sem índice

Existem `CHANGELOG_0.6.0.md` … `CHANGELOG_0.7.5.md`, mas:

- não há `CHANGELOG.md` consolidado;
- o README não aponta para eles;
- a release usa `--generate-notes`, não o changelog;
- não há validação de que a versão da tag tem changelog.

O histórico existe, mas não é navegável a partir da porta de entrada.

### Sem verificação automática de documentação

Não há:

- link checker;
- lint de Markdown;
- validação de frontmatter (`tipo`, `status`, `sha`, `atualizado`);
- verificação de que toda nota de área tem `classificacao` e `nivel`;
- varredura de segredos no vault;
- verificação de “documento histórico”;
- comparação entre `AGENTS.md` e código.

O vault depende de disciplina manual. A auditoria de 18 áreas mostrou que essa
disciplina funciona quando há um agente dedicado, mas não há garantia de
continuidade.

## O que está ausente ou quebrado

- Numeração única no `AGENTS.md`.
- Vault rastreado no Git.
- `.gitignore` do vault.
- Banner de documento histórico na raiz.
- Índice de documentos vigentes.
- README sem afirmações falsas.
- `LICENSE`.
- `DESIGN_SYSTEM.md` alinhado ao código ou marcado como intenção.
- `DEPENDENCY_COMPATIBILITY.md` atualizado ou marcado como 0.5.0.
- `Mapa das Áreas` e estados centrais atualizados.
- Link checker no CI.
- Lint/frontmatter no CI.
- Varredura de segredos no vault.
- Changelog consolidado e ligado à release.
- ADRs para decisões já tomadas (paleta, APK universal, pins, câmera).
- Definição de “documentação pronta” no `AGENTS.md`.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Vault versionado em `knowledge-base/`” | 0 arquivos rastreados | `git ls-files knowledge-base` |
| “`workspace*.json` é ignorado” | Não há `.gitignore` no vault | `ls knowledge-base/.gitignore` |
| “Importação de imagens” | Só PDF, JSON e manual | `publish_page.dart:124-125, 264-265` |
| “Modo de demonstração” | Nenhuma referência a demo em `lib/` | busca global |
| “Código aberto” | Sem `LICENSE` | raiz |
| “Fundo escuro `#101311`” | App usa `#050907` | `DESIGN_SYSTEM.md`; `app_theme.dart:20` |
| “Matriz de compatibilidade 0.5.0” | App 0.7.5+15; versões mudaram | `DEPENDENCY_COMPATIBILITY.md`; `pubspec.yaml:4` |
| “Base Obsidian indisponível” | Vault existe e está em uso | `IMPLEMENTATION_REPORT.md`; `knowledge-base/` |
| “Suíte e CI saudáveis” | 296 testes locais, mas `main` vermelha | `AUDIT.md`; run `41760190392` |
| “Área 9 é a única concluída” | Estado anterior à consolidação; hoje as 18 áreas têm nota | `Mapa das Áreas.md` (antes/depois) |
| “§15 Offline” e “§15 Base de conhecimento” | Duas seções com o mesmo número | `AGENTS.md:483, 706` |

## Evidência de testes

- Não há teste de documentação.
- `tool/test_generate_seo_pages.py` testa o gerador de páginas, não o vault.
- O script manual de links encontrou 9 alvos quebrados; 4 eram a área 18
  (resolvidos), 3 eram nomes antigos (corrigidos), 1 era link de produto
  inexistente (corrigido), 2 eram placeholders da fonte original.
- Não há verificação de frontmatter; as notas de área 1–18 seguem o padrão, mas
  nada impede uma nota futura sem `sha`.
- Não há verificação de segredos; a busca manual não encontrou valores.
- Não há golden de documentação nem comparação automática com o código.

## Riscos

1. **Duas verdades.** README, AGENTS, AUDIT e vault podem divergir; o leitor
   escolhe a que confirma o que quer.
2. **Vault perdido.** Sem Git, um `rm -rf` ou falha de disco apaga a auditoria.
3. **Estado de dispositivo commitado.** `workspace.json` e `graph.json` podem
   poluir o repositório e conflitar entre máquinas.
4. **Afirmação falsa em produto.** “Importação de imagens” e “demonstração”
   podem virar expectativa de usuário.
5. **Licença ambígua.** “Código aberto” sem `LICENSE` impede uso/contribuição
   com segurança jurídica.
6. **Documento histórico lido como atual.** `PROVA_SOCIAL_CONTEXT.md` e
   `DEPENDENCY_COMPATIBILITY.md` podem orientar decisões erradas.
7. **Link quebrado.** Evidência citada deixa de ser verificável.
8. **Numeração duplicada.** Referências “§15” ficam ambíguas.
9. **Sem CI de docs.** A qualidade cai assim que o agente dedicado sai.
10. **Decisões não registradas.** Paleta, APK universal, pins e câmera são
    decisões tomadas sem ADR.

## Plano de refatoração da área

### Lote 1 — Fonte única e numeração

- Corrigir a segunda seção “15” para “25” (ou “Base de conhecimento” sem
  número), com autorização do responsável.
- Adicionar ao `AGENTS.md` uma subseção “Hierarquia documental”:
  `AGENTS.md` normativo → vault estado/decisões → raiz histórico.
- Definir “documentação pronta” (checklist curto).
- Critério de aceite: nenhuma seção duplicada; hierarquia escrita; links
  internos conferidos.

### Lote 2 — Versionar o vault

- Criar `knowledge-base/.gitignore` com `workspace*.json`, cache e lixeira.
- Adicionar o vault ao Git (quando autorizado).
- Garantir que `.obsidian/community-plugins.json` continue vazio.
- Critério de aceite: `git ls-files knowledge-base` > 0; `workspace.json` não
  aparece no status; clone restaura as notas.

### Lote 3 — Marcar história e consolidar raiz

- Adicionar banner “documento histórico” em `AUDIT.md`,
  `IMPLEMENTATION_REPORT.md`, `SECOND_PHASE_REPORT.md`,
  `PROVA_SOCIAL_CONTEXT.md`, `CODEX_*`, `DEPENDENCY_COMPATIBILITY.md` e
  `DESIGN_SYSTEM.md`, com link para a nota vigente no vault.
- Criar `docs/README.md` (ou seção no vault) com o índice do que está vigente.
- Decidir o destino de `DESIGN_SYSTEM.md` e `DEPENDENCY_COMPATIBILITY.md`:
  atualizar ou aposentar.
- Critério de aceite: nenhum documento histórico sem banner; índice único.

### Lote 4 — Corrigir README e licença

- Remover “Imagens” e “modo de demonstração” ou implementar o que prometem.
- Decidir licença e adicionar `LICENSE`.
- Linkar `AGENTS.md`, vault, changelog e releases no README.
- Critério de aceite: README verificável por teste manual; `LICENSE` presente;
  todos os links funcionam.

### Lote 5 — CI de documentação

- Adicionar job `docs-check`:
  - link checker de `knowledge-base/` e raiz;
  - lint de Markdown;
  - validação de frontmatter das notas de área;
  - varredura de segredos;
  - verificação de que toda nota de área tem `classificacao`.
- Critério de aceite: PR falha com link quebrado ou frontmatter inválido;
  varredura de segredos roda em todo push.

### Lote 6 — ADRs e decisões pendentes

- Registrar ADRs para:
  - paleta escura (`EmeraldColors` vs tokens do `AGENTS.md`);
  - APK universal vs apenas splits;
  - pins exatos de dependências;
  - captura por câmera (escopo ou remoção do rótulo);
  - versionamento do vault.
- Critério de aceite: cada decisão tem contexto, alternativas, consequência e
  validação; o código aponta para o ADR quando relevante.

### Lote 7 — Sincronizar estados

- Atualizar `Mapa das Áreas`, `Estado Atual`, `Plano Mestre`, `Roadmap`,
  `Progresso`, `Validação Atual`, `Documentação e Divergências`, `Índice`,
  `Visão Geral` e `Mapa de Módulos` com o resultado das 18 áreas.
- Critério de aceite: nenhuma nota central contradiz as notas de área; a
  síntese global é o único ponto de entrada para a refatoração.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Documentação rica, mas com afirmações falsas e números duplicados. |
| Testes | 2 | Nenhuma verificação automática de links, frontmatter ou segredos. |
| Acoplamento | 3 | Hierarquia AGENTS/vault/raiz existe na intenção, não na prática. |
| Clareza | 2 | Duas seções 15, README contraditório e relatórios sem banner. |
| Segurança | 3 | Sem segredos encontrados; falta varredura automática. |
| Robustez | 2 | Vault fora do Git e sem `.gitignore`; links quebram. |
| Aderência | 2 | §25 promete vault versionado; §19 pede changelog coerente; ambos parciais. |
| Portabilidade | 4 | Markdown e Obsidian funcionam bem; sem dependência proprietária. |

Classificação resultante: **EVOLUIR** — o acervo é valioso e pode ser mantido,
mas precisa de hierarquia, versionamento e verificação para ser confiável.

## Dependências

- Área 14 para `docs-check` no CI.
- Área 15 para changelog na release e links do site.
- Área 16 para decidir a paleta e atualizar `DESIGN_SYSTEM.md`.
- Área 17 para atualizar a matriz de compatibilidade.
- Autorização do responsável para alterar `AGENTS.md` e versionar o vault.

## O que não foi verificado

- Renderização do vault no Obsidian após as alterações.
- Links externos (GitHub, Supabase, Cloudflare) em todas as notas.
- Frontmatter de todas as notas antigas.
- Existência de segredos em histórico Git (não apenas no working tree).
- Se `workspace.json` já foi commitado em algum momento.
- Se `AGENTS.md` tem outras referências numéricas quebradas.
- Consistência do `README.md` com todas as 18 áreas.
- Validade jurídica da licença “código aberto para fins educacionais”.

## Links

- [[../../00 - Central/Índice|Índice do vault]]
- [[../../00 - Central/Estado Atual|Estado Atual]]
- [[../../00 - Central/Plano Mestre|Plano Mestre]]
- [[../../00 - Central/Roadmap|Roadmap]]
- [[Mapa das Áreas|Mapa das Áreas]]
- [[../Documentação e Divergências|Documentação e Divergências]]
- [[../../05 - Qualidade/Validação Atual|Validação Atual]]
- [[../../01 - Produto/Princípios|Princípios]]
- [[../../Templates/ADR|Template de ADR]]

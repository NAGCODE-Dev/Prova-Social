---
tipo: area
area: documentação e divergências
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, PROVA_SOCIAL_CONTEXT.md, DEPENDENCY_COMPATIBILITY.md, pubspec.yaml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-08
---

# Documentação e Divergências Conhecidas

## Precedência atual

1. `AGENTS.md`: requisitos normativos atuais de produto e processo.
2. Código, migrations e testes no SHA citado: implementação observável.
3. Plano Mestre fornecido: plano de trabalho cuja execução exige confirmar fatos.
4. Relatórios de auditoria existentes: evidência datada, não estado remoto atual.
5. Documentação legada: hipótese até ser confrontada com o código.

## Divergências confirmadas na inspeção inicial

- `PROVA_SOCIAL_CONTEXT.md` diz ter sido atualizado em 27/09/2026 e contém
  estados de produto daquele momento.
- `DEPENDENCY_COMPATIBILITY.md` se intitula v0.5.0 e data versões em
  17/09/2026; o app está em `0.7.5+15`, e versões resolvidas variam. Não
  substituir a matriz sem revalidar restrições e lockfile.
- Relatórios `AUDIT.md` e `SECOND_PHASE_REPORT.md` foram escritos em execução
  anterior. As afirmações sobre o benchmark e código têm escopo e limites
  descritos neles; o CI remoto mudou depois, conforme [[../00 - Central/Estado Atual]].
- `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md` registra os cortes de 80%/99% e
  revisão obrigatória antes de publicar como comportamento de produto. A
  inspeção de `question_parser.dart` e `import_quality_gate.dart` confirma esses
  números como heurísticas que afetam estados de revisão, não scores calibrados
  contra ground truth. Para o desenho atual, eles não serão apresentados como
  porcentagens de acurácia nem usados sozinhos para excluir questões. A nota
  histórica permanece preservada; a análise técnica atual está em
  [[../01 - Produto/Importação e OCR]].
- **Scanner (área 9):** a UI ainda mostra “confiança ≥ 99%” e “confiança X%”
  (`publish_page.dart:732, 1733, 2057`), contrariando a decisão de não exibir
  porcentagem. `fieldConfidence` existe no modelo, mas o parser nunca o
  preenche. A publicação exige alternativas e gabarito em todas as questões
  (`publish_page.dart:1333-1343`), bloqueando discursivas e rascunho objetivo
  sem chave. Câmera/galeria e fila de feedback não existem. Evidência e
  critérios de aceite em
  [[Áreas/09 - Importação, OCR, parser e quality gate|auditoria da área 9]].
- `docs/DIAGNOSTICO_ATUAL.md` afirma que o PDF VUNESP não atinge 80 questões. O
  teste atual `vunesp_2024_import_test.dart` exige 80 e passa; a afirmação
  histórica está desatualizada e não deve ser usada como estado atual.
- O `AGENTS.md` anterior apontava para um vault externo não montado neste
  ambiente. Por instrução atual, a base ativa foi criada em `knowledge-base/`;
  não houve importação do repositório de docs externo.

## Consolidação da área 18 (2026-11-04)

- As **18 áreas** foram auditadas; a documentação foi confrontada com o código
  em cada uma. O acervo está em
  [[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e a síntese em
  [[Síntese da Refatoração|Síntese da Refatoração]].
- **Divergências confirmadas:** o `AGENTS.md` tem duas seções 15; o vault é
  chamado de versionado, mas `git ls-files knowledge-base` = 0 e não há
  `.gitignore` no vault; o `README.md` promete importação de imagens e “modo de
  demonstração” inexistentes e diz “código aberto” sem `LICENSE`; o
  `DESIGN_SYSTEM.md` declara `#101311` e o app usa `#050907`;
  `DEPENDENCY_COMPATIBILITY.md` é da versão 0.5.0; relatórios da raiz competem
  com o vault sem banner de histórico.
- **Links:** 9 alvos quebrados foram encontrados; 7 corrigidos (4 para a área 18,
  que passou a existir, 2 nomes antigos da área 15 e 1 link de produto); 2
  placeholders da fonte original foram preservados.
- **Plano detalhado:** [[Áreas/18 - Documentação e divergências código × docs|Área
  18 — Documentação]].

## Lote 1 — o que foi corrigido em 2026-11-08

O trabalho foi feito em worktree separado, sobre `origin/main` em `2c62e30`,
sem commit/push. Ele não altera código do app.

- **`AGENTS.md`:** a segunda seção 15 (“Base de conhecimento do projeto”) passou
  a ser a seção **25**. A fonte normativa não tem mais numeração duplicada.
- **Hierarquia documental:** criada em
  [[../00 - Central/Hierarquia Documental|Hierarquia Documental]], com
  precedência, lista de documentos vigentes e histórico, regras de manutenção e
  vínculo com o ADR-0008.
- **Banners:** `AUDIT.md`, `IMPLEMENTATION_REPORT.md`,
  `SECOND_PHASE_REPORT.md`, `PROVA_SOCIAL_CONTEXT.md`,
  `DEPENDENCY_COMPATIBILITY.md`, `CODEX_P0_GOAL.md`,
  `CODEX_QA_COMPLETO_PROVA_SOCIAL.md` e os relatórios datados em `docs/`
  receberam banner de documento histórico.
- **README:** removida a promessa de importação de imagens e de “modo de
  demonstração”; a seção “O que ainda não existe” agora lista os dois. A
  distribuição foi corrigida para dizer que o site ainda usa `arm64-v8a` como
  padrão e que o APK universal é pendência. A seção de licença agora declara
  **todos os direitos reservados** e aponta para o `LICENSE`.
- **Licença:** `LICENSE` criado na raiz com todos os direitos reservados; a
  decisão foi aprovada pelo responsável e registrada no
  [[../06 - Decisões/ADR/ADR-0007 - Licença do app e política de fixtures de terceiros|ADR-0007]]
  como `aceito`.
- **ADRs:** o ADR-0007 (licença e fixtures) foi aceito. Foram criados como
  `proposto` o ADR-0008 (hierarquia/vault), o ADR-0001 (paleta/tema), o
  ADR-0004 (persistência), o ADR-0005 (distribuição/ABI), o ADR-0006
  (câmera/imagem) e o ADR-0009 (dependências/atualização), além do ADR-0002
  (questão/gabarito/publicação) e do ADR-0003 (versionamento/tentativa) no
  início do Lote 2.

Ainda não resolvido neste lote: **aprovação** dos ADR-0001, 0002, 0003, 0004,
0005, 0006, 0008 e 0009, revisão dos notices de dependências e a varredura
automática de links.

## Pendências

- Auditar os Markdown restantes da raiz e de `docs/` que ainda não foram
  confrontados com o código, especialmente os guias operacionais.
- Atualizar a matriz de dependências com versões/constraints medidos e linkar
  evidências de `pubspec.lock`.
- Não eliminar fontes históricas; adicionar banner, data e link para a nota
  vigente antes de substituir afirmações.
- Adicionar verificação automática de links, frontmatter e segredos no CI.
- Aprovar os ADR-0001, 0002, 0003, 0004, 0005, 0006, 0008 e 0009, que estão
  propostos.
- Revisar notices de dependências e confirmar o titular legal do copyright.
- Auditar guias operacionais restantes em `docs/` e decidir quais continuam
  vigentes, quais viram nota no vault e quais permanecem apenas históricos.

---
tipo: area
area: estado atual
status: VALIDADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.yaml, lib/, test/, .github/workflows/flutter-ci.yml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Estado Atual — baseline local

## Identidade do checkout

| Medida | Resultado |
|---|---|
| Data da auditoria | 2026-11-03 |
| Branch | `main` |
| SHA | `05a8fc1aab92d43f58ad7da8b24e710f9874d281` |
| Versão do app | `0.7.5+15` |
| Estado do worktree | Limpo antes das alterações documentais deste vault |
| Total de commits alcançáveis | 104 |
| Arquivos rastreados | 275 |
| `lib/` | 60 arquivos Dart; 19.113 linhas |
| Testes | 48 arquivos Dart |
| SQL Supabase | 9 migrations, 15 arquivos SQL no total |

Comandos de evidência: `git rev-parse HEAD`, `git status --short --branch`,
`git rev-list --count HEAD`, `git ls-files | wc -l`, `find lib -name '*.dart'`
e `find test -name '*.dart'`.

## Ferramentas e validação

Medidas em 2026-11-03 (SHA `05a8fc1` limpo):

- Flutter 3.47.6 e Dart 3.13.5.
- `flutter analyze`: aprovado, sem issues.
- `flutter test --reporter expanded --concurrency=1 --timeout 90s`: 296
  aprovados, 1 opcional ignorado.
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  reprovado porque estes probes precisam ser formatados:
  `test/_corpus_bench_probe_test.dart`,
  `test/_corpus_detail_probe_test.dart` e
  `test/_corpus_probe_test.dart`. Não foram alterados durante a auditoria
  somente leitura.
- Testes auxiliares do gate estático: 7 verificações Supabase e 11 verificações
  SEO aprovadas.
- Benchmark universal em 46 PDFs: 2.419 questões detectadas, 474 para revisão,
  181 incompletas, 2 documentos sem questões, 54 páginas sem texto utilizável.
  Sem ground truth anotado, precisão/recall não são mensuráveis.

### Reverificação em 2026-11-05 (Lote 0 commitado no fork)

- `bash qa/run_static.sh`: **exit 0 medido no próprio script**. A leitura anterior
  usou `bash qa/run_static.sh | tail` e tomou o `$?` do `tail` — com isso eu havia
  declarado o gate verde enquanto `flutter analyze` tinha 1 issue
  (`unused_local_variable` em `test/manual/corpus_probe.dart:182`), causada pela
  própria migração da saída dos probes para buffer. Corrigida em `46eb9a0`.
- `dart format --output=none --set-exit-if-changed lib test tool packages`:
  **exit 0** (115 arquivos, 0 alterados).
- `flutter test --reporter expanded --concurrency=1 --timeout 90s`: **313
  aprovados, 1 ignorado** em 46 arquivos `*_test.dart` (`290` + 23 expectativas de
  caracterização). A queda anterior de 296 para 290 foi o efeito esperado de tirar
  os probes da suíte automatizada, não regressão.
- Caracterização adicionada em `ff3be0c`:
  `test/scoring_definitions_characterization_test.dart` (10),
  `test/publication_characterization_test.dart` (8),
  `test/draft_resume_characterization_test.dart` (5).
- Os probes vivem em `test/manual/corpus_*.dart` (sem sufixo `_test`, portanto
  fora da suíte), lêem o corpus por `PROVA_SOCIAL_PROVAS_DIR` /
  `PROVA_SOCIAL_CORPUS_ROOT`, gravam em `build/qa/probes/` e rodam por
  `qa/run_corpus_probes.sh`. `grep -rn "/home/nikolas" test tool qa scripts site
  web .github` não retornou nada.
- `.github/workflows/flutter-ci.yml:134`: `qa-full` voltou a rodar em evento
  `schedule`.
- Estado no Git: 4 commits em `NAGC-Student/main` (`27403be` Lote 0, `eebb2b0`
  vault com 76 arquivos, `46eb9a0` fix do analyzer, `ff3be0c` caracterização),
  worktree limpo. `git push upstream main` foi recusado com 403 — o fork não tem
  escrita em `NAGCODE-Dev` — e o fork não roda Actions.
- **Ainda não provado:** nada acima está no `main` do upstream nem validado pelo
  Actions; falta o PR. As migrations nunca foram executadas nesta máquina (sem
  `initdb`, e o runner PGlite pede um módulo instalado fora do repo).


## Auditoria profunda concluída

- **18 de 18 áreas** auditadas contra o SHA `05a8fc1`. Notas, escopo e placar em
  [[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]].
- **Placar:** 16 áreas **EVOLUIR**, 2 **REFATORAR** (Domínio e Supabase) e
  nenhuma **MANTER** ou **REESCREVER**.
- **Média geral:** 2,92/5. Critérios mais fortes: clareza (3,44), segurança
  (3,39) e portabilidade (3,33). Mais fracos: aderência (2,17), robustez (2,39)
  e testes (2,56).
- **Síntese global:** [[../09 - Auditoria/Síntese da Refatoração|Síntese da
  Refatoração]], com achados transversais, ordem dos lotes e ADRs necessários.
- **Área 9 (scanner):** 105 testes do scanner aprovados, 1 ignorado (PDF ENEM
  ausente). Especificação fechada; implementação parcial. Faltam câmera/galeria,
  fila de feedback, publicação de discursivas, estados estruturais no lugar da
  porcentagem e validação de OCR em aparelho.
- O fixture VUNESP está versionado com licença não verificada e não autoriza
  conteúdo de produto.

## CI e pull requests

- Run [#104](https://github.com/NAGCODE-Dev/Prova-Social/actions/runs/41760190392)
  falhou em `QA estático`; as mesmas três divergências de formatação causaram a
  falha.
- Run [#100](https://github.com/NAGCODE-Dev/Prova-Social/actions/runs/41674799007)
  falhou pela mesma razão. Analyzer e testes auxiliares do gate passaram.
- Run [#98](https://github.com/NAGCODE-Dev/Prova-Social/actions/runs/41477351285)
  foi um evento agendado, com o job QA completo ignorado; não prova o pipeline
  completo.
- PRs `NAGCODE-Dev/Prova-Social#16`, `#17` e `#18` estão mesclados no upstream
  no SHA auditado.
- Nenhum commit, push ou merge foi feito nesta tarefa.

## Integridade, limites e riscos

- O benchmark cobre o caminho de texto PDF no runner Linux; não mede OCR nativo
  Android/iOS nem fidelidade visual.
- Não havia totais esperados nos 46 PDFs; não afirmar que o número de questões
  detectadas é correto.
- O corpus local não contém EPCAR/AFA; fontes oficiais consultadas em execução
  anterior não estavam acessíveis. Não copiar documentos para o app sem
  permissão.
- Há arquivos de ambiente locais ignorados (`.env.p0` e `.env.supabase.json`).
  Os valores não foram lidos nem copiados para o vault.
- Licença de nível raiz decidida em 2026-11-08: **todos os direitos
  reservados**, com `LICENSE` e ADR-0007 aceito. A licença de
  `packages/paddleocr_android` não licencia automaticamente o aplicativo.
- Configuração e migrations locais não provam o estado do Supabase remoto.

## Próximas verificações

1. Corrigir o gate de formatação e tornar os probes portáveis em tarefa
   autorizada de código (Lote 0 da síntese); repetir o CI e confirmar `main`
   verde.
2. Atualizar a fonte documental — `AGENTS.md` (numeração corrigida no Lote 1),
   README, `DESIGN_SYSTEM.md` e `DEPENDENCY_COMPATIBILITY.md`; o vault está
   versionado e a licença foi resolvida no Lote 1.
3. Aprovar ADRs de identidade, domínio, persistência, distribuição e vault
   antes de qualquer mudança estrutural.
4. Fechar contratos de domínio, publicação e RLS (Lote 2) e só então avançar
   para Focus/offline, importação, identidade, distribuição e social.
5. Obter ground truth autorizado para benchmark e OCR; não promover fixture de
   terceiros a conteúdo de produto.

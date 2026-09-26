# Relatório P0 — 26/09/2026

> Documento histórico. Para o estado consolidado após push, migration e consulta remota, leia o [relatório de revisão externa](REVISAO_EXTERNA_20260926.md).

**Atualização posterior:** push autorizado concluído em `ff04f25`; correção Supabase autorizada e aplicada como `20260926160028_secure_attempt_delivery`. Smoke test remoto aprovado com rollback. Veja [evidências atuais](REVISAO_MIGRATION_REMOTA.md). O relatório abaixo preserva a auditoria anterior; os bloqueios remotos ali descritos foram resolvidos. Flutter permanece pendente.

O P0 **não está concluído nem validado para distribuição**. Esta execução preservou o trabalho local, confirmou o estado remoto por consultas somente de leitura e acrescentou correções locais. Nenhum commit, push, tag, release, deploy ou alteração no Supabase foi realizado.

## 1. SHA e branch iniciais

`main`, `6d3ed92` — Implementar entrega offline idempotente.

## 2. Local versus origin/main

`git fetch origin` executado com sucesso. HEAD igual a `origin/main`, sem commits ahead/behind. Worktree modificado. Não houve pull, reset, clean, rebase ou sincronização automática de arquivos.

## 3. Trabalho preexistente

Já havia 40 arquivos rastreados modificados, além de arquivos não rastreados: missão P0, cache `.dart_tool`, lockfile, armazenamento de provas locais, busca, testes UX, scripts PostgreSQL, documentação e testes do site. As alterações abrangiam backend, autenticação, importação, inicialização, tema, Focus Mode, resultado, site e SQL. Não devem ser atribuídas integralmente a esta execução.

O inventário preservado no início da auditoria é:

```text
 M lib/core/backend/attempt_draft_store.dart
 M lib/core/backend/attempt_repository.dart
 M lib/core/backend/attempt_submission.dart
 M lib/core/backend/attempt_sync_service.dart
 M lib/core/backend/auth_repository.dart
 M lib/core/backend/content_delivery_repository.dart
 M lib/core/backend/digital_exam_service.dart
 M lib/core/backend/exam_media_repository.dart
 M lib/core/backend/exam_publication_service.dart
 M lib/core/backend/exam_repository.dart
 M lib/core/backend/supabase_config.dart
 M lib/core/import/ocr_service.dart
 M lib/core/import/ocr_service_native.dart
 M lib/core/import/pdf_text_extractor.dart
 M lib/core/import/question_parser.dart
 M lib/core/startup/startup_gate.dart
 M lib/core/theme/app_theme.dart
 M lib/core/update/github_release_service.dart
 M lib/core/update/update_gate.dart
 M lib/core/widgets/brand.dart
 M lib/core/widgets/skeleton.dart
 M lib/domain/models/exam.dart
 M lib/features/auth/auth_gate.dart
 M lib/features/auth/auth_page.dart
 M lib/features/home/home_page.dart
 M lib/features/onboarding/onboarding_page.dart
 M lib/features/publish/publish_page.dart
 M lib/features/quiz/quiz_page.dart
 M lib/features/result/result_page.dart
 M site/app.js
 M site/index.html
 M site/styles.css
 M supabase/tests/attempt_idempotency.sql
 M test/attempt_draft_store_test.dart
 M test/attempt_sync_service_test.dart
 M test/exam_provenance_test.dart
 M test/exam_result_test.dart
 M test/quiz_draft_exit_test.dart
 M test/quiz_offline_submission_test.dart
 M test/source_badge_test.dart
?? .dart_tool/
?? CODEX_P0_GOAL.md
?? docs/TESTES_POSTGRES_LOCAL.md
?? docs/UX_LOCAL_SEARCH.md
?? lib/core/backend/local_exam_store.dart
?? lib/features/search/
?? pubspec.lock
?? scripts/
?? site/tests/
?? test/ux/

```

## 4. Problemas encontrados

- Supabase implantado sem a RPC de cinco argumentos e sem `attempts.client_attempt_id`.
- Conteúdo de provas públicas em andamento não persistido para reabrir offline.
- Resultado local era apenas exibido, sem histórico persistente nem remoção do rascunho.
- `PGRST202` era classificado como permanente, impedindo retry após atualização do serviço.
- Resultado não mostrava enunciado, procedência nem separava erradas/em branco/marcadas.
- JSON podia considerar `null == null` como acerto, e prova vazia causava divisão por zero.
- CI formatava arquivos em vez de verificar e flexibilizava infos do analyzer.
- SDK ausente e cluster local PostgreSQL incompleto.
- Resposta da RPC não validava alternativas, duplicatas, marcações e contagens.
- Reabertura pelo catálogo podia associar rascunho antigo ao conteúdo atualizado da prova.
- Payload mutável podia mudar enquanto aguardava gravação na fila.

## 5. Causas

O rascunho armazenava somente índices de respostas, sem conteúdo da prova; a Biblioteca dependia do catálogo remoto. A finalização local retornava antes de escrever o resultado no armazenamento. O classificador de erros não contemplava ausência/defasagem de assinatura da RPC. O resultado usava comparação direta entre resposta e gabarito opcionais. Os comandos do CI não eram gates estritos.

## 6. Alterações desta execução

- `AttemptQueueStore` agora persiste conteúdo iniciado, remove-o na mesma gravação que enfileira a entrega e grava resultados locais sem envio remoto.
- Focus Mode exige persistência do conteúdo antes de liberar a prova, reconhece resultados locais já entregues após interrupção e salva resultado antes de limpar rascunho.
- Biblioteca apresenta provas em andamento disponíveis offline e resultados locais com indicação correta. Carrega dados locais antes de aguardar sincronização.
- `PGRST202` permanece elegível para retry com backoff e mesmo `clientAttemptId`. Nenhum fallback para RPC antiga foi introduzido. Erros de permissão/payload continuam permanentes.
- Resultado ganhou enunciado, marcação, contagens separadas, agrupamento por disciplina e procedência com link HTTPS. O SourceBadge existente foi movido para componente compartilhado, mantendo export compatível na Home.
- Modelo trata prova vazia e não considera ausência de gabarito um acerto; lista índices errados para futura prova dos erros.
- CI agora executa format check e analyze estritos. Novo workflow manual `p0-validation` executa apenas dependências/format/analyze/test, sem credenciais ou publicação; não foi disparado.
- Resposta da RPC é validada contra a entrega salva (IDs únicos, alternativas válidas, respostas, marcações e contagens); inconsistências preservam a entrega em atenção.
- Retomada pelo catálogo usa o snapshot original da prova; a fila captura o payload antes de aguardar outras gravações.
- Entregas em atenção podem ser reenviadas por ação explícita com mesmo ID/payload. Retry automático continua bloqueado nesses casos.
- Runner PGlite acrescentado para executar SQL sequencial em memória, com limitações documentadas.
- Formatação auxiliar via `@wasm-fmt/dart_fmt@0.4.0`; 52 arquivos parseados e saída idempotente. Isso não comprova aprovação do formatter da versão de Dart exigida no CI.

## 7. Arquivos alterados por esta execução

- `lib/core/backend/attempt_repository.dart`
- `lib/core/backend/attempt_sync_service.dart`
- `lib/core/widgets/source_badge.dart` (novo; extraído sem redesign)
- `lib/domain/models/exam.dart`
- `lib/features/home/home_page.dart`
- `lib/features/quiz/quiz_page.dart`
- `lib/features/result/result_page.dart`
- `codemagic.yaml`
- `scripts/pglite_test.mjs` (novo)
- `docs/TESTES_POSTGRES_LOCAL.md`
- `lib/core/backend/exam_repository.dart`, `lib/features/onboarding/onboarding_page.dart` e `lib/features/publish/publish_page.dart`: somente ajustes do formatter nesta continuação, preservando alterações anteriores.
- testes listados abaixo e documentação de diagnóstico/roadmap/este relatório.

## 8. Testes criados ou alterados

- Novo `test/attempt_repository_test.dart`: PGRST202 recuperável, 22023/42501 permanentes, envio do ID idempotente, oito tipos de resposta inválida e correção válida.
- `test/attempt_sync_service_test.dart`: conteúdo após reinício; falha na transição para entrega preserva conteúdo; resultado local persistido sem fila remota; snapshot do payload mutável e retry explícito após correção externa.
- `test/quiz_offline_submission_test.dart`: conclusão local fica no histórico e limpa rascunho; falha de fila injetada após início persistido; retomada preserva conteúdo original mesmo com catálogo alterado.
- `test/quiz_draft_exit_test.dart`: mock de SharedPreferences para persistência do conteúdo.
- `test/exam_result_test.dart`: índices errados, em branco, agrupamento, gabarito ausente e prova vazia.

**Esses testes Dart foram escritos, mas não executados neste ambiente.**

## 9. Verificações executadas

- `git diff --check`: aprovado.
- `node --test site/tests/site.test.cjs`: 3 testes aprovados.
- `sh -n scripts/local_db_start.sh scripts/local_db_test.sh scripts/local_db_stop.sh`: aprovado (somente sintaxe).
- `dart format --output=none --set-exit-if-changed .`: não executou; `dart: not found`.
- Inicialização PostgreSQL recusada: `global/pg_control` ausente no cluster preexistente. Diretório preservado. O teste nativo não rodou; o runner alternativo PGlite passou no escopo abaixo.
- YAML validado com `yaml@2.8.1`, instalado em `/tmp`; workflow `p0-validation` conferido sem trigger automático, publicação ou grupo de credenciais.
- Runner `scripts/pglite_test.mjs`: aprovado no PostgreSQL 18.3/PGlite 0.5.8; três migrations e fixture de retries sequenciais/RLS/grants/rollback. Só `CREATE EXTENSION pgcrypto` omitido; UUID nativo exercitado. Concorrência não testada.
- `node --check scripts/pglite_test.mjs`: aprovado.
- Formatter auxiliar [dart_fmt](https://github.com/wasm-fmt/dart_fmt): 52 arquivos Dart parseados e formatados; segunda formatação sem diferenças. Não realiza análise de tipos e não substitui `flutter analyze`. Dependências auxiliares ficaram fora do repositório.
- Consultas remotas de leitura: histórico de migrations, assinatura da RPC, colunas e security advisors.

## 10. flutter analyze

Não executou: `flutter: not found`. Nenhuma alegação de ausência de warnings/erros.

## 11. flutter test

Não executou: `flutter: not found`. Testes Flutter novos e preexistentes aguardam execução.

## 12. Não verificável neste Termux/Alpine aarch64

Build Android/Web, format, analyze, testes Dart/widget/integração, interação real no celular/desktop, light/dark, fonte ampliada, redução de movimento, interrupção do processo, retomada offline real e callback OAuth no aplicativo. `.dart_tool/package_config.json` aponta para `/tmp/prova-flutter`, inexistente; esse cache não prova instalação nem execução de testes. Nenhuma toolchain Flutter/Dart grande foi instalada; verificadores WebAssembly auxiliares ficaram em `/tmp`.

## 13. Dependências externas

É necessário um ambiente Flutter compatível (ou Codemagic autorizado), ambiente PostgreSQL/Supabase isolado para testes e validação de Auth/allowlist/callbacks. Publicação e aplicação de migration em produção exigem autorização explícita; nada foi aplicado remotamente.

## 14. Migration Supabase

Projeto ativo identificado pelo nome Prova Social: `kpjcwpdnzsbgypdefrpz`. Em 26/09/2026, consultas somente de leitura comprovaram:

- histórico: `20260916022412`, `20260916022458`, `20260921005016`, `20260921005845`;
- apenas `submit_exam_attempt(p_exam_id uuid, p_answers jsonb, p_review_question_ids uuid[], p_duration_seconds integer)`;
- `attempts.client_attempt_id` ausente;
- `exams.source_type` e `exams.source_url` presentes.

Portanto `supabase/migrations/202609210003_attempt_idempotency.sql` está **pendente no ambiente implantado — BLOQUEADOR EXTERNO confirmado**. O histórico remoto usa nomes/versões diferentes dos arquivos locais; não aplicar todas as migrations cegamente. Validar compatibilidade e o teste SQL em ambiente isolado antes da implantação autorizada.

Advisors apontaram funções SECURITY DEFINER executáveis, RLS sem policy em `private.question_keys` e proteção de senhas vazadas desabilitada. Os dois primeiros exigem análise do desenho de privilégios; não significam automaticamente acesso indevido (o gabarito privado é deliberadamente restrito). Referências: [funções anon](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [funções autenticadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [RLS sem policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [senhas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

A classificação de PGRST202 foi conferida na [documentação PostgREST](https://postgrest.org/en/stable/references/errors.html): assinatura ausente ou desatualizada no cache.

## 15. Riscos restantes

- Todas as mudanças Flutter desta execução precisam compilar e passar pelos testes; formatação foi aplicada com ferramenta auxiliar; a confirmação por `dart format` oficial permanece pendente.
- SharedPreferences é armazenamento pequeno, sem garantia absoluta contra encerramento forçado durante escrita; fila/histórico/conteúdo crescem juntos e precisam futura gestão de volume.
- Rascunhos legados sem snapshot só passam a ter conteúdo offline ao abrir a prova novamente com conteúdo disponível.
- Histórico/fila são locais ao aparelho; isolamento por conta e vinculação posterior de resultados já sincronizados como visitante ainda precisam evolução explícita.
- Registros antigos em `requiresAttention` podem receber retry explícito; não são automaticamente reclassificados.
- OAuth Web pode perder intenções mantidas só em memória; publicação local tem intenção persistida, favoritos não têm comprovação equivalente.
- Cronômetros configuráveis, conflitos entre aparelhos e sincronização de respostas parciais ainda não completos.
- Parser linear não preserva coordenadas/imagens, não valida prova real de 80 questões e não suporta discursivas completas: P1.
- Explicações não estão modeladas; dados sem gabarito ainda não têm fluxo completo de resultado discursivo.
- CI ainda recria plataformas, faz dois builds Android e acopla deploy a credenciais; release existente ainda usa `--clobber`. Não executar publicação sem revisão.
- Não há prova de fluxo integral importar → publicar → resolver → finalizar contra backend implantado.

## 16. Próximos passos

1. Executar o workflow manual `p0-validation` em ambiente com estas alterações disponíveis, ou os mesmos comandos no Flutter compatível; corrigir falhas antes de distribuir. O workflow não foi disparado e nenhum código foi enviado ao remoto.
2. Validar a migration idempotente em Supabase isolado e comparar schema real; solicitar autorização final para implantação.
3. Testar retomada offline e interrupção entre persistência/limpeza do rascunho, além de duas sessões/contas e retries.
4. Validar Google/e-mail e callbacks no domínio oficial e Android, preservando favoritos após redirecionamento.
5. Só então simplificar distribuição incrementalmente e seguir P1.

## 17. git status final

```text
 M codemagic.yaml
 M docs/DIAGNOSTICO_ATUAL.md
 M docs/ROADMAP_EXECUCAO.md
 M lib/core/backend/attempt_draft_store.dart
 M lib/core/backend/attempt_repository.dart
 M lib/core/backend/attempt_submission.dart
 M lib/core/backend/attempt_sync_service.dart
 M lib/core/backend/auth_repository.dart
 M lib/core/backend/content_delivery_repository.dart
 M lib/core/backend/digital_exam_service.dart
 M lib/core/backend/exam_media_repository.dart
 M lib/core/backend/exam_publication_service.dart
 M lib/core/backend/exam_repository.dart
 M lib/core/backend/supabase_config.dart
 M lib/core/import/ocr_service.dart
 M lib/core/import/ocr_service_native.dart
 M lib/core/import/pdf_text_extractor.dart
 M lib/core/import/question_parser.dart
 M lib/core/startup/startup_gate.dart
 M lib/core/theme/app_theme.dart
 M lib/core/update/github_release_service.dart
 M lib/core/update/update_gate.dart
 M lib/core/widgets/brand.dart
 M lib/core/widgets/skeleton.dart
 M lib/domain/models/exam.dart
 M lib/features/auth/auth_gate.dart
 M lib/features/auth/auth_page.dart
 M lib/features/home/home_page.dart
 M lib/features/onboarding/onboarding_page.dart
 M lib/features/publish/publish_page.dart
 M lib/features/quiz/quiz_page.dart
 M lib/features/result/result_page.dart
 M site/app.js
 M site/index.html
 M site/styles.css
 M supabase/tests/attempt_idempotency.sql
 M test/attempt_draft_store_test.dart
 M test/attempt_sync_service_test.dart
 M test/exam_provenance_test.dart
 M test/exam_result_test.dart
 M test/quiz_draft_exit_test.dart
 M test/quiz_offline_submission_test.dart
 M test/source_badge_test.dart
?? .dart_tool/
?? CODEX_P0_GOAL.md
?? docs/RELATORIO_P0_20260926.md
?? docs/TESTES_POSTGRES_LOCAL.md
?? docs/UX_LOCAL_SEARCH.md
?? lib/core/backend/local_exam_store.dart
?? lib/core/widgets/source_badge.dart
?? lib/features/search/
?? pubspec.lock
?? scripts/
?? site/tests/
?? test/attempt_repository_test.dart
?? test/ux/
```

## 18. Resumo do diff

Diff acumulado, incluindo trabalho preexistente e excluindo arquivos não rastreados. A seção 7 delimita esta execução.

```text
 codemagic.yaml                                    |   23 +-
 docs/DIAGNOSTICO_ATUAL.md                         |   40 +-
 docs/ROADMAP_EXECUCAO.md                          |   14 +
 lib/core/backend/attempt_draft_store.dart         |   53 +-
 lib/core/backend/attempt_repository.dart          |  124 +-
 lib/core/backend/attempt_submission.dart          |    6 +-
 lib/core/backend/attempt_sync_service.dart        |  366 ++++--
 lib/core/backend/auth_repository.dart             |   37 +-
 lib/core/backend/content_delivery_repository.dart |   36 +-
 lib/core/backend/digital_exam_service.dart        |    6 +-
 lib/core/backend/exam_media_repository.dart       |   33 +-
 lib/core/backend/exam_publication_service.dart    |   34 +-
 lib/core/backend/exam_repository.dart             |  116 +-
 lib/core/backend/supabase_config.dart             |    4 +-
 lib/core/import/ocr_service.dart                  |    3 +-
 lib/core/import/ocr_service_native.dart           |    5 +-
 lib/core/import/pdf_text_extractor.dart           |   14 +-
 lib/core/import/question_parser.dart              |   65 +-
 lib/core/startup/startup_gate.dart                |  166 +--
 lib/core/theme/app_theme.dart                     |   83 +-
 lib/core/update/github_release_service.dart       |   24 +-
 lib/core/update/update_gate.dart                  |    6 +-
 lib/core/widgets/brand.dart                       |   47 +-
 lib/core/widgets/skeleton.dart                    |  101 +-
 lib/domain/models/exam.dart                       |  121 +-
 lib/features/auth/auth_gate.dart                  |    4 +-
 lib/features/auth/auth_page.dart                  |  301 +++--
 lib/features/home/home_page.dart                  | 1284 ++++++++++++-------
 lib/features/onboarding/onboarding_page.dart      |  131 +-
 lib/features/publish/publish_page.dart            | 1416 ++++++++++++++-------
 lib/features/quiz/quiz_page.dart                  | 1076 +++++++++-------
 lib/features/result/result_page.dart              |  345 +++--
 site/app.js                                       |   12 +-
 site/index.html                                   |   24 +-
 site/styles.css                                   |    4 +-
 supabase/tests/attempt_idempotency.sql            |  311 +++--
 test/attempt_draft_store_test.dart                |  178 +--
 test/attempt_sync_service_test.dart               |  390 ++++--
 test/exam_provenance_test.dart                    |   12 +-
 test/exam_result_test.dart                        |   72 +-
 test/quiz_draft_exit_test.dart                    |   48 +-
 test/quiz_offline_submission_test.dart            |  187 ++-
 test/source_badge_test.dart                       |   37 +-
 43 files changed, 4775 insertions(+), 2584 deletions(-)
```

## 19. Mensagem sugerida de commit

`Estabilizar retomada offline e persistência de resultados locais`

Somente após executar as verificações e revisar o diff acumulado. **Commit não criado.**

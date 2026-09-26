# Relatório consolidado para revisão externa — Prova Social

Data: 26/09/2026. Estado do código analisado: `4be6972a3f6b37aff035a9c750aa7b6f301d7360`, branch `main`.

## 1. Conclusão e alcance

A correção de entrega de tentativas foi aplicada ao Supabase e passou nos testes SQL descritos neste documento. O aplicativo P0 ainda **não está aprovado para distribuição**: Flutter/Dart não estão disponíveis neste ambiente, não houve execução de analyze/test/build e faltam testes de concorrência e de ponta a ponta.

A consulta remota mais recente, em **26/09/2026 às 16:08:57 UTC**, confirmou a migration, ambas as assinaturas da RPC, RLS habilitada nas tabelas de tentativas e ausência de grants diretos de escrita para PUBLIC/anon/authenticated nessas tabelas. Existem **zero provas, zero tentativas e zero respostas**. Isso confirma implantação de schema, mas não comprova upload/publicação de uma prova. Não foi feito inventário de objetos do Storage nesta verificação; zero provas não significa necessariamente zero arquivos enviados.

Este documento é a referência consolidada para a revisão. O [relatório P0 anterior](RELATORIO_P0_20260926.md) preserva o diagnóstico histórico e contém decisões posteriormente superadas. As evidências específicas de implantação estão em [revisão da migration](REVISAO_MIGRATION_REMOTA.md).

## 2. Proveniência do código e autorizações

| Marco | Referência | Conteúdo |
| --- | --- | --- |
| Base inicial | `6d3ed92f259de14ad9b627c82a58000d28f48c14` | Entrega offline idempotente anterior ao lote auditado |
| Lote P0 enviado | `ff04f25724267c7ef639a6494a5ffcd8bf525f02` | Trabalho local preservado, persistência offline, resultados, testes e documentação |
| Correção Supabase enviada | `4be6972a3f6b37aff035a9c750aa7b6f301d7360` | Compatibilidade com schema remoto, privilégios, migration e testes SQL |

O primeiro lote inclui trabalho que já estava no diretório: 40 arquivos rastreados modificados e arquivos novos. Nem todas as mudanças podem ser atribuídas à execução de correção. O inventário original está no relatório histórico. O diff acumulado da base até o código revisado tem 66 arquivos, 8.585 inserções e 2.591 exclusões.

O responsável autorizou explicitamente push e migration segura, depois priorizou a correção do Supabase e solicitou este relatório no Git para revisão externa. Não houve criação de tag ou release nesta sequência. O commit deste relatório altera apenas documentação; sua identificação fica no histórico Git, sem autorreferência de hash no arquivo.

Comparações reproduzíveis:

```sh
git diff --stat 6d3ed92..4be6972
git diff ff04f25..4be6972 -- supabase scripts .gitignore
git show 4be6972
```

## 3. Diagnóstico do produto frente ao AGENTS.md

“Parcial” indica implementação encontrada, sem equivaler a aprovação em runtime. “Funcional” abaixo se restringe ao escopo explicitamente testado.

| Área | Estado | Evidência ou pendência |
| --- | --- | --- |
| Navegação visitante e onboarding | Parcial | Cinco abas, onboarding dispensável e login contextual no código; runtime pendente |
| E-mail/Google e callbacks | Parcial | Configuração no código/CI; OAuth real, allowlist e retorno Android/Web ainda precisam validação |
| Home, busca e perfil | Parcial | Consultas reais e estados vazios; catálogo remoto sem provas na consulta atual |
| Conteúdo em andamento offline | Parcial | Snapshot persistido e retomada implementados; encerramento real do processo não testado |
| Rascunhos e respostas | Parcial | Escritas serializadas e flush; regressões Dart escritas, não executadas |
| Entrega e retry no banco | Funcional no teste SQL sequencial | Visitante, retry, vínculo e isolamento aprovados; concorrência e integração cliente pendentes |
| Focus Mode | Parcial | Navegação, marcação, timer isolado/ocultável; configuração prévia de timers incompleta |
| Resultado e procedência | Parcial | Contagens, enunciado, disciplina e origem no código; explicações/discursivas incompletas |
| Prova dos erros | Parcial | Índices errados modelados; fluxo integral ainda não demonstrado |
| Importação/OCR | Parcial | Texto nativo, OCR seletivo e editor; parser linear e validação de 80 questões pendentes |
| Mídia e pacotes | Parcial | Gzip/hash e upload existentes; associação espacial e fluxo completo não validados |
| Discussões/comunidades | Parcial/ausente | Fluxo social completo não implementado no lote P0 |
| RLS global e privacidade | Parcial | Verificação focada em tentativas/respostas/gabaritos; não é auditoria de todo o projeto |
| Marca, responsividade e acessibilidade | Não verificável em runtime | Ativos/componentes presentes; mobile, desktop, temas e preferências ainda precisam execução |
| Atualização do app | Parcial | Timeout e consulta de releases; comparação SemVer simplificada |
| CI/CD e distribuição | Parcial | Gates preparados; nenhuma execução bem-sucedida de Flutter comprovada neste relatório |

Não foram criadas entidades em massa nem conteúdo demonstrativo de produção para preencher o catálogo vazio.

## 4. Alterações do fluxo de tentativas no aplicativo

Os arquivos centrais são [attempt_sync_service.dart](../lib/core/backend/attempt_sync_service.dart), [attempt_repository.dart](../lib/core/backend/attempt_repository.dart), [quiz_page.dart](../lib/features/quiz/quiz_page.dart), [home_page.dart](../lib/features/home/home_page.dart) e [result_page.dart](../lib/features/result/result_page.dart).

- O armazenamento da fila mantém conteúdo iniciado e resultados locais. A prova precisa ser persistida antes de liberar a resolução; a retomada utiliza o snapshot original mesmo se o catálogo mudar.
- A finalização local salva o resultado antes de limpar o rascunho. A Biblioteca carrega dados locais antes de aguardar a rede e distingue resultados locais e sincronizados.
- A fila captura o payload antes de aguardar outras gravações, reduzindo risco de respostas mutáveis alterarem uma entrega já solicitada.
- `PGRST202` permanece recuperável com backoff e o mesmo `clientAttemptId`, sem fallback automático para a RPC antiga. Erros permanentes ficam em atenção; retry explícito preserva ID/payload.
- O cliente verifica IDs, duplicatas, alternativas, respostas, marcações e contagens retornados pela RPC. Uma resposta inconsistente mantém a entrega para tratamento.
- O resultado mostra enunciado, procedência, erradas, em branco, marcadas e agrupamento por disciplina. Ausência de gabarito não equivale a acerto; prova vazia não divide por zero.

Essas mudanças têm testes Dart associados, mas a validade de tipos, compilação e comportamento dos widgets permanece sem comprovação neste ambiente.

## 5. Causa confirmada no Supabase

O schema remoto diferia do fixture local: `attempts.user_id` era NOT NULL; não havia RPC de cinco argumentos nem as colunas de idempotência; existiam políticas e grants de escrita direta. Havia inclusive grants de TRUNCATE para papéis de cliente, operação que não é protegida por RLS.

Aplicar somente a migration antiga teria mantido incompatibilidade com visitantes e permissões inadequadas. Por isso, a primeira revisão suspendeu a aplicação e uma migration incremental foi preparada depois de inspecionar o remoto. Nenhuma operação destrutiva foi usada para demonstrar o problema.

## 6. Migration aplicada e contrato de segurança

Arquivo: [20260926160028_secure_attempt_delivery.sql](../supabase/migrations/20260926160028_secure_attempt_delivery.sql).

SHA-256 do SQL aplicado:

```text
d538de8a78279c128e3c178b5aa1a8691f4a1fcf9c9e07050c16def424200f4b
```

A migration permite proprietário NULL para visitante, mantém RLS em `attempts` e `attempt_answers`, revoga todos os grants dessas tabelas para PUBLIC/anon/authenticated e concede apenas SELECT a authenticated. Remove as policies legadas de INSERT/DELETE e preserva a leitura restrita ao proprietário.

Adiciona `client_attempt_id uuid`, `request_payload jsonb` e índice único parcial para IDs não nulos. Registros antigos não exigem backfill nem remoção. A nova RPC recebe cinco argumentos, valida prova pública/publicada e compara o payload canônico no retry. O mesmo ID e payload reutilizam a tentativa; conflitos são recusados. O vínculo posterior de tentativa visitante a usuário autenticado usa atualização condicional.

A função usa SECURITY DEFINER, owner postgres e `search_path=pg_catalog`, com EXECUTE revogado de PUBLIC e concedido explicitamente a anon/authenticated. SECURITY DEFINER exige revisão cuidadosa das validações internas; RLS não substitui essas verificações dentro da função privilegiada. O grant de service_role permaneceu. Nenhuma chave de serviço foi colocada no cliente ou neste relatório.

A RPC antiga de quatro argumentos foi preservada. O hash de sua definição permaneceu `e415e4f2f0fbcbf20d14108d2ee18d4f` antes/depois. Ela foi exercitada no smoke test, mas não recebeu garantia nova de idempotência. O aplicativo atualizado continua usando a nova assinatura.

O SQL define limites de espera de lock/execução e notifica o PostgREST para recarregar o schema. Não elimina linhas nem restaura permissões inseguras para manter compatibilidade.

## 7. Estado remoto observado

Projeto Prova Social: `kpjcwpdnzsbgypdefrpz`, PostgreSQL 17. Histórico retornado pelo servidor:

| Versão | Nome |
| --- | --- |
| 20260916022412 | create_prova_social_core_schema |
| 20260916022458 | add_missing_foreign_key_indexes |
| 20260921005016 | secure_exam_core |
| 20260921005845 | private_question_keys_rls |
| 20260926160028 | secure_attempt_delivery |

Resultado de leitura em 26/09/2026 às 16:08:57 UTC:

```json
{
  "exams": 0,
  "attempts": 0,
  "answers": 0,
  "rls_enabled": true,
  "rpc_idempotent": true,
  "rpc_legacy": true,
  "direct_write_grants": 0
}
```

`rls_enabled` agrega somente attempts/attempt_answers. `direct_write_grants` conta privilégios diferentes de SELECT para PUBLIC/anon/authenticated nessas duas tabelas. Verificação anterior também confirmou as novas colunas, índice único e ausência de fixtures remanescentes.

O histórico remoto não coincide com os nomes/versões das migrations iniciais locais. **Não executar todas as migrations locais no projeto remoto cegamente**, nem alterar o histórico para torná-lo visualmente igual. A nova migration contém a compatibilidade necessária; uma futura reconciliação exige comparação de schema e plano próprio.

## 8. Evidências dos testes e seus limites

| Verificação | Resultado registrado | Limite |
| --- | --- | --- |
| SQL em PGlite 0.5.8 / PostgreSQL 18.3 | Aprovado | Uma conexão, auth.uid simulado, pgcrypto omitido |
| Schema legado no fixture | Reproduzido antes da correção | Não replica todos os objetos do Supabase |
| Retry autenticado/visitante, conflito de payload e vínculo | Aprovado sequencialmente | Não demonstra duas sessões simultâneas |
| RLS entre identidades e grants | Aprovado no fixture e smoke remoto | Escopo de tentativas e respostas |
| Smoke remoto em PostgreSQL 17 | Aprovado com rollback | Transação controlada via SQL, não login real |
| RPC antiga após restrição de grants | Aprovado | Não equivale a testar todos os clientes antigos |
| HTTP PostgREST com chave publishable e prova inexistente | HTTP 400 / 22023, `exam unavailable` | Prova resolução da assinatura e recusa; não entrega HTTP válida completa |
| Ausência de fixtures após teste remoto | Confirmada | Contagens já eram zero antes |
| Site: `node --test site/tests/site.test.cjs` | 3 testes aprovados | Teste unitário, não browser/Flutter |
| Sintaxe dos scripts shell/Node e YAML | Aprovada | Não substitui execução de CI |
| Formatter Dart auxiliar WASM | 52 arquivos parseados, segunda passagem idempotente | Não é analyzer nem gate oficial do SDK |
| `dart format`, `flutter analyze`, `flutter test` | Não executados: SDK ausente | Bloqueio real da aprovação do app |
| PostgreSQL nativo local | Não executado: cluster incompleto | Diretório preservado, sem recriação destrutiva |
| Concorrência, builds e ponta a ponta | Não executados | Pendências explícitas |

Os resultados acima consolidam as execuções da sessão; não indicam que todos os testes foram repetidos para o commit de documentação. A consulta de estado da seção 7 foi renovada ao preparar este relatório.

Testes SQL: [attempt_idempotency.sql](../supabase/tests/attempt_idempotency.sql), [legacy_attempt_schema.sql](../supabase/tests/legacy_attempt_schema.sql), [deployed_attempt_smoke.sql](../supabase/tests/deployed_attempt_smoke.sql). O smoke usa um perfil existente e fixtures em transação; nenhum usuário Auth foi criado. O rollback de fixtures não deve ser confundido com reversão da migration aplicada.

## 9. Riscos e pendências para revisão

| Prioridade | Questão | Critério para encerrar |
| --- | --- | --- |
| P0 | App sem analyze/test/build | Gates oficiais aprovados no SHA revisado |
| P0 | Catálogo sem provas; publicação não demonstrada | Publicar conteúdo real autorizado e confirmar banco, leitura e resolução |
| P0 | Concorrência da idempotência/vínculo | Duas conexões com mesmo ID; uma tentativa, resultado consistente e isolamento |
| P0 | Persistência sob interrupção/rede instável | Retomar respostas/conteúdo e concluir sem perda nem duplicação |
| P0 | Login e intenção após callback | Google/e-mail em Web e Android, retorno à ação original |
| P0 | Armazenamento local entre contas | Definir e testar privacidade da fila/histórico na troca de conta |
| P1 | Crescimento de SharedPreferences | Política de retenção/limites e teste de falha de escrita |
| P1 | Parser de PDF e discursivas | Prova real permitida de 80 questões, ordem/alternativas/imagens e revisão humana |
| P1 | Sincronização parcial e conflitos entre aparelhos | Política explícita e testes de resolução |
| P1 | Proteção de senhas vazadas desabilitada | Revisar configuração Auth e decisão de ativação |
| P1 | CI/publicação acoplados | Validar credenciais, evitar duplicação de build e sobrescrita de release |

Os advisors ainda sinalizam funções SECURITY DEFINER executáveis e ausência de policy em `private.question_keys`. O desenho usa funções autorizadas para corrigir sem expor tabelas de gabarito, e o acesso direto ao gabarito permanece restrito. Esses avisos foram analisados no escopo da correção, não eliminados nem tratados como uma aprovação global de segurança. Proteção de senhas vazadas é uma configuração separada e não foi alterada.

O ID aleatório de tentativa visitante participa do contrato de retry/vínculo. Revisar explicitamente esse modelo, exposição de IDs, proteção contra abuso de chamadas públicas e limites operacionais antes de ampliar uso. A correção não comprova rate limiting de toda a aplicação.

## 10. Roteiro para o revisor

1. Revisar primeiro o diff `ff04f25..4be6972` e o contrato da RPC, incluindo ACL, search_path, validação de payload e vínculo de visitante.
2. Executar migrations/testes em banco descartável. Nunca executar `legacy_attempt_schema.sql` isoladamente em produção: ele reproduz privilégios inseguros para testar a correção.
3. Exercitar concorrência com duas conexões e payloads iguais/diferentes, incluindo vínculo simultâneo por contas distintas.
4. Executar Flutter no código revisado e inspecionar regressões de persistência e interpretação de respostas.
5. Em ambiente de teste, percorrer importar → revisar → publicar → resolver → finalizar → revisar → reabrir offline; repetir com sessão expirada e troca de conta.
6. Validar telas em mobile pequeno/desktop, light/dark, fonte ampliada e redução de movimento.
7. Revisar pipeline separadamente antes de autorizar distribuição; um push não comprova deploy ou release bem-sucedidos.

Comandos para ambiente Flutter compatível:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
```

Alternativa SQL sequencial, com dependência fora do app:

```sh
npm install --prefix /tmp/prova-p0-pglite --ignore-scripts --no-audit --no-fund --save-exact @electric-sql/pglite@0.5.8
node scripts/pglite_test.mjs /tmp/prova-p0-pglite/node_modules/@electric-sql/pglite/dist/index.js
```

Para PostgreSQL nativo descartável, consultar [instruções e limites](TESTES_POSTGRES_LOCAL.md). O script nativo inclui testes de concorrência, mas a existência do script não significa execução aprovada nesta sessão.

## 11. Recuperação em caso de regressão

Preservar filas e IDs no cliente e identificar o erro antes de reenviar. Não contornar a correção com escrita direta nem trocar automaticamente para a RPC antiga. Não apagar tentativas, colunas ou índice para reverter código.

Não existe evidência de um rollback operacional completo da migration em produção. O teste local verifica a receita de rollback e preservação de linhas no fixture; isso não cobre todos os dados futuros. Uma correção progressiva e revisada é preferível a restabelecer grants de escrita. Restaurar NOT NULL em user_id seria incompatível com tentativas visitantes já criadas e exige tratamento explícito desses dados.

## 12. Critério de aprovação externa

A correção SQL pode ser revisada com evidências reais de implantação e teste sequencial. A aprovação do produto completo depende dos gates Flutter, concorrência, autenticação real, upload/publicação e retomada offline. O relatório não atesta ausência de todos os bugs, segurança global do projeto, sucesso de release ou existência de conteúdo publicado.

Ao registrar achados, informar SHA, arquivo/linha, cenário reproduzível, comportamento esperado/observado, gravidade e teste que demonstra a correção. Não incluir tokens, senhas, dados pessoais ou respostas privadas nos comentários de revisão.

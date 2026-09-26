# Correção aplicada — 26/09/2026

Após autorização do responsável para corrigir o Supabase, a migration
`20260926160028_secure_attempt_delivery.sql` foi aplicada com sucesso ao projeto
Prova Social. O arquivo foi criado com `supabase migration new` e seu timestamp
foi alinhado ao histórico retornado pelo servidor após aplicação via MCP.

SHA-256 do SQL aplicado:
`d538de8a78279c128e3c178b5aa1a8691f4a1fcf9c9e07050c16def424200f4b`.

## Mudanças

- `attempts.user_id` aceita NULL para visitantes; os dados existentes não foram apagados.
- RLS permanece habilitada; leitura de histórico continua restrita ao proprietário autenticado.
- Revogados grants diretos de escrita (incluindo INSERT/DELETE/TRUNCATE) de
  PUBLIC/anon/authenticated em attempts e attempt_answers; authenticated mantém SELECT.
- Removidas policies legadas de INSERT/DELETE dessas tabelas.
- Instalada RPC idempotente de cinco argumentos, com índice único por clientAttemptId.
- RPC antiga de quatro argumentos preservada sem alteração de definição.
- Cache de schema PostgREST notificado para reconhecer a nova assinatura.

## Evidências executadas

1. Fixture local reproduziu NOT NULL e grants legados antes da nova migration.
2. PGlite passou retries, visitante, vínculo posterior, RLS, grants, rollback e RPC legada.
3. Smoke test transacional no PostgreSQL 17 remoto passou entrega de visitante,
   retry sem duplicação, payload conflitante recusado, vínculo autenticado,
   isolamento de outra identidade e recusa de DELETE direto.
4. Rollback confirmado: zero provas de smoke test, zero tentativas e zero
   respostas de teste persistidas (contagens de tentativas/respostas já eram zero antes).
5. Hash da RPC antiga idêntico antes/depois: `e415e4f2f0fbcbf20d14108d2ee18d4f`.
6. Verificados owner postgres, search_path=pg_catalog, ausência de EXECUTE para
   PUBLIC, grants explícitos anon/authenticated, índice único e RLS.
7. Chamada HTTP real via PostgREST, usando chave publishable e exame inexistente,
   retornou HTTP 400/22023 `exam unavailable`: a assinatura nova foi resolvida,
   o controle de conteúdo público foi executado e nenhuma tentativa foi criada.
8. Histórico remoto registra `20260926160028 secure_attempt_delivery`.

## Limites e advisors

Não foi executado teste com duas conexões simultâneas; o índice único e as
operações condicionais foram revisados, e retries sequenciais passaram.
Flutter continua dependendo do CI para teste de ponta a ponta.

Advisors continuam sinalizando as RPCs SECURITY DEFINER executáveis: é
intencional para corrigir provas públicas de visitantes sem expor o gabarito
privado. As verificações de propriedade e payload estão dentro da RPC.
A ausência de policies em private.question_keys também é intencional: somente
as funções autorizadas acessam os gabaritos. Isso não significa auditoria
completa de todas as outras tabelas do projeto.

Proteção de senhas vazadas permanece desabilitada; é uma configuração Auth
separada, não alterada por esta migration. Referências dos advisors:
[RPC pública](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[RLS sem policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[proteção de senhas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Histórico da revisão anterior

# Revisão antes da migration remota — 26/09/2026

O responsável autorizou push e aplicação da migration somente se segura.
O push inclui o trabalho local preservado e as correções P0. A migration
`202609210003_attempt_idempotency.sql` **não foi aplicada**.

## Evidência do schema implantado

Consultas somente de leitura no projeto Prova Social confirmaram:

- A RPC de cinco argumentos não existe.
- `attempts.user_id` é NOT NULL no remoto, enquanto o schema de teste local
  permite NULL. A entrega de visitante da nova RPC falharia no remoto.
- Há políticas de INSERT/DELETE por proprietário e grants de INSERT para
  `authenticated` em attempts/attempt_answers. A migration pressupõe gravação
  controlada pela RPC; escritas diretas podem contornar a validação canônica.
- Há grants adicionais (inclusive TRUNCATE) para anon/authenticated. RLS não
  constitui proteção contra TRUNCATE. Não foi executada operação destrutiva.
- RLS está habilitada nas tabelas de tentativas/respostas e gabaritos privados.
- A contagem de tentativas era zero no momento da consulta.

## Decisão

Não aplicar cegamente a migration testada contra um schema diferente. É preciso
preparar uma migration incremental de compatibilidade: permitir visitante com
proprietário NULL, restringir escrita às RPCs e testar os clientes legados antes
de revogar grants. Nenhum dado, política, grant ou função remota foi alterado.

Os testes SQL sequenciais em PGlite continuam válidos apenas para o fixture
local. Flutter analyze/test ainda precisam de ambiente compatível. O workflow
manual `p0-validation` está no código enviado; não é uma execução já aprovada.

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

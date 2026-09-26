# Roadmap de execução — atualização 26/09/2026

Consulte [diagnóstico](DIAGNOSTICO_ATUAL.md) e [relatório P0](RELATORIO_P0_20260926.md). O texto histórico abaixo não comprova validação.

## Gate imediato P0

1. Executar format/analyze/test no Flutter compatível via workflow manual `p0-validation` (sem publicação). SDK ausente no Termux atual; testes escritos não contam como aprovados.
2. Validar o lote local: conteúdo iniciado offline, histórico de resultados locais, transição atômica para fila, retry PGRST202 e revisão com procedência.
3. Validar migration `202609210003_attempt_idempotency.sql` em ambiente isolado compatível com Supabase 17 e concorrência; fixture sequencial já passou no PGlite 18.3. Ausência no Supabase remoto confirmada por histórico, coluna e assinatura. Implantar só com autorização explícita.
4. Exercitar ciclo integral, OAuth/retomada de intenção e troca de contas em aparelho/Web.
5. Só depois distribuição e P1. Nenhuma release/tag/commit/push autorizada nesta execução.

## Histórico anterior (preservado)

# Roadmap de execução

## P0 — produto utilizável

1. **Procedência (implementado no código, aguardando CI):** mapear tipo e URL, exibir os três estados, abrir apenas origem HTTPS e retirar contagem fixa de discussão. Testes unitários e de widget adicionados.
2. **Confiabilidade da prova (implementada no código, aguardando CI e migration):** respostas e entregas são persistidas localmente antes de sair da prova. Entregas sem correção ficam em fila com backoff, estados acessíveis e reenvio idempotente por `clientAttemptId`. Uma entrega iniciada como visitante é vinculada ao usuário no reenvio autenticado somente quando ID e payload canônico coincidem. Aplicar `202609210003_attempt_idempotency.sql` antes de distribuir este cliente; a migration adiciona as colunas e a nova assinatura da RPC sem remover a anterior.

   A fila e os resultados corrigidos usam `SharedPreferences` neste primeiro lote.
   As operações são serializadas, mas o armazenamento é adequado apenas para um
   volume pequeno. Um lote futuro deve migrar o histórico para armazenamento
   local estruturado e aplicar expiração somente a resultados já sincronizados;
   entregas pendentes ou que requerem atenção nunca devem expirar automaticamente.
3. **Navegação e autenticação:** retomar automaticamente a ação original após login e validar deep links Android/Web.
4. **Conteúdo e estados:** completar estados vazios e leitura pública real, sem métricas ou listas simuladas.
5. **Marca e distribuição:** conferir ícones Android/Web/PWA e simplificar CI sem publicação implícita.

## P1 — importação confiável

Preservar página e coordenadas, ordenar colunas, combinar evidências estruturais e validar com prova real de 80 questões antes de declarar a importação resolvida.

## P2–P4

Evoluir Focus Mode e prova dos erros; depois questões sociais e comunidades; por fim automatizar distribuição e atualização. Cada lote exige análise, testes e revisão de diff antes de publicação.

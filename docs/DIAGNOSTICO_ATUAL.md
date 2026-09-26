# Diagnóstico atual

Data: 26/09/2026. Base: `main`, `6d3ed92`, com trabalho local preexistente preservado. Código inspecionado; consultas Supabase somente de leitura. Ver [relatório completo](RELATORIO_P0_20260926.md).

| Área | Classificação | Evidência e limite |
| --- | --- | --- |
| Git | Funcional | Fetch aprovado; HEAD igual a origin/main; worktree modificado preservado. |
| Navegação visitante/onboarding | Parcial, não validada em runtime | Cinco abas, onboarding dispensável e login contextual presentes. |
| Auth | Parcial | E-mail/Google e callbacks oficiais no código/CI; intenção de publicação local persistida. OAuth real e retomada de favoritos após reload pendentes. |
| Home/busca/perfil | Parcial | Repositório consulta dados reais, perfil usa sessão e estados vazios existem; sem métricas demonstrativas encontradas na busca estática. |
| Biblioteca/offline | Parcial, novo lote não validado | Conteúdo iniciado persistido e retomada direta; resultados locais persistidos; falta execução Flutter. |
| Rascunhos | Parcial | Escritas serializadas, flush na saída e snapshot de respostas; testes existem, não executados neste ambiente. |
| Entrega/idempotência | Parcial; backend validado | Migration secure_attempt_delivery aplicada; visitante/retry/vínculo/RLS/RPC antiga verificados no remoto com rollback. Flutter e concorrência entre conexões pendentes. |
| Focus Mode | Parcial | Alternativas, navegação, revisão e timer isolado/ocultável presentes; configuração prévia dos timers incompleta; runtime pendente. |
| Resultado | Parcial | Contagens reais, enunciado, procedência e disciplina no código; histórico local acrescentado. Explicações/discursivas incompletas. |
| Procedência | Parcial | Três badges e URL HTTPS; colunas confirmadas remotamente. Verificação visual pendente. |
| Importação | Parcial/P1 | Texto nativo, OCR seletivo e editor existem; parser linear sem coordenadas e sem fixture real de 80 questões. |
| Imagens/compactação | Parcial | Pacote gzip/hash e upload existentes; associação espacial e fluxo completo não validados. |
| Discussões/comunidades | Parcial/ausente | Não fazem parte do lote P0; fluxo social completo ausente. |
| Schema/RLS | Parcial | Advisors consultados, migrations locais inspecionadas; não executar testes de escrita em produção. |
| Marca/design/skeletons | Parcial | Ativos próprios e componentes presentes; plataformas geradas pelo CI; não há APK/Web validados aqui. |
| Atualizações | Parcial | Timeout/API de releases; comparação SemVer ainda simplificada. |
| CI/CD | Parcial | Gates estritos e workflow manual sem publicação preparados; plataformas repetidas, dois builds APK e publicação acoplada persistem. |
| Testes Flutter | Bloqueados no ambiente | dart/flutter ausentes. Sem instalação de toolchain grande. |
| Testes PostgreSQL | Parcial | Cluster nativo incompleto preservado. Fixture sequencial/RLS/grants/rollback aprovado em PGlite 18.3; pgcrypto e concorrência não validados. |
| Testes site | Funcional no escopo unitário | 3/3 testes Node aprovados; não equivale a validação visual do Flutter. |

## Lote P0 realizado e próximo gate

Lote incremental: persistir conteúdo iniciado e resultados locais, manter retry quando RPC ainda não implantada e tornar revisão útil. Sem troca de arquitetura, pacote novo ou publicação. Testes adicionados; 52 arquivos Dart parseados/formatados por ferramenta WASM auxiliar e YAML validado. O lote só poderá ser chamado de funcional depois de format/analyze/test e fluxo offline executados em ambiente Flutter compatível. O bloqueio da migration remota foi resolvido; ver REVISAO_MIGRATION_REMOTA.md.

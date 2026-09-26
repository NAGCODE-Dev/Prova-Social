# CODEX QA COMPLETO --- PROVA SOCIAL

## Missão

Execute uma auditoria completa e uma bateria de testes do Prova Social.
Não basta compilar: teste o produto como usuário real. Ao final,
responda com evidências: o que funciona, o que está quebrado, o que não
pôde ser testado e se o P0 está pronto para uma rodada humana.

## Regras

Leia primeiro `AGENTS.md`, `CODEX_P0_GOAL.md`,
`docs/RELATORIO_P0_20260926.md`, `docs/REVISAO_EXTERNA_20260926.md`,
`docs/REVISAO_MIGRATION_REMOTA.md`, `docs/DIAGNOSTICO_ATUAL.md` e
`docs/ROADMAP_EXECUCAO.md`. Inspecione Git e preserve o trabalho
existente. Não faça reset/clean/rebase destrutivo, commit, push, tag,
release, deploy ou mudança em produção sem autorização explícita. Não
enfraqueça gates. Classifique cada área como PASS, FAIL, BLOCKED ou NOT
TESTED. Código existente ou teste não executado não conta como PASS.

## Ambiente de referência

Codemagic: Flutter 3.47.5 stable, framework `6a19cca564`, Dart 3.13.4
stable, macOS arm64. Registre `flutter --version`, `dart --version` e
`flutter doctor -v`. Não troque versões arbitrariamente para contornar
erros.

## 1. Gates oficiais

Execute:

``` sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
```

Registre erros completos. Corrija apenas problemas seguros, rode
novamente e não esconda warnings. Verifique dependências, imports, APIs
depreciadas, null safety, assets, fontes, ícones, Android, Web, deep
links, Supabase, build, pubspec e lockfile.

## 2. Testes automatizados

Inventarie `test/` e `integration_test/` e execute tudo: unitários,
widgets, repositories, persistência, offline, sincronização,
idempotência, resultados, procedência, busca, navegação,
publicação/importação, UX, site e SQL. Cubra especialmente
AttemptQueueStore, AttemptRepository, AttemptSyncService,
clientAttemptId, retry, PGRST202, payload conflitante, resultado local,
retomada, snapshot, prova vazia, gabarito ausente, erradas, brancas,
marcadas, SourceBadge, busca, navegação e prova local. Crie testes para
lacunas P0 razoáveis.

## 3. Builds

Execute `flutter build web` e, se possível, `flutter build apk --debug`.
Valide release apenas localmente se seguro, sem publicar. Registre
warnings, erros e tamanhos.

## 4. Browser e teste visual

Suba o Flutter Web. Se houver browser interno, Chromium, Playwright,
agent-browser ou equivalente, USE. Abra visualmente e clique no
aplicativo. Capture screenshots quando possível. Inspecione console e
network procurando exceptions, JS errors, requests falhando, overflow,
404, Supabase/CORS, loops e telas travadas.

## 5. Visitante

Deslogado, teste primeira abertura, onboarding/pular, reabertura, Home,
Explorar, Busca, Publicar, Biblioteca, Perfil, cinco abas,
voltar/avançar, refresh em rotas, estados vazios, skeleton/loading e
offline. Compare permissões com AGENTS.md. Login contextual deve
preservar intenção quando implementado.

## 6. Auth

Quando o ambiente permitir, teste e-mail, logout, sessão
persistida/expirada, Google, callbacks Web/Android, intenção pós-login e
troca de conta. Observe rascunhos, histórico, fila, favoritos e dados
locais. Nunca exponha tokens.

## 7. Conteúdo/busca

Teste catálogo vazio, conteúdo permitido, pesquisa
normal/inexistente/parcial/especial, filtros, abrir prova, procedência,
links, SourceBadge, favoritos e Biblioteca. Não crie conteúdo falso em
produção.

## 8. Importação/publicação

Teste PDF, imagem, câmera quando possível, JSON e manual. Use válido,
inválido, vazio, PDF difícil, erro OCR, JSON malformado/parcial,
cancelamento, voltar e retry. Nada deve publicar sem revisão explícita.
Confira metadados, questões, alternativas, ordem, imagens e procedência.
Documente limitações do parser.

## 9. Focus Mode

Teste prova completa: iniciar, progresso, selecionar/trocar resposta,
anterior/próxima, marcar revisão, navegador, respondidas/não
respondidas, timer/ocultar, scroll, imagens e textos/alternativas
longos. Confirme persistência imediata.

## 10. Torture test offline

Durante prova: responda, desligue rede, continue, navegue,
feche/recarregue, reabra offline, confirme posição/respostas/marcações,
finalize offline, reabra, confirme resultado local, restaure rede,
sincronize e confirme ausência de duplicação. Repita interrupção após
resposta, durante navegação, antes/durante/depois da finalização e
durante retry. Use throttling/offline do browser.

## 11. Idempotência

Teste mesmo ID+mesmo payload, mesmo ID+payload diferente, retries, falha
de rede, PGRST202, resposta remota inconsistente, requiresAttention,
retry explícito, visitante, vínculo e duas sessões. Se houver PostgreSQL
descartável, teste concorrência com duas conexões. Uma tentativa lógica
nunca deve duplicar remotamente.

## 12. Resultado

Teste finalizar completa, com brancas, marcadas, cancelar, revisar e
resultado. Confira total, acertos, erros, brancas, marcadas, percentual,
duração, disciplina, enunciado, escolhida, correta e procedência.
Gabarito ausente não é acerto; prova vazia não pode quebrar. Confira
Biblioteca/histórico.

## 13. Prova dos erros

Valide identificação de erradas e todo fluxo existente. Se incompleto,
registre exatamente onde termina.

## 14. Responsividade

Teste celular pequeno/comum/grande, tablet e desktop; portrait/landscape
relevante; light/dark; fonte ampliada; zoom; redução de movimento.
Procure overflow, cortes, sobreposição, scroll impossível, contraste,
estado apenas por cor e alvos pequenos. Compare com AGENTS.md.

## 15. Acessibilidade

Teste Semantics, labels, teclado Web, foco, contraste, escala, botões,
campos e erros.

## 16. Site/PWA

Teste landing, links, download, PWA, `/app/`, responsividade, console,
rotas, assets, ícones, manifest e service worker. Rode testes Node.

## 17. Supabase

No remoto, somente operações seguras/read-only salvo autorização
específica. Verifique migration, RPC 5 args, RPC legada, RLS, grants,
client_attempt_id, índice e contrato do cliente. Nada destrutivo em
produção. Testes destrutivos só em banco descartável ou transação com
rollback.

## 18. Exploratório

Clique em tudo: voltar rápido, clique duplo, loading, troca rápida de
abas, refresh, múltiplas abas, vazio, textos enormes, Unicode,
perda/retorno de rede, expiração de sessão e ações repetidas.

## 19. Regressão

Após correções:

``` sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
```

Refaça fluxos afetados e, se possível: abrir → encontrar/importar →
iniciar → responder → sair → retomar → offline → finalizar → sincronizar
→ resultado → revisar.

## Relatório obrigatório

Crie/atualize relatório QA no repositório com SHA, branch, Flutter/Dart,
SO/browser, flutter doctor, format, analyze, testes Flutter/Web/SQL,
builds, testes manuais/browser, screenshots, console/network, bugs
P0/P1/P2, reprodução, esperado/observado, arquivo/linha provável,
correção, regressão, riscos e itens não testados.

Inclua matriz P0 com: abertura, onboarding, visitante, login, busca,
importação, publicação, Focus Mode, persistência, saída, retomada,
offline, finalização, sincronização, idempotência, resultado, revisão,
procedência, Biblioteca, troca de conta, responsividade, dark mode,
acessibilidade, Android build e Web build. Para cada item: Estado,
Evidência e Pendência.

## Critério final

Use todas as ferramentas disponíveis. Se houver browser automatizado,
abra o app e clique. Se puder tirar screenshots, simular offline,
inspecionar console/network ou rodar integração, faça. Pode corrigir
bugs locais claramente seguros, documentando e testando regressão. Se a
correção afetar arquitetura, dados, segurança, Supabase remoto ou
comportamento importante, pare antes e peça autorização.

NÃO commit/push/tag/release/deploy/migration de produção sem
autorização.

Só interrompa a execução quando uma decisão realmente exigir
autorização. Ao final responda explicitamente: 1. O que comprovadamente
funciona? 2. O que comprovadamente está quebrado? 3. O que ainda não
conseguimos testar? 4. O P0 está tecnicamente pronto para uma rodada de
teste humano?

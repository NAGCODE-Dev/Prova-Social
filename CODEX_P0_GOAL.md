# Codex Goal — Prova Social P0

## Regra principal

Leia primeiro `AGENTS.md`. Ele continua sendo a fonte principal de verdade do projeto.

Este documento define a tarefa atual.

Não faça push, commit, tag, release, reset, clean, rebase ou qualquer operação Git destrutiva sem autorização explícita.

Não apague trabalho local existente.

---

# 1. Objetivo

Retomar o Prova Social a partir do estado REAL atual do repositório e estabilizar o P0.

O ciclo que precisa funcionar é:

Abrir
→ descobrir ou importar uma prova
→ iniciar
→ responder
→ salvar cada resposta localmente
→ sair
→ retornar exatamente de onde parou
→ continuar offline
→ finalizar
→ sincronizar posteriormente
→ não duplicar tentativa
→ mostrar resultado
→ revisar erros.

Prioridade:

CONFIABILIDADE
> UX essencial
> testes
> importação
> social
> novas features.

Não priorize Turso, P2P, comunidades, IA paga, gamificação ou grandes features sociais agora.

---

# 2. Primeiro: auditar Git

ANTES DE ALTERAR QUALQUER ARQUIVO execute:

```bash
git status
git branch --show-current
git rev-parse --short HEAD
git log --oneline -10
git remote -v
git fetch origin
git status -sb
```

Último estado remoto conhecido anteriormente:

`6d3ed92` — Implementar entrega offline idempotente

Compare o estado local com `origin/main`.

Se houver modificações locais, commits locais, arquivos não rastreados, branch diferente, ahead/behind/diverged:

PARE qualquer tentativa automática de sincronização.

Preserve tudo.

NÃO use:
- `git reset`
- `git clean`
- checkout destrutivo
- rebase automático
- pull automático

Documente primeiro o que encontrou.

---

# 3. Entender o estado real

Leia:

- `AGENTS.md`
- `README.md`
- `docs/DIAGNOSTICO_ATUAL.md`
- `docs/ROADMAP_EXECUCAO.md`
- `DESIGN_SYSTEM.md`
- `pubspec.yaml`
- `codemagic.yaml`

Inspecione:

- `lib/core/backend/`
- `lib/core/import/`
- `lib/core/startup/`
- `lib/core/update/`
- `lib/features/auth/`
- `lib/features/home/`
- `lib/features/publish/`
- `lib/features/quiz/`
- `lib/features/result/`
- `supabase/`
- `test/`

Documentação antiga pode estar desatualizada. Código atual tem prioridade para determinar o que realmente existe.

Classifique cada área como funcional, incompleta, não validada, quebrada, ausente ou bloqueada externamente.

Não reescreva componentes que já funcionam.

---

# 4. P0.1 — Confiabilidade das tentativas

Audite principalmente:

- `attempt_draft_store.dart`
- `attempt_repository.dart`
- `attempt_submission.dart`
- `attempt_sync_service.dart`

e seus testes.

Comportamento obrigatório:

Resposta alterada
→ persistência local imediata
→ estado consistente
→ sincronização quando possível.

Sair da prova NÃO pode perder respostas.

A entrega precisa sobreviver a falta de internet, timeout, fechamento do app, retry e autenticação posterior quando aplicável.

A sincronização deve ser idempotente usando `clientAttemptId`.

Retries não podem criar tentativas duplicadas.

Verifique também ordenação das gravações, concorrência, race conditions, múltiplas alterações rápidas da mesma resposta e saída imediatamente após responder.

Existe:

`supabase/migrations/202609210003_attempt_idempotency.sql`

Ela é necessária para a implementação atual.

NÃO presuma que já foi aplicada no Supabase remoto.

Se não houver acesso ao ambiente implantado, registre como `BLOQUEADOR EXTERNO`.

Não invente validação. Nunca exponha service role keys ou segredos.

---

# 5. P0.2 — Testes

Quando o ambiente permitir, execute:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Se Flutter não estiver funcional no Termux, NÃO instale toolchains enormes nem destrua o ambiente.

Faça as verificações possíveis e prepare o restante para Codemagic.

Priorize testes para draft local, retomada, saída durante prova, sincronização, offline, retry, idempotência, resultado, procedência e parser.

Não faça alterações cosméticas apenas para criar diff.

---

# 6. P0.3 — Auth

Exploração pública não deve exigir login.

Login somente quando necessário para persistência remota ou recurso social.

Validar/corrigir:
- preservar intenção original;
- login;
- retorno após login;
- email/senha;
- Google/Supabase Auth;
- Android callback;
- Web callback;
- deep links;
- nenhum redirect indevido para localhost.

Web oficial:

`https://prova-social.pages.dev/app/`

Android deve retornar ao aplicativo.

Onboarding NÃO deve obrigar login.

---

# 7. P0.4 — Conteúdo real

Não mostrar conteúdo falso como real.

Evitar métricas inventadas, provas fake em produção, estatísticas hardcoded, discussões falsas e conteúdo demonstrativo fingindo ser real.

Criar/manter empty states honestos.

Home: encontrar algo para fazer.

Explorar: busca real.

Biblioteca: salvas, em andamento e concluídas reais.

Perfil: dados reais.

Navegação mobile:
- Início
- Explorar
- Publicar
- Biblioteca
- Perfil

---

# 8. P0.5 — Focus Mode

Validar:
- questão atual/total;
- progresso;
- alternativas;
- anterior/próxima;
- marcar revisão;
- respondidas;
- não respondidas;
- marcadas;
- persistência local;
- retomada;
- cronômetro;
- ocultar/revelar cronômetro;
- finalização;
- offline.

O cronômetro não deve reconstruir toda a questão a cada segundo.

Estados não podem depender somente de cor.

---

# 9. P0.6 — Resultado

Resultado deve mostrar dados reais:
- acertos/total;
- percentual;
- duração;
- erradas;
- em branco;
- marcadas;
- desempenho por disciplina quando houver dados;
- questões para revisão.

Revisão deve permitir identificar questão, resposta escolhida, correta, explicação quando existir e procedência.

Prepare a arquitetura para `prova dos erros`, mas não transforme isso numa expansão enorme antes do P0.

---

# 10. Importação

Já existem componentes de importação. Não reescreva tudo.

Audite especialmente:
- `pdf_text_extractor.dart`
- `ocr_service.dart`
- `ocr_service_native.dart`
- `question_parser.dart`

O parser ainda deve evoluir para lidar corretamente com duas colunas, continuidade entre páginas, imagens, cabeçalhos, rodapés, instruções, alternativas e ordem espacial.

Arquitetura futura deve preservar página e coordenadas.

OCR somente quando necessário.

Meta futura: prova real de aproximadamente 80 questões.

Neste momento, estabilize somente o necessário para P0 e deixe o restante claramente classificado como P1.

---

# 11. Design

Preserve o Study Surface descrito em `AGENTS.md` e `DESIGN_SYSTEM.md`.

Brand: `#16A36A`

Claro:
- background `#F7F8F6`
- surface `#FFFFFF`
- textPrimary `#171A18`

Escuro:
- background `#101311`
- surface `#181C19`
- textPrimary `#F3F5F3`

Warning: `#E5A524`

Danger: `#DC4C4C`

Mobile-first.

Não transforme tudo em card. Não faça dashboard corporativo.

Respeite acessibilidade e redução de movimento.

Nunca restaure ícone padrão Flutter.

---

# 12. CI/CD

Arquitetura:

GitHub
→ Codemagic
→ análise/testes
→ Flutter Web/Android
→ Cloudflare Pages/GitHub Release.

Audite `codemagic.yaml`.

Problemas conhecidos a investigar:
- `flutter create` repetido;
- plataformas recriadas;
- Android compilado mais de uma vez;
- deploy muito acoplado ao pipeline.

NÃO faça grande refatoração de CI antes do P0 estar estável.

Primeiro garanta confiabilidade. Depois proponha simplificação incremental.

Não crie tag para forçar build. Não publique release. Não faça push.

---

# 13. Fora do escopo agora

Não priorizar:
- Turso;
- P2P;
- comunidades automáticas;
- rede social completa;
- IA paga;
- rewrite do Flutter;
- abstrações desnecessárias;
- gamificação;
- grandes features cosméticas.

---

# 14. Critério de conclusão

O objetivo é conseguir:

abrir
→ encontrar/importar
→ iniciar
→ responder
→ persistir
→ sair
→ retornar
→ continuar
→ ficar offline
→ continuar
→ finalizar
→ sincronizar sem duplicação
→ resultado
→ revisão.

---

# 15. Forma de trabalho

Trabalhe incrementalmente.

Antes de editar, entenda a implementação existente.

Não reescreva código funcional sem motivo.

Para cada problema:

1. reproduza/identifique;
2. encontre a causa;
3. faça a menor correção robusta;
4. teste;
5. prossiga.

Se descobrir algo que invalide este plano, siga o estado real do código e documente a divergência.

Continue trabalhando de forma autônoma nas etapas que não exigirem credenciais, autorização de publicação ou decisões destrutivas. Não pare após a auditoria: prossiga até concluir o máximo possível do P0 e seus testes.

---

# 16. Relatório final obrigatório

Ao terminar, NÃO faça commit nem push.

Entregue:

1. SHA e branch iniciais;
2. situação local vs `origin/main`;
3. alterações que já existiam antes da execução;
4. problemas encontrados;
5. causas identificadas;
6. alterações realizadas;
7. arquivos alterados;
8. testes criados/alterados;
9. testes executados;
10. resultado de `flutter analyze`;
11. resultado de `flutter test`;
12. itens impossíveis de validar no Termux;
13. dependências externas pendentes;
14. situação da migration Supabase;
15. riscos restantes;
16. próximos passos recomendados;
17. `git status` final;
18. resumo do `git diff`;
19. sugestão de mensagem de commit.

NÃO CRIE O COMMIT.

NÃO FAÇA PUSH.

NÃO PUBLIQUE RELEASE.

Pare somente se precisar de autorização para ação destrutiva/publicação, credencial indisponível ou decisão que não possa ser tomada com segurança a partir de `AGENTS.md` e deste documento.

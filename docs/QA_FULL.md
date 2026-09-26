# QA completo — infraestrutura e cobertura P0

## Objetivo e regra de publicação

Reunir os testes e gates de compilação em um workflow independente. A etapa 1
preparou a infraestrutura; a etapa 2 amplia somente a cobertura Dart/Flutter P0,
sem refactor do aplicativo. **`qa-full` nunca publica produto.**
Não faz deploy, upload Cloudflare, commit, push, tag, GitHub Release ou migration
remota; não importa grupos de segredos, assinatura de produção ou credenciais.
Os builds não são distribuídos. A partir da etapa 3, somente evidências de QA
são coletadas como artifacts.

Iniciar manualmente no Codemagic selecionando `qa-full` e a branch alvo `main`,
após incorporar a alteração por processo autorizado. A ausência de `triggering`
impede disparos automáticos por eventos, conforme a
[documentação do Codemagic](https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/).
Não fornecer variáveis de produção ao iniciar a execução.

A auditoria foi feita no checkout `p0-validation-diagnostics`, que contém
alterações anteriores em relação a `main`. Nenhuma troca de branch ou integração
foi realizada. Os arquivos não rastreados `CODEX_QA_COMPLETO_PROVA_SOCIAL.md` e
`docs/qa/` foram preservados. Os workflows anteriores permanecem intactos;
`web-ci` ainda publica em pushes de `main`, fora do escopo de `qa-full`.

## Cobertura existente auditada

Foram encontrados 16 arquivos `*_test.dart`, incluindo quatro em `test/ux/`.
Todos são descobertos uma única vez por `flutter test --reporter expanded`.
A presença dos testes representa cobertura parcial, não certificação do produto.

| Arquivos | Cobertura existente |
| --- | --- |
| `test/attempt_draft_store_test.dart` | Persistência, compatibilidade do rascunho e ID estável |
| `test/attempt_sync_service_test.dart` | Fila, retry/backoff, reinício, idempotência e erros de gravação |
| `test/attempt_repository_test.dart` | Validação da correção recebida e classificação de falhas com HTTP simulado |
| `test/quiz_draft_exit_test.dart`, `test/quiz_offline_submission_test.dart` | Saída aguardando gravação, retomada, entrega offline e resultado online simulado |
| `test/exam_result_test.dart` | Pontuação e exportação, incluindo resposta em branco |
| `test/question_parser_test.dart` | Separação de questões/alternativas e variações simples de numeração |
| `test/content_package_test.dart` | Compactação e restauração JSON |
| `test/github_release_service_test.dart` | Comparação básica de versão |
| `test/exam_provenance_test.dart`, `test/source_badge_test.dart` | Procedência, URLs seguras e badge acessível por texto/ícone |
| `test/ux/local_exam_test.dart` | Edição e integridade da prova local, corrupção e tamanho |
| `test/ux/navigation_editor_test.dart` | Visitante/login simulado, intenção de publicação, privacidade local, navegação e editor em 320/1280 px |
| `test/ux/search_test.dart` | Filtros e busca com HTTP simulado, layout com fonte ampliada |
| `test/ux/startup_test.dart` | Inicialização e redução de movimento |
| `site/tests/site.test.cjs` | Três testes: simulador, fallback offline do link de download, contraste e estilos de acessibilidade |
| `scripts/pglite_test.mjs` | Migrations em memória, fixture legado, retry, RLS/grants, rollback e smoke transacional local |

## Execução do workflow

Ordem exata dos comandos (cada bloco multiline usa `set -eu`):

```sh
flutter --version
dart --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
```

Testes adicionais seguros, sem conexão com banco remoto:

```sh
set -eu
node --test site/tests/site.test.cjs
qa_sql_dir=$(mktemp -d)
npm install --prefix "$qa_sql_dir" --ignore-scripts --no-audit --no-fund --save-exact @electric-sql/pglite@0.5.8
node scripts/pglite_test.mjs "$qa_sql_dir/node_modules/@electric-sql/pglite/dist/index.js"
```

Como `android/` e `web/` estão ausentes no checkout auditado, a preparação é
condicional e copia apenas plataformas de um projeto temporário. Não cria nem
apaga testes no repositório, e não sobrescreve plataformas existentes:

```sh
set -eu
if [ ! -d web ] || [ ! -d android ]; then
  qa_platform_dir=$(mktemp -d)
  flutter create "$qa_platform_dir" --platforms=android,web --project-name=prova_social --org=dev.nagcode --no-pub
  if [ ! -d web ]; then
    cp -R "$qa_platform_dir/web" web
  fi
  if [ ! -d android ]; then
    cp -R "$qa_platform_dir/android" android
  fi
fi
```

Na etapa 1, os comandos finais eram somente de compilação. Na etapa 3, o build
Web abaixo foi substituído pelo build isolado e QA browser documentados ao final:

```sh
flutter build web --release --no-pub
flutter build apk --debug --no-pub
```

Falhas encerram o passo com código não zero e interrompem o workflow. Não há
`ignore_failure`, `|| true` ou pós-processamento que substitua
o status original. O gate de formatação não reescreve arquivos. Não imprimir
ambiente, tokens ou segredos. O APK usa somente assinatura debug do SDK.

## Scripts excluídos e limites de segurança

- `scripts/local_db_start.sh`, `local_db_test.sh`, `local_db_stop.sh`: usam
  exclusivamente socket local, porta 5433 e cluster fixo em `/tmp`. Não alteram
  infraestrutura externa, mas exigem PostgreSQL nativo, usuário `postgres` e
  privilégios para `su/chown`; o teste derruba e recria `prova_social_test`.
  Não executados nesta etapa nem incluídos no runner portátil. São necessários
  posteriormente para validar concorrência real entre duas sessões.
- `scripts/pglite_test.mjs`: selecionado porque cria banco apenas em memória.
  Executa SQL do repositório, inclusive `deployed_attempt_smoke.sql`, somente
  nesse banco. Não usa URL, senha ou cliente Supabase remoto.
- Nenhum script em `scripts/` auditado conecta infraestrutura externa. A receita
  de smoke remoto mencionada em `docs/TESTES_POSTGRES_LOCAL.md` não faz parte
  desta suíte e não foi executada. Rollback não autoriza teste em produção.

## Tipos de teste e lacunas

- **Automatizado:** unitários, widgets e testes Node verificam asserções
  repetíveis com armazenamento/HTTP simulados. Build comprova compilação,
  não funcionamento em dispositivo ou navegador.
- **Integração:** PGlite exercita migrations e funções SQL juntas em memória.
  Não é integração completa com Supabase; `auth.uid()` é simulado, `pgcrypto`
  é omitido pelo runner existente e não há múltiplas conexões. PGlite 0.5.8 usa
  PostgreSQL 18, enquanto a documentação existente registra remoto em 17.
  Não existe diretório `integration_test/` nem fluxo completo automatizado de
  importar → revisar → publicar → fazer → finalizar em ambiente real isolado.
- **Manual:** ainda requer aparelhos/navegadores, OAuth/deep links reais,
  acessibilidade assistiva, teclado, rede ruim, encerramento do processo e
  retomada. Layout, dark mode, fonte ampliada e redução de movimento têm
  verificações pontuais; não há matriz completa de telas e dispositivos.

Faltam validação de PDF real de 80 questões/duas colunas e imagens, OCR nativo,
segurança completa de pacotes, matriz SemVer/prerelease, concorrência SQL no CI,
Auth/JWT/PostgREST e sincronização real. Não criar testes para essas lacunas
nesta etapa. Ícones e deep links das plataformas temporárias não certificam os
artefatos de distribuição.

## Dependências e validação desta etapa

O runner requer Flutter `stable` compatível com `pubspec.yaml` (Flutter >=3.47.0,
Dart >=3.13.0), Node 22, Java 17, Android SDK e acesso aos registries de pacotes.
PGlite 0.5.8 é fixado conforme a receita já existente, instalado fora do app com
scripts npm desabilitados. O canal Flutter stable e suas plataformas geradas
podem mudar; as versões são registradas no início do job.

O ambiente local não disponibiliza `flutter` ou `dart`. Assim, formatação Dart,
análise, testes Flutter e builds dependem da primeira execução no Codemagic.
Validações locais: sintaxe YAML e scripts shell, invariantes do workflow,
testes Node do site, runner SQL em memória e `git diff --check`.
A validação local do YAML não substitui a execução do serviço Codemagic.

## Etapa 2 — cobertura automatizada P0 em Dart/Flutter

Auditoria iniciada em `fd30887`, branch `p0-validation-diagnostics`, sincronizada
com sua branch remota e seis commits à frente de `origin/main` após `git fetch
origin`. Nenhuma integração de branches foi feita. Os arquivos não rastreados
preexistentes foram preservados. Nesta etapa não houve commit, push, navegador,
deploy, consulta Supabase remota ou migration remota.

### Critério de leitura da matriz

A matriz abaixo descreve **cobertura escrita**, não resultado de execução:
`COVERED` significa que há asserções para o contrato indicado; `PARTIAL` indica
um recorte simulado ou incompleto; `NOT COVERED` indica ausência de teste;
`BLOCKED` indica verificação que o ambiente não permite. **Os testes Flutter,
antigos e novos, não foram executados nesta etapa. Nenhum PASS é declarado.**
A aprovação da bateria depende de format/analyze/test no SDK compatível.

### Auditoria anterior às alterações

Já existiam 16 arquivos de testes Dart, quatro em `test/ux/`. Foram reaproveitados
sem duplicação: ordenação de gravações e flush, erro de armazenamento, leitura
v1, ID estável, snapshot persistido, saída aguardando gravação, finalização
local/online, fila e backoff, retomada do serviço, conflito de ID pendente,
serialização de RPCs, erro permanente/retry explícito, validação de correção,
resultado básico/vazio, procedência, pesquisa, startup, navegação e provas locais.

As lacunas eram: inicialização da composição `ProvaSocialApp` com dados locais;
interação com várias questões seguida de saída e retomada completa; comprovação
da ordem entrega/resultado → limpeza do draft; mutação de listas do conteúdo
enfileirado; timeout após aceite no limite HTTP; conflito de ID já concluído;
revisão visual de resultado misto e ausência de gabarito em questão respondida.

### Matriz P0

Os caminhos abaixo são relativos a `test/`. Nível `integration` nesta etapa
significa integração de componentes Dart com HTTP simulado, não teste de servidor
nem execução por `integration_test/` em dispositivo.

| REQUISITO | TESTE | NÍVEL | STATUS |
| --- | --- | --- | --- |
| Startup: espera mínima e redução de movimento | `ux/startup_test.dart`: `static book, ring respects reduced motion=…` (existente) | widget | COVERED |
| Abrir app sem exceção, com/sem progresso local | `ux/navigation_editor_test.dart`: `app inicia com progresso local=…` (2 casos novos) | widget | COVERED |
| Inicialização nativa real, PDF e sessão real | Novo teste usa inicializador injetado, Supabase/HTTP e canal de pacote simulados; não chama `main()` real | integration | PARTIAL |
| Encontrar prova: busca, abrir resultado da busca, erro e vazio | `ux/search_test.dart`: `debounce, loading, stale results, empty, error, retry and open` (existente) | widget | COVERED |
| Encontrar prova salva e abrir pela Biblioteca | `ux/navigation_editor_test.dart`: `app inicia com progresso local=true`, abre “Continuar — disponível offline” | widget | COVERED |
| Provas locais e integridade após edição | `ux/local_exam_test.dart`: persistência, identidade do conteúdo, backup, corrupção/tamanho (existentes) | unit | COVERED |
| Iniciar e preservar snapshot independente do catálogo | `quiz_offline_submission_test.dart`: `responder, sair, retomar snapshot e entregar offline` (amplia o teste de snapshot existente) | widget | COVERED |
| Selecionar e alterar alternativa persiste sem sair | Mesmo teste: lê draft após cada toque, antes da navegação | widget | COVERED |
| Navegar anterior/próxima e marcar revisão preserva estado | Mesmo teste: respostas, posição e marcação; seleção acessível ao retomar | widget | COVERED |
| Alterações rápidas, flush concorrente e retry de disco | `attempt_draft_store_test.dart`: gravações ordenadas, flush e falha recuperável (existentes) | unit | COVERED |
| Sair aguarda gravação pendente | `quiz_draft_exit_test.dart`: `sair espera a gravação pendente e preserva a resposta` (existente) | widget | COVERED |
| Reabrir recupera prova, posição, respostas, marcações, tempo e ID | `quiz_offline_submission_test.dart`: ciclo ampliado usa nova instância de draft store e catálogo sem questões, mas restaura conteúdo original | widget | COVERED |
| Responder e navegar sem rede | Mesmo ciclo: submitter offline, nenhuma submissão durante resolução | widget | COVERED |
| Finalizar pública offline preserva entrega antes de limpar draft | Mesmo ciclo: observa fila durável no momento de remover draft, verifica payload após falha de rede | widget | COVERED |
| Resultado de prova privada salvo antes de limpar draft | `quiz_offline_submission_test.dart`: `conclusão local fica no histórico e libera nova tentativa` (ampliado com observação da ordem) | widget | COVERED |
| Falha de persistência não apaga draft | `quiz_offline_submission_test.dart`: `rascunho não é apagado quando fila não pode ser persistida` (existente) | widget | COVERED |
| Pública offline não inventa nota/gabarito | `quiz_offline_submission_test.dart`: `entrega offline não exibe nota nem gabarito` (existente) | widget | COVERED |
| Payload enfileirado congelado inclusive questões/alternativas | `attempt_sync_service_test.dart`: `entrega captura respostas antes de aguardar gravações anteriores` (ampliado com mutação de listas) | unit | COVERED |
| Falhas repetidas continuam retryable, com backoff limitado | `attempt_sync_service_test.dart`: `backoff é limitado a uma hora` (ampliado: estado, payload e ausência de resultado após sete falhas) | unit | COVERED |
| requiresAttention não dispara nova tentativa automaticamente | `attempt_sync_service_test.dart`: erro permanente e retry explícito após reinício (existentes) | unit | COVERED |
| Retry explícito preserva ID e payload | `attempt_sync_service_test.dart`: `retry explícito recupera entrega após correção externa sem trocar ID` (ampliado: respostas, revisão, prova, tempo e data em cada envio) | unit | COVERED |
| Timeout após aceite, reinício, retry equivalente, uma tentativa lógica | `attempt_repository_test.dart`: `aceite remoto com resposta perdida repete o mesmo payload` (novo; repository + sync + HTTP simulado, sem espera real de timeout) | integration | COVERED |
| Conflito de ID com payload diferente na fila | `attempt_sync_service_test.dart`: `clientAttemptId não pode ser reutilizado com respostas diferentes` (existente) | unit | COVERED |
| Conflito de ID já concluído não sobrescreve resultado | `attempt_sync_service_test.dart`: `ID concluído rejeita conflito sem substituir resultado` (novo) | unit | COVERED |
| Idempotência e concorrência reais no servidor | Simulação HTTP comprova reenvio pelo cliente; não comprova unicidade no banco real | integration | PARTIAL |
| Reconectar, sincronizar, abrir resultado e não reenviar concluída | `quiz_offline_submission_test.dart`: ciclo ampliado aciona “Tentar agora”, verifica resultado persistido e chamada repetida sem RPC | widget | COVERED |
| Identificar questões em branco e marcadas antes de finalizar | Mesmo ciclo: modal “2 de 3 respondidas”, pendências e entrega explícita em branco | widget | COVERED |
| Prova vazia não divide por zero no resultado | `exam_result_test.dart`: caso existente ampliado com contagens, tópicos e exportação vazios | unit | COVERED |
| Resultado: corretas/total/percentual, erradas, branco, duração e disciplinas | `exam_result_test.dart`: caso básico existente e `revisão distingue errada, em branco e sem gabarito` (novo) | widget | COVERED |
| Sem gabarito não entra em erradas nem estatística da disciplina | Mesmo teste novo: questão respondida sem chave não entra em `wrongQuestionIndices`/`byTopic`; interface informa indisponibilidade | widget | COVERED |
| Revisão: resposta selecionada, gabarito quando existe e marcações | Mesmo teste novo: asserções por card e rolagem até última questão | widget | COVERED |
| Procedência em resultado e revisão | Mesmo teste novo: fonte oficial, autor e ação de fonte; `exam_provenance_test.dart` e `source_badge_test.dart` reaproveitados | widget | COVERED |
| Explanation quando disponível | `Question` não possui campo de explicação; nenhuma explicação é fabricada | widget | NOT COVERED |
| Fluxo público completo da Home ao resultado sem pontos de injeção | Coberto em segmentos; catálogo/busca, quiz e sync usam fixtures locais/HTTP simulado | integration | PARTIAL |
| Processo encerrado, armazenamento real e rede física | Recriação de stores/widgets não equivale a encerrar processo no aparelho | manual | NOT COVERED |
| QA de navegador | Fora desta etapa; nenhum navegador executado | browser | NOT COVERED |
| Formatação oficial, análise e execução Flutter | Flutter/Dart indisponíveis neste ambiente | unit | BLOCKED |

### Alterações e limites

Cinco casos novos foram adicionados em arquivos existentes: dois de startup,
um de HTTP/idempotência, um de conflito após conclusão e um de resultado/revisão.
O teste isolado de snapshot foi ampliado para um ciclo de três questões, em vez
de ser duplicado. Outros casos existentes ganharam asserções de payload,
persistência e contagens. O arquivo de submissão offline desmonta explicitamente
as páginas antes de descartar stores, cancelando timers de prova/retry.

Não foi necessário alterar `codemagic.yaml`: `flutter test --reporter expanded`
já descobre esses arquivos. Nenhum `skip`, supressão de análise ou conversão de
falha em warning foi acrescentado. Nenhum arquivo de `lib/` foi alterado.

O contrato atual diferencia:

- **Prova privada local:** resultado local persistido, sem sincronização.
- **Prova pública offline:** entrega durável enfileirada; nota/correção só após
  resposta válida do servidor. Aguardar correção não significa perder resultado.

Limites encontrados no código, não corrigidos por expansão de escopo:

- `_sameSubmission`/`_matchesResult` verificam prova, respostas, revisão e duração;
  não comparam integralmente snapshot e `finishedAt`. Os testes de conflito
  comprovam respostas incompatíveis, não equivalência de todos os metadados.
- `scorePercent` usa todas as questões como denominador; questões sem gabarito
  não entram em erradas, mas o percentual não representa só as questões corrigidas.
- A revisão usa “Revisar” e ícone de erro também quando não há gabarito, embora
  informe “Gabarito indisponível”. Semântica visual pode melhorar em lote próprio.
- Não existe validação geral de duração negativa no construtor de `ExamResult`;
  esta bateria verifica duração produzida pelo cronômetro e preservação na entrega.
- Sem `explanation` no modelo, sem integração nativa de ponta a ponta e sem
  validação de backend real nesta sessão. O estado remoto das migrations não foi
  consultado; registros históricos não substituem validação atual.

### Validação real da etapa 2

- `git fetch origin`: concluído; comparação `HEAD...origin/main`: `6 0` no início.
- `command -v flutter` / `command -v dart`: não encontraram executáveis.
- `dart format --output=none --set-exit-if-changed lib test tool`: **não executado**.
- `flutter analyze`: **não executado**.
- `flutter test --reporter expanded`: **não executado**.
- `git diff --check`: executado, sem erros (exit 0).

Revisão estática dos testes feita contra os contratos e textos atuais do código.
Não foi instalado SDK grande, não houve QA de navegador e não foi acionado CI.
A matriz precisa ser acompanhada pelos logs de uma execução Flutter antes de
considerar o fluxo P0 validado.

## Etapa 3 — Flutter Web em Chromium headless

### Decisão e isolamento

Playwright Test **1.63.0**, fixado em `qa/browser/package.json` e `package-lock.json`,
com Chromium headless shell correspondente. A instalação usa `npm ci`, sem scripts
npm, e `playwright install --with-deps --only-shell chromium`. Não adiciona pacote
Flutter nem dependência de produção. A escolha segue a preferência desta etapa e
permite [controle de rede](https://playwright.dev/docs/api/class-browsercontext#browser-context-set-offline),
[relatórios e execução CI](https://playwright.dev/docs/ci) na mesma ferramenta.

`qa-full` usa explicitamente `linux_x2` com Ubuntu 24.04, Node 22 e Java 17.
A [máquina Linux X2 do Codemagic](https://docs.codemagic.io/specs-linux/ubuntu-24.04/)
permite instalar dependências Chromium com o procedimento oficial. A disponibilidade
na conta/billing não foi consultada; deve ser confirmada na primeira execução.
Os outros workflows foram preservados. O workflow continua manual e nunca publica.

O build usa o entrypoint normal do aplicativo e configuração fictícia:

```sh
flutter build web --debug --no-pub --no-web-resources-cdn \
  --dart-define=SUPABASE_URL=http://127.0.0.1:8787 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=qa-public-placeholder \
  --dart-define=WEB_AUTH_CALLBACK=http://127.0.0.1:8787/
```

Debug foi escolhido para expor assertions e diagnósticos de overflow Flutter;
não certifica otimizações do build release. `--no-web-resources-cdn` mantém o
renderer local. Qualquer dependência externa inesperada, inclusive fonte/CDN,
será bloqueada e falhará o teste, sem liberar produção para contornar a falha.
O build resultante é exclusivo de QA, não é distribuído.

### Servidor, fixtures e ciclo de vida

`server.mjs` serve exclusivamente `build/web` em `127.0.0.1:8787`. Valida a presença
de `index.html`, `flutter_bootstrap.js` e `main.dart.js` antes da readiness.
`/__qa/health` responde somente após iniciar o servidor. O `webServer` do
[Playwright](https://playwright.dev/docs/test-webserver) espera até 30 segundos,
não reutiliza servidor preexistente e encerra o processo com SIGTERM (limite de
cinco segundos). O servidor fecha conexões em SIGTERM/SIGINT; não há processo em
background iniciado manualmente ou URL configurável para produção.

- Catálogo e pesquisa: `/rest/v1/exams` e `/rest/v1/questions` retornam fixtures
  sintéticas de `fixtures.mjs`. Não há proxy nem chamada a Supabase real.
- Prova privada: fixture de três questões inserida no `localStorage` do contexto
  descartável, no formato real de `shared_preferences_web`. Não injeta respostas,
  draft, resultado, sessão ou token. Nunca sobrescreve progresso no reload.
- Interações e retomada passam pelas telas reais. A fixture privada tem gabarito
  para validar correção offline sem RPC; não se apresenta como prova oficial.
- Servidor recusa métodos de escrita (405) e endpoints não implementados. Não há
  criação de conta, publicação nem sincronização real de tentativas.
- Browser bloqueia toda origem externa e WebSockets. Nenhum `service_role`, cookie
  de autenticação ou credencial de produção é necessário.

### Fluxos programados e estado real

**Nenhum teste de produto em browser foi executado nesta sessão.** `PASS` abaixo
aplica-se somente às verificações de infraestrutura efetivamente executadas.
As linhas da etapa 2 continuam sendo uma matriz histórica de cobertura escrita.

| Fluxo/verificação | Estado | Evidência ou limite |
| --- | --- | --- |
| Servidor: ausência de build, readiness, arquivos/MIME, fixtures, isolamento de escrita e symlink | PASS | `node --test qa/browser/infra.test.mjs`: 2/2 |
| Descoberta da suíte Playwright e sintaxe JS | PASS | `npm run list` e `node --check`; não iniciam Chromium |
| Smoke HTTP → Flutter → onboarding → visitante → Home | NOT RUN | Programado nos três viewports, valida semantics e estado utilizável |
| Navegação Início/Explorar/Publicar/Biblioteca/Perfil e reload | NOT RUN | Programado nos três viewports |
| Pesquisa com resultado, consulta vazia/sem resultado e abertura | NOT RUN | Catálogo local, mobile 390×844 |
| Login contextual ao salvar prova pública | NOT RUN | Abre formulário e fecha; não autentica |
| Prova privada: responder, trocar resposta, avançar/voltar, marcar, sair/retomar | NOT RUN | Mobile 390×844, estado DOM/ARIA e persistência local |
| Reload durante tentativa e retomada explícita na Biblioteca | NOT RUN | Confere questão atual, seleção, marcação e ID/payload persistido |
| Offline real: continuar, navegar e finalizar localmente | NOT RUN | `context.setOffline(true)` + `navigator.onLine` e fetch local que deve falhar |
| Revisão pré-entrega, branco/marcada, resultado e revisão | NOT RUN | Uma correta, uma errada e uma em branco: 1/3, 33%, marcada=1 |
| Reconectar, reload e reabrir resultado do histórico | NOT RUN | Resultado salvo, uma conclusão, nenhuma fila para prova privada |
| Robustez: três ciclos anterior/próxima, mudança de alternativa, modal e duplo clique de entrega | NOT RUN | Sequência curta sem sleeps fixos; verifica ausência de duplicação local |
| Responsividade 360×640, 390×844 e 1366×768 | NOT RUN | Smoke/navegação; viewport, overflow DOM e diagnósticos Flutter |
| Semântica e foco básico de teclado no desktop | NOT RUN | Botões/campos com nomes acessíveis, seleção ARIA e Tab |
| Dark mode via preferência do sistema | NOT RUN | `emulateMedia({colorScheme:'dark'})` no desktop e navegação; não existe seletor de tema no app |
| Reload totalmente offline | BLOCKED | Service workers desabilitados para isolamento; não se afirma suporte PWA offline |
| Sincronização/idempotência com servidor real | BLOCKED | Backend QA real não configurado; simulação Dart pertence à etapa 2 |
| Explicação das respostas | BLOCKED | Modelo atual não oferece `explanation` |
| Detecção completa de truncamento/contraste e auditoria de acessibilidade | PARTIAL | Asserções de controles/estado + screenshots; não é auditoria WCAG ou comparação visual automática |

Há nove combinações descobertas: três smoke, três busca e três P0; os testes de
busca/P0 são intencionalmente pulados fora de 390×844. Portanto cinco execuções
ativas e quatro skips de matriz. `retries: 0` impede que uma falha seja escondida
por repetição; `forbidOnly: true` impede publicação acidental de suíte reduzida.

### Semantics e mudanças no aplicativo

Nenhum arquivo do aplicativo foi alterado. A automação ativa o botão invisível
[Enable accessibility do Flutter](https://docs.flutter.dev/ui/accessibility/web-accessibility)
para obter o DOM semântico. Depois usa labels/textos existentes, como “Continuar”,
“Explorar sem conta”, “Fazer prova”, “Marcar para revisão” e “Revisar entrega”.
Não usa coordenadas fixas nem screenshots como critério único. Se o DOM semântico
produzido pelo SDK não expuser os contratos esperados, o teste falha para revisão;
não há fallback que marque PASS sem interação.

### Offline, console e evidências

Offline real é distinto do catálogo fictício: o catálogo é um servidor HTTP local,
e a perda de rede é aplicada ao contexto Chromium. A prova privada em andamento
continua usando dados carregados. Não recarrega offline; após restaurar rede,
recarrega e abre o resultado persistido. Esse cenário não comprova sincronização
remota e não a substitui pelos mocks da etapa 2.

Todos os testes capturam console, page errors, crash, respostas HTTP >=400,
requests falhas e tentativas de acesso externo. `console.error`, exceções e
mensagens de assertion/overflow Flutter falham a suíte. Warnings são registrados.
A única falha de rede esperada é o GET de prova de offline em `/__qa/health`
enquanto o contexto está explicitamente offline; sua mensagem específica
`ERR_INTERNET_DISCONNECTED` é classificada separadamente. Outros erros continuam
fatais, inclusive durante offline. Favicon opcional responde 204 no servidor.

Artifacts de `qa-full`: `artifacts/browser/**`, contendo:

- `runner.log`: stdout/stderr do runner, incluindo ciclo de vida do servidor;
- `html/`: relatório navegável;
- `report.json` e `junit.xml`: resultados estruturados;
- `results/`: screenshots e anexos `console.json` por teste;
- screenshots de startup, Home em cada viewport, login contextual, prova,
  retomada após reload, revisão offline, resultado restaurado e desktop dark;
- screenshot automática de falha, inclusive quando erros de console são
  detectados no encerramento do teste.

Não grava HAR, trace, vídeo, headers, storageState nem dump de localStorage.
Logs de console passam por redação de tokens, senhas e parâmetros de URLs.
Screenshots contêm somente fixtures e navegação visitante, sem login real.

### Comandos CI e timeouts

Após build Web e antes do APK debug:

```sh
cd qa/browser
timeout --kill-after=15s 300s npm ci --ignore-scripts --no-audit --no-fund --fetch-timeout=30000 --fetch-retries=1
timeout --kill-after=15s 600s npx --no-install playwright install --with-deps --only-shell chromium
timeout --kill-after=15s 60s npm run test:infra
```

O passo seguinte executa `timeout --kill-after=15s 900s npm test` e captura saída
com `tee`; guarda `${PIPESTATUS[0]}` e retorna o mesmo código. Não usa
`ignore_failure`, `|| true` ou warnings para mascarar falhas. O runner limita a
suíte a 12 minutos, cada teste a dois minutos, navegação a 30 segundos e ações/
asserções a 15 segundos. APK debug só roda após sucesso. Artifacts são coletados
pelo Codemagic mesmo quando o teste falha, desde que tenham sido produzidos.
O limite global do workflow permanece 60 minutos.

### Validação local e pendências reais

Flutter/Dart ausentes e `build/web` inexistente: compilação e todos os fluxos do
produto em Chromium estão **NOT RUN**. Não foi baixado SDK Flutter nem utilizado
site publicado como substituto. Instalação npm isolada, testes do servidor,
descoberta Playwright, sintaxe JS/YAML/shell e `git diff --check` foram verificados.
A execução no Codemagic ainda é necessária para validar o build, instalação de
Chromium, seletores efetivos do renderer e os cenários de produto.

Riscos observados por leitura, ainda sem reprodução em navegador: onboarding com
preview fixo de 230 px pode não caber em 360×640; textos/cores fixos podem limitar
dark mode; fontes externas podem ser solicitadas mesmo com renderer local.
Não foram registrados como bugs reproduzidos nem corrigidos nesta etapa. Falhas
reais devem preservar o relatório e ser tratadas em lote posterior.

## Etapa 4 — tortura, recuperação e idempotência (2026-09-26)

**Não há aprovação do P0 nesta execução. Baseline do produto: BLOCKED.**
Checkout inicial `ee4df9f`, branch `p0-validation-diagnostics`; após fetch,
`HEAD...origin/main = 8 0`. Os caminhos não rastreados preexistentes
`CODEX_QA_COMPLETO_PROVA_SOCIAL.md` e `docs/qa/` foram preservados.
Nenhum arquivo de `lib/`, migration ou workflow de distribuição foi alterado.
Não houve deploy, publicação, commit, push, tag, login externo ou acesso ao banco
remoto. Somente fixtures sintéticas e armazenamento descartável de QA.

### Baseline e ambiente efetivamente observado

- Node **24.18.1**, npm **11.12.1**, cliente PostgreSQL **17.11**, PGlite **0.5.8**
  (PostgreSQL WASM **18.3**). CI continua configurado com Node 22.
- Smoke da Etapa 3 tentado: `npm test -- --project=mobile --grep '^smoke'`.
  O servidor abortou por `ENOENT build/web/`, antes de iniciar o navegador.
  **Não foi possível confirmar inicialização nem início de tentativa local.**
- `dart format`, `flutter analyze` e `flutter test` tentados: executáveis ausentes.
  Não foi instalado SDK grande nem usado o site publicado como substituto.
- `sh scripts/local_db_test.sh` tentou preparar o banco nativo, mas o guard
  detectou cluster incompleto em `/tmp/prova_social_postgres_5433`, sem
  `global/pg_control`. Cluster preservado; nenhuma migration nativa executada.
- `node scripts/qa_concurrency.mjs` também parou na conexão ao socket ausente,
  antes de qualquer cenário. Isso **não é falha de concorrência do produto**.
- PGlite executou migrations/fixtures/testes existentes em memória e passou.
  A omissão de `CREATE EXTENSION pgcrypto` e o Auth simulado permanecem limites.

### Matriz de tortura — resultados reais, não contagem de testes escritos

`PASS` exige execução de asserções. `BLOCKED` identifica impedimento do ambiente;
`NOT RUN` identifica cenário não executado; `PARTIAL` limita a evidência ao recorte
explicitamente descrito. Ausência de FAIL reproduzido não significa aprovação.

| CENÁRIO | CAMADA | RESULTADO | EVIDÊNCIA | OBSERVAÇÃO |
| --- | --- | --- | --- | --- |
| Baseline: iniciar app e tentativa | Browser | BLOCKED | `artifacts/qa-stage4/baseline-browser.log` | Sem build Web/Flutter; tortura browser não iniciada |
| Infraestrutura de servidor isolado | Node | PASS | `infra.log`, 2/2 | Não comprova inicialização Flutter |
| Reload A: iniciar | Browser | BLOCKED | `torture reload A-start` escrito | Snapshot e quantidade de tentativas; draft ainda pode não existir antes de interação |
| Reload B: resposta imediata | Browser | BLOCKED | `torture reload B-immediate-answer` escrito | Sem polling de storage entre toque e reload |
| Reload C: duas respostas | Browser | BLOCKED | `torture reload C-two-answers` escrito | Respostas, índice, ID, snapshot e seleção |
| Reload D: revisão | Browser | BLOCKED | `torture reload D-review` escrito | Marcar/desmarcar/marcar, reload e estado final |
| Reload E: intermediária | Browser | BLOCKED | `torture reload E-middle` escrito | Índice contratualmente persistido |
| Reload F: confirmação | Browser | BLOCKED | `torture reload F-confirmation` escrito | Sem entrega/resultado/duplicação antes de confirmar |
| Fechar página e reabrir | Browser | BLOCKED | `torture close page...` escrito | Fecha Page, cria outra no mesmo BrowserContext; storage preservado |
| Nova aba simultânea / novo BrowserContext persistente | Browser | NOT RUN | Sem automação nova para esses dois recortes | Novo contexto descartável não compartilha storage por padrão; não equivale a reabrir perfil |
| Offline durante respostas | Browser + widget | BLOCKED | Etapa 3 + `quiz_offline_submission_test.dart` | Rede real bloqueada no browser; Dart usa submitter fake |
| Online/offline quatro transições | Browser | BLOCKED | `torture rapid...` escrito | Respostas, navegação e estado final; não comprova servidor real |
| Finalização offline e resultado antes de limpar draft | Widget + browser | BLOCKED | Testes existentes + `quiz_torture_test.dart` | Privada: resultado local; pública: payload pendente, sem inventar correção |
| Morte antes de finalizar | Browser | BLOCKED | Reload F programado | Não simula morte do processo do SO |
| Morte entre entrega durável e remoção do draft | Widget | BLOCKED | `reinício entre entrega durável e remoção` | Captura bytes no callback do fake; recria stores para resultado local e fila pública |
| Morte antes/durante sync | Dart | BLOCKED | `reinício com sending=...` | Estado durável pending/sending; sem hooks no produto |
| Aceite remoto antes de persistência local/UI | Dart | BLOCKED | `morte após aceite remoto mantém fila` | Escrita de completed falha; restaura bytes sending; retry usa mesmo ID |
| Timeout antes de aceite e retry | HTTP fake + Dart | BLOCKED | `attempt_repository_test.dart` ampliado | Duas chamadas, mesmo corpo e endpoint; sucesso posterior |
| Resposta perdida após aceite | Dart + SQL | PARTIAL | Teste HTTP existente; `pglite.log` | Cliente não executado; deduplicação SQL sequencial passou |
| Duplo finalizar / dois enqueues / retry | Browser + Dart | BLOCKED | `torture close page...`, `dois enqueues rápidos...` | Clique duplo físico; simultaneidade Dart não é concorrência PostgreSQL |
| Respostas rápidas | Browser + Dart | BLOCKED | `torture rapid...`, teste de gravações ordenadas existente | Fixture browser tem duas opções: A→B→A→B; última seleção válida é o oráculo |
| Navegação agressiva | Browser | BLOCKED | `torture rapid...` | Próxima/próxima/anterior/próxima/anterior/anterior com respostas distintas |
| Todas/primeira/última/alternadas em branco | Widget | BLOCKED | Quatro casos em `quiz_torture_test.dart` | Confirmação, contagens, resultado e ausência de NaN/Infinity |
| Sem gabarito | Widget + domínio | BLOCKED | Regressão nova + `exam_result_test.dart` | Risco estático E4-03 abaixo; não tratado como PASS |
| Prova vazia / uma questão | Widget + domínio | BLOCKED | Nova recusa explícita de prova vazia; casos de recuperação com uma questão | Resultado vazio também coberto anteriormente |
| Alternativa mínima / texto longo | UI | NOT RUN | Sem cenário novo | Não houve fuzzing nem certificação desses limites |
| Snapshot A com catálogo B | Browser + widget | BLOCKED | `torture rapid...` + retomada existente | Altera somente catálogo QA; retoma enunciado original e respostas |
| Payload congelado após mutação local | Dart | BLOCKED | `resposta perdida, mutação local e retry preservam payload` | Muta respostas/opções/fonte após enqueue; compara ID, respostas, revisão, tempo e questão |
| RequiresAttention e retry explícito | Dart | BLOCKED | Testes existentes em `attempt_sync_service_test.dart` | Item preservado, sem retry automático, sem novo ID |
| PGRST202 retryable sem fallback legado | HTTP fake + Dart | BLOCKED | Classificação existente + novo retry com sucesso | Mesmo endpoint/corpo/clientAttemptId |
| Mesmo ID, respostas conflitantes (público) | SQL | PASS | `pglite.log`, `attempt_idempotency.sql` | SQLSTATE 22023; sem sobrescrever nem criar duplicata |
| Mesmo ID, respostas conflitantes (cliente) | Dart | BLOCKED | Testes existentes e nova regressão local | Risco E4-01 para `completeLocal` |
| Mesmo ID, snapshot conflitante | Dart | BLOCKED | Nova regressão `mesmo ID com snapshot diferente...` | Risco E4-02; não aceitar silêncio como sucesso |
| Migrations, visitante, vínculo posterior, RLS, grants, rollback | SQL em memória | PASS | `pglite.log` | Quatro migrations; schema descartável; Auth simulado |
| Concorrência A: payload igual | PostgreSQL nativo | BLOCKED | `postgres.log`, `concurrency.log` | Script novo exige observar lock real entre duas sessões |
| Concorrência B: payload diferente | PostgreSQL nativo | BLOCKED | Mesmos logs | Espera 22023, uma tentativa e resposta original |
| Concorrência C: vínculo incompatível | PostgreSQL nativo | BLOCKED | Mesmos logs | Espera 42501; primeiro proprietário preservado |
| Draft ausente / campo opcional ausente | Dart | BLOCKED | Novos testes de storage + compatibilidade v1 existente | Não exige recuperação arbitrária de dados inválidos |
| JSON inválido / fila incompleta | Dart | BLOCKED | `attempt_torture_test.dart` | Exige erro e preservação dos bytes/outros dados; não comprova UI de recuperação |
| Storage cheio/falha de escrita | Dart + widget | BLOCKED | Fakes de storage existentes + BoundaryStorage novo | Indicador failed, flush/retry e draft mantido quando enqueue falha |
| Troca visitante/A/B no armazenamento local | Cliente | PARTIAL | Leitura das chaves em `attempt_draft_store.dart` e `attempt_sync_service.dart` | Sem isolamento por conta demonstrado; RLS SQL não comprova isolamento local |
| Reload e fechar/reabrir após resultado | Browser | BLOCKED | Etapa 3 + `torture close page...` | Reabre Biblioteca/histórico, mesmo ID e uma conclusão |
| Smoke visual posterior 390×844 | Browser | BLOCKED | `post-torture smoke...` programado | Home/prova/resultado; não é auditoria visual completa |
| Três repetições críticas | Dart + browser | NOT RUN | `sh scripts/qa_stress.sh` | Baseline bloqueado; modo manual, sem aumentar build padrão |
| Site existente | Node | PASS | `site.log`, 3/3 | Simulador/fallback/contraste; não substitui Flutter |
| Sintaxe JS/shell, descoberta e configuração CI | Infraestrutura | PASS | `syntax.log`, `config.log`, `discovery.log` | Descoberta de 36 combinações não é execução de 36 testes |
| Formatação Dart / analyze / flutter test | Flutter | BLOCKED | `format.log`, `analyze.log`, `flutter-test.log` | Comandos tentados, executáveis ausentes |
| Diff sem whitespace inválido | Git | PASS | `diff-check.log` | Não valida sintaxe Dart nem runtime |

### Riscos encontrados e regressões que devem manter o gate vermelho

Nenhuma perda de resposta ou duplicação foi **reproduzida em runtime do app**
neste ambiente. A análise estática revelou os seguintes candidatos; os testes
novos exigem o comportamento correto, sem `skip`, `expectFailure` ou ajuste para
aceitar o defeito. **Espera-se que essas regressões falhem no código atual**,
mas essa expectativa não é um FAIL executado e não substitui o primeiro run Flutter.

- **E4-01 — P0, possível sobrescrita de resultado local:** `completeLocal` atribui
  diretamente `completed[clientAttemptId]` sem comparar resultado anterior.
  A regressão envia duas respostas distintas para o mesmo ID e exige conflito
  explícito e preservação da original. Ainda não há evidência de que a UI normal
  consiga produzir esse caso; o double click possui guarda `finishing`.
- **E4-02 — conflito de snapshot não sinalizado:** `_sameSubmission` compara ID
  da prova, respostas, revisão e duração, mas não o snapshot nem `finishedAt`.
  A regressão altera a questão mantendo ID/índices e exige rejeição explícita.
  A fila conserva o primeiro payload pelo código atual, portanto não se afirma
  mutação no retry; o risco é reportar aceitação de conteúdo incompatível.
- **E4-03 — percentual sem gabarito:** `ResultPage` sempre renderiza
  `scorePercent`, mesmo quando nenhuma questão é corrigível. O teste exige
  “Gabarito indisponível” e ausência de percentual inventado. O domínio já evita
  incluir essa resposta em `wrongQuestionIndices`. Problema de semântica de
  correção, não perda de respostas.
- **Isolamento local entre contas — risco P0 pendente:** chaves de draft e fila
  são por prova/dispositivo, sem escopo de usuário; não existe prova nesta bateria
  de isolamento visitante/A/B. Não houve login externo ou promessa de suporte.
- Corrupção local pode impedir leitura da fila inteira. Os testes exigem não
  apagar bytes e não bloquear a fila de operações após restaurar a fixture;
  não certificam recuperação automática nem UX de reparo.

Nenhuma correção de produto foi feita. O próximo lote deve primeiro executar
Flutter em ambiente compatível e reproduzir esses candidatos; correções ficam
fora desta Etapa 4.

### Execução padrão, stress e concorrência nativa

`qa-full` descobre automaticamente os novos arquivos Dart e `torture.spec.mjs`.
São **9 cenários browser novos**, somente em 390×844. Com os anteriores: 36
combinações descobertas, 14 execuções previstas e 22 skips de viewport. `retries: 0`,
limite global de 12 minutos e timeouts existentes foram mantidos. Cada falha
crítica executada retorna código não zero, inclusive as regressões de perda/
conflito acima. O log Flutter agora usa `tee` com retorno de `PIPESTATUS[0]` e é
coletado em artifacts; não há conversão de erro em warning.

Stress **manual local**, com build isolado e dependências da Etapa 3 preparados:

```sh
sh scripts/qa_stress.sh
```

O script executa primeiro smoke + fluxo privado existente. Só após aprovação
repete três vezes draft/retry/tortura Dart, depois três vezes um subconjunto
browser de resposta rápida, reload imediato e duplo finalizar/reabertura.
Artifacts repetidos ficam em `artifacts/browser/stress/`, separados do baseline.
Não foi criado workflow `qa-stress`; não há triggers nem deploy. Essa separação
mantém uma execução padrão no Codemagic e repetições fora do build obrigatório.

Concorrência nativa manual, somente no cluster descartável já definido em scripts:

```sh
sh scripts/local_db_test.sh
# Executar o próximo comando somente se o anterior passou.
node scripts/qa_concurrency.mjs
```

O primeiro comando já contém o teste concorrente A antigo e recria somente
`prova_social_test`. O novo runner exige o socket/porta/database/data_directory
fixos, fixture presente e IDs de teste ainda ausentes; recusa reutilizar dados.
Usa duas sessões `psql`, mantém a primeira transação aberta, observa a segunda
com `wait_event_type = 'Lock'` e só então confirma a primeira. Verifica IDs,
SQLSTATE, proprietário, quantidade de linhas e resposta original em A/B/C.
Timeouts de statement/lock/barreira impedem espera indefinida. Não conecta por
URL configurável nem executa migrations; a terceira conexão apenas observa.
PGlite não é fallback para declarar concorrência PASS.

### Evidências, duração e limitações finais

Artifacts locais desta execução estão em `artifacts/qa-stage4/` (ignorados pelo
Git): baseline-browser, infra, site, pglite, postgres, concurrency, discovery,
config, syntax, format, analyze, flutter-test, diff-check e `summary.json`.
Os logs registram cenário/resultado e o resumo registra timestamp. O Playwright
também produziu relatórios de runner em `artifacts/browser/`; não há screenshots
ou trace de produto porque nenhum browser iniciou. Trace permanece desligado,
conforme política de evidências da Etapa 3. Logs de páginas adicionais agora são
capturados e recebem timestamp; continuam redigidos, sem dump de storage,
credenciais, cookies ou dados pessoais.

Tempos observados: servidor Node **2,42 s**, site **0,52 s**, descoberta Playwright
**8,51 s**, validação de configuração **2,66 s**. PGlite passou, mas não teve duração
isolada registrada. Não há tempo medido da bateria Flutter/browser/nativa e não
se estima aprovação por orçamento. O custo extra do CI é nove fluxos mobile e
21 casos Dart novos; depende de medição na primeira execução. Repetições e SQL
nativo ficam manuais; limite do workflow continua 60 minutos.

`dart format` não pôde normalizar os testes novos: o gate oficial continua
obrigatório e pode exigir ajustes quando houver SDK. Não houve build APK/Web,
auditoria visual real ou verificação de rede/reconexão no aplicativo. A Etapa 5
não foi iniciada.

## Etapas 5 e 6 — integração local e gate consolidado

**Situação: implementação preparada; execução integral e fechamento BLOCKED.**
A escolha do responsável foi **Supabase local descartável**, sem projeto remoto.
O trabalho da Etapa 4 e os arquivos não rastreados anteriores foram preservados.
Nenhum arquivo de produto em `lib/`, migration, versão ou workflow de publicação
foi alterado nestas etapas. Não houve acesso ao Supabase de produção, commit,
push, deploy, release ou execução remota do Codemagic.

### Integração real preparada (Etapa 5)

`qa/integration/run.mjs` cria um diretório temporário e um `project_id` aleatório
por execução. Copia somente as migrations versionadas para esse projeto novo.
Recusa Docker remoto e portas locais ocupadas; não reutiliza nem reseta uma
instalação existente. A URL permitida é exatamente `http://127.0.0.1:54321`.
Não há parâmetro de URL remota, `link`, `db push`, `db reset` ou chave privilegiada
em nenhum cliente de teste.

Supabase CLI **2.118.0**, PGlite **0.5.8** e YAML **2.8.1** são dependências apenas
de QA, com lockfile em `qa/integration/`. O CLI foi executado com `--help` para
confirmar `start`, `status`, `stop`, `init` e `--workdir`. A configuração foi
comparada com `supabase init` dessa versão: o SMTP local usa `[local_smtp]`.
`status` leu a configuração preparada, mas parou na ausência de Docker/Podman.
As [instruções oficiais do CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
confirmam a necessidade de container runtime; não foi instalado Docker dentro
deste ambiente Termux/proot.

O stack deve executar Postgres 17, Auth e PostgREST reais. Confirmação de e-mail
fica desabilitada **somente no config temporário**, permitindo contas sintéticas
`@example.test` sem SMTP externo. Signup/login geram os JWTs: nenhum `auth.uid()`
falso, service key ou JWT forjado participa da integração real. O PGlite e seus
mocks anteriores continuam em etapa separada e nunca são apresentados como Auth
real.

`api.mjs` programa: cadastro, login válido/inválido, trigger de perfil, refresh,
logout, recusa de publicação por visitante, rollback de publicação inválida,
publicação autenticada, busca pública, gabarito inacessível, prova/questão privada
invisível a visitante/B, tentativa de edição por B, favoritos isolados, entrega
visitante, retry, vínculo posterior por A, recusa de vínculo por B, conflito de
payload e bloqueio de alteração direta da nota. Cada request usa somente chave
pública e a sessão do usuário correspondente. **Estes cenários não executaram
neste ambiente**, porque o stack não pôde iniciar.

`live.spec.mjs` programa duas integrações pela UI real:

1. Visitante importa JSON pelo seletor de arquivo → revisa → salva privado →
   login contextual → cancela a primeira confirmação → confirma publicação →
   pesquisa → resolve parcialmente → finaliza offline → observa fila durável →
   reconecta → sincroniza → compara tentativa/respostas no backend → reload e
   resultado na Biblioteca. Login sozinho nunca deve publicar a cópia privada.
2. Visitante conclui uma tentativa pública online → entra em conta → a mesma
   tentativa deve aparecer no histórico remoto da conta, com o mesmo ID.
   O teste não faz a RPC de vínculo em nome da UI para esconder suporte ausente.

O segundo cenário registra um **candidato a bug P0 ainda não reproduzido**:
`HomePage` chama `syncDue()` após Auth, mas o serviço percorre somente pendentes;
resultados já concluídos como visitante aparentemente não são vinculados após
login. Uma RPC de vínculo que funciona isoladamente não certifica esse fluxo.
Os candidatos E4-01/02/03 continuam sem correção ou reprodução Flutter.

O JSON sintético exercita importação, editor e publicação existentes. Isso não
valida PDF/OCR, imagens nem a prova real de 80 questões. OAuth Google, confirmação
por e-mail externo e deep links de distribuição continuam **NOT RUN/BLOCKED**;
não se apresenta auto-confirmação local como evidência desses contratos.

### Isolamento, cleanup e artifacts

- Antes de iniciar, valida daemon Docker por socket Unix e portas desocupadas.
- Remove variáveis Supabase/PG herdadas do processo dos comandos locais.
- `status` do CLI permanece em memória; somente URL e chave pública validadas são
  gravadas em arquivo temporário modo 0600. Saída bruta de start/status/stop não
  entra nos artifacts, pois pode conter segredos locais.
- Browser permite somente origem do app e API loopback; não usa proxy para
  produção. Não grava trace, HAR, storageState, cookies, senha ou token.
- Credenciais sintéticas ficam em memória; falhas de preenchimento de login têm
  mensagem substituída para não anexar senha ao call log. Screenshots são
  suspensos enquanto o formulário de Auth estiver ativo.
- `finally` executa `stop --project-id <ID gerado> --no-backup` exclusivamente
  naquele projeto. Nunca usa `--all`. Só remove o próprio diretório temporário
  depois de cleanup bem-sucedido. Interrupção normal cancela o comando atual e
  permite cleanup; SIGKILL/encerramento forçado da VM não pode garantir `finally`.
- A integração escreve `artifacts/integration/report.json` e logs sanitizados.
  Falha de cleanup também impede aprovação. Uma falha de prerequisite não cria
  PASS fictício para API/browser.

### Gate consolidado (Etapa 6)

`qa-full` agora executa `node qa/gate/full.mjs`, reutilizando testes, servidor,
fixtures e Playwright existentes. Nenhum workflow de distribuição foi modificado.
Continua manual, sem grupos de segredos ou seção `publishing`, em `linux_x2`,
Ubuntu 24.04, Node 22, Java 17, Flutter stable e limite de 60 minutos.
A [imagem Linux documentada pelo Codemagic](https://docs.codemagic.io/specs-linux/ubuntu-24.04/)
lista Docker; disponibilidade do daemon e billing ainda precisam de comprovação
na execução da conta. A documentação não é evidência de job executado.

O runner registra início/resultado/duração por etapa, mantém `INCOMPLETE` até
terminar e consolida `PASS`, `FAIL` ou `BLOCKED`. Retornos: **0 PASS, 1 FAIL,
2 BLOCKED**. Ambos os últimos falham o job. Uma falha de formatação não suprime
coleta de testes independentes; no final, FAIL tem precedência sobre BLOCKED.
Não há `ignore_failure` ou substituição de erro por warning. Exit 2 de uma
ferramenta genérica continua FAIL; apenas o subrunner de integração usa o contrato
explícito de BLOCKED.

Etapas obrigatórias: dependências QA fixadas, guards, SDK, pub, format, analyze,
Flutter tests, site, SQL em memória, plataformas ausentes, ícones Android/Web,
build Web isolado, infraestrutura browser, Chromium, browser real e validação de
seu relatório, APK debug, inspeção de artefatos, integração Supabase local e diff.
Os builds da integração ficam em `build/qa-live`; o build de fixtures em `build/web`
é preservado. Preparação copia somente plataformas ausentes e usa geradores de
marca existentes. APK/Web são artifacts de QA, sem distribuição.

Relatórios Playwright devem comprovar pelo menos 14 execuções da matriz existente
e duas da integração, sem runner errors, falhas ou testes flaky. `--list`, todos
skipped ou sucesso após retry não aprovam o gate. Retries permanecem zero. Isso
previne mascaramento de flakiness, mas **não prova que a UI está livre de flakiness**:
ainda não houve execução real neste ambiente. Stress da Etapa 4 continua manual.

A inspeção Web/APK verifica estrutura, marca, assets e hashes. Não instala o APK,
não comprova comportamento Android, assinatura de distribuição ou OAuth. O
relatório distingue aprovação automatizada de autorização de publicação e lista
pendências manuais, incluindo concorrência PostgreSQL A/B/C. O runner nativo da
Etapa 4 permanece disponível, mas não foi adaptado para o container Supabase;
PGlite não substitui essa prova. **Fechamento/release gate continua bloqueado.**
Os workflows de publicação existentes ainda não dependem automaticamente de um
resultado deste job; encadeá-los requer um lote explícito após validar o gate.

### Matriz executada destas etapas

| CENÁRIO | CAMADA | RESULTADO | EVIDÊNCIA | OBSERVAÇÃO |
| --- | --- | --- | --- | --- |
| Recusa de URL remota e chave privilegiada | Node | PASS | `guards-final.log` | Guards executados com entradas sintéticas |
| Falha/timeout preservados; BLOCKED não vira aprovação | Node | PASS | Mesmo log | Subprocessos de teste falham intencionalmente; asserções do runner passam |
| Redação de segredos e separação stdout/stderr | Node | PASS | Mesmo log | Material artificial; nenhuma credencial real gravada |
| Cancelamento permite somente cleanup posterior | Node | PASS | Mesmo log | Não equivale a matar um stack Docker real |
| Gate manual e demais workflows preservados | YAML/Node | PASS | Guard compara contra HEAD | Sem execução Codemagic |
| CLI instalado, comandos e config inspecionados | CLI | PARTIAL | `cli-help.log`, `config-init.log`, `config-parse.log` | Config chega à dependência ausente; stack não iniciou |
| Auth real, visitante/conta, RLS, RPC, visibilidade | Supabase local | BLOCKED | `artifacts/integration/report.json` | Docker/Podman ausentes |
| Importação JSON → publicação → offline → sync | Browser real | BLOCKED | Mesmo relatório; `live-discovery.log` | Dois testes descobertos; zero testes UI executados |
| Vínculo automático de resultado visitante após login | Browser real | BLOCKED | Regressão escrita | Candidato estático; não atribuir PASS da RPC à UI |
| PDF/OCR/80 questões e imagens | Produto | NOT RUN | Fora do recorte implementado | Sem certificação de importação completa |
| OAuth Google / confirmação externa / deep links | Auth/dispositivos | NOT RUN | Sem provider/runner externo | Auto-confirmação local não valida isso |
| SQL sequencial, site e infraestrutura browser | Node/PGlite | PASS | `artifacts/qa-full/*.log` | Reexecutados pelo gate; limites anteriores preservados |
| Format/analyze/Flutter tests/Web/APK | Flutter | BLOCKED | `artifacts/qa-full/report.json` | SDK ausente; nenhum build produzido |
| Responsividade/a11y e flakiness do produto | Browser/Android | BLOCKED | Matriz anterior reutilizada | Sem evidência visual nova ou Android runtime |
| Concorrência PostgreSQL nativa | Banco | BLOCKED | Etapa 4 | Não substituída por requests paralelos |
| Gate consolidado local | Orquestração | BLOCKED | `full-run-final.log`, `qa-full/report.json` | O código não zero impede falsa aprovação |
| Job completo no Codemagic | CI remoto | NOT RUN | Sem acesso/job configurado nesta sessão | Alterações locais não foram commitadas/enviadas |

### Como reproduzir e o que falta para fechar

Com Node 22+, Flutter compatível, Android SDK, Python 3 e Docker local, na raiz:

```sh
node qa/gate/full.mjs
```

Esse comando instala dependências de QA com `npm ci --ignore-scripts`, executa
as etapas e retorna o estado final. Ele não instala Flutter nem Docker.
Para inspecionar só os guards (após instalar as dependências QA):

```sh
node --test qa/integration/guards.test.mjs
```

Para integração isolada, após `flutter pub get`, plataformas/ícones e Playwright
preparados, executar `node qa/integration/run.mjs`. Nenhuma URL/credencial remota
é aceita. O pacote não integra dependências ao aplicativo Flutter.

Faltam: executar o checkout completo em runner compatível/Codemagic, reproduzir e
corrigir os FAIL reais encontrados, medir duração/flakiness, validar concorrência
nativa e APK em dispositivo, validar Auth/deep links de distribuição e só então
aprovar um gate de publicação. Nenhum desses itens foi declarado concluído.
Artifacts e arquivos novos são revisáveis localmente; as Etapas 5/6 não estão
fechadas apenas porque seus testes foram escritos.

Execução consolidada final local: **22 etapas, 7 PASS, 0 FAIL e 15 BLOCKED**;
aproximadamente **62,8 segundos** somados nos subprocessos. Os guards tiveram
**10/10 PASS**, além de site 3/3, servidor 2/2 e SQL sequencial aprovado. Esse tempo
não estima builds, downloads de imagens Docker ou UI, que não executaram.
Resultado/exit code do runner: **BLOCKED / 2**. Os artifacts da execução final
estão em `artifacts/qa-full/`, `artifacts/integration/` e `artifacts/qa-stage56/`.

### Correções autorizadas e execução remota de diagnóstico

Após autorização explícita para corrigir e fazer push, foram aplicadas correções
localizadas: `completeLocal` congela o resultado antes de aguardar escrita e
rejeita reutilização conflitante do ID; enqueue compara snapshot e instante da
finalização, permitindo apenas a inclusão legítima do gabarito no resultado do
servidor; a tela sem gabarito deixa de apresentar percentual/acertos inventados.
Os testes correspondentes continuam pendentes de execução Flutter, não PASS.

`.github/workflows/qa-diagnostics.yml` executa o mesmo runner `qa-full` em Ubuntu
na branch `p0-validation-diagnostics`, com permissões somente de leitura,
Supabase local descartável e sem publicação. O workflow preserva relatórios e
patch de formatação mesmo em falha; produzir o patch não aprova o format check.
Esta execução complementa o Codemagic, não comprova execução no Codemagic.
Vínculo automático de resultado visitante já sincronizado e isolamento entre
contas permanecem pendentes de validação/correção; não há aprovação de release.

O vínculo de novas entregas de visitante foi implementado em seguida: o resultado
concluído conserva a submissão original congelada; após login, essa submissão
entra na fila com a mesma identidade, preservando o resultado durante o vínculo.
A fila registra a conta e não envia uma pendência de A usando a sessão de B.
Dois testes Dart cobrem o vínculo único/payload original e a troca de conta.
Resultados legados sem payload original não são reconstruídos automaticamente.
Isso não resolve por si só o isolamento visual de todo armazenamento local.
Validação Flutter/remota ainda pendente nesta revisão.

O workflow de diagnóstico inclui também um job de PostgreSQL nativo descartável,
com duas sessões e barreira de lock observada para concorrência A/B/C. O helper
existente passa a localizar os binários também no layout Debian/Ubuntu.
A inclusão do job não é evidência de execução: seu relatório é separado.
Há três regressões Dart para vínculo, interrupção do vínculo e troca de conta.

### Evidência remota coletada durante as correções

- GitHub Actions `36266704802`, revisão `39aabc4`: SDK Flutter 3.47.5 /
  Dart 3.13.4, dependências e analyze PASS; format FAIL. Execução cancelada ao
  substituir a revisão, portanto bateria INCOMPLETE e testes Flutter NOT RUN
  até conclusão verificável. Patch do formatter coletado e aplicado.
- GitHub Actions `36267187458`, revisão `8a3166f`: migrations, testes SQL nativos,
  RLS/rollback e teste concorrente do helper existente passaram. A bateria
  adicional A/B/C foi BLOCKED por permissão do socket para o usuário runner;
  corrigida a execução para o mesmo usuário autorizado do banco descartável.
- O runner agora mantém checkpoints dos logs redigidos durante comandos longos.
  Testes Flutter usam timeout individual de dois minutos: timeout continua FAIL.

Links de evidência: https://github.com/NAGCODE-Dev/Prova-Social/actions/runs/36266704802
 e https://github.com/NAGCODE-Dev/Prova-Social/actions/runs/36267187458 .

Execução `36267421345`, revisão `04ea170`: format e analyze PASS; os três
cenários de concorrência A/B/C PASS em duas conexões reais com lock observado.
A bateria Flutter produziu falhas reais (14 até o checkpoint), não aprovação:
respostas de MockClient sem `request` causavam erro no parser PostgREST; testes
de widget seguintes ficavam aguardando o Future global associado ao teste
anterior. A execução foi interrompida para diagnóstico e os logs preservados em
`artifacts/qa-stage56/remote-third/full/qa-full/flutter-tests.log`.
Correções: adicionar request aos mocks HTTP e liberar as caudas globais quando
ociosas, mantendo a serialização das operações ainda ativas. Revalidação pendente.

A proteção de duração da etapa Flutter passa a três minutos para a bateria
unitária/widget atual; estourar o limite é FAIL, com o log intermediário
preservado. O timeout individual continua em dois minutos. Essa proteção impede
que um teste travado consuma dez minutos antes das demais verificações.
O resultado concluído também fica acessível enquanto um vínculo offline aguarda
retry, sem remover a pendência nem apresentar o vínculo como concluído.
Os testes de respostas inválidas/RPC agora verificam a causa específica, evitando
falso PASS provocado por uma exceção genérica do mock.

Revisão `e113067` (run `36268017205`): 91 testes Flutter PASS, quatro testes de
busca FAIL por mocks HTTP sem request, e um teste de inicialização com progresso
não terminou. O Web compilou em 69 s. Os testes browser falharam no baseline:
semântica Flutter agrupava os textos e o roteiro local omitia o botão “Começar
prova”. As falhas posteriores de tortura não comprovam falhas do produto.
Correções incrementais: liberar a fila ociosa de LocalExamStore, completar os
mocks de busca, procurar texto acessível agrupado e seguir a página da prova.
O browser agora para na primeira falha. Integração real e APK aguardam sucesso
unitário/widget e browser, evitando builds caros enquanto o baseline está falho.

### Diagnóstico remoto de 0e1b0c3 — 2026-09-26

Execução GitHub Actions `36269304811`: format/analyze, SQL descartável e build Web PASS; Flutter 101 PASS / 5 FAIL em 35 s; browser 1 PASS / 13 FAIL. Integração Supabase e APK BLOCKED por pré-requisitos. O baseline ainda não está aprovado. Evidência local: `artifacts/qa-stage56/remote-sixth/full/`.

Causas reproduzidas: decoração opaca da sidebar oculta pintura de ListTile; overflow de 12 px após perfil em 320 px (diagnóstico detalhado acrescentado); cliques de widget fora do viewport; enunciado selecionável sem rótulo acessível visível no browser; download automático de Noto Sans Symbols bloqueado no ambiente offline. Correções deste lote: sidebar usa Ink, enunciado ganha semanticsLabel, testes rolam antes do toque, fonte SIL OFL é incluída localmente com licença. Roteiros de finalização agora navegam à última questão. O limite de uma falha browser foi efetivamente acrescentado ao comando do gate. Estas correções aguardam nova execução; testes Node locais: 12 PASS, sintaxe e diff check PASS.

### Diagnóstico remoto de 3876484 — 2026-09-26

Execução `36270101469`: 105 testes Flutter PASS / 1 FAIL (18 s de testes; baseline completo ~3,5 min). Sidebar, editor e publicação contextual passaram. Browser: 3 PASS / 1 FAIL, demais não executados após primeira falha. Fonte local removeu as requisições externas dos smokes executados. O último overflow foi localizado no BrandLockup da tela Auth em 320 px; aplicado FittedBox como nos demais cabeçalhos. A resposta foi persistida, mas `selected` em Semantics com papel button não expôs estado no browser; acrescentado `toggled` para estado pressionado acessível. Integração real recebe a mesma correção de navegação até a última questão; formatter remoto aplicado. Nova revisão ainda requer execução.

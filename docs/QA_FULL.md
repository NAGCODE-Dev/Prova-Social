# QA completo — infraestrutura e cobertura P0

## Objetivo e regra de publicação

Reunir os testes e gates de compilação em um workflow independente. A etapa 1
preparou a infraestrutura; a etapa 2 amplia somente a cobertura Dart/Flutter P0,
sem refactor do aplicativo. **`qa-full` nunca publica produto.**
Não faz deploy, upload Cloudflare, commit, push, tag, GitHub Release ou migration
remota; não importa grupos de segredos, assinatura de produção ou credenciais.
Os builds não são distribuídos nem listados como artefatos deste workflow.

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

Por fim, somente compilação, sem configurações de produção:

```sh
flutter build web --release --no-pub
flutter build apk --debug --no-pub
```

Falhas encerram o passo com código não zero e interrompem o workflow. Não há
`ignore_failure`, `|| true`, pipeline de logs ou pós-processamento que substitua
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

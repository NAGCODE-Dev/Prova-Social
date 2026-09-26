# QA completo — etapa 1: infraestrutura

## Objetivo e regra de publicação

Reunir os testes existentes e gates de compilação em um workflow independente,
sem novos testes de produto ou refactor. **`qa-full` nunca publica produto.**
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

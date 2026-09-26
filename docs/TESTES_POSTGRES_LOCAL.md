# PostgreSQL local para testes

Este ambiente usa PostgreSQL 17 instalado pelo Alpine, sem Docker e sem conexão
com serviços remotos. O cluster exclusivo fica em
`/tmp/prova_social_postgres_5433`, usa a porta `5433` e contém somente o banco
descartável `prova_social_test`.

## Dependências

```sh
apk add --no-cache postgresql17 postgresql17-client postgresql17-contrib
```

## Uso

```sh
./scripts/local_db_start.sh
./scripts/local_db_test.sh
./scripts/local_db_stop.sh
```

`local_db_test.sh` recria exclusivamente `prova_social_test`, aplica todos os
arquivos de `supabase/migrations` em ordem lexical e executa os testes de
idempotência, concorrência, visitante, autenticação, RLS, permissões e rollback.
Qualquer erro encerra o script com status diferente de zero.

Os scripts nunca removem o diretório do cluster. Para evitar atingir outra
instalação, nome do banco, porta e caminho são constantes e verificados antes de
operações destrutivas.

## Limitações

O bootstrap local cria somente roles `anon` e `authenticated`, uma tabela mínima
`auth.users` e um mock de `auth.uid()`. O mock confia no parâmetro de sessão
`request.jwt.claim.sub` controlado pelos testes. Ele não valida JWT, não executa
GoTrue ou PostgREST e não reproduz toda a segurança ou configuração do Supabase.

Passar localmente comprova o comportamento PostgreSQL das migrations neste
fixture. Antes da aplicação remota ainda são necessárias revisão da migration,
execução em ambiente isolado compatível com Supabase e validação dos advisors.


## Alternativa em memória para Termux/PRoot

Quando `initdb` não funciona, há um runner opcional, sem acesso remoto e sem
alterar o cluster existente:

```sh
npm install --prefix /tmp/prova-p0-pglite --ignore-scripts --no-audit --no-fund --save-exact @electric-sql/pglite@0.5.8
node scripts/pglite_test.mjs /tmp/prova-p0-pglite/node_modules/@electric-sql/pglite/dist/index.js
```

Executado em 26/09/2026: aprovado no PostgreSQL 18.3/PGlite 0.5.8. Executa todas as
quatro migrations locais atuais e o fixture SQL sequencial: retry autenticado, visitante,
vínculo posterior, RLS de proprietário, grants e rollback preservando linhas.

Limitações explícitas: o Supabase implantado usa PostgreSQL 17; o PGlite tem
uma única conexão; não valida corrida entre sessões, JWT, GoTrue ou PostgREST.
`CREATE EXTENSION pgcrypto` é a única instrução de migration omitida porque a
extensão não é distribuída pelo PGlite. A função usada pelo schema,
`pg_catalog.gen_random_uuid()`, é nativa e é exercitada pelo runner. As demais
instruções e asserções SQL são executadas sem substituição por mocks.

O runner não é substituto do teste nativo de concorrência nem autorização para
implantar migrations. A dependência é instalada fora do repositório e não faz
parte do aplicativo. Documentação: [PGlite](https://pglite.dev/docs/).


## Verificação da compatibilidade implantada

Os runners agora reproduzem o schema legado usando
`supabase/tests/legacy_attempt_schema.sql` (somente banco descartável), antes
da migration corretiva. Também verificam bloqueio de escrita direta e RPC antiga.
`supabase/tests/deployed_attempt_smoke.sql` é um smoke test autorizado separado:
usa um perfil existente, cria fixtures dentro de uma transação e sempre termina
com rollback quando aprovado. Foi executado no projeto remoto em 26/09/2026;
nenhum usuário Auth foi criado e nenhuma fixture permaneceu no banco.

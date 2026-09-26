#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cluster_root=/tmp/prova_social_postgres_5433
socket_dir="$cluster_root/socket"
port=5433
database=prova_social_test
admin_uri="host=$socket_dir port=$port user=postgres"
test_uri="$admin_uri dbname=$database"

if [ "$database" != prova_social_test ] ||
   [ "$cluster_root" != /tmp/prova_social_postgres_5433 ] ||
   [ "$port" -ne 5433 ]; then
  echo "Configuração de segurança inesperada; teste recusado." >&2
  exit 1
fi

"$repo_dir/scripts/local_db_start.sh"

# DROP DATABASE is fixed to the dedicated test name. No data directory is ever
# removed by this script.
psql "$admin_uri dbname=postgres" -v ON_ERROR_STOP=1 <<'SQL'
select pg_terminate_backend(pid)
from pg_stat_activity
where datname = 'prova_social_test' and pid <> pg_backend_pid();
drop database if exists prova_social_test;
create database prova_social_test;
SQL

psql "$admin_uri dbname=postgres" -v ON_ERROR_STOP=1 <<'SQL'
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end
$$;
SQL

# Minimal local Supabase compatibility. This is deliberately not an Auth/JWT
# emulator: auth.uid() trusts a session setting controlled by these tests.
psql "$test_uri" -v ON_ERROR_STOP=1 <<'SQL'
create schema auth;
create table auth.users (
  id uuid primary key,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
create function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
revoke all on schema auth from public, anon, authenticated;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
SQL

for migration in "$repo_dir"/supabase/migrations/*.sql; do
  echo "Aplicando $(basename "$migration")"
  psql "$test_uri" -v ON_ERROR_STOP=1 -f "$migration"
  if [ "$(basename "$migration")" = 202609210001_core.sql ]; then
    psql "$test_uri" -v ON_ERROR_STOP=1 \
      -f "$repo_dir/supabase/tests/legacy_attempt_schema.sql"
  fi
done

echo "Executando testes SQL sequenciais, RLS e rollback"
psql "$test_uri" -v ON_ERROR_STOP=1 \
  -f "$repo_dir/supabase/tests/attempt_idempotency.sql"

echo "Executando teste concorrente em duas sessões"
concurrent_id=33333333-3333-4333-8333-333333333333
result_a="$cluster_root/concurrent_a.txt"
result_b="$cluster_root/concurrent_b.txt"
rm -f "$result_a" "$result_b"

psql "$test_uri" -Atq -v ON_ERROR_STOP=1 >"$result_a" <<SQL &
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
select public.submit_exam_attempt(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
  '{}'::uuid[], 45, '$concurrent_id'
) ->> 'attempt_id';
select pg_sleep(2);
commit;
SQL
pid_a=$!
sleep 1
psql "$test_uri" -Atq -v ON_ERROR_STOP=1 >"$result_b" <<SQL &
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false);
select public.submit_exam_attempt(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
  '{}'::uuid[], 45, '$concurrent_id'
) ->> 'attempt_id';
SQL
pid_b=$!
wait "$pid_a"
wait "$pid_b"

id_a=$(sed -n '2p' "$result_a")
id_b=$(sed -n '2p' "$result_b")
if [ -z "$id_a" ] || [ "$id_a" != "$id_b" ]; then
  echo "Falha: chamadas concorrentes retornaram tentativas diferentes." >&2
  exit 1
fi

psql "$test_uri" -v ON_ERROR_STOP=1 <<SQL
do \$\$
begin
  if (select count(*) from public.attempts
      where client_attempt_id = '$concurrent_id') <> 1 then
    raise exception 'concurrent delivery created duplicate attempts';
  end if;
  if (select count(*) from public.attempt_answers aa
      join public.attempts a on a.id = aa.attempt_id
      where a.client_attempt_id = '$concurrent_id') <> 1 then
    raise exception 'concurrent delivery created duplicate answers';
  end if;
end
\$\$;
SQL

rm -f "$result_a" "$result_b"
echo "Todos os testes PostgreSQL locais passaram."

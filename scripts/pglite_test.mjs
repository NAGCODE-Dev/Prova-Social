// Optional in-memory SQL verification for hosts unable to start PostgreSQL.
// Usage: node scripts/pglite_test.mjs /absolute/path/to/pglite/dist/index.js
// This does not connect to any remote database or exercise concurrent sessions.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const modulePath = process.argv[2];
if (!modulePath) {
  throw new Error('Informe o caminho do módulo PGlite instalado fora do app.');
}
const { PGlite } = await import(pathToFileURL(resolve(modulePath)).href);
const root = fileURLToPath(new URL('../', import.meta.url));
const db = new PGlite();
try {
  console.log((await db.query('select version() as version')).rows[0].version);
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create table auth.users (
      id uuid primary key,
      raw_user_meta_data jsonb not null default '{}'::jsonb
    );
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    $$;
    revoke all on schema auth from public, anon, authenticated;
    grant usage on schema auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
  `);
  // PGlite does not ship pgcrypto. These migrations use only gen_random_uuid,
  // which PostgreSQL also supplies in pg_catalog. No SQL function is mocked.
  const uuid = (await db.query('select pg_catalog.gen_random_uuid() as id')).rows[0].id;
  assert.match(uuid, /^[0-9a-f-]{36}$/);
  const migrationDir = resolve(root, 'supabase/migrations');
  for (const name of (await readdir(migrationDir)).filter(n => n.endsWith('.sql')).sort()) {
    let sql = await readFile(resolve(migrationDir, name), 'utf8');
    const extension = 'create extension if not exists pgcrypto;';
    if (sql.includes(extension)) {
      assert.equal(name, '202609210001_core.sql');
      sql = sql.replace(extension, '-- pgcrypto unavailable in PGlite; native UUID verified.');
      console.log('LIMITAÇÃO: somente CREATE EXTENSION pgcrypto omitido.');
    }
    await db.exec(sql);
    console.log(`Migration executada: ${name}`);
    if (name === '202609210001_core.sql') {
      await db.exec(await readFile(resolve(root, 'supabase/tests/legacy_attempt_schema.sql'), 'utf8'));
      console.log('Fixture: NOT NULL e grants legados reproduzidos.');
    }
  }
  let sql = await readFile(resolve(root, 'supabase/tests/attempt_idempotency.sql'), 'utf8');
  sql = sql.replace(/^\\set ON_ERROR_STOP on\s*$/m, '');
  assert.doesNotMatch(sql, /^\\/m, 'Comando psql não suportado');
  // Separate simple-query messages commit the fixture before the explicit
  // rollback test; otherwise a single implicit transaction could erase it.
  const marker = '-- Rollback recipe';
  const split = sql.indexOf(marker);
  assert.ok(split > 0, 'Seção de rollback esperada');
  await db.exec(sql.slice(0, split));
  await db.exec(sql.slice(split));
  const rows = (await db.query('select count(*)::int as total from public.attempts')).rows;
  assert.equal(rows[0].total, 2, 'Rollback preserva tentativas');
  await db.exec(await readFile(resolve(root, 'supabase/tests/deployed_attempt_smoke.sql'), 'utf8'));
  assert.equal((await db.query('select count(*)::int as total from public.attempts')).rows[0].total, 2);
  console.log('PASS: smoke test transacional, RPC legada e bloqueio de escrita direta.');
  console.log('PASS: retries sequenciais, visitante, vínculo autenticado, RLS, grants e rollback.');
  console.log('NÃO TESTADO: concorrência entre conexões, pgcrypto, Auth/JWT e Supabase remoto.');
} finally {
  await db.close();
}

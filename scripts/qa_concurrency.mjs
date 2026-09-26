// Native PostgreSQL ONLY, after local_db_test.sh. No configurable host/URL.
// Two sessions must overlap on an observed database lock, not Promise.all alone.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const connection = 'host=/tmp/prova_social_postgres_5433/socket port=5433 user=postgres dbname=prova_social_test';
function session(name) {
  const child = spawn('psql', [connection, '-X', '-Atq', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose'], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, PGAPPNAME: name, PGOPTIONS: '-c statement_timeout=15000 -c lock_timeout=12000' },
  });
  let output = '', error = '';
  child.stdout.on('data', bytes => { output += bytes; });
  child.stderr.on('data', bytes => { error += bytes; });
  child.stdin.on('error', () => {}); // Exit status/stderr remain the assertion.
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => resolve({ code, output, error }));
  });
  return { child, done, output: () => output };
}
async function query(sql) {
  const s = session('qa-stage4-observer');
  s.child.stdin.end(sql + '\n');
  const result = await s.done;
  assert.equal(result.code, 0, result.error);
  return result.output.trim();
}
async function until(check, message) {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    if (await check()) return;
    await delay(50);
  }
  throw new Error(message);
}
const exam = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const question = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const rpc = (id, answer) => `select public.submit_exam_attempt('${exam}',
  jsonb_build_object('${question}', ${answer}), '{}'::uuid[], 45, '${id}') ->> 'attempt_id';`;
const auth = user => `set role authenticated; select set_config('request.jwt.claim.sub', '${user}', false);`;

assert.equal(await query('select current_database();'), 'prova_social_test');
assert.equal(await query('show data_directory;'), '/tmp/prova_social_postgres_5433/data');
assert.equal(await query(`select count(*) from public.exams where id = '${exam}';`), '1', 'Run local_db_test.sh first');
for (const [name, id, differentPayload, claim] of [
  ['A-same', '44444444-4444-4444-8444-444444444444', false, false],
  ['B-conflict', '55555555-5555-4555-8555-555555555555', true, false],
  ['C-claim', '66666666-6666-4666-8666-666666666666', false, true],
]) {
  assert.equal(await query(`select count(*) from public.attempts where client_attempt_id = '${id}';`), '0',
    'Use a freshly recreated disposable test database; do not delete rows to hide prior results');
  if (claim) await query(`set role anon; ${rpc(id, 1)}`);
  const first = session(`qa-stage4-${name}-first`);
  let second;
  try {
    // Hold first transaction open after RPC, without arbitrary pg_sleep.
    first.child.stdin.write(`begin; ${auth(userA)} ${rpc(id, 1)}\n\\echo QA_HELD\n`);
    await until(() => first.output().includes('QA_HELD'), 'First RPC did not reach transaction barrier');
    second = session(`qa-stage4-${name}-second`);
    second.child.stdin.end(`${auth(claim ? userB : userA)} ${rpc(id, differentPayload ? 0 : 1)}\n`);
    await until(async () => (await query(`select count(*) from pg_stat_activity
      where datname = 'prova_social_test' and application_name = 'qa-stage4-${name}-second'
      and wait_event_type = 'Lock';`)) === '1', 'No overlapping database lock observed');
    first.child.stdin.end('commit;\n');
    const a = await first.done;
    const b = await second.done;
    assert.equal(a.code, 0, a.error);
    if (differentPayload || claim) {
      assert.notEqual(b.code, 0, 'Conflicting request must fail');
      assert.match(b.error, new RegExp(differentPayload ? '22023' : '42501'));
    } else {
      assert.equal(b.code, 0, b.error);
      const uuid = /[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/g;
      const idsA = a.output.match(uuid), idsB = b.output.match(uuid);
      assert.equal(idsA?.length, 2, 'Expected user ID and attempt ID from first session');
      assert.equal(idsB?.length, 2, 'Expected user ID and attempt ID from second session');
      assert.equal(idsA[1], idsB[1]);
    }
    assert.equal(await query(`select count(*) from public.attempts where client_attempt_id = '${id}';`), '1');
    assert.equal(await query(`select user_id from public.attempts where client_attempt_id = '${id}';`), userA);
    assert.equal(await query(`select count(*) from public.attempt_answers aa join public.attempts a on a.id=aa.attempt_id
      where a.client_attempt_id='${id}' and aa.selected_index=1;`), '1');
    console.log(`PASS ${name}: two native sessions, lock overlap observed, one attempt, original answer/owner preserved`);
  } finally {
    first.child.kill('SIGTERM');
    second?.child.kill('SIGTERM');
    await first.done;
    if (second) await second.done;
  }
}

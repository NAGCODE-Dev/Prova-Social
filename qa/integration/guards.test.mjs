import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import YAML from 'yaml';
import { fileURLToPath } from 'node:url';
const repo = fileURLToPath(new URL('../../', import.meta.url));
import { validateConfig, localUrl } from './client.mjs';
import { decision, Runner } from '../gate/runner.mjs';
import { validateBrowserReport } from '../gate/browser-report.mjs';
import { redact } from '../browser/harness-redaction.mjs';

const publicJwt = `header.${Buffer.from(JSON.stringify({ role: 'anon' })).toString('base64url')}.signature`;
const config = { apiUrl: 'http://127.0.0.1:54321', anonKey: publicJwt, runId: 'qa-11111111-1111-4111-8111-111111111111' };
test('integration refuses every non-exact loopback target', () => {
  validateConfig(config);
  for (const url of ['https://project.supabase.co', 'http://localhost:54321', 'http://127.0.0.1:54321/evil',
    'http://127.0.0.1.evil.test:54321', 'http://127.0.0.1:54321@evil.test', 'http://127.0.0.1:8787']) {
    assert.throws(() => validateConfig({ ...config, apiUrl: url }));
  }
});
test('privileged keys and arbitrary API paths are rejected', () => {
  for (const key of ['sb_secret_qa', `header.${Buffer.from('{"role":"service_role"}').toString('base64url')}.signature`, 'invalid']) {
    assert.throws(() => validateConfig({ ...config, anonKey: key }));
  }
  for (const path of ['https://production.test/rest/v1/exams', '//evil.test/rest/v1/exams', '/rest/v1/../../../admin', '/admin']) {
    assert.throws(() => localUrl(path));
  }
  assert.equal(localUrl('/rest/v1/exams').origin, config.apiUrl);
});
test('missing, BLOCKED, PARTIAL and NOT RUN cannot become gate PASS', () => {
  for (const state of ['BLOCKED', 'PARTIAL', 'NOT RUN', 'INCOMPLETE']) {
    assert.equal(decision([{ id: 'a', result: state }], ['a']), 'BLOCKED');
  }
  assert.equal(decision([], ['missing']), 'BLOCKED');
  assert.equal(decision([{ id: 'a', result: 'FAIL' }], ['a', 'missing']), 'FAIL');
  assert.equal(decision([{ id: 'a', result: 'PASS' }], ['a']), 'PASS');
});
test('discovery, skipped matrix and flaky retries do not certify browser', () => {
  assert.throws(() => validateBrowserReport({}, 2));
  assert.throws(() => validateBrowserReport({ stats: { expected: 1, unexpected: 0, flaky: 0 } }, 2));
  assert.throws(() => validateBrowserReport({ stats: { expected: 2, unexpected: 0, flaky: 1 } }, 2));
  assert.throws(() => validateBrowserReport({ stats: { expected: 2, unexpected: 1, flaky: 0 } }, 2));
  validateBrowserReport({ stats: { expected: 2, unexpected: 0, flaky: 0 }, errors: [] }, 2);
});
test('runner preserves nonzero status, distinguishes unavailable tool and hides sensitive output', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'qa-runner-test-'));
  try {
    const runner = new Runner(dir);
    assert.equal((await runner.command('exit-two', process.execPath, ['-e', 'process.exit(2)'])).ok, false);
    assert.equal(runner.stages[0].result, 'FAIL', 'Generic exit 2 is a failure, not infrastructure BLOCKED');
    await runner.command('absent', '/qa-tool-does-not-exist', []);
    assert.equal(runner.stages[1].result, 'BLOCKED');
    await runner.command('sensitive', process.execPath, ['-e', 'console.log("QA_FAKE_SECRET")'], { sensitive: true });
    assert.doesNotMatch(await readFile(join(dir, 'sensitive.log'), 'utf8'), /QA_FAKE_SECRET/);
    assert.equal(await runner.finish(['exit-two', 'absent', 'sensitive']), 1);
    assert.equal(JSON.parse(await readFile(join(dir, 'report.json'), 'utf8')).result, 'FAIL');
  } finally { await rm(dir, { recursive: true, force: true }); }
});
test('runner timeout fails and returns boundedly', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'qa-timeout-test-'));
  try {
    const runner = new Runner(dir);
    await runner.command('timeout', process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { timeoutMs: 100 });
    assert.equal(runner.stages[0].result, 'FAIL');
    assert.equal(runner.stages[0].reason, 'timeout');
  } finally { await rm(dir, { recursive: true, force: true }); }
});
test('redaction hides auth material in console diagnostics', () => {
  const output = redact('Authorization: Bearer QA_FAKE_SECRET password=QA_PASSWORD https://local.test?token=QA_QUERY eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.abcdefghijklmnop');
  for (const value of ['QA_FAKE_SECRET', 'QA_PASSWORD', 'QA_QUERY', 'eyJhbGci']) assert.ok(!output.includes(value));
});
test('qa-full is manual, has no publishing or secret groups, and leaves other workflows intact', async () => {
  const yaml = await readFile(join(repo, 'codemagic.yaml'), 'utf8');
  const config = YAML.parse(yaml);
  const previous = YAML.parse(spawnSync('git', ['show', 'HEAD:codemagic.yaml'], { encoding: 'utf8', cwd: repo }).stdout);
  for (const [name, value] of Object.entries(previous.workflows)) {
    if (name !== 'qa-full') assert.deepEqual(config.workflows[name], value);
  }
  const qa = config.workflows['qa-full'];
  assert.equal(qa.triggering, undefined); assert.equal(qa.publishing, undefined);
  assert.equal(qa.environment.groups, undefined);
  assert.match(qa.scripts[0].script, /node qa\/gate\/full\.mjs/);
  assert.doesNotMatch(qa.scripts[0].script, /\|\| true|ignore_failure|wrangler|gh release/);
});
test('CLI JSON remains parseable when diagnostics are on stderr', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'qa-stream-test-'));
  try {
    const runner = new Runner(dir);
    const result = await runner.command('streams', process.execPath,
      ['-e', 'console.error("diagnostic"); console.log(JSON.stringify({ ok: true }))'], { sensitive: true });
    assert.deepEqual(JSON.parse(result.stdout), { ok: true });
    assert.match(result.stderr, /diagnostic/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
test('cancelled runner blocks new work but permits scoped cleanup', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'qa-cancel-test-'));
  try {
    const runner = new Runner(dir);
    runner.cancel();
    const work = await runner.command('work', '/qa-tool-must-never-run', []);
    assert.equal(work.ok, false);
    assert.equal(runner.stages[0].reason, 'Run cancelled');
    const cleanup = await runner.command('cleanup', process.execPath, ['-e', 'process.exit(0)'], { allowAfterCancel: true });
    assert.equal(cleanup.ok, true);
    assert.equal(await runner.finish(['work', 'cleanup']), 2);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

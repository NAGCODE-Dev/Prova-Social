import { mkdtemp, mkdir, readFile, writeFile, readdir, copyFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import net from 'node:net';
import { Runner } from '../gate/runner.mjs';
import { validateConfig } from './client.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const runner = new Runner(join(root, 'artifacts/integration'));
const required = ['docker-local', 'ports-free', 'supabase-start', 'local-config', 'api', 'live-build', 'live-browser', 'live-evidence', 'cleanup'];
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => runner.cancel());
const cli = join(root, 'qa/integration/node_modules/.bin/supabase');
const runId = `qa-${randomUUID()}`;
let directory, started = false;
// No inherited remote Supabase credentials, Docker context overrides or token log.
const env = { ...process.env, DO_NOT_TRACK: '1', SUPABASE_TELEMETRY_DISABLED: '1' };
for (const key of Object.keys(env)) {
  if (/^(SUPABASE_|PG)/.test(key) && key !== 'SUPABASE_TELEMETRY_DISABLED') delete env[key];
}
async function free(port) {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => server.close(resolve));
  });
}
try {
  const context = await runner.command('docker-context', 'docker', ['context', 'inspect', '--format', '{{.Endpoints.docker.Host}}'], { env });
  if (!context.ok) throw new Error('BLOCKED: Docker runtime unavailable');
  if (!context.stdout.trim().startsWith('unix://') || (env.DOCKER_HOST && !env.DOCKER_HOST.startsWith('unix://'))) {
    throw new Error('BLOCKED: a local Unix-socket Docker daemon is required');
  }
  const docker = await runner.command('docker-local', 'docker', ['info', '--format', '{{.ServerVersion}}'], { env });
  if (!docker.ok) throw new Error('BLOCKED: local Docker not running');
  for (const port of [54320, 54321, 54322, 8787]) await free(port);
  await runner.record('ports-free', 'PASS', 'Reserved loopback ports unused; no existing stack reused');
  directory = await mkdtemp(join(tmpdir(), 'prova-social-qa-'));
  await mkdir(join(directory, 'supabase/migrations'), { recursive: true });
  const template = await readFile(join(root, 'qa/integration/local.config.toml'), 'utf8');
  await writeFile(join(directory, 'supabase/config.toml'), template.replace('QA_PROJECT_ID', runId));
  for (const name of (await readdir(join(root, 'supabase/migrations'))).filter(n => n.endsWith('.sql'))) {
    await copyFile(join(root, 'supabase/migrations', name), join(directory, 'supabase/migrations', name));
  }
  // Fresh project has no link metadata; start applies only copied local migrations.
  started = true;
  const start = await runner.command('supabase-start', cli, ['start', '--workdir', directory], { env, timeoutMs: 600000, sensitive: true });
  if (!start.ok) throw new Error('Local stack startup failed; no live integration evidence');
  const status = await runner.command('supabase-status', cli, ['status', '--workdir', directory, '-o', 'json'], { env, sensitive: true });
  if (!status.ok) throw new Error('Local status unavailable');
  const values = JSON.parse(status.stdout);
  const config = validateConfig({ runId, apiUrl: values.API_URL ?? values.api?.url,
    anonKey: values.ANON_KEY ?? values.PUBLISHABLE_KEY ?? values.api?.anon_key ?? values.api?.publishable_key });
  const path = join(directory, 'public-config.json');
  await writeFile(path, JSON.stringify(config), { mode: 0o600 });
  env.QA_LOCAL_CONFIG = path;
  await runner.record('local-config', 'PASS', 'Exact loopback origin and public key validated');
  await runner.command('api', 'node', ['qa/integration/api.mjs'], { cwd: root, env, timeoutMs: 180000 });
  const build = await runner.command('live-build', 'flutter', ['build', 'web', '--debug', '--no-pub', '--no-web-resources-cdn', '--output=build/qa-live',
    `--dart-define=SUPABASE_URL=${config.apiUrl}`, `--dart-define=SUPABASE_PUBLISHABLE_KEY=${config.anonKey}`,
    '--dart-define=WEB_AUTH_CALLBACK=http://127.0.0.1:8787/'], { cwd: root, env, timeoutMs: 600000 });
  if (build.ok) {
    const browser = await runner.command('live-browser', 'node', ['qa/browser/node_modules/@playwright/test/cli.js', 'test', '--config=qa/integration/playwright.config.mjs'],
      { cwd: root, env, timeoutMs: 600000 });
    if (browser.ok) await runner.command('live-evidence', 'node', ['qa/gate/browser-report.mjs', 'artifacts/integration/browser/report.json', '2'], { cwd: root, env });
  }
} catch (error) {
  // Never include raw CLI output/status/config; may contain service keys.
  await runner.record('integration-error', runner.cancelled || error.message.startsWith('BLOCKED:') || error.code === 'EADDRINUSE' ? 'BLOCKED' : 'FAIL',
    error.code === 'EADDRINUSE' ? 'QA ports occupied; existing services preserved' :
      runner.cancelled ? 'Integration cancelled; scoped cleanup follows' :
      error.message.startsWith('BLOCKED:') ? 'Local Docker prerequisite unavailable or unsafe' :
      'Local integration failed; inspect stage results. Raw CLI/config errors withheld');
} finally {
  if (started) {
    const cleanup = await runner.command('cleanup', cli, ['stop', '--workdir', directory, '--project-id', runId, '--no-backup'],
      { env, sensitive: true, timeoutMs: 120000, allowAfterCancel: true });
    if (cleanup.ok) await rm(directory, { recursive: true, force: true });
  } else {
    await runner.record('cleanup', 'PASS', 'No stack was created');
  }
  for (const id of required) {
    if (!runner.stages.some(s => s.id === id)) await runner.record(id, 'BLOCKED', 'Prerequisite unavailable');
  }
  process.exitCode = await runner.finish([...required, ...(runner.stages.some(s => s.id === 'integration-error') ? ['integration-error'] : [])],
    { scope: 'Local disposable Supabase only; no remote projects', runId });
}

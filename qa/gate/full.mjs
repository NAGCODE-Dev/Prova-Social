import { resolve } from 'node:path';
import { Runner } from './runner.mjs';
import { spawnSync } from 'node:child_process';
const runner = new Runner(resolve('artifacts/qa-full'));
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => runner.cancel());
const required = ['qa-deps', 'guards', 'flutter-version', 'pub', 'format', 'analyze', 'flutter-tests', 'site', 'sql',
  'platforms', 'android-icons', 'web-icons', 'web-build', 'browser-deps', 'browser-infra', 'chromium', 'browser', 'browser-evidence',
  'apk-build', 'build-inspection', 'integration', 'diff'];
async function step(id, command, args, deps = [], options = {}) {
  const missing = deps.filter(dep => !runner.stages.some(s => s.id === dep && s.result === 'PASS'));
  if (missing.length) return runner.record(id, 'BLOCKED', `Prerequisites: ${missing.join(', ')}`);
  return (await runner.command(id, command, args, options)).ok;
}
try {
  await step('qa-deps', 'npm', ['ci', '--prefix', 'qa/integration', '--ignore-scripts', '--no-audit', '--no-fund', '--fetch-timeout=30000', '--fetch-retries=1']);
  await step('guards', 'node', ['--test', 'qa/integration/guards.test.mjs'], ['qa-deps']);
  await step('flutter-version', 'flutter', ['--version']);
  await step('pub', 'flutter', ['pub', 'get'], ['flutter-version']);
  // Collect independent failures; formatting failure does not suppress test evidence.
  await step('format', 'dart', ['format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool'], ['flutter-version']);
  await step('analyze', 'flutter', ['analyze'], ['pub']);
  await step('flutter-tests', 'flutter', ['test', '--reporter', 'expanded', '--timeout=2m'], ['pub'], { timeoutMs: 180000 });
  await step('site', 'node', ['--test', 'site/tests/site.test.cjs']);
  await step('sql', 'node', ['scripts/pglite_test.mjs', resolve('qa/integration/node_modules/@electric-sql/pglite/dist/index.js')], ['qa-deps']);
  await step('platforms', 'node', ['qa/gate/prepare.mjs'], ['pub']);
  await step('android-icons', 'dart', ['run', 'flutter_launcher_icons'], ['platforms']);
  await step('web-icons', 'dart', ['run', 'tool/generate_web_icons.dart'], ['platforms']);
  await step('web-build', 'flutter', ['build', 'web', '--debug', '--no-pub', '--no-web-resources-cdn',
    '--dart-define=SUPABASE_URL=http://127.0.0.1:8787', '--dart-define=SUPABASE_PUBLISHABLE_KEY=qa-public-placeholder',
    '--dart-define=WEB_AUTH_CALLBACK=http://127.0.0.1:8787/'], ['web-icons'], { timeoutMs: 600000 });
  await step('browser-deps', 'npm', ['ci', '--prefix', 'qa/browser', '--ignore-scripts', '--no-audit', '--no-fund', '--fetch-timeout=30000', '--fetch-retries=1']);
  await step('browser-infra', 'node', ['--test', 'qa/browser/infra.test.mjs'], ['browser-deps']);
  const playwright = 'qa/browser/node_modules/@playwright/test/cli.js';
  await step('chromium', 'node', [playwright, 'install', '--with-deps', '--only-shell', 'chromium'], ['browser-deps', 'web-build'], { timeoutMs: 600000 });
  await step('browser', 'node', [playwright, 'test', '--config=qa/browser/playwright.config.mjs', '--max-failures=1'], ['chromium', 'web-build'], { timeoutMs: 900000 });
  await step('browser-evidence', 'node', ['qa/gate/browser-report.mjs', 'artifacts/browser/report.json', '14'], ['browser']);
  // The integration runner records its own BLOCKED cause (e.g. missing Docker).
  await step('integration', 'node', ['qa/integration/run.mjs'], ['qa-deps', 'guards', 'flutter-tests', 'browser'], { timeoutMs: 1500000, blockedExitCodes: [2], killGraceMs: 130000 });
  await step('apk-build', 'flutter', ['build', 'apk', '--debug', '--no-pub', '--dart-define=SUPABASE_URL=http://127.0.0.1:54321',
    '--dart-define=SUPABASE_PUBLISHABLE_KEY=qa-public-placeholder'], ['android-icons', 'flutter-tests', 'browser'], { timeoutMs: 600000 });
  await step('build-inspection', 'python3', ['qa/gate/artifacts.py'], ['web-build', 'apk-build']);
  await step('diff', 'git', ['diff', '--check']);
} catch {
  await runner.record('runner-error', 'FAIL', 'Unexpected runner error; inspect individual stage logs');
  required.push('runner-error');
} finally {
  for (const id of required) if (!runner.stages.some(s => s.id === id)) await runner.record(id, 'BLOCKED', 'Runner interrupted before stage');
  const gitSha = spawnSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout?.trim();
  const dirty = Boolean(spawnSync('git', ['status', '--porcelain'], { encoding: 'utf8' }).stdout?.trim());
  process.exitCode = await runner.finish(required, {
    gitSha, dirty, scope: 'automated QA only', publicationAuthorized: false,
    releaseReadiness: 'BLOCKED until manual release evidence is supplied',
    manualReleaseChecks: ['Native PostgreSQL concurrency A/B/C', 'Android device runtime and signed release', 'OAuth/deep links with intended distribution configuration'],
  });
}

import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
export function validateBrowserReport(report, minimum) {
  assert.ok(report.stats, 'Execution stats required, discovery alone is not evidence');
  assert.equal(report.stats.unexpected, 0, 'Browser failure');
  assert.equal(report.stats.flaky, 0, 'Flaky success is not gate approval');
  assert.ok(report.stats.expected >= minimum, 'Mandatory cases were not executed');
  assert.equal((report.errors ?? []).length, 0, 'Runner/setup error');
}
if (process.argv[1]?.endsWith('browser-report.mjs')) {
  validateBrowserReport(JSON.parse(await readFile(process.argv[2], 'utf8')), Number(process.argv[3]));
  console.log('PASS actual browser executions, no unexpected errors or flaky retries');
}

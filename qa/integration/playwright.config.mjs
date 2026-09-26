import { defineConfig } from '../browser/node_modules/@playwright/test/index.mjs';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../../', import.meta.url));
export default defineConfig({
  testDir: '.', testMatch: 'live.spec.mjs', workers: 1, fullyParallel: false,
  forbidOnly: true, retries: 0, timeout: 180000, globalTimeout: 540000,
  expect: { timeout: 15000 }, outputDir: `${root}artifacts/integration/browser/results`,
  reporter: [['list'], ['json', { outputFile: `${root}artifacts/integration/browser/report.json` }],
    ['html', { outputFolder: `${root}artifacts/integration/browser/html`, open: 'never' }]],
  use: { baseURL: 'http://127.0.0.1:8787', browserName: 'chromium', headless: true,
    viewport: { width: 390, height: 844 }, locale: 'pt-BR', colorScheme: 'light',
    actionTimeout: 15000, navigationTimeout: 30000, serviceWorkers: 'block',
    screenshot: 'off', trace: 'off', video: 'off' },
  webServer: { command: 'node qa/integration/server.mjs', cwd: root,
    url: 'http://127.0.0.1:8787/__qa/health', reuseExistingServer: false, timeout: 30000,
    gracefulShutdown: { signal: 'SIGTERM', timeout: 5000 } },
});

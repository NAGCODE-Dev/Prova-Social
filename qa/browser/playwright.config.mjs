import { defineConfig } from '@playwright/test';
import { fileURLToPath } from 'node:url';
const artifactDir = process.env.QA_STRESS === '1' ? '../../artifacts/browser/stress/' : '../../artifacts/browser/';
const artifacts = fileURLToPath(new URL(artifactDir, import.meta.url));
export default defineConfig({
  testDir: '.', testMatch: ['p0.spec.mjs', 'torture.spec.mjs'], fullyParallel: false, workers: 1,
  forbidOnly: true, retries: 0, timeout: 120000, globalTimeout: 720000,
  expect: { timeout: 15000 }, outputDir: `${artifacts}/results`,
  reporter: [['list'], ['html', { outputFolder: `${artifacts}/html`, open: 'never' }],
    ['json', { outputFile: `${artifacts}/report.json` }],
    ['junit', { outputFile: `${artifacts}/junit.xml` }]],
  use: {
    baseURL: 'http://127.0.0.1:8787', browserName: 'chromium', headless: true,
    actionTimeout: 15000, navigationTimeout: 30000, serviceWorkers: 'block',
    screenshot: 'only-on-failure', trace: 'off', video: 'off',
    locale: 'pt-BR', colorScheme: 'light',
  },
  projects: [
    { name: 'mobile-small', use: { viewport: { width: 360, height: 640 } } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'desktop', use: { viewport: { width: 1366, height: 768 } } },
  ],
  webServer: {
    command: 'node server.mjs', cwd: fileURLToPath(new URL('.', import.meta.url)),
    url: 'http://127.0.0.1:8787/__qa/health', timeout: 30000,
    reuseExistingServer: false, stdout: 'pipe', stderr: 'pipe',
    gracefulShutdown: { signal: 'SIGTERM', timeout: 5000 },
  },
});

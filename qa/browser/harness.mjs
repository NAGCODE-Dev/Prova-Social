import { test as base, expect } from '@playwright/test';
import { localExam } from './fixtures.mjs';
export { expect };
export const origin = 'http://127.0.0.1:8787';
import { redact } from './harness-redaction.mjs';
export { redact };
export const test = base.extend({
  audit: [async ({ page, context }, use, info) => {
    const logs = [], fatal = [];
    const audit = { offline: false };
    const cancelledAssets = new Set();
    const record = (kind, message, fails = false) => {
      const entry = { at: new Date().toISOString(), kind, message: redact(message) };
      logs.push(entry);
      if (fails) fatal.push(entry);
    };
    const watchPage = page => {
      page.on('console', msg => {
        const text = msg.text();
        const offlineProbe = audit.offline && msg.location().url.startsWith(`${origin}/__qa/health`) &&
          /ERR_INTERNET_DISCONNECTED/.test(text);
        record(offlineProbe ? 'expected-offline-console' : msg.type(), text, (!offlineProbe && msg.type() === 'error') ||
          /EXCEPTION CAUGHT|Another exception was thrown|RenderFlex overflowed|Unhandled (?:Exception|error)|Uncaught|Assertion failed|ErrorWidget/i.test(text));
      });
      page.on('pageerror', error => record('pageerror', error.message, true));
      page.on('crash', () => record('crash', 'Chromium page crashed', true));
      page.on('requestfailed', request => {
        const url = new URL(request.url());
        const cancelledFontManifest = url.origin === origin &&
          url.pathname === '/assets/FontManifest.json' && request.failure()?.errorText === 'net::ERR_ABORTED';
        if (cancelledFontManifest) {
          cancelledAssets.add(url.href);
          record('cancelled-font-manifest', 'Font manifest request cancelled; availability checked at teardown');
          return;
        }
        // Only the intentional offline health probe is expected to fail.
        const expected = url.origin === origin && url.pathname === '/__qa/health' && audit.offline;
        record(expected ? 'expected-offline' : 'requestfailed',
          `${url.origin}${url.pathname}: ${request.failure()?.errorText}`, !expected);
      });
      page.on('response', response => {
        if (response.status() >= 400) record('http-error',
          `${response.status()} ${new URL(response.url()).pathname}`, true);
      });
    };
    watchPage(page);
    context.on('page', watchPage);
    await context.route('**/*', async route => {
      const url = new URL(route.request().url());
      if (url.origin === origin || ['data:', 'blob:'].includes(url.protocol)) return route.continue();
      record('blocked-external', `${url.origin}${url.pathname}`, true);
      await route.abort('blockedbyclient');
    });
    await context.routeWebSocket('**/*', ws => {
      record('blocked-websocket', 'Unexpected WebSocket', true);
      ws.close();
    });
    try {
      await use(audit);
    } finally {
      for (const url of cancelledAssets) {
        try {
          const response = await context.request.get(url, { timeout: 5000 });
          expect(response.status(), 'Cancelled font manifest remains available locally').toBe(200);
          expect(Array.isArray(await response.json()), 'Font manifest is valid JSON').toBe(true);
        } catch { record('font-manifest-unavailable', 'Cancelled manifest could not be reloaded', true); }
      }
      if (info.status !== info.expectedStatus || fatal.length) {
        try { await evidence(context.pages().find(p => !p.isClosed()) ?? page, info, 'failure'); } catch (error) {
          record('capture-error', error.message);
        }
      }
      await info.attach('console.json', {
        body: Buffer.from(JSON.stringify({ logs, fatal }, null, 2)), contentType: 'application/json',
      });
      expect(fatal, 'Console/runtime/network failures; see console.json').toEqual([]);
    }
  }, { auto: true }],
});

// Real labels from Flutter widgets; text leaves and aria-label nodes vary by engine.
export function text(page, label) {
  return page.getByText(label, { exact: false })
    .or(page.locator(`[aria-label*=${JSON.stringify(label)}]`)).first();
}
export function button(page, label) {
  return page.getByRole('button', { name: label, exact: true });
}
export async function clickText(page, label) {
  const target = text(page, label);
  await target.scrollIntoViewIfNeeded();
  await expect(target).toBeInViewport();
  await target.click();
}
export async function evidence(page, info, name) {
  const path = info.outputPath(`${name}.png`);
  await page.screenshot({ path, fullPage: false, timeout: 10000 });
  await info.attach(name, { path, contentType: 'image/png' });
}
export async function semantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({ state: 'attached' });
  // Flutter's documented invisible accessibility opt-in, not a product action.
  if (await placeholder.count()) await placeholder.dispatchEvent('click');
  await expect(page.locator('flt-semantics').first()).toBeAttached();
}
export async function open(page) {
  const response = await page.goto('/');
  expect(response.status()).toBe(200);
  await semantics(page);
}
export async function seed(context) {
  await context.addInitScript(({ fixture, expectedOrigin }) => {
    if (location.origin !== expectedOrigin) return;
    const key = 'flutter.private_exams_v1';
    // shared_preferences_web JSON-encodes the Dart String stored at this key.
    // Never overwrite progress on reload; this only provides initial content.
    if (localStorage.getItem(key) === null) localStorage.setItem(key, JSON.stringify(JSON.stringify([fixture])));
  }, { fixture: localExam, expectedOrigin: origin });
}
export async function onboard(page, info) {
  await expect(text(page, 'Encontre o que estudar')).toBeVisible();
  await evidence(page, info, 'startup');
  await button(page, 'Continuar').click();
  await expect(text(page, 'Resolva sem distrações')).toBeVisible();
  await button(page, 'Continuar').click();
  await expect(text(page, 'Transforme PDF em prova')).toBeVisible();
  await button(page, 'Explorar sem conta').click();
  await expect(text(page, 'Encontre sua próxima prova')).toBeVisible();
}
export async function layout(page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1),
    'Horizontal document overflow').toBe(true);
  // Canvas overflow is also checked through Flutter debug console diagnostics.
}
export async function selected(page, answer) {
  await expect(page.getByRole('radio', { name: answer })).toBeChecked();
}
export async function draft(page) {
  return page.evaluate(() => {
    const key = Object.keys(localStorage).find(k => k.startsWith('flutter.attempt_draft_v1_qa-local-'));
    return key ? JSON.parse(JSON.parse(localStorage.getItem(key))) : null;
  });
}

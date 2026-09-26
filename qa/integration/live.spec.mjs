import { test as base, expect } from '../browser/node_modules/@playwright/test/index.mjs';
import { button, text, clickText, open, semantics, evidence } from '../browser/harness.mjs';
import { redact } from '../browser/harness-redaction.mjs';
import { loadConfig, LocalClient, createUser, importFixture, publication, apiOrigin } from './client.mjs';
import { randomUUID } from 'node:crypto';

const test = base.extend({
  audit: [async ({ page, context }, use, info) => {
    const errors = [], logs = [];
    const audit = { offline: false, authInput: false };
    const record = (message, fatal = true) => {
      const entry = { at: new Date().toISOString(), message: redact(message) };
      logs.push(entry); if (fatal) errors.push(entry);
    };
    await context.route('**/*', route => {
      const url = new URL(route.request().url());
      if (['http://127.0.0.1:8787', apiOrigin].includes(url.origin) || ['data:', 'blob:'].includes(url.protocol)) return route.continue();
      record(`Blocked external origin: ${url.origin}`);
      return route.abort();
    });
    await context.routeWebSocket('**/*', ws => { record('Unexpected WebSocket'); ws.close(); });
    page.on('pageerror', e => record(e.message));
    page.on('crash', () => record('Page crash'));
    page.on('console', msg => {
      const expected = audit.offline && msg.location().url.startsWith(`${apiOrigin}/rest/v1/rpc/submit_exam_attempt`) &&
        /ERR_INTERNET_DISCONNECTED/.test(msg.text());
      if (msg.type() === 'error' || /EXCEPTION CAUGHT|RenderFlex overflowed|Unhandled Exception/.test(msg.text())) record(msg.text(), !expected);
    });
    page.on('requestfailed', req => {
      const url = new URL(req.url());
      const expected = audit.offline && url.origin === apiOrigin && url.pathname === '/rest/v1/rpc/submit_exam_attempt';
      record(`${url.pathname}: ${req.failure()?.errorText}`, !expected);
    });
    page.on('response', res => { if (res.status() >= 400) record(`HTTP ${res.status()} ${new URL(res.url()).pathname}`); });
    try { await use(audit); }
    finally {
      // Never screenshot credentials/forms; trace/storageState/HAR remain off.
      if (!audit.authInput && info.status !== info.expectedStatus) {
        try { await evidence(page, info, 'failure'); } catch {}
      }
      await info.attach('console.json', { body: Buffer.from(JSON.stringify(logs)), contentType: 'application/json' });
      expect(errors, 'Unexpected runtime/network failures').toEqual([]);
    }
  }, { auto: true }],
});
async function login(page, user, audit) {
  audit.authInput = true;
  try {
    await page.getByRole('textbox', { name: 'E-mail', exact: true }).fill(user.email);
    await page.getByRole('textbox', { name: 'Senha', exact: true }).fill(user.password);
    await button(page, 'Entrar').click();
  } catch { throw new Error('QA login interaction failed; credential-bearing call log withheld'); }
  // Caller resets authInput only after observing a non-authenticated-form screen.
}
async function search(page, title) {
  await clickText(page, 'Explorar');
  await page.getByRole('textbox', { name: 'Buscar provas, concursos e matérias' }).fill(title);
  await clickText(page, title);
  await button(page, 'Começar prova').click();
}
async function queue(page) {
  return page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem('flutter.attempt_sync_queue_v1'))));
}

test('real JSON import, contextual Auth, explicit publication, search, offline delivery and sync', async ({ page, context, audit }, info) => {
  const config = await loadConfig();
  const visitor = new LocalClient(config);
  const user = await createUser(config, 'browser-author');
  const title = `QA UI ${randomUUID()}`;
  await open(page);
  await button(page, 'Pular').click();
  await clickText(page, 'Publicar');
  const chooser = page.waitForEvent('filechooser');
  await clickText(page, 'Importar JSON');
  await (await chooser).setFiles({ name: 'qa-exam.json', mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify({ ...importFixture, title })) });
  await expect(page.getByRole('textbox', { name: 'Título', exact: true })).toHaveValue(title);
  await clickText(page, 'Salvar só para mim');
  await expect(text(page, 'Prova privada salva na biblioteca local.')).toBeVisible();
  const lookup = () => visitor.ok(`/rest/v1/exams?title=eq.${encodeURIComponent(title)}`);
  expect(await lookup()).toHaveLength(0);
  await clickText(page, 'Publicar para todos — requer conta');
  await login(page, user, audit);
  await expect(text(page, 'Publicar para todos?')).toBeVisible();
  audit.authInput = false;
  // Account creation/login alone must not publish the imported private copy.
  expect(await lookup()).toHaveLength(0);
  await button(page, 'Manter privada').click();
  expect(await lookup()).toHaveLength(0);
  await clickText(page, 'Publicar para todos — requer conta');
  await button(page, 'Publicar para todos').click();
  await expect.poll(async () => (await lookup()).length).toBe(1);
  const examId = (await lookup())[0].id;
  await page.reload(); await semantics(page);
  await search(page, title);
  await expect(text(page, importFixture.questions[0].statement)).toBeVisible();
  await page.getByRole('button', { name: /Alternativa B, Dois/ }).click();
  audit.offline = true; await context.setOffline(true);
  expect(await page.evaluate(() => navigator.onLine)).toBe(false);
  await button(page, 'Revisar entrega').click();
  await button(page, 'Entregar mesmo com questões em branco').click();
  await expect(text(page, 'Entrega salva no aparelho — aguardando correção')).toBeVisible();
  const pending = (await queue(page)).pending;
  expect(pending).toHaveLength(1);
  const frozen = pending[0];
  expect(frozen.answers).toEqual({ 0: 1 });
  expect(frozen.exam.id).toBe(examId);
  await evidence(page, info, 'durable-offline-delivery');
  await context.setOffline(false); audit.offline = false;
  await button(page, 'Tentar agora').click();
  await expect(text(page, '1 de 2 acertos')).toBeVisible();
  const rows = await user.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${frozen.clientAttemptId}`);
  expect(rows).toHaveLength(1);
  expect(rows[0].user_id).toBe(user.id);
  expect(rows[0].correct_count).toBe(1);
  const answers = await user.client.ok(`/rest/v1/attempt_answers?attempt_id=eq.${rows[0].id}&order=question_id`);
  expect(answers).toHaveLength(2);
  expect(answers.filter(a => a.selected_index === 1)).toHaveLength(1);
  expect(answers.filter(a => a.selected_index === null)).toHaveLength(1);
  expect((await queue(page)).pending).toHaveLength(0);
  expect(Object.keys((await queue(page)).completed)).toEqual([frozen.clientAttemptId]);
  await evidence(page, info, 'real-synced-result');
  await page.reload(); await semantics(page);
  await clickText(page, 'Biblioteca');
  await clickText(page, 'Sincronizada');
  await expect(text(page, '1 de 2 acertos')).toBeVisible();
  await evidence(page, info, 'real-result-after-reload');
});

test('visitor result must become account history after real login', async ({ page, audit }) => {
  const config = await loadConfig();
  const owner = await createUser(config, 'visitor-claim');
  const title = `QA claim ${randomUUID()}`;
  expect((await owner.client.rpc('publish_exam', publication(title))).status).toBe(200);
  await open(page); await button(page, 'Pular').click();
  await search(page, title);
  await page.getByRole('button', { name: /Alternativa B, Dois/ }).click();
  await button(page, 'Revisar entrega').click();
  await button(page, 'Entregar mesmo com questões em branco').click();
  await expect(text(page, '1 de 2 acertos')).toBeVisible();
  const id = Object.keys((await queue(page)).completed)[0];
  expect(id).toBeTruthy();
  expect(await owner.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${id}`)).toHaveLength(0);
  await page.reload(); await semantics(page);
  await clickText(page, 'Perfil');
  await button(page, 'Entrar ou criar conta').click();
  await login(page, owner, audit);
  await expect(text(page, 'Sair da conta')).toBeVisible();
  audit.authInput = false;
  // Contract regression: successful RPC claim alone is not evidence that the
  // app actually replays a completed visitor submission after authentication.
  await expect.poll(async () => (await owner.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${id}`)).length).toBe(1);
  expect(Object.keys((await queue(page)).completed)).toEqual([id]);
});

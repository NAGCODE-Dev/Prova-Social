import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

export const apiOrigin = 'http://127.0.0.1:54321';
export function validateConfig(config) {
  assert.equal(config.apiUrl, apiOrigin, 'Only the disposable loopback API is allowed');
  assert.match(config.runId, /^qa-[a-f0-9-]{36}$/);
  assert.equal(typeof config.anonKey, 'string', 'Missing public key');
  // Never accept a privileged key, including legacy JWTs with service_role.
  if (!config.anonKey.startsWith('sb_publishable_')) {
    let role;
    try { role = JSON.parse(Buffer.from(config.anonKey.split('.')[1], 'base64url')).role; } catch {}
    assert.equal(role, 'anon', 'Only an anon/publishable key is accepted');
  }
  return config;
}
export async function loadConfig() {
  assert.ok(process.env.QA_LOCAL_CONFIG, 'Run through qa/integration/run.mjs');
  return validateConfig(JSON.parse(await readFile(process.env.QA_LOCAL_CONFIG, 'utf8')));
}
export function localUrl(path) {
  assert.ok(path.startsWith('/auth/v1/') || path.startsWith('/rest/v1/'), 'Only Auth/REST paths');
  const url = new URL(path, apiOrigin);
  assert.equal(url.origin, apiOrigin);
  assert.ok(url.pathname.startsWith('/auth/v1/') || url.pathname.startsWith('/rest/v1/'));
  return url;
}
export class LocalClient {
  constructor(config, token) { this.config = validateConfig(config); this.token = token; }
  async request(path, { method = 'GET', body, headers = {} } = {}) {
    const response = await fetch(localUrl(path), {
      method, redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { apikey: this.config.anonKey, Authorization: `Bearer ${this.token ?? this.config.anonKey}`,
        'Content-Type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const raw = await response.text();
    let data;
    try { data = raw ? JSON.parse(raw) : null; } catch { throw new Error(`Non-JSON local response (${response.status})`); }
    return { status: response.status, data };
  }
  async ok(path, options) {
    const { status, data } = await this.request(path, options);
    // Do not place auth response bodies/tokens in assertion diagnostics.
    assert.ok(status >= 200 && status < 300, `Local ${options?.method ?? 'GET'} ${path.split('?')[0]}: HTTP ${status}`);
    return data;
  }
  rpc(name, body) { return this.request(`/rest/v1/rpc/${name}`, { method: 'POST', body }); }
}
export async function createUser(config, label) {
  const email = `qa-${label}-${randomUUID()}@example.test`;
  const password = `Qa!${randomUUID()}aA9`;
  const visitor = new LocalClient(config);
  const registered = await visitor.ok('/auth/v1/signup', {
    method: 'POST', body: { email, password, data: { display_name: 'QA synthetic user' } },
  });
  assert.ok(Boolean(registered.user?.id), 'Signup must create a local user');
  const session = await visitor.ok('/auth/v1/token?grant_type=password', { method: 'POST', body: { email, password } });
  assert.ok(Boolean(session.access_token && session.refresh_token && session.user?.id), 'Real Auth session required');
  return { email, password, id: session.user.id, refreshToken: session.refresh_token,
    client: new LocalClient(config, session.access_token) };
}
export const importFixture = {
  id: 'qa-import', title: 'QA imported exam', category: 'QA Matemática',
  source: 'Synthetic QA fixture, authored for tests', durationMinutes: 10,
  questions: [
    { statement: 'QA import: quanto é 1 + 1?', options: ['Um', 'Dois'], correctIndex: 1 },
    { statement: 'QA import: quanto é 2 + 2?', options: ['Três', 'Quatro'], correctIndex: 1 },
  ],
};
export function publication(title) {
  return { p_title: title, p_category: importFixture.category, p_source: importFixture.source,
    p_source_type: 'community', p_year: null, p_duration_minutes: 10,
    p_questions: importFixture.questions.map(q => ({ topic: 'QA', statement: q.statement, options: q.options, correct_index: q.correctIndex })) };
}

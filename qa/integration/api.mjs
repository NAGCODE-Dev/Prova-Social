import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadConfig, LocalClient, createUser, publication } from './client.mjs';

// All identities are created via Auth. No JWT forging/auth.uid mock/admin key.
const config = await loadConfig();
const visitor = new LocalClient(config);
const a = await createUser(config, 'a');
const b = await createUser(config, 'b');
const title = `QA API ${config.runId}`;
const badLogin = await visitor.request('/auth/v1/token?grant_type=password', {
  method: 'POST', body: { email: a.email, password: 'QA deliberately invalid password' },
});
assert.ok(badLogin.status >= 400, 'Invalid password must not create a session');
assert.ok(!badLogin.data.access_token);
const profiles = await a.client.ok(`/rest/v1/profiles?id=eq.${a.id}&select=id`);
assert.equal(profiles.length, 1, 'Auth trigger creates profile');
const rejected = await visitor.rpc('publish_exam', publication(title));
assert.ok([401, 403].includes(rejected.status), 'Visitor cannot publish');
const invalid = publication(`${title} invalid`);
invalid.p_questions[1].correct_index = 99;
assert.ok((await a.client.rpc('publish_exam', invalid)).status >= 400);
assert.equal((await a.client.ok(`/rest/v1/exams?title=eq.${encodeURIComponent(invalid.p_title)}`)).length, 0, 'Publication rolls back atomically');
const published = await a.client.rpc('publish_exam', publication(title));
assert.equal(published.status, 200);
assert.equal(typeof published.data, 'string');
const examId = published.data;
const search = await visitor.ok(`/rest/v1/exams?title=ilike.${encodeURIComponent(`%${config.runId}%`)}&status=eq.published&is_public=eq.true`);
assert.equal(search.length, 1);
assert.equal(search[0].id, examId);
const questions = await visitor.ok(`/rest/v1/questions?exam_id=eq.${examId}&order=position`);
assert.equal(questions.length, 2);
assert.deepEqual(questions.map(q => q.position), [1, 2]);
assert.ok(questions.every(q => !('correct_index' in q)), 'Public question payload hides keys');
const keys = await visitor.request('/rest/v1/question_keys?select=*', { headers: { 'Accept-Profile': 'private' } });
assert.ok(keys.status >= 400, 'Private answer schema is inaccessible');
console.log('PASS Auth signup/login/profile, publication validation/atomicity, public search and hidden answer keys');

// Visibility: direct writes run as real users and must obey RLS, never admin.
const drafts = await a.client.ok('/rest/v1/exams', { method: 'POST', headers: { Prefer: 'return=representation' }, body: {
  author_id: a.id, title: `${title} private`, category: 'QA', source_name: 'QA fixture', status: 'draft', is_public: false,
} });
assert.equal(drafts.length, 1);
const privateId = drafts[0].id;
await a.client.ok('/rest/v1/questions', { method: 'POST', body: {
  exam_id: privateId, position: 1, topic: 'QA private', statement: 'QA private question?', options: ['A', 'B'],
} });
for (const client of [visitor, b.client]) {
  assert.equal((await client.ok(`/rest/v1/exams?id=eq.${privateId}`)).length, 0);
  assert.equal((await client.ok(`/rest/v1/questions?exam_id=eq.${privateId}`)).length, 0);
}
await b.client.ok(`/rest/v1/exams?id=eq.${privateId}`, { method: 'PATCH', body: { title: 'QA takeover' } });
assert.equal((await a.client.ok(`/rest/v1/exams?id=eq.${privateId}`))[0].title, `${title} private`);
const favorite = { user_id: a.id, exam_id: examId };
await a.client.ok('/rest/v1/favorites', { method: 'POST', body: favorite });
assert.equal((await b.client.ok(`/rest/v1/favorites?user_id=eq.${a.id}`)).length, 0);
assert.ok((await b.client.request('/rest/v1/favorites', { method: 'POST', body: favorite })).status >= 400);
console.log('PASS private visibility and cross-account RLS');

const id = randomUUID();
const payload = { p_exam_id: examId, p_answers: { [questions[0].id]: 1 },
  p_review_question_ids: [questions[1].id], p_duration_seconds: 12, p_client_attempt_id: id };
const first = await visitor.rpc('submit_exam_attempt', payload);
assert.equal(first.status, 200);
assert.equal(first.data.correct, 1);
assert.equal(first.data.total, 2);
const retry = await visitor.rpc('submit_exam_attempt', structuredClone(payload));
assert.equal(retry.data.attempt_id, first.data.attempt_id);
assert.equal(retry.data.duplicate, true);
const claim = await a.client.rpc('submit_exam_attempt', structuredClone(payload));
assert.equal(claim.status, 200);
assert.equal(claim.data.attempt_id, first.data.attempt_id);
const rows = await a.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${id}`);
assert.equal(rows.length, 1);
assert.equal(rows[0].user_id, a.id);
assert.equal((await b.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${id}`)).length, 0);
assert.equal((await b.client.ok(`/rest/v1/attempt_answers?attempt_id=eq.${rows[0].id}`)).length, 0);
const stolen = await b.client.rpc('submit_exam_attempt', payload);
assert.equal(stolen.data.code, '42501');
const conflict = await a.client.rpc('submit_exam_attempt', { ...payload, p_answers: { [questions[0].id]: 0 } });
assert.equal(conflict.data.code, '22023');
const write = await a.client.request(`/rest/v1/attempts?id=eq.${rows[0].id}`, { method: 'PATCH', body: { score_percent: 100 } });
assert.ok(write.status >= 400, 'Direct grade mutation forbidden by grants');
assert.equal((await a.client.ok(`/rest/v1/attempts?client_attempt_id=eq.${id}`))[0].correct_count, 1);
console.log('PASS visitor retry, account claim, conflicting payload, RLS and write grants');
const refreshed = await visitor.ok('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: a.refreshToken } });
assert.ok(Boolean(refreshed.access_token), 'Auth refresh returns a session');
const refreshedClient = new LocalClient(config, refreshed.access_token);
assert.equal((await refreshedClient.ok('/auth/v1/user')).id, a.id);
await refreshedClient.ok('/auth/v1/logout', { method: 'POST' });
const afterLogout = await visitor.request('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: refreshed.refresh_token } });
assert.ok(afterLogout.status >= 400, 'Logout revokes refresh, not the already issued access JWT');
console.log('PASS real refresh and logout; entire stack discarded by parent runner');

import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createQaServer } from './server.mjs';

test('server refuses a missing Flutter build', { timeout: 5000 }, async () => {
  const root = await mkdtemp(join(tmpdir(), 'prova-qa-empty-'));
  try { await assert.rejects(createQaServer(root)); }
  finally { await rm(root, { recursive: true }); }
});

test('loopback readiness, fixtures, static MIME and mutation isolation', { timeout: 10000 }, async () => {
  const root = await mkdtemp(join(tmpdir(), 'prova-qa-server-'));
  const outside = await mkdtemp(join(tmpdir(), 'prova-qa-outside-'));
  let server;
  try {
    for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
      await writeFile(join(root, file), 'QA server test; not Flutter evidence');
    }
    await writeFile(join(root, 'module.wasm'), 'wasm');
    await writeFile(join(outside, 'private.txt'), 'must not be served');
    await symlink(join(outside, 'private.txt'), join(root, 'escape.txt'));
    server = await createQaServer(root);
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });
    const base = `http://127.0.0.1:${server.address().port}`;
    const get = (path, options = {}) => fetch(base + path, { ...options, signal: AbortSignal.timeout(3000) });
    assert.equal((await get('/__qa/health')).status, 200);
    assert.equal((await get('/')).status, 200);
    assert.equal((await get('/module.wasm')).headers.get('content-type'), 'application/wasm');
    assert.equal((await get('/rest/v1/exams')).status, 200);
    assert.equal((await (await get('/rest/v1/exams?title=ilike.%25zzzz%25')).json()).length, 0);
    assert.equal((await (await get('/rest/v1/exams?category=ilike.%25Matemática%25')).json()).length, 1);
    assert.equal((await (await get('/rest/v1/questions?exam_id=eq.qa-public')).json()).length, 3);
    for (const path of ['/rest/v1/exams', '/rest/v1/rpc/submit_exam_attempt', '/auth/v1/token']) {
      assert.equal((await get(path, { method: 'POST' })).status, 405);
    }
    assert.equal((await get('/escape.txt')).status, 403);
    assert.equal((await get('/missing.js')).status, 404);
    assert.equal((await get('/auth/v1/user')).status, 404);
  } finally {
    if (server) {
      server.closeAllConnections();
      await new Promise(resolve => server.close(resolve));
    }
    await rm(root, { recursive: true });
    await rm(outside, { recursive: true });
  }
});

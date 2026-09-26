import http from 'node:http';
import { readFile, realpath, stat } from 'node:fs/promises';
import { resolve, sep, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { apiResponse } from './fixtures.mjs';

export const buildRoot = fileURLToPath(new URL('../../build/web/', import.meta.url));
const mime = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
  '.css': 'text/css' };

export async function createQaServer(root = buildRoot) {
  const canonicalRoot = await realpath(root);
  for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
    if (!(await stat(resolve(root, file))).isFile()) throw new Error(`Build ausente: ${file}`);
  }
  return http.createServer({ requestTimeout: 15000, headersTimeout: 10000 }, async (req, res) => {
    const reply = (status, body, type = 'application/json') => {
      res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
      res.end(body);
    };
    try {
      const url = new URL(req.url, 'http://127.0.0.1:8787');
      // No credentials, forwarding, remote API, uploads or mutations.
      if (req.method !== 'GET' && req.method !== 'HEAD') return reply(405, '{}');
      if (url.pathname === '/__qa/health') return reply(200, '{"qa":true}');
      const fixture = apiResponse(url);
      if (fixture !== null) return reply(200, JSON.stringify(fixture));
      if (url.pathname.startsWith('/rest/') || url.pathname.startsWith('/auth/')) return reply(404, '{}');
      if (url.pathname === '/favicon.ico') return reply(204, '');
      const requested = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
      const file = await realpath(resolve(root, `.${requested}`));
      if (!file.startsWith(canonicalRoot + sep)) return reply(403, '{}');
      reply(200, await readFile(file), mime[extname(file)] ?? 'application/octet-stream');
    } catch (error) {
      reply(error.code === 'ENOENT' ? 404 : 500, '{}');
    }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await createQaServer();
  server.on('error', (error) => {
    console.error(`QA server failed: ${error.code ?? 'unknown'}`);
    process.exitCode = 1;
  });
  server.listen(8787, '127.0.0.1', () => console.log('QA server ready on loopback:8787'));
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
    server.closeAllConnections();
    server.close(() => process.exit(0));
  });
}

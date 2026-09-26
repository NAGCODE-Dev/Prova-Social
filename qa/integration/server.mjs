import { createQaServer } from '../browser/server.mjs';
import { fileURLToPath } from 'node:url';
const server = await createQaServer(fileURLToPath(new URL('../../build/qa-live/', import.meta.url)));
server.listen(8787, '127.0.0.1');
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
  server.closeAllConnections();
  server.close(() => process.exit(0));
});

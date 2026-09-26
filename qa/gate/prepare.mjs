// Preserve existing platforms; generate only missing directories in isolation.
import { access, cp, mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const exists = async path => { try { await access(path); return true; } catch { return false; } };
const missing = [];
for (const platform of ['android', 'web']) if (!await exists(platform)) missing.push(platform);
if (missing.length) {
  const temp = await mkdtemp(join(tmpdir(), 'prova-qa-platform-'));
  try {
    const generated = spawnSync('flutter', ['create', join(temp, 'project'), '--platforms=android,web', '--project-name=prova_social', '--org=dev.nagcode', '--no-pub'], { stdio: 'inherit', timeout: 120000 });
    if (generated.status !== 0) throw new Error('Platform generation failed');
    for (const platform of missing) await cp(join(temp, 'project', platform), platform, { recursive: true, errorOnExist: true, force: false });
    if (missing.includes('web')) {
      const manifest = JSON.parse(await readFile('web/manifest.json', 'utf8'));
      manifest.name = manifest.short_name = 'Prova Social';
      await writeFile('web/manifest.json', JSON.stringify(manifest, null, 2));
      const index = await readFile('web/index.html', 'utf8');
      await writeFile('web/index.html', index.replace('<title>prova_social</title>', '<title>Prova Social</title>'));
    }
    if (missing.includes('android')) {
      const path = 'android/app/src/main/AndroidManifest.xml';
      await writeFile(path, (await readFile(path, 'utf8')).replace('android:label="prova_social"', 'android:label="Prova Social"'));
    }
  } finally { await rm(temp, { recursive: true, force: true }); }
}
console.log(`Platforms prepared; only missing copied: ${missing.join(', ') || 'none'}`);

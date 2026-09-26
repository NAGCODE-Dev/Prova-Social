"""Inspect QA builds without installing/publishing them or extracting the APK."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

web = Path('build/web')
manifest = json.loads((web / 'manifest.json').read_text())
assert manifest['name'] == 'Prova Social'
assert '<title>Prova Social</title>' in (web / 'index.html').read_text()
for name in ['flutter_bootstrap.js', 'main.dart.js', 'favicon.png']:
    assert (web / name).stat().st_size > 0
for name in ['favicon.png', 'icons/Icon-192.png', 'icons/Icon-512.png']:
    assert (web / name).read_bytes() == (Path('web') / name).read_bytes()
apk = Path('build/app/outputs/flutter-apk/app-debug.apk')
with ZipFile(apk) as archive:
    names = archive.namelist()
    assert 'AndroidManifest.xml' in names and 'classes.dex' in names
    assert any(n.endswith('/libflutter.so') for n in names)
    brand = 'assets/flutter_assets/assets/branding/app_icon.png'
    assert archive.getinfo(brand).file_size < 10 * 1024 * 1024
    assert archive.read(brand) == Path('assets/branding/app_icon.png').read_bytes()
    assert archive.getinfo('AndroidManifest.xml').file_size < 1024 * 1024
    android_manifest = archive.read('AndroidManifest.xml')
    assert b'Prova Social' in android_manifest or 'Prova Social'.encode('utf-16le') in android_manifest
report = {
    'apk': str(apk), 'bytes': apk.stat().st_size,
    'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
    'webMainSha256': hashlib.sha256((web / 'main.dart.js').read_bytes()).hexdigest(),
    'scope': 'QA debug build inspection; no Android runtime or release signing certification',
}
Path('artifacts/qa-full/builds.json').write_text(json.dumps(report, indent=2))
print('PASS Web/APK structure, branding assets and hashes; runtime Android NOT RUN')

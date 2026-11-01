import json
import re
from pathlib import Path


BRAND_BACKGROUND = "#050907"
BRAND_DESCRIPTION = (
    "Resolva provas, descubra o que precisa estudar e refaça somente as "
    "questões que errou."
)
ROBOTS_META = '<meta name="robots" content="noindex,follow">'
SHELL_STYLE = """<style id="prova-social-shell">
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      background: #050907;
      color-scheme: dark;
      overscroll-behavior: none;
    }
    body {
      overflow: hidden;
    }
  </style>"""

manifest_path = Path("web/manifest.json")
index_path = Path("web/index.html")
if not manifest_path.is_file() or not index_path.is_file():
    raise SystemExit("Flutter Web scaffolding is incomplete.")

manifest = json.loads(manifest_path.read_text())
manifest["name"] = "Prova Social"
manifest["short_name"] = "Prova Social"
manifest["description"] = BRAND_DESCRIPTION
manifest["orientation"] = "portrait-primary"
manifest["background_color"] = BRAND_BACKGROUND
manifest["theme_color"] = BRAND_BACKGROUND
manifest.setdefault(
    "icons",
    [
        {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
        {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable",
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable",
        },
    ],
)
manifest_path.write_text(f"{json.dumps(manifest, indent=2)}\n")


def _set_meta(html: str, name: str, content: str) -> str:
    pattern = re.compile(
        rf'<meta\s+name="{re.escape(name)}"\s+content="[^"]*"\s*/?>',
        re.IGNORECASE,
    )
    tag = f'<meta name="{name}" content="{content}">'
    if pattern.search(html):
        return pattern.sub(tag, html, count=1)
    return html.replace("</head>", f"  {tag}\n</head>", 1)


def _set_link(html: str, rel: str, href: str, extra: str = "") -> str:
    pattern = re.compile(
        rf'<link\s+rel="{re.escape(rel)}"[^>]*>',
        re.IGNORECASE,
    )
    tag = f'<link rel="{rel}"{extra} href="{href}">'
    if pattern.search(html):
        return pattern.sub(tag, html, count=1)
    return html.replace("</head>", f"  {tag}\n</head>", 1)


index = index_path.read_text()
index = re.sub(r"<html(?![^>]*\blang=)", '<html lang="pt-BR"', index, count=1)
index = re.sub(r"<title>.*?</title>", "<title>Prova Social</title>", index, count=1)
index = _set_meta(index, "description", BRAND_DESCRIPTION)
index = _set_meta(index, "theme-color", BRAND_BACKGROUND)
index = _set_meta(index, "robots", "noindex,follow")
index = _set_meta(index, "apple-mobile-web-app-title", "Prova Social")
index = _set_meta(index, "apple-mobile-web-app-capable", "yes")
index = _set_meta(index, "apple-mobile-web-app-status-bar-style", "black")
index = _set_meta(index, "mobile-web-app-capable", "yes")
index = _set_link(index, "manifest", "manifest.json")
index = _set_link(index, "icon", "favicon.png", ' type="image/png"')
index = _set_link(index, "apple-touch-icon", "icons/Icon-192.png")
index = re.sub(
    r'<meta\s+name="viewport"\s+content="[^"]*"\s*/?>',
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, '
    'viewport-fit=cover">',
    index,
    count=1,
)
if 'id="prova-social-shell"' not in index:
    index = index.replace("</head>", f"  {SHELL_STYLE}\n</head>", 1)
index_path.write_text(index)

if (
    "<title>Prova Social</title>" not in index
    or ROBOTS_META not in index
    or f'content="{BRAND_BACKGROUND}"' not in index
    or 'id="prova-social-shell"' not in index
):
    raise SystemExit("Could not apply Flutter Web branding and indexing policy.")

print("Flutter Web branding prepared.")

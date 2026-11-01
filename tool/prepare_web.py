import json
from pathlib import Path


manifest_path = Path("web/manifest.json")
index_path = Path("web/index.html")
if not manifest_path.is_file() or not index_path.is_file():
    raise SystemExit("Flutter Web scaffolding is incomplete.")

manifest = json.loads(manifest_path.read_text())
manifest["name"] = "Prova Social"
manifest["short_name"] = "Prova Social"
manifest["description"] = "Resolva provas e descubra o que precisa estudar."
manifest["orientation"] = "portrait-primary"
manifest_path.write_text(f"{json.dumps(manifest, indent=2)}\n")

index = index_path.read_text()
index = index.replace(
    '<meta name="description" content="A new Flutter project.">',
    '<meta name="description" content="Resolva provas e descubra o que precisa estudar.">',
)
index = index.replace(
    '<meta name="apple-mobile-web-app-title" content="prova_social">',
    '<meta name="apple-mobile-web-app-title" content="Prova Social">',
)
robots_meta = '<meta name="robots" content="noindex,follow">'
if '<meta name="robots"' in index:
    index = index.replace(
        next(
            line.strip()
            for line in index.splitlines()
            if '<meta name="robots"' in line
        ),
        robots_meta,
    )
else:
    index = index.replace("</head>", f"  {robots_meta}\n</head>")
index = index.replace("<title>prova_social</title>", "<title>Prova Social</title>")
if (
    "<title>Prova Social</title>" not in index
    or robots_meta not in index
):
    raise SystemExit("Could not apply Flutter Web branding and indexing policy.")
index_path.write_text(index)

print("Flutter Web branding prepared.")

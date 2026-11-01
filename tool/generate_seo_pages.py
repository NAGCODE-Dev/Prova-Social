#!/usr/bin/env python3
"""Generate crawlable HTML pages for publicly readable exams and questions."""

import argparse
import html
import json
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__:
    from .supabase_build_config import validate
else:
    from supabase_build_config import validate

SITE_ORIGIN = "https://prova-social.pages.dev"
PAGE_SIZE = 50
SITEMAP_CHUNK_SIZE = 40_000
SITEMAP_NAMESPACE = "http://www.sitemaps.org/schemas/sitemap/0.9"
GENERATED_START = "# BEGIN GENERATED SEO ROUTES"
GENERATED_END = "# END GENERATED SEO ROUTES"
EXAM_SELECT = (
    "id,title,description,category,source_name,source_type,source_url,year,"
    "updated_at,questions(id,position,topic,statement,options)"
)


def _read_public_exams(config: dict[str, str]) -> list[dict[str, Any]]:
    base_url = config["SUPABASE_URL"].rstrip("/") + "/rest/v1/exams"
    key = config["SUPABASE_PUBLISHABLE_KEY"]
    exams: list[dict[str, Any]] = []
    offset = 0

    while True:
        query = urllib.parse.urlencode(
            {
                "select": EXAM_SELECT,
                "status": "eq.published",
                "is_public": "eq.true",
                "order": "created_at.asc,id.asc",
                "questions.order": "position.asc",
                "limit": str(PAGE_SIZE),
                "offset": str(offset),
            }
        )
        request = urllib.request.Request(
            f"{base_url}?{query}",
            headers={
                "Accept": "application/json",
                "apikey": key,
                "Authorization": f"Bearer {key}",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                rows = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"Falha ao consultar o catálogo público do Supabase "
                f"({type(error).__name__})."
            ) from error

        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise RuntimeError("A consulta do catálogo público retornou um formato inválido.")
        exams.extend(rows)
        if len(rows) < PAGE_SIZE:
            return exams
        offset += len(rows)


def _safe_id(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    try:
        return str(uuid.UUID(value))
    except ValueError:
        return None


def _text(value: object) -> str:
    if not isinstance(value, str):
        return ""
    return " ".join(value.split())


def _escape(value: object) -> str:
    return html.escape(_text(value), quote=True)


def _safe_source_url(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        return None
    return value.strip()


def _source_label(value: object) -> str:
    return {
        "official": "Fonte oficial",
        "community": "Enviado pela comunidade",
        "unverified": "Fonte não verificada",
    }.get(value, "Fonte não verificada")


def _question_options(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    options = []
    for option in value:
        text = option.get("text", "") if isinstance(option, dict) else option
        normalized = _text(text)
        if normalized:
            options.append(normalized)
    return options


def _description(value: str, limit: int = 180) -> str:
    normalized = _text(value)
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 1].rsplit(" ", 1)[0] + "…"


def _json_ld(value: dict[str, Any]) -> str:
    return (
        json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        .replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("&", "\\u0026")
    )


def _last_modified(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).date().isoformat()


def _page_head(title: str, description: str, canonical: str, schema: dict[str, Any]) -> str:
    escaped_title = _escape(title)
    escaped_description = _escape(description)
    escaped_canonical = _escape(canonical)
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="theme-color" content="#101311">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <title>{escaped_title}</title>
  <meta name="description" content="{escaped_description}">
  <link rel="canonical" href="{escaped_canonical}">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <meta property="og:type" content="article">
  <meta property="og:locale" content="pt_BR">
  <meta property="og:site_name" content="Prova Social">
  <meta property="og:title" content="{escaped_title}">
  <meta property="og:description" content="{escaped_description}">
  <meta property="og:url" content="{escaped_canonical}">
  <meta name="twitter:card" content="summary">
  <script type="application/ld+json">{_json_ld(schema)}</script>
  <link rel="stylesheet" href="/styles.css">
  <style>
    .public-page{{max-width:820px;margin:0 auto;padding:24px 18px 56px}}
    .public-header{{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px 18px;border-bottom:1px solid #2a302c}}
    .public-header a{{color:#69cca4}}
    .public-page nav{{font-size:.85rem;color:#aab2ac;margin:16px 0 26px}}
    .public-page nav a{{color:#69cca4}}
    .public-page h1{{font-size:clamp(1.8rem,6vw,2.7rem);line-height:1.12;margin:10px 0}}
    .public-meta{{display:flex;flex-wrap:wrap;gap:8px 14px;color:#aab2ac;font-size:.9rem;margin:14px 0 24px}}
    .public-content{{background:#181c19;border:1px solid #2a302c;border-radius:14px;padding:18px;margin:16px 0;line-height:1.65;overflow-wrap:anywhere}}
    .public-content li{{padding:7px 0}}
    .public-cta{{display:inline-flex;align-items:center;justify-content:center;min-height:48px;margin:18px 0;padding:0 18px;border-radius:10px;background:#16a36a;color:#052017;font-weight:700}}
    .public-note{{color:#aab2ac;font-size:.88rem}}
    @media(min-width:700px){{.public-page{{padding-top:38px}}.public-content{{padding:24px}}}}
  </style>
</head>"""


def _schema_page(name: str, description: str, canonical: str, breadcrumbs: list[tuple[str, str]]) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": name,
        "description": description,
        "url": canonical,
        "inLanguage": "pt-BR",
        "breadcrumb": {
            "@type": "BreadcrumbList",
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": position,
                    "name": label,
                    "item": url,
                }
                for position, (label, url) in enumerate(breadcrumbs, 1)
            ],
        },
    }


def _write_exam_pages(
    site_dir: Path,
    exam: dict[str, Any],
    exam_id: str,
) -> tuple[list[str], list[str], str | None]:
    title = _text(exam.get("title"))
    if not title:
        return [], [], None
    category = _text(exam.get("category"))
    source = _text(exam.get("source_name")) or "Fonte não informada"
    year = exam.get("year")
    year_label = str(year) if isinstance(year, int) else ""
    description = _description(
        _text(exam.get("description"))
        or f"{title} — prova de {category}, publicada no Prova Social."
    )
    exam_url = f"{SITE_ORIGIN}/provas/{exam_id}"
    app_url = f"/app/provas/{exam_id}"
    questions = exam.get("questions")
    if not isinstance(questions, list):
        questions = []

    exam_path = site_dir / "seo-generated" / "provas" / exam_id / "index.html"
    exam_path.parent.mkdir(parents=True, exist_ok=True)
    schema = _schema_page(
        title,
        description,
        exam_url,
        [("Início", SITE_ORIGIN + "/"), (title, exam_url)],
    )
    question_links = []
    urls = [exam_url]
    routes = [f"/provas/{exam_id} /seo-generated/provas/{exam_id}/index.html 200"]
    for question in questions:
        if not isinstance(question, dict):
            continue
        question_id = _safe_id(question.get("id"))
        if question_id is None:
            continue
        position = question.get("position")
        if not isinstance(position, int) or position < 1:
            continue
        question_url = f"{exam_url}/questoes/{question_id}"
        question_title = f"{title} — Questão {position} | Prova Social"
        question_description = _description(_text(question.get("statement")))
        options = _question_options(question.get("options"))
        question_path = (
            site_dir
            / "seo-generated"
            / "provas"
            / exam_id
            / "questoes"
            / f"{question_id}.html"
        )
        question_path.parent.mkdir(parents=True, exist_ok=True)
        question_schema = _schema_page(
            question_title,
            question_description,
            question_url,
            [
                ("Início", SITE_ORIGIN + "/"),
                (title, exam_url),
                (f"Questão {position}", question_url),
            ],
        )
        options_html = "".join(
            f"<li><strong>{chr(65 + index)}.</strong> {_escape(option)}</li>"
            for index, option in enumerate(options)
        )
        statement = _escape(question.get("statement"))
        topic = _escape(question.get("topic"))
        question_html = (
            _page_head(
                question_title,
                question_description,
                question_url,
                question_schema,
            )
            + f"""
<body>
  <header class="public-header"><a href="/" aria-label="Prova Social, início">Prova Social</a><a href="{app_url}">Abrir no app</a></header>
  <main class="public-page">
    <nav aria-label="Trilha de navegação"><a href="/">Início</a> / <a href="{exam_url}">{_escape(title)}</a> / Questão {position}</nav>
    <p class="eyebrow">{_escape(category)}</p>
    <h1>{_escape(title)} — Questão {position}</h1>
    <div class="public-meta"><span>{_escape(_source_label(exam.get("source_type")))}</span><span>{_escape(source)}{f" · {year_label}" if year_label else ""}</span>{f"<span>{topic}</span>" if topic else ""}</div>
    <section class="public-content" aria-labelledby="question-title">
      <h2 id="question-title">Enunciado</h2>
      <p>{statement}</p>
      {f"<h2>Alternativas</h2><ol type='A'>{options_html}</ol>" if options_html else ""}
    </section>
    <p class="public-note">Conteúdo público da comunidade Prova Social. A resposta correta não é exibida nesta página.</p>
    <a class="public-cta" href="{app_url}">Abrir questão e discussão no app</a>
  </main>
</body>
</html>
"""
        )
        question_path.write_text(question_html, encoding="utf-8")
        urls.append(question_url)
        routes.append(
            f"/provas/{exam_id}/questoes/{question_id} "
            f"/seo-generated/provas/{exam_id}/questoes/{question_id}.html 200"
        )
        question_links.append(
            f'<li><a href="/provas/{exam_id}/questoes/{question_id}">'
            f"Questão {position}: {_escape(question.get('topic') or 'Geral')}</a></li>"
        )

    description_html = (
        f'<p class="public-content">{_escape(exam.get("description"))}</p>'
        if _text(exam.get("description"))
        else ""
    )
    source_url = _safe_source_url(exam.get("source_url"))
    source_html = (
        f'<p><a href="{_escape(source_url)}" target="_blank" rel="noopener noreferrer">Consultar fonte original</a></p>'
        if source_url
        else ""
    )
    exam_html = (
        _page_head(
            title,
            description,
            exam_url,
            schema,
        )
        + f"""
<body>
  <header class="public-header"><a href="/" aria-label="Prova Social, início">Prova Social</a><a href="{app_url}">Abrir no app</a></header>
  <main class="public-page">
    <nav aria-label="Trilha de navegação"><a href="/">Início</a> / {_escape(title)}</nav>
    <p class="eyebrow">{_escape(category)}</p>
    <h1>{_escape(title)}</h1>
    <div class="public-meta"><span>{_escape(_source_label(exam.get("source_type")))}</span><span>{_escape(source)}{f" · {year_label}" if year_label else ""}</span><span>{len(urls) - 1} questões</span></div>
    {description_html}
    {source_html}
    <h2>Questões desta prova</h2>
    <section class="public-content"><ol>{''.join(question_links)}</ol></section>
    <a class="public-cta" href="{app_url}">Resolver prova no app</a>
  </main>
</body>
</html>
"""
    )
    exam_path.write_text(exam_html, encoding="utf-8")
    return urls, routes, _last_modified(exam.get("updated_at"))


def _write_sitemaps(site_dir: Path, entries: list[tuple[str, str | None]]) -> None:
    namespace = f"{{{SITEMAP_NAMESPACE}}}"
    ET.register_namespace("", SITEMAP_NAMESPACE)
    chunks = [
        entries[index : index + SITEMAP_CHUNK_SIZE]
        for index in range(0, len(entries), SITEMAP_CHUNK_SIZE)
    ] or [[]]
    sitemap_files = []
    for index, chunk in enumerate(chunks, 1):
        root = ET.Element(namespace + "urlset")
        for url, last_modified in chunk:
            item = ET.SubElement(root, namespace + "url")
            ET.SubElement(item, namespace + "loc").text = url
            if last_modified:
                ET.SubElement(item, namespace + "lastmod").text = last_modified
        filename = f"sitemap-{index}.xml"
        (site_dir / filename).write_bytes(
            ET.tostring(root, encoding="utf-8", xml_declaration=True)
        )
        sitemap_files.append(filename)

    for old_file in site_dir.glob("sitemap-*.xml"):
        if re.fullmatch(r"sitemap-\d+\.xml", old_file.name) and old_file.name not in sitemap_files:
            old_file.unlink()

    if len(sitemap_files) == 1:
        root = ET.parse(site_dir / sitemap_files[0]).getroot()
        (site_dir / "sitemap.xml").write_bytes(
            ET.tostring(root, encoding="utf-8", xml_declaration=True)
        )
        return

    root = ET.Element(namespace + "sitemapindex")
    for filename in sitemap_files:
        sitemap = ET.SubElement(root, namespace + "sitemap")
        ET.SubElement(sitemap, namespace + "loc").text = f"{SITE_ORIGIN}/{filename}"
    (site_dir / "sitemap.xml").write_bytes(
        ET.tostring(root, encoding="utf-8", xml_declaration=True)
    )


def _write_redirects(site_dir: Path, routes: list[str]) -> None:
    path = site_dir / "_redirects"
    lines = path.read_text(encoding="utf-8").splitlines()
    cleaned = []
    inside_generated_block = False
    for line in lines:
        if line == GENERATED_START:
            inside_generated_block = True
            continue
        if line == GENERATED_END:
            inside_generated_block = False
            continue
        if not inside_generated_block:
            cleaned.append(line)
    if inside_generated_block:
        raise RuntimeError("Bloco gerado de rotas SEO está incompleto em site/_redirects.")

    if not routes:
        path.write_text("\n".join(cleaned).rstrip() + "\n", encoding="utf-8")
        return

    fallback_index = next(
        (index for index, line in enumerate(cleaned) if line.startswith("/provas/* ")),
        len(cleaned),
    )
    generated_block = [GENERATED_START, *routes, GENERATED_END]
    cleaned[fallback_index:fallback_index] = generated_block
    path.write_text("\n".join(cleaned).rstrip() + "\n", encoding="utf-8")


def generate(site_dir: Path, config: dict[str, str]) -> int:
    exams = _read_public_exams(validate(config))
    generated_root = site_dir / "seo-generated"
    if generated_root.is_symlink():
        raise RuntimeError("A pasta de páginas SEO não pode ser um link simbólico.")
    if generated_root.exists():
        shutil.rmtree(generated_root)
    generated_root.mkdir(parents=True)

    entries = [(SITE_ORIGIN + "/", None)]
    routes: list[str] = []
    generated_pages = 0
    for exam in exams:
        exam_id = _safe_id(exam.get("id"))
        if exam_id is None:
            continue
        urls, exam_routes, modified = _write_exam_pages(site_dir, exam, exam_id)
        if not urls:
            continue
        generated_pages += len(urls)
        entries.extend((url, modified) for url in urls)
        routes.extend(exam_routes)

    _write_sitemaps(site_dir, entries)
    _write_redirects(site_dir, routes)
    return generated_pages


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--site-dir", type=Path, default=Path("site"))
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        generated = generate(args.site_dir, config)
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as error:
        print(f"Falha ao gerar páginas públicas para indexação: {error}", file=sys.stderr)
        return 1
    print(f"Páginas públicas preparadas para indexação: {generated}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

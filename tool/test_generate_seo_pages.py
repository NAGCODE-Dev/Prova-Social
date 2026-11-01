import io
import json
import subprocess
import sys
import tempfile
import unittest
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

import generate_seo_pages


ROOT = Path(__file__).resolve().parents[1]
EXAM_ID = "00000000-0000-4000-8000-000000000001"
QUESTION_ID = "00000000-0000-4000-8000-000000000002"
CONFIG = {
    "SUPABASE_URL": "https://example.supabase.co",
    "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_test",
}
EXAM = {
    "id": EXAM_ID,
    "title": 'Prova <script>alert("x")</script>',
    "description": "Revisão pública & acessível.",
    "category": "Concurso",
    "source_name": "Banca",
    "source_type": "official",
    "source_url": "javascript:alert(1)",
    "year": 2025,
    "updated_at": "2026-10-30T12:30:00Z",
    "questions": [
        {
            "id": QUESTION_ID,
            "position": 1,
            "topic": "Português",
            "statement": "Qual alternativa contém <b>HTML</b>?",
            "options": [
                {"text": "Alternativa <script>alert(1)</script>"},
                {"text": "Texto & conteúdo"},
            ],
            "correct_index": 0,
        }
    ],
}


class GenerateSeoPagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary_directory.name)
        (self.site / "_redirects").write_text(
            "/app/* /app/index.html 200\n/provas/* /app/index.html 200\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_generates_escaped_public_exam_and_question_pages(self):
        with patch(
            "generate_seo_pages._read_public_exams",
            return_value=[EXAM],
        ):
            count = generate_seo_pages.generate(self.site, CONFIG)

        exam_page = (
            self.site / "seo-generated" / "provas" / EXAM_ID / "index.html"
        ).read_text(encoding="utf-8")
        question_page = (
            self.site
            / "seo-generated"
            / "provas"
            / EXAM_ID
            / "questoes"
            / f"{QUESTION_ID}.html"
        ).read_text(encoding="utf-8")
        self.assertEqual(count, 2)
        canonical = (
            '<link rel="canonical" '
            f'href="https://prova-social.pages.dev/provas/{EXAM_ID}/questoes/{QUESTION_ID}">'
        )
        self.assertIn(canonical, question_page)
        self.assertIn("Qual alternativa contém &lt;b&gt;HTML&lt;/b&gt;?", question_page)
        self.assertIn("Alternativa &lt;script&gt;alert(1)&lt;/script&gt;", question_page)
        self.assertNotIn("javascript:alert(1)", exam_page)
        self.assertNotIn("<script>alert", question_page)
        self.assertNotIn("correct_index", question_page)
        self.assertIn("Abrir questão e discussão no app", question_page)
        self.assertIn("\\u003c", question_page)

    def test_sitemap_and_routes_include_only_public_canonical_urls(self):
        with patch(
            "generate_seo_pages._read_public_exams",
            return_value=[EXAM],
        ):
            generate_seo_pages.generate(self.site, CONFIG)

        namespace = {"s": generate_seo_pages.SITEMAP_NAMESPACE}
        sitemap = ET.parse(self.site / "sitemap.xml")
        urls = [
            node.text
            for node in sitemap.findall(".//s:url/s:loc", namespace)
        ]
        self.assertEqual(
            urls,
            [
                "https://prova-social.pages.dev/",
                f"https://prova-social.pages.dev/provas/{EXAM_ID}",
                f"https://prova-social.pages.dev/provas/{EXAM_ID}/questoes/{QUESTION_ID}",
            ],
        )

        redirects = (self.site / "_redirects").read_text(encoding="utf-8")
        self.assertLess(
            redirects.index(f"/provas/{EXAM_ID} "),
            redirects.index("/provas/* "),
        )
        self.assertIn(
            f"/provas/{EXAM_ID}/questoes/{QUESTION_ID} "
            f"/seo-generated/provas/{EXAM_ID}/questoes/{QUESTION_ID}.html 200",
            redirects,
        )

    def test_regeneration_replaces_route_block_without_duplicates(self):
        with patch(
            "generate_seo_pages._read_public_exams",
            return_value=[EXAM],
        ):
            generate_seo_pages.generate(self.site, CONFIG)
            generate_seo_pages.generate(self.site, CONFIG)

        redirects = (self.site / "_redirects").read_text(encoding="utf-8")
        self.assertEqual(redirects.count(f"/provas/{EXAM_ID} "), 1)
        self.assertEqual(redirects.count(generate_seo_pages.GENERATED_START), 1)

    def test_api_query_is_public_only_and_uses_publishable_key(self):
        requests = []

        def fake_open(request, timeout):
            requests.append((request, timeout))
            return io.BytesIO(json.dumps([EXAM]).encode("utf-8"))

        with patch("generate_seo_pages.urllib.request.urlopen", fake_open):
            rows = generate_seo_pages._read_public_exams(CONFIG)

        request, timeout = requests[0]
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(request.full_url).query)
        self.assertEqual(query["status"], ["eq.published"])
        self.assertEqual(query["is_public"], ["eq.true"])
        self.assertNotIn("correct_index", query["select"][0])
        self.assertEqual(request.get_header("Apikey"), CONFIG["SUPABASE_PUBLISHABLE_KEY"])
        self.assertEqual(
            request.get_header("Authorization"),
            f"Bearer {CONFIG['SUPABASE_PUBLISHABLE_KEY']}",
        )
        self.assertEqual(timeout, 20)
        self.assertEqual(rows, [EXAM])

    def test_no_public_exams_leaves_only_the_homepage_in_sitemap(self):
        with patch("generate_seo_pages._read_public_exams", return_value=[]):
            count = generate_seo_pages.generate(self.site, CONFIG)

        namespace = {"s": generate_seo_pages.SITEMAP_NAMESPACE}
        sitemap = ET.parse(self.site / "sitemap.xml")
        urls = [
            node.text
            for node in sitemap.findall(".//s:url/s:loc", namespace)
        ]
        self.assertEqual(count, 0)
        self.assertEqual(urls, ["https://prova-social.pages.dev/"])
        redirects = (self.site / "_redirects").read_text(encoding="utf-8")
        self.assertNotIn(generate_seo_pages.GENERATED_START, redirects)

    def test_invalid_non_public_client_key_is_rejected(self):
        with patch(
            "generate_seo_pages._read_public_exams",
        ) as fetch:
            with self.assertRaises(ValueError):
                generate_seo_pages.generate(
                    self.site,
                    {
                        "SUPABASE_URL": CONFIG["SUPABASE_URL"],
                        "SUPABASE_PUBLISHABLE_KEY": "service_role_secret",
                    },
                )
        fetch.assert_not_called()

    def test_sitemap_is_sharded_before_protocol_url_limit(self):
        with patch("generate_seo_pages.SITEMAP_CHUNK_SIZE", 2):
            generate_seo_pages._write_sitemaps(
                self.site,
                [
                    ("https://prova-social.pages.dev/", None),
                    ("https://prova-social.pages.dev/provas/1", None),
                    ("https://prova-social.pages.dev/provas/2", None),
                ],
            )

        namespace = {"s": generate_seo_pages.SITEMAP_NAMESPACE}
        index = ET.parse(self.site / "sitemap.xml")
        sitemap_urls = [
            node.text for node in index.findall(".//s:sitemap/s:loc", namespace)
        ]
        self.assertEqual(
            sitemap_urls,
            [
                "https://prova-social.pages.dev/sitemap-1.xml",
                "https://prova-social.pages.dev/sitemap-2.xml",
            ],
        )

    def test_landing_and_flutter_shell_have_distinct_indexing_policies(self):
        landing = (ROOT / "site/index.html").read_text(encoding="utf-8")
        web_preparer = (ROOT / "tool/prepare_web.py").read_text(encoding="utf-8")

        self.assertIn(
            '<meta name="robots" content="index,follow,max-image-preview:large">',
            landing,
        )
        self.assertIn(
            '<link rel="canonical" href="https://prova-social.pages.dev/">',
            landing,
        )
        self.assertIn(
            "https://prova-social.pages.dev/sitemap.xml",
            (ROOT / "site/robots.txt").read_text(encoding="utf-8"),
        )
        self.assertIn('<meta name="robots" content="noindex,follow">', web_preparer)

    def test_web_preparer_marks_flutter_shell_noindex(self):
        with tempfile.TemporaryDirectory() as directory:
            web_dir = Path(directory) / "web"
            web_dir.mkdir()
            (web_dir / "manifest.json").write_text(
                json.dumps({"name": "old", "short_name": "old"}),
                encoding="utf-8",
            )
            (web_dir / "index.html").write_text(
                """<!doctype html>
<html><head>
<meta name="description" content="A new Flutter project.">
<meta name="apple-mobile-web-app-title" content="prova_social">
<title>prova_social</title>
</head></html>
""",
                encoding="utf-8",
            )

            result = subprocess.run(
                [sys.executable, str(ROOT / "tool/prepare_web.py")],
                cwd=directory,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            index = (web_dir / "index.html").read_text(encoding="utf-8")
            manifest = json.loads((web_dir / "manifest.json").read_text())
            self.assertIn('<meta name="robots" content="noindex,follow">', index)
            self.assertIn("<title>Prova Social</title>", index)
            self.assertIn('<html lang="pt-BR">', index)
            self.assertIn('<meta name="theme-color" content="#050907">', index)
            self.assertIn('id="prova-social-shell"', index)
            self.assertIn("background: #050907;", index)
            self.assertIn('color-scheme: dark;', index)
            self.assertIn('<link rel="manifest" href="manifest.json">', index)
            self.assertIn(
                '<link rel="icon" type="image/png" href="favicon.png">', index
            )
            self.assertIn(
                '<link rel="apple-touch-icon" href="icons/Icon-192.png">', index
            )
            self.assertEqual(manifest["name"], "Prova Social")
            self.assertEqual(manifest["short_name"], "Prova Social")
            self.assertEqual(manifest["background_color"], "#050907")
            self.assertEqual(manifest["theme_color"], "#050907")
            self.assertEqual(manifest["orientation"], "portrait-primary")
            self.assertEqual(
                [icon["src"] for icon in manifest["icons"]],
                [
                    "icons/Icon-192.png",
                    "icons/Icon-512.png",
                    "icons/Icon-maskable-192.png",
                    "icons/Icon-maskable-512.png",
                ],
            )

    def test_web_preparer_is_idempotent_and_keeps_flutter_base_href(self):
        scaffold = """<!doctype html>
<html><head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="prova_social">
  <link rel="manifest" href="manifest.json">
  <title>prova_social</title>
</head><body></body></html>
"""
        with tempfile.TemporaryDirectory() as directory:
            web_dir = Path(directory) / "web"
            web_dir.mkdir()
            (web_dir / "index.html").write_text(scaffold, encoding="utf-8")
            (web_dir / "manifest.json").write_text(
                json.dumps({"name": "prova_social", "short_name": "prova_social"}),
                encoding="utf-8",
            )

            for _ in range(2):
                result = subprocess.run(
                    [sys.executable, str(ROOT / "tool/prepare_web.py")],
                    cwd=directory,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            index = (web_dir / "index.html").read_text(encoding="utf-8")
            self.assertIn('<base href="$FLUTTER_BASE_HREF">', index)
            self.assertIn(
                '<meta name="viewport" content="width=device-width, '
                'initial-scale=1.0, viewport-fit=cover">',
                index,
            )
            for tag in (
                '<meta name="theme-color"',
                '<meta name="robots"',
                '<meta name="description"',
                '<link rel="manifest"',
                'id="prova-social-shell"',
            ):
                self.assertEqual(index.count(tag), 1, tag)

            manifest = json.loads((web_dir / "manifest.json").read_text())
            self.assertEqual(len(manifest["icons"]), 4)

    def test_workflow_generates_seo_pages_after_building_the_site(self):
        workflow = (ROOT / ".github/workflows/flutter-ci.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("python3 tool/generate_seo_pages.py", workflow)
        self.assertEqual(workflow.count("python3 tool/generate_seo_pages.py"), 1)
        self.assertIn('--config "$RUNNER_TEMP/prova-social-supabase.json"', workflow)


if __name__ == "__main__":
    unittest.main()

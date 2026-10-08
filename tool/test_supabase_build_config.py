#!/usr/bin/env python3
"""Tests local and Actions config injection without using real credentials."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from supabase_build_config import validate, write_from_environment


ROOT = Path(__file__).resolve().parents[1]
URL = "https://example-project.supabase.co"
KEY = "sb_publishable_test_fixture"


class SupabaseBuildConfigTests(unittest.TestCase):
    def test_valid_client_configuration(self):
        self.assertEqual(
            validate({"SUPABASE_URL": URL, "SUPABASE_PUBLISHABLE_KEY": KEY}),
            {"SUPABASE_URL": URL, "SUPABASE_PUBLISHABLE_KEY": KEY},
        )

    def test_url_missing_or_invalid(self):
        for url in ("", "not-a-url", "http://example-project.supabase.co"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate({"SUPABASE_URL": url, "SUPABASE_PUBLISHABLE_KEY": KEY})

    def test_key_missing_empty_or_administrative(self):
        for key in (None, "", "sb_secret_fixture"):
            with self.subTest(key="empty" if not key else "secret"), self.assertRaises(ValueError):
                validate({"SUPABASE_URL": URL, "SUPABASE_PUBLISHABLE_KEY": key})

    def test_github_environment_writes_only_public_config(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "supabase.json"
            previous = {name: os.environ.get(name) for name in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY")}
            try:
                os.environ["SUPABASE_URL"] = URL
                os.environ["SUPABASE_PUBLISHABLE_KEY"] = KEY
                write_from_environment(output)
            finally:
                for name, value in previous.items():
                    if value is None:
                        os.environ.pop(name, None)
                    else:
                        os.environ[name] = value
            self.assertEqual(set(json.loads(output.read_text())), {"SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"})
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_local_wrapper_passes_file_to_flutter_without_printing_values(self):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            config = temp / "local.json"
            config.write_text(json.dumps({"SUPABASE_URL": URL, "SUPABASE_PUBLISHABLE_KEY": KEY}))
            mock_bin = temp / "bin"
            mock_bin.mkdir()
            capture = temp / "flutter-args.txt"
            flutter = mock_bin / "flutter"
            flutter.write_text(
                "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"$CAPTURE_ARGS\"\n"
            )
            flutter.chmod(0o755)
            env = os.environ.copy()
            env.update({
                "SUPABASE_CONFIG_FILE": str(config),
                "CAPTURE_ARGS": str(capture),
                "PATH": f"{mock_bin}{os.pathsep}{env['PATH']}",
            })
            result = subprocess.run(
                [str(ROOT / "tool/flutter_with_supabase.sh"), "run", "-d", "test-device"],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            args = capture.read_text().splitlines()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f"--dart-define-from-file={config}", args)
            self.assertIn("--dart-define=APP_ENV=desenvolvimento", args)
            self.assertNotIn(KEY, "\n".join(args))
            self.assertNotIn(KEY, result.stdout + result.stderr)

    def test_ci_workflow_uses_same_config_for_release_builds(self):
        workflow = (ROOT / ".github/workflows/flutter-ci.yml").read_text()
        self.assertIn("SUPABASE_URL: ${{ secrets.SUPABASE_URL }}", workflow)
        self.assertIn("SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}", workflow)
        self.assertGreaterEqual(workflow.count("--write-from-environment"), 3)
        self.assertGreaterEqual(workflow.count("--dart-define-from-file=\"$RUNNER_TEMP/prova-social-supabase.json\""), 4)
        self.assertNotIn("--dart-define=SUPABASE_URL=", workflow)
        self.assertNotIn("--dart-define=SUPABASE_PUBLISHABLE_KEY=", workflow)

    def test_local_file_is_ignored_and_example_is_template_only(self):
        gitignore = (ROOT / ".gitignore").read_text()
        example = json.loads((ROOT / ".env.supabase.json.example").read_text())
        self.assertIn(".env.supabase.json", gitignore)
        self.assertIn("seu-project-ref", example["SUPABASE_URL"])
        self.assertIn("REPLACE_WITH", example["SUPABASE_PUBLISHABLE_KEY"])


if __name__ == "__main__":
    unittest.main(verbosity=2)

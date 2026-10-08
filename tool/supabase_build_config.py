#!/usr/bin/env python3
"""Validates the public Supabase config and writes it for Flutter dart-defines."""

import argparse
import base64
import json
import os
import sys
from pathlib import Path
from urllib.parse import urlparse


REQUIRED_KEYS = {"SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"}


def _valid_client_key(value: str) -> bool:
    if value.startswith("sb_publishable_"):
        return len(value) > len("sb_publishable_")
    parts = value.split(".")
    if len(parts) != 3 or not parts[0].startswith("eyJ"):
        return False
    try:
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
    except (ValueError, json.JSONDecodeError):
        return False
    return isinstance(claims, dict) and claims.get("role") == "anon"


def validate(config: object) -> dict[str, str]:
    if not isinstance(config, dict) or set(config) != REQUIRED_KEYS:
        raise ValueError(
            "O arquivo deve conter somente SUPABASE_URL e "
            "SUPABASE_PUBLISHABLE_KEY."
        )
    url = config["SUPABASE_URL"]
    key = config["SUPABASE_PUBLISHABLE_KEY"]
    if not isinstance(url, str) or not url.strip():
        raise ValueError("SUPABASE_URL ausente.")
    parsed = urlparse(url)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("SUPABASE_URL deve ser HTTPS e não conter credenciais.")
    if not isinstance(key, str) or not key.strip():
        raise ValueError("SUPABASE_PUBLISHABLE_KEY ausente.")
    if not _valid_client_key(key):
        raise ValueError(
            "SUPABASE_PUBLISHABLE_KEY inválida; use sb_publishable_ ou anon legada."
        )
    return {"SUPABASE_URL": url, "SUPABASE_PUBLISHABLE_KEY": key}


def write_from_environment(output_path: Path) -> None:
    config = validate(
        {
            name: os.environ.get(name, "")
            for name in REQUIRED_KEYS
        }
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    temporary_path.chmod(0o600)
    temporary_path.replace(output_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate", type=Path)
    mode.add_argument("--write-from-environment", type=Path)
    args = parser.parse_args()
    try:
        if args.validate:
            validate(json.loads(args.validate.read_text(encoding="utf-8")))
        else:
            write_from_environment(args.write_from_environment)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"Configuração Supabase inválida: {error}", file=sys.stderr)
        return 1
    print("Configuração Supabase válida (valores não exibidos).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

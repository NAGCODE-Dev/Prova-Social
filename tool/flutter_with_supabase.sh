#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${SUPABASE_CONFIG_FILE:-$repo_root/.env.supabase.json}"

if [[ ! -f "$config_file" ]]; then
  echo "Configuração local ausente: $config_file" >&2
  echo "Copie .env.supabase.json.example para .env.supabase.json e configure os dois valores públicos." >&2
  exit 2
fi

python3 "$repo_root/tool/supabase_build_config.py" --validate "$config_file" >/dev/null

if (($# == 0)); then
  set -- run
fi

exec flutter "$@" \
  "--dart-define-from-file=$config_file" \
  --dart-define=APP_ENV=desenvolvimento

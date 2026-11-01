#!/bin/sh
set -eu

cluster_root=/tmp/prova_social_postgres_5433_local
data_dir="$cluster_root/data"
socket_dir="$cluster_root/socket"
log_file="$cluster_root/postgresql.log"
port=5433
pg_bindir=$(pg_config --bindir)

if [ ! -x "$pg_bindir/initdb" ] || [ ! -x "$pg_bindir/pg_ctl" ]; then
  echo "Binários PostgreSQL ausentes em $pg_bindir. Instale o pacote do servidor PostgreSQL." >&2
  exit 1
fi
PATH="$pg_bindir:$PATH"
export PATH

if [ "$(id -u)" -eq 0 ]; then
  echo "Execute este teste como seu usuário normal, sem sudo." >&2
  exit 1
fi

if [ "${data_dir}" != /tmp/prova_social_postgres_5433_local/data ]; then
  echo "Diretório de dados inesperado; inicialização recusada." >&2
  exit 1
fi

mkdir -p "$data_dir" "$socket_dir"
chmod 700 "$data_dir"
chmod 770 "$socket_dir"

if [ -f "$data_dir/PG_VERSION" ] && [ ! -s "$data_dir/global/pg_control" ]; then
  echo "Cluster local incompleto: global/pg_control ausente. Preserve o diretório para diagnóstico antes de recriar o ambiente descartável." >&2
  exit 1
fi

if [ ! -f "$data_dir/PG_VERSION" ]; then
  if [ -n "$(find "$data_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Diretório não vazio sem PG_VERSION; inicialização recusada." >&2
    exit 1
  fi
  initdb -D "$data_dir" --username=postgres --encoding=UTF8 --locale=C \
    --auth-local=trust --auth-host=reject
  cat >>"$data_dir/postgresql.conf" <<EOF
port = $port
# Tests connect over the private Unix socket only; do not open a TCP port.
listen_addresses = ''
unix_socket_directories = '$socket_dir'
fsync = off
synchronous_commit = off
full_page_writes = off
EOF
fi

# Keep an existing disposable cluster compatible with socket-only execution.
sed -i "s/^listen_addresses = .*/listen_addresses = ''/" "$data_dir/postgresql.conf"
if ! grep -q '^listen_addresses = ' "$data_dir/postgresql.conf"; then
  printf "\nlisten_addresses = ''\n" >>"$data_dir/postgresql.conf"
fi

if pg_ctl -D "$data_dir" status >/dev/null 2>&1; then
  echo "PostgreSQL local já está ativo na porta $port."
  exit 0
fi

pg_ctl -D "$data_dir" -l "$log_file" -w start
echo "PostgreSQL local iniciado: socket=$socket_dir porta=$port"
